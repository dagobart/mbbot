require 'rubygems'
gem('twitter', '>=0.4.1')
require 'twitter'
require 'yaml'

# After tons of hassles with disrupted Ruby/Rails/RubyGems installations --
# http://is.gd/hvM9 -- I gave in and gave another Debian Ruby/Rails a try,
# that is Debian Lenny's Ruby. Currently -- that is just before release of
# Debian Lenny -- if not perfect, it looks usable. I hope backports.org will
# keep us up to date with Ruby/Rails/RubyGems once Lenny's released.
#
# To get this here Twitter bot up and running, additionally to the default
# Debian ruby package, you need the following:
#
# deb: ruby-dev => mkmf
# gem: twitter => core gem
#      echoe => fix rubygems

# Note: Before you can exec any Twitter interactions through the connection,
# you need to update +twitterbot.yaml+ with valid credentials.
#
class TwitterConnector
  def initialize
    @account_data = YAML::load( File.open( 'twitterbot.yaml' ) )
#     @account_data = YAML::load( File.open( 'my-twitterbot.yaml' ) )

    # ensure that you're about to use non-default -- read: not known to the
    # world --  login data:
    if (password == 'secret')
      raise StandardError,
           "Please, use a serious password (or some other config but twitterbot.yaml)!"
    end

    @connection = Twitter::Base.new(user, password)
  end

  attr_reader :connection

  # Currently, Twitter alternatives don't actually get used; +service_in_use+
  # is only about what the config file says.
  def service_in_use
    @account_data['account']['service']
  end

  def user
    @account_data[service_in_use]['user']
  end

  def password
    @account_data[service_in_use]['password']
  end

  def errmsg(error)
    return "#{service_in_use} is refusing to perform the desired action for us." if error == Twitter::CantConnect
    "#{service_in_use} is refusing to perform the desired action for us."
  end
end

class TwitterFriending
  def initialize(connector)
    @connection = connector.connection
  end

  # for some unknown reason, this method causes Twitter to hiccup in reply,
  # i.e. answer by: 400: Bad Request (Twitter::CantConnect)
  def follower_stats
    "friends:        #{friend_names.join(', ')}\n" +
    "followers:      #{follower_names.join(', ')}\n" +
    "new followers:  #{new_followers.join(', ')}\n" +
    "followers gone: #{lost_followers.join(', ')}"
  end

  def catch_up_with_followers
    # follow back everyone we don't [follow back] yet:
    new_followers.each do |follower_screen_name|
      puts "following back #{follower_screen_name}"
      follow(follower_screen_name)
    end

    # leave everyone who left us:
    lost_followers.each do |follower_screen_name|
      puts "leaving #{follower_screen_name}"
      leave(follower_screen_name)
    end
  end

  def follow(user_screen_name)
    @connection.create_friendship(user_screen_name)
    @connection.follow(user_screen_name)
  end

  def leave(user_screen_name)
    @connection.leave(user_screen_name)
    @connection.destroy_friendship(user_screen_name)
  end

  def new_followers
    follower_names - friend_names
  end

  def lost_followers
    friend_names - follower_names
  end

  def follower_names
    user_names(@connection.followers)
  end

  def friend_names
    user_names(@connection.friends)
  end

  def user_names(users)
    users.collect { |user| user.screen_name }
  end
end

class TwitterMessagingIO
  LATEST_TWEED_ID_PERSISTENCY_FILE = 'latest_tweeds.yaml'
  # Note:
  # Instead of reusing twitterbot.yaml, we currently use latest_tweeds.yaml
  # to persist the ID of the latest received tweed. Reason for not reusing
  # the twitterbot.yaml file is the risk of accidentally kill that file, thus
  # the login credentials as well.
  #
  # If you've got an idea how to improve the latest tweed ID storage, please
  # let me know. -- @dagobart/20090129
  def initialize(connector)
    @connection = connector.connection
    @latest_tweeds = YAML::load( File.open( LATEST_TWEED_ID_PERSISTENCY_FILE ) )
  end

  def say(msg)
    @connection.update(msg)
  end

  def shutdown
    yaml_file = File.open( LATEST_TWEED_ID_PERSISTENCY_FILE, 'w' )
    yaml_file.write(@latest_tweeds.to_yaml)
    yaml_file.close
  end

  def twitter_latest_received
    @latest_tweeds['inbox_latest']['twitter']
  end # fixme: use connector.service_in_use

  def twitter_latest_received=(new_latest_ID)
    @latest_tweeds['inbox_latest']['twitter'] = new_latest_ID
  end # fixme: use connector.service_in_use

  # Note: During the collect, we do temp-store the latest received message id
  # to a temporary storage +latest_message_id+ rather than using
  # twitter_latest_received(). That's for performance: Using
  # twitter_latest_received would involve the use of several hashes rather
  # than just updating a single Fixnum.
  def get_latest_replies(perform_latest_message_id_update = true)
#   twitter: 1158336453
    latest_message_id = self.twitter_latest_received

      latest_replies = @connection.replies(:since_id => latest_message_id).collect do |reply|
        # reply.pretty_inspect

        # take side-note(s):
        id = reply.id.to_i
        latest_message_id = id if (id > latest_message_id)

        # perform actual collect:
        {
           'created_at' => reply.created_at,
                   'id' => id,
          'screen_name' => reply.user.screen_name,
                 'text' => reply.text
        }
      end

    self.twitter_latest_received = latest_message_id if perform_latest_message_id_update

    return latest_replies
  end
end

class TwitterBot
  def initialize
    @connector = TwitterConnector.new
    @friending = TwitterFriending.new(@connector)
    @talk = TwitterMessagingIO.new(@connector)

    begin
      puts @friending.follower_stats
      @friending.catch_up_with_followers
    rescue Twitter::CantConnect
      puts @connector.errmsg(Twitter::CantConnect)
    end
  end

  def operate
#     @talk.say "Prior to perform the second echo test, I want to figure out how to reply to a /certain/ message, i.e. use and keep threading intact"
    process_latest_received
  end

  def process_latest_received
    do_not_update = false

    @talk.get_latest_replies(do_not_update).each do |msg|
#       puts "#{msg['created_at']}/#{msg['id']}: #{msg['screen_name']}: #{msg['text']}"
      echo_back(msg)
    end
  end

  # + add Pong kind of echo reply
  def echo_back(msg)
    timestamp = msg['created_at']; timestamp.gsub!(/ \+0000/, '')
    text = msg['text']; text.sub!(/^@logbot\s+/, '')
    answer = "@#{msg['screen_name']}: [echo:] On #{ timestamp } you asked me: #{ text }"
    answer = "#{answer[1,137]}..." if answer.length > 140
    puts answer
#       @talk.say(answer)
  end

  # actually, I didn't grasp Ruby finalizing. If you do feel free to implement
  # a better solution than this need to call shutdown explicitly each time.
  def shutdown
    @talk.shutdown
  end
end

bot = TwitterBot.new
bot.operate
bot.shutdown

# todo:
# + keep the ID of the latest received message(s) up to date, so persistent
#   storing of it will work correctly.
# + add functionality to read/post updates
# + Don't attempt to follow back any users whose accounts are under Twitter
#   investigation, such as @michellegggssee.
#   . a bot service that determines spam bot followers (followees?) would be
#     nice
# + add tests
# + make sure that if users change their screen names, nothing is going to
#   break
# + learn to deal with errors like this: "in `handle_response!': Twitter is
#   returning a 400: Bad Request (Twitter::CantConnect)" -- which actually
#   can be (witnessed!) some fail whale thing at the other end, cf. commit
#   #10, which *looked* broken because of that error, though after getting a
#   new IP address, it was gone, ie. it indeed was a fail of Twitter, not of
#   the bot code.
