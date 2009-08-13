require 'test/unit'

require File.join(File.dirname(__FILE__), '..', 'micro_blog_friending')

# This piece of software is released under the
# Lesser GNU General Public License version 3.
#
# Copyright (c) 2009 by Wolfram R. Sieber <Wolfram.R.Sieber@GMail.com>
#
#
# Follow me on Twitter or Identi.ca, where you'll find me as @dagobart but
# under the first name/last name pseudonyme A.F.
#
# Suggestions? Please let me know.

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
