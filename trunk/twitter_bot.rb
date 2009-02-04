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

# Obviously, as you don't want  to be held legally responsible for any kind
# of abusive action taken through your bot account, you don't want to share
# your actual login data for the ~Twitter bot with the rest of us. Neither do
# I.
#    Hence, to the repository I check in false login data in the form of some
# yaml files, so everyone easily can get the idea of what format the yaml
# shall be in. On the other hand, I keep another set of yaml files that hold
# valid login data for the bots I am using for development.
#    As much as the next one I dislike software packages checked out somewhere
# else only to find them disrupt. Therefore, Prior to every update to the
# repository, I make sure the bot code refers to files that are actually
# there even if filled with invalid data -- the latter will be pointed out by
# mechanisms inside the bot, while the prior just leaves the inexperienced
# clueless: "What *are* these files, that error message is talking about?"
#    In the past, I eased the swap-in/swap-out process by having the another
# set of yaml files named just like those checked in to the repository, with
# the only exception that they are prepended with  a "my-".
#    Though, still the files names were hard-coded all around. This changes
# by now, collecting them all below.
#    Still the advice holds true: Copy the checked in/checked out credential
# files to some own ones, patch them to have valid credentials and make sure
# that the names of these valid files are assigned to
# VALID_TWITTER_CREDENTIALS__DO_NOT_CHECK_IN and
# VALID_IDENTICA_CREDENTIALS__DO_NOT_CHECK_IN respectively.
 INVALID_TWITTER_CREDENTIALS = 'twitterbot.yaml'
INVALID_IDENTICA_CREDENTIALS = 'identibot.yaml'
VALID_TWITTER_CREDENTIALS__DO_NOT_CHECK_IN = 'my-twitterbot.yaml'
VALID_IDENTICA_CREDENTIALS__DO_NOT_CHECK_IN = 'my-identibot.yaml'

VALID_CONNECT_CREDENTIALS__DO_NOT_CHECK_IN = 'my-bot.yaml'
INVALID_CONNECT_CREDENTIALS = INVALID_TWITTER_CREDENTIALS
DEFAULT_CONFIG_FILE = INVALID_CONNECT_CREDENTIALS

MB_SERVICE__CFG_FILE =
	{
	 'identica' => VALID_IDENTICA_CREDENTIALS__DO_NOT_CHECK_IN,
	  'twitter' =>  VALID_TWITTER_CREDENTIALS__DO_NOT_CHECK_IN
	}
KNOWN_MICRO_BLOGGING_SERVICES = MB_SERVICE__CFG_FILE.keys
KNOWN_MIN_TWEED_ID = {
		       'identica' => 2068347,
		        'twitter' => 1164876335
		     }

# As downtimes happen more often than not, we now support
# skipping down services.
#
# How to know how to initialize this hash's values?
# : If lots of tests fail with a Twitter::CantConnect
#   though you changed little or even nothing, that's an
#   indicator, that the respective micro-blogging service
#   is temporarily down. -- I experienced this mostly on
#   Twitter, never on Identi.ca -- dagobart/20090203
SERVICE_IS_AVAILABLE = {'twitter'  => true,
			'identica' => true}

MISSING_FEATURES =
    {
      'identica' => ['destroy', 'follow', 'leave'],
       'twitter' => ['destroy'] # FIXME: fix destroy()
    }
POSSIBLE_SHORTFALLS = MISSING_FEATURES.values.flatten.uniq

class MicroBlogConnector
  def initialize(config_file = DEFAULT_CONFIG_FILE)
    @account_data = YAML::load(File.open(config_file))

    # initialize read-only variables:
       @service_in_use = @account_data['account']['service']
             @username = @account_data[@service_in_use]['user']
             @password = @account_data[@service_in_use]['password']
            @peer_user = @account_data[@service_in_use]['peer'] # FIXME: add test for this
    @use_alternative_api = @account_data[@service_in_use]['use_alternative_api']

    @service_lacks = Hash.new
    POSSIBLE_SHORTFALLS.each do |possible_shortfall|
      current_service_lacks_anything = (MISSING_FEATURES[service_in_use.downcase] != nil)
      @service_lacks[possible_shortfall] = (MISSING_FEATURES[service_in_use.downcase].find_index(possible_shortfall) != nil) if current_service_lacks_anything
    end

    # ensure we're not using some intendedly invalid credentials:
    assess_account_data

      # perform actual connect:
      if use_alternative_api? then
        begin
          @connection = Twitter::Base.new(@username, @password, :api_host => @use_alternative_api)
        rescue Twitter::CantConnect
          raise Twitter::CantConnect,
        	   "#{config_file}: Failed to connect to micro-blogging service provider '#{@service_in_use}'."
        end
      else
        @connection = Twitter::Base.new(@username, @password)
      end

    # finish initializing read-only variables:
    @user_id = @connection.user(@username).id   # ; puts @user_id; exit
  end # we even could implement a reconnect()--but skip that now

  attr_reader :connection, :user_id, :use_alternative_api, :service_in_use, :service_lacks, :peer_user, :username #, :password

  def errmsg(error)
    if error == Twitter::CantConnect
      "#{@service_in_use} says it couldn't connect. Translates to: is refusing to perform the desired action for us."
    else
      "something went wrong on #{@service_in_use} with the just before intended action."
    end
  end

  def use_alternative_api?
    @use_alternative_api != nil
  end

  # forces you to use non-default -- read: not known to the
  # world --  login data
  def assess_account_data
    if (@password == 'secret')
      raise StandardError,
           "\nPlease, use a serious password (or some other config but any of the default -- and intendedly invalid -- ones)!\n"
    end
  end
end

require 'test/unit'
# require 'micro_blog_connector'
class MicroBlogConnector
  attr_reader :password
end
class TC_MicroBlogConnector < Test::Unit::TestCase
  def setup
      twitter_config_file = nil
     identica_config_file = nil

    # comment away the following two lines for check-in,
    # uncomment them for actual testing:
     twitter_config_file =
                    VALID_TWITTER_CREDENTIALS__DO_NOT_CHECK_IN
    identica_config_file =
                   VALID_IDENTICA_CREDENTIALS__DO_NOT_CHECK_IN

    service_is_available = SERVICE_IS_AVAILABLE
    if service_is_available['twitter'] then
      @twitter_connector =
                   MicroBlogConnector.new(twitter_config_file)
      @twitter_friending =
                    MicroBlogFriending.new(@twitter_connector)
    else
      @twitter_connector = nil
      @twitter_friending = nil
    end

    if service_is_available['identica'] then
      @identica_connector =
                  MicroBlogConnector.new(identica_config_file)
      @identica_friending =
                   MicroBlogFriending.new(@identica_connector)
    else
      @identica_connector = nil
      @identica_friending = nil
    end

     @connectors = [@twitter_connector, @identica_connector]
     @friendings = [@twitter_friending, @identica_friending]
     @connectors.delete(nil)
     @friendings.delete(nil)

     @connector__friending =
     		{@twitter_connector  => @twitter_friending,
     		 @identica_connector => @identica_friending}
     @connector__friending.delete(nil)
  end

  def test_initialize_in_general
    # assert false # make sure test gets executed at all

    assert_raise StandardError do MicroBlogConnector.new end
    assert_raise StandardError do
      invalid_connector = MicroBlogConnector.new('fixtures/original-twitterbot.yaml')
    end

    assert_raise Twitter::CantConnect do
      MicroBlogConnector.new('fixtures/other-enabled_with_invalid_api_URI.yaml')
    end
  end

  def test_initialize_twitter
    # assert false # make sure test gets executed at all

    # do nothing when Twitter is down:
    return if @twitter_connector == nil

    assert_equal 'twitter',  @twitter_connector.service_in_use
    assert_equal 'logbot',   @twitter_connector.username
    assert       'secret' != @twitter_connector.password
    assert_equal  nil,       @twitter_connector.use_alternative_api
    assert                  !@twitter_connector.use_alternative_api?
    assert_equal '19619847', @twitter_connector.user_id

    MISSING_FEATURES['twitter'].each do |shortfall|
      assert @twitter_connector.service_lacks[shortfall]
    end
  end

  def test_initialize_identica
    # assert false # make sure test gets executed at all

    # do nothing when Identi.ca is down:
    return if @identica_connector == nil

    assert_equal 'identica', @identica_connector.service_in_use
    assert_equal 'logbot',   @identica_connector.username
    assert       'secret' != @identica_connector.password
    assert_equal 'identi.ca/api',
                             @identica_connector.use_alternative_api
    assert                  @identica_connector.use_alternative_api?
    assert_equal '36999',    @identica_connector.user_id

    MISSING_FEATURES['identica'].each do |shortfall|
      assert @identica_connector.service_lacks[shortfall]
    end
  end

  def test_errmsg
    # assert false # make sure test gets executed at all

    @connectors.each do |connector|
      assert '' != connector.errmsg(Twitter::CantConnect)
    end
  end
end

class MicroBlogFriending
  def initialize(connector)
    @connector = connector
    @connection = @connector.connection
  end

  attr_reader :connection

  # for some unknown reason, this method causes Twitter to hiccup in reply,
  # i.e. answer by: 400: Bad Request (Twitter::CantConnect)
  def follower_stats
    "friends:        #{friend_names.join(', ')}\n" +
    "followers:      #{follower_names.join(', ')}\n" +
    "new followers:  #{new_followers.join(', ')}\n" +
    "followers gone: #{lost_followers.join(', ')}"
  end

  # +collected_messages+ is intended to ease testing [of this
  # method]:
  def catch_up_with_followers
    collected_messages = ''

    # follow back everyone we don't [follow back] yet:
    new_followers.each do |follower_screen_name|
      message = "following back #{follower_screen_name}"
      collected_messages += "#{message}\n"
      puts message
      follow(follower_screen_name)
    end

    # leave everyone who left us:
    lost_followers.each do |follower_screen_name|
      message = "leaving #{follower_screen_name}"
      collected_messages += "#{message}\n"
      puts message
      leave(follower_screen_name)
    end

    return collected_messages
  end

  def follow(user_screen_name)
    @connection.create_friendship(user_screen_name)
    @connection.follow(user_screen_name) unless @connector.service_lacks['follow']
    # FIXME: just learned that @connection.follow is a misnomer: @connection.follow means: get notified by followee's updates
  end

  def leave(user_screen_name)
    @connection.leave(user_screen_name) unless @connector.service_lacks['leave']
    @connection.destroy_friendship(user_screen_name)
    # FIXME: just learned that @connection.leave is a misnomer: @connection.leave means: get no longer notified by leaveee's updates
  end

  # Note: +user_names(@connection.followers - @connection.friends)+
  # does not work because of different object-in-memory-addresses
  # of follower/friend users, even if they have the same user ID.
  def new_followers
    follower_names - friend_names
  end

  # Note: +user_names(@connection.friends - @connection.followers)+
  # does not work because of different object-in-memory-addresses
  # of follower/friend users, even if they have the same user ID.
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

  def is_friend_with?(user_screen_name)
    @connection.friendship_exists?(@connector.username, user_screen_name)
  end # FIXME: + add test
#
#   def block_follower(user_screen_name)
#   end
end

# require 'test/unit'
# require 'micro_blog_friending'
class TC_MicroBlogFriending < Test::Unit::TestCase
  def setup
      twitter_config_file = nil
     identica_config_file = nil

    # comment away the following two lines for check-in,
    # uncomment them for actual testing:
     twitter_config_file =
                    VALID_TWITTER_CREDENTIALS__DO_NOT_CHECK_IN
    identica_config_file =
                   VALID_IDENTICA_CREDENTIALS__DO_NOT_CHECK_IN

    service_is_available = SERVICE_IS_AVAILABLE
    if service_is_available['twitter'] then
      @twitter_connector =
                   MicroBlogConnector.new(twitter_config_file)
      @twitter_friending =
                    MicroBlogFriending.new(@twitter_connector)
    else
      @twitter_connector = nil
      @twitter_friending = nil
    end

    if service_is_available['identica'] then
      @identica_connector =
                  MicroBlogConnector.new(identica_config_file)
      @identica_friending =
                   MicroBlogFriending.new(@identica_connector)
    else
      @identica_connector = nil
      @identica_friending = nil
    end

     @connectors = [@twitter_connector, @identica_connector]
     @friendings = [@twitter_friending, @identica_friending]
     @connectors.delete(nil)
     @friendings.delete(nil)

     @connector__friending =
     		{@twitter_connector  => @twitter_friending,
     		 @identica_connector => @identica_friending}
     @connector__friending.delete(nil)
  end

  def test_initialize
    @connector__friending.each do |connector, friending|
      assert_same connector.connection, friending.connection
    end
  end

  class DummyUser
    def initialize(screen_name)
      @screen_name = screen_name
    end

    attr_accessor :screen_name

    def self.generate_some
      users = []
      screen_names = []

      n = 1 + (rand * 6).to_i

        1.upto n do
          screen_name = rand.to_s
          screen_names << screen_name
          users << DummyUser.new(screen_name)
        end

      [users.uniq, screen_names.uniq]
    end
  end

  # depends on no MicroBlogFriending method => test it first
  def test_user_names
    users, expected_screen_names = DummyUser.generate_some

    @friendings.each do |f|
      assert_equal expected_screen_names, f.user_names(users)
    end
  end

  def ensure_we_follow_peer_user(connector, friending)
    peer_user = connector.peer_user

      begin
        friending.follow(peer_user)
      rescue Twitter::CantFollowUser, Twitter::AlreadyFollowing
        # this will be the case if bot's not following itself
      end

    return peer_user
  end

  # depends on no MicroBlogFriending method => test it first
  def test_follow_leave
    @connector__friending.each do |c,f|
      peer_user = ensure_we_follow_peer_user(c, f)

      assert_nothing_raised do
        f.leave(peer_user)
      end

      assert_nothing_raised do
        f.follow(peer_user)
      end
    end
  end

  # needs user_names() to be working => test that one first
  def test_friend_names
    # as long as we are testing against a live micro-blogging
    # service, its impredictable who's actually
    # following/friended, as followees can block you in the
    # middle of a test, or new ones can join, also while the
    # test is running. Therefore, the test is restricted to
    # watch out for the peer user, known to be followed by
    # the bot and also known to be following the bot also.
    @connector__friending.each do |c,f|
      peer_user = ensure_we_follow_peer_user(c, f)

      assert_nothing_raised do
        f.friend_names.select { |friend| friend == peer_user}
      end
    end
  end

  # needs user_names() to be working => test that one first
  def test_follower_names
    # as long as we are testing against a live micro-blogging
    # service, its impredictable who's actually
    # following/friended, as followees can block you in the
    # middle of a test, or new ones can join, also while the
    # test is running. Therefore, the test is restricted to
    # watch out for the peer user, known to be followed by
    # the bot and also known to be following the bot also.
    @connector__friending.each do |c,f|
      assert_nothing_raised do
        f.follower_names.select { |follower| follower == c.peer_user}
      end
    end
  end

  # needs follower_names() and friend_names() to be working
  # => test those first
  def test_new_followers
    # without controlling a second account we can't influence
    # whether or not a certain user is following us, so this
    # here test is a bit whacky, anyways:
    expected_new_follower = rand.to_s
    @friendings.each do |f|
      new_followers = f.new_followers

      assert_same Array, new_followers.class

      new_followers << expected_new_follower

      assert_equal expected_new_follower,
                   new_followers.detect { |follower|
                     follower == expected_new_follower
                   }
    end
  end

  # needs follower_names() and friend_names() to be working
  # => test those first
  def test_lost_followers
    # We can prevent someone -- e.g. the peer user -- from
    # following, but as we cannot influence they will
    # re-follow us once we stop preventing them from
    # following us, it's a bad idea to actually block the
    # peer user: After that, other tests relying on that the
    # peer user is still following us, will fail. Therefore,
    # for this here test applies the same as for
    # test_new_followers(): This here test is a bit whacky:
    expected_lost_follower = rand.to_s
    @friendings.each do |f|
      lost_followers = f.lost_followers

      assert_same Array, lost_followers.class

      lost_followers << expected_lost_follower

      assert_equal expected_lost_follower,
                   lost_followers.detect { |follower|
                     follower == expected_lost_follower
                   }
    end
  end

  # needs new_followers(), lost_followers(), follow() and
  # leave() to be working => test those first
  def test_catch_up_with_followers
    @friendings.each do |f|
      expected = ''

      f.new_followers.each do |screen_name|
        expected += "following back #{screen_name}\n"
      end

      # leave everyone who left us:
      f.lost_followers.each do |screen_name|
        expected += "leaving #{screen_name}\n"
      end

      assert_equal expected, f.catch_up_with_followers,
                   "If this fails, reason might be that followers/followees joined/left amidst the test. To achieve certainity, just rerun the test."
    end
  end

  # needs friend_names(), follower_names(),new_followers()
  # and lost_followers() to be working => test those first
  def test_follower_stats
    @friendings.each do |f|
      s = "friends:        #{f.friend_names.join(', ')}\n" +
          "followers:      #{f.follower_names.join(', ')}\n" +
          "new followers:  #{f.new_followers.join(', ')}\n" +
          "followers gone: #{f.lost_followers.join(', ')}"
      assert_equal s, f.follower_stats
    end
  end
end

class MicroBlogMessagingIO
  LATEST_TWEED_ID_PERSISTENCY_FILE = 'latest_tweeds.yaml'
  # Note:
  # Instead of re-using the login credentials file named by
  # +VALID_CONNECT_CREDENTIALS__DO_NOT_CHECK_IN+, we currently use
  # latest_tweeds.yaml to persist the ID of the latest received tweed.
  # Reason for not reusing the login credentials file is the risk of
  # accidentally kill that file, thus the login credentials might get lost.
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
      # filter_replies if every_message_is_tagged_reply?
      # puts latest_replies.pretty_inspect

    self.latest_message_received = latest_message_id if perform_latest_message_id_update

    return latest_replies
  end
end

# # require 'test/unit'
# # require 'micro_blog_messaging_io'
class MicroBlogMessagingIO
  attr_reader :connector, :connection
  attr_accessor :latest_tweeds
end
class TC_MicroBlogMessagingIO < Test::Unit::TestCase
  def setup
    @mb_services = KNOWN_MICRO_BLOGGING_SERVICES

    service_is_available = SERVICE_IS_AVAILABLE
    service__config_file = MB_SERVICE__CFG_FILE

    @latest_message_received = Hash.new
      @connector__message_io = Hash.new
                  @connector = Hash.new
                 @message_io = Hash.new

    service__config_file.each do |mb_service, config_file|
      if service_is_available[mb_service] then
         connector = MicroBlogConnector.new(config_file)
        message_io = MicroBlogMessagingIO.new(connector)

        @connector__message_io[connector] = message_io

           @connector[mb_service] = connector
          @message_io[mb_service] = message_io
        @latest_message_received[mb_service] =
               message_io.latest_tweeds['inbox_latest'][mb_service].to_i
      end
    end
  end

  def test_initialize
    @connector__message_io.each do |c,io|
       assert_same c, io.connector
       assert_same c.connection, io.connection
    end

    KNOWN_MIN_TWEED_ID.each do |mb_service, min_tweed_id|
      assert @latest_message_received[mb_service] >= min_tweed_id if SERVICE_IS_AVAILABLE[mb_service]
    end
  end

  def test_say
    @connector__message_io.each do |connector, io|
      message = "test: say(#{rand.to_s})"
      result = io.say(message)

        assert_same Twitter::Status, result.class
        assert result.id != nil
        assert_equal message, result.text
        assert_equal connector.username, result.user.screen_name

      io.connection.destroy(result.id) unless connector.service_lacks['destroy']
    end
  end

  def test_reply
    @connector__message_io.each do |connector, io|
      pilot_fish = io.say("test: say(#{rand.to_s})")
      message = "test: reply(#{pilot_fish.id}, #{rand.to_s})"
      result = io.reply(message, pilot_fish.id, pilot_fish.user.id)

        assert_same Twitter::Status, result.class
        assert result.id != nil
        assert_equal pilot_fish.id, result.in_reply_to_status_id
        assert_equal message, result.text
        assert_equal connector.username, result.user.screen_name
        assert_equal pilot_fish.user.id, result.user.id

      unless connector.service_lacks['destroy']
        io.connection.destroy(result.id)
        io.connection.destroy(pilot_fish.id)
      end
    end
  end

  def test_latest_message_received__read
    @message_io.each do |mb_service, io|
      assert_equal @latest_message_received[mb_service],
                   io.latest_message_received.to_i
    end
  end

  def test_latest_message_received__write
    @message_io.values.each do |io|
      value = rand.to_s
      assert_equal value, io.latest_message_received = value

      # bonus: do an additional read test:
      assert_equal value, io.latest_message_received
    end
  end

  def test_get_latest_replies
    @message_io.each do |mb_service, io|
      ancient_msg_max_id = KNOWN_MIN_TWEED_ID[mb_service]

        io.latest_message_received = ancient_msg_max_id
        latest_reply = io.get_latest_replies(false).last

      assert_equal ancient_msg_max_id, io.latest_message_received
      assert ancient_msg_max_id < latest_reply['id']

        recent_replies = io.get_latest_replies(true)
        # puts mb_service, recent_replies.pretty_inspect
        latest_reply = recent_replies.last

      assert       ancient_msg_max_id < io.latest_message_received
      assert       ancient_msg_max_id < latest_reply['id']
      assert_equal latest_reply['id'], io.latest_message_received if (mb_service == 'identica') # fixme: find appropriate test for Twitter
    end
  end # FIXME: unify whether or not IDs shall be Fixnums or Strings

  def test_shutdown
    msg_io_for_compare = []
      conn_for_compare = []
    KNOWN_MICRO_BLOGGING_SERVICES.each do |mb_service|
      if SERVICE_IS_AVAILABLE[mb_service] then
        msg_io_for_compare << @message_io[mb_service]
          conn_for_compare << @connector[mb_service]
      end
    end
    assert_not_nil msg_io_for_compare
    1.upto(msg_io_for_compare.size - 1) do |index|
      assert_equal msg_io_for_compare[0].latest_tweeds,
                   msg_io_for_compare[index].latest_tweeds
    end
    message_io = msg_io_for_compare[0]
    connector  =   conn_for_compare[0]

      orig_latest_tweeds = message_io.latest_tweeds

        # Note:
        # w/o the two to_s, the later equality assertion fails
        # although it displays exactly the same values for both
        # values compared, i.e. for +new_latest_tweeds+ and for
        # what gets compared to it.
        new_latest_tweeds = {
        		      'inbox_latest' =>
        		    	{
        		    	  'identica' => rand.to_s,
        		    	  'twitter'  => rand.to_s
        		    	}
        		    }
        message_io.latest_tweeds = new_latest_tweeds
        message_io.shutdown

        message_io = MicroBlogMessagingIO.new(connector)

        assert_equal new_latest_tweeds, message_io.latest_tweeds

      message_io.latest_tweeds = orig_latest_tweeds
      message_io.shutdown

    message_io = MicroBlogMessagingIO.new(connector)
    assert_equal orig_latest_tweeds, message_io.latest_tweeds
  end # FIXME: if possible, unify whether it's to be latest_tweeds or latest_message_received
end

class TwitterBot
  def initialize
    @connector =
          MicroBlogConnector.new( VALID_CONNECT_CREDENTIALS__DO_NOT_CHECK_IN )
    @friending = MicroBlogFriending.new(@connector)
    @talk = MicroBlogMessagingIO.new(@connector)

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

# bot = TwitterBot.new
# bot.operate
# bot.shutdown

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
