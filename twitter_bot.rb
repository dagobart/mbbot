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
    config_file = 'my-twitterbot.yaml'
    config_file = 'twitterbot.yaml'
    @account_data = YAML::load(File.open(config_file))

    # ensure that you're about to use non-default -- read: not known to the
    # world --  login data:
    if (password == 'secret')
      raise StandardError,
           "Please, use a serious password (or some other config but twitterbot.yaml)!"
    end

    service = service_in_use.downcase
    if service == 'twitter' then
      @connection = Twitter::Base.new(user, password)
      puts "You're using Twitter. Expect glitches."
    elsif service == 'identica'
      @connection = Twitter::Base.new(user, password, :api_host => 'identi.ca/api')
    else
      raise Twitter::CantConnect,
      	   "#{config_file}: Unknown micro-blogging service provider '#{service}'. No idea how to connect to that one."
    end

    @user_id = @connection.user(user).id   # ; puts @user_id; exit
  end

  attr_reader :connection, :user_id

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
    @connector = connector
    @connection = @connector.connection
    @latest_tweeds = YAML::load( File.open( LATEST_TWEED_ID_PERSISTENCY_FILE ) )
  end

  def say(msg)
    @connection.update(msg)
  end

  # chances are that Twitter needs both pieces of data, in_reply_to_status_id
  # and in_reply_to_user_id to get the message threading right. (You can
  # verify that by having a look at the look of the bot's replies within its
  # Twitter web page: If there's a "in reply to" threading got through, i.e.
  # got applied -- otherwise not.)
  def reply(msg, in_reply_to_status_id = nil, in_reply_to_user_id = nil)
    if in_reply_to_status_id && in_reply_to_user_id then
      @connection.update(msg, {
      				:in_reply_to_status_id => in_reply_to_status_id,
        			  :in_reply_to_user_id => in_reply_to_user_id
      			      }
      			)
    else
      say(msg)
    end
  end

  def shutdown
    yaml_file = File.open( LATEST_TWEED_ID_PERSISTENCY_FILE, 'w' )
    yaml_file.write(@latest_tweeds.to_yaml)
    yaml_file.close
  end

  def latest_message_received
    @latest_tweeds['inbox_latest'][@connector.service_in_use]
  end

  def latest_message_received=(new_latest_ID)
    @latest_tweeds['inbox_latest'][@connector.service_in_use] = new_latest_ID
  end

  # Note: During the collect, we do temp-store the latest received message id
  # to a temporary storage +latest_message_id+ rather than using
  # latest_message_received(). That's for performance: Using
  # latest_message_received would involve the use of several hashes rather
  # than just updating a single Fixnum.
  def get_latest_replies(perform_latest_message_id_update = true)
    latest_message_id = self.latest_message_received # 1st received on twitter: 1158336454

      latest_replies = @connection.replies(:since_id => latest_message_id).collect do |reply|
        # take side-note(s):
        id = reply.id.to_i
        latest_message_id = id if (id > latest_message_id)

        # perform actual collect:
        {
           'created_at' => reply.created_at,
                   'id' => id,
          'screen_name' => reply.user.screen_name,
                 'text' => reply.text,
              'user_id' => reply.user.id
        }
      end

    self.latest_message_received = latest_message_id if perform_latest_message_id_update

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
    # progress_message = 'Just learned how to ...'
    # progress_message = 'Due to ongoing glitches of Twitter yesterday, today I\'m going to operate on identi.ca, mainly.'
    # @talk.say(progress_message)
    process_latest_received
  end

  def process_latest_received
    begin

      @talk.get_latest_replies.each do |msg|
        echo_back(msg)
      end

    rescue Twitter::CantConnect
      puts @connector.errmsg(Twitter::CantConnect)
    end
  end

  # . Uses ~Twitter message threading, i.e. refers to the message ID we're
  #   responding to.
  # * On identi.ca, from its creation on, the bot account had itself as
  #   friend and follower. Also, whatever it posts -- e.g. replies to other
  #   users' requests -- the bot sees as replies to itself. This holds true
  #   only for identi.ca. But this would imply: Once the bot gets running
  #   continuously, it would deadlock itself by reacting on and replying to
  #   its own messages over and over again. Therefore, to avoid such, this
  #   method quits as soon as we realize we are about to talk to ourselves,
  #   i.e. the bot is going to talk to itself.
  def echo_back(msg)
        user_id = msg['user_id']; return if user_id == @connector.user_id # for identica
    screen_name = msg['screen_name']
         msg_id = msg['id']
      timestamp = msg['created_at']; timestamp.gsub!(/ \+0000/, '')
           text = msg['text'];       text.sub!(/^@logbot\s+/, '')

    if text.strip.downcase == 'ping' then
      answer = "@#{ screen_name } Pong"
    elsif text.strip.downcase == 'ping?' then
      answer = "@#{ screen_name } Pong!"
    else
      answer = "@#{ screen_name } [echo:] On #{ timestamp } you asked me:  #{ text }"
    end

    answer = "#{answer[0,136]}..." if answer.length > 140

    # puts answer, msg_id, user_id
    @talk.reply(answer, msg_id, user_id)
  end

  # actually, I didn't grasp Ruby finalizing. If you do, feel free to
  # implement a better solution than this need to call shutdown explicitly
  # each time.
  def shutdown
    @talk.shutdown
  end
end

bot = TwitterBot.new
bot.operate
bot.shutdown

# todo:
# + add tests
# + add functionality to parse/act on/answer updates
# + Don't attempt to follow back any users whose accounts are under Twitter
#   investigation, such as @michellegggssee.
#   . a bot service that determines spam bot followers (followees?) would be
#     nice
# + make sure that if users change their screen names, nothing is going to
#   break
# + learn to deal with errors like this: "in `handle_response!': Twitter is
#   returning a 400: Bad Request (Twitter::CantConnect)" -- which actually
#   can be (witnessed!) some fail whale thing at the other end, cf. commit
#   #10, which *looked* broken because of that error, though after getting a
#   new IP address, it was gone, ie. it indeed was a fail of Twitter, not of
#   the bot code.
