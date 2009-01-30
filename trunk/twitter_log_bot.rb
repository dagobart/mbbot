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
#    @account_data = YAML::load( File.open( 'twitterbot.yaml' ) )
    @account_data = YAML::load( File.open( 'my-twitterbot.yaml' ) )

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
end

class TwitterFriending
  def initialize(connector)
    @connection = connector.connection
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
    result = []
    @connection.followers.collect { |follower| result << follower.screen_name }

    return result
  end

  def friend_names
    result = []
    @connection.friends.collect { |friend| result << friend.screen_name }

    return result
  end

  def user_names(users)
    users.collect { |user| user.screen_name }
  end
end

class TwitterTalk
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
#     @connection.update('Just learned how to make the ID of the latest processed received message sticky (persistent).')
#     @connection.update('')
  end

  def shutdown
#     self.twitter_latest_received = (1158336453 + 5)
    yaml_file = File.open( LATEST_TWEED_ID_PERSISTENCY_FILE, 'w' )
    yaml_file.write(@latest_tweeds.to_yaml)
    yaml_file.close
  end

  def twitter_latest_received
    @latest_tweeds['inbox_latest']['twitter']
  end

  def twitter_latest_received=(new_latest_ID)
    @latest_tweeds['inbox_latest']['twitter'] = new_latest_ID
  end

  def get_latest_replies
#     @connection.replies(:since_id => 1158336453).collect { |reply|
    @connection.replies(:since_id => twitter_latest_received).collect { |reply|
      [
        reply.created_at,
        reply.id,
        reply.user.screen_name,
        reply.text
      ]
    }
  end
end

connector = TwitterConnector.new
friending = TwitterFriending.new(connector)
talk = TwitterTalk.new(connector)

# puts "friends: #{friending.friend_names.join(', ')}"
# puts "followers: #{friending.follower_names.join(', ')}"
# puts "new followers: #{friending.new_followers.join(', ')}"
# puts "lost followers: #{friending.lost_followers.join(', ')}"

friending.catch_up_with_followers

talk.get_latest_replies.each do |msg|
  puts "#{msg[0]}/#{msg[1]}: #{msg[2]}: #{msg[3]}"
end

talk.shutdown
#     @connection.replies(:since_id => 1158336453).each do |s|
#       puts "#{s.created_at}/#{s.id}: #{s.user.screen_name}: #{s.text}"
#     end

# todo:
# + store somewhere the ID of the latest received message(s), so we won't
#   reread them again and again
# + add functionality to read/post updates
# + Don't attempt to follow back any users whose accounts are under Twitter
#   investigation, such as @michellegggssee.
#   . a bot service that determines spam bot followers (followees?) would be
#     nice
# + add tests
# + make sure that if users change their screen names, nothing is going to break
