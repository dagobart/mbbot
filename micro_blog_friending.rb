# require 'micro_blog_connector'
require File.join(File.dirname(__FILE__), 'micro_blog_connector')

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

class MicroBlogFriending
  def initialize(connector)
    @connector = connector
    @connection = @connector.connection
    @bot_name   = @connector.username
  end

  attr_reader :connection

  def follower_stats
    friend_names   = self.friend_names
    follower_names = self.follower_names

    new_followers  = self.new_followers
    new_followers  = nil if new_followers.size == 0
    lost_followers = self.lost_followers
    lost_followers = nil if lost_followers.size == 0

    # calculate the delta here instead by followers_delta() to
    # avoid to redo the traffic just caused by friend_names()
    # and follower_names:
    followers_delta = follower_names.size - friend_names.size

    result =
      "friends:         #{friend_names.join(', ')}\n" +
      "followers:       #{follower_names.join(', ')}\n" 
    result += 
      "new followers:   #{new_followers.join(', ')}\n"  if new_followers
    result += 
      "followers gone:  #{lost_followers.join(', ')}\n" if lost_followers
    result += 
      "followers delta: #{followers_delta}"

    return result
  end  # fixme: for some unknown reason, this method causes Twitter to
       #        hiccup in reply, i.e. answer by:
       #        400: Bad Request (Twitter::CantConnect)
       # fixme: figure out why we have such a notable long pause past
       # calling this here method

  # +collected_messages+ is intended to ease testing [of this
  # method]:
  def catch_up_with_followers(enforce = false)
    collected_messages = ''
    new_followers  =  new_followers(enforce)
    lost_followers = lost_followers(enforce)

    # follow back everyone we don't [follow back] yet:
    new_followers.each do |follower_screen_name|
      message = "following back #{follower_screen_name}"
      collected_messages += "#{message}\n"
      DBM.open('followbacks') do  |db| 
        if ((!db[follower_screen_name]) || 
            (db[follower_screen_name].length == 0)) then
          db[follower_screen_name] = DateTime.now.to_s

          puts message
          # fixme: make use of log(), here, once log() is available
          #        to low-level classes, like this one here, too

          begin
            follow(follower_screen_name)
          rescue Twitter::TwitterError => e
            puts "We couldn't follow #{follower_screen_name}: #{e.message} (#{e.type})"
            # fixme: make use of log(), here, once it's available to
            #        low-level classes, like this one here, too
          end
        end
      end
    end

    # leave everyone who left us:
    lost_followers.each do |follower_screen_name|
      message = "leaving #{follower_screen_name}"
      collected_messages += "#{message}\n"
      DBM.open('followerwelcomes') do  |db| 
        if ((!db[follower_screen_name]) || 
            (db[follower_screen_name].length == 0)) then
          db[follower_screen_name] = nil
          puts message
          # fixme: make use of log(), here, once log() is available
          #        to low-level classes, like this one here, too
          # fixme: just like in catch_up_with_followers(), make use
          #        of rescue, here too
          leave(follower_screen_name)
        end
      end
    end

    return {'collected_messages' => collected_messages, 
                 'new_followers' => new_followers, 
                'lost_followers' => lost_followers
            }
  end # FIXME: return array of new followers/leavers instead, so we can do
      # anything with that info. Such as welcoming the new followers with
      # some 'howto' message,

  def follow(user_screen_name)
    if USE_GEM_0_4_1 then
      @connection.create_friendship(user_screen_name)      
      @connection.follow(user_screen_name) unless @connector.service_lacks['follow']
      # FIXME: just learned that @connection.follow is a misnomer: @connection.follow means: get notified by followee's updates
    else
      @connection.friendship_create(user_screen_name)
    end
  end

  def leave(user_screen_name)
    if USE_GEM_0_4_1 then
      @connection.leave(user_screen_name) unless @connector.service_lacks['leave']
      @connection.destroy_friendship(user_screen_name)
      # FIXME: just learned that @connection.leave is a misnomer:
      #  @connection.leave means: get no longer notified by leavee's updates
    else
      @connection.friendship_destroy(user_screen_name)
    end
  end

  # FIXME: Twitter sometimes returns incorrect values, therefore, then no
  #        method that relies on this here will work correctly either.
  #
  # returns:
  # = 0 on no change
  # < 0 on lost followers
  # > 0 on new followers
  def followers_delta(enforce = false)
#    user = @connection.user(@bot_name)
    user = @connector.user

    # initialize result to a default value:
    result = (user.followers_count.to_i - user.friends_count.to_i)

    if (enforce && !USE_GEM_0_4_1) then
      # overrule the result value only when we're on Twitter and
      # decidedly want to get a correct result value. -- Note, to
      # accept an incorrect result value for Twitter may be okay 
      # since enforcing the correct value incurs a lot of traffic.
      result = (follower_names.size - friend_names.size)
    end

    # return result:
    return result
  end

  # Note: +user_names(@connection.followers - @connection.friends)+
  # does not work because of different object-in-memory-addresses
  # of follower/friend users, even if they have the same user ID.
  def new_followers(enforce = false)
    # Originally, we calculated new followers and lost followers about once
    # a minute, without testing whether their number changed at all. At as
    # few as 20 followers this added up to about 350 MB traffic every day.
    # -- The prepended delta testing now avoids to request all the whole
    # user objects if the delta didn't change in the meantime.
    if enforce || (followers_delta != 0) then
      follower_names - friend_names
    else
      []
    end
  end

  # Note: +user_names(@connection.friends - @connection.followers)+
  # does not work because of different object-in-memory-addresses
  # of follower/friend users, even if they have the same user ID.
  def lost_followers(enforce = false)
    # Originally, we calculated new followers and lost followers about once
    # a minute, without testing whether their number changed at all. At as
    # few as 20 followers this added up to about 350 MB traffic every day.
    # -- The prepended delta testing now avoids to request all the whole
    # user objects if the delta didn't change in the meantime.
    if enforce || (followers_delta != 0) then
      friend_names - follower_names
    else
      []
    end
  end

  def follower_names
    num_followers = 100
    counter = 1
    follower_array = []
    until num_followers < 100 do # fixme: why a loop? why not a each, map, collect or inject?
      query = { "page" => counter }
      follower_page = @connection.followers(query).to_a
      # fixme: twitter gem's friends() often does not return an array,
      #        despite it should
      num_followers = follower_page.length
      follower_array = follower_array + follower_page
      counter = counter + 1
    end
    user_names(follower_array)
  end # fixme: not yet tested with gem v0.4.1; for gem v0.4.1 this method consisted of a single line of code: +user_names(@connection.followers)+

  def friend_names
    num_friends = 100
    counter = 1
    friend_array = []
    until num_friends < 100 do # fixme: why a loop? why not a each, map, collect or inject?
      query = { "page" => counter }
      friend_page = @connection.friends(query).to_a
      # fixme: twitter gem's friends() often does not return an array,
      #        despite it should
      num_friends = friend_page.length
      friend_array = friend_array + friend_page
      counter = counter + 1
    end
    user_names(friend_array)
  end # fixme: not yet tested with gem v0.4.1; for gem v0.4.1 this method consisted of a single line of code: +user_names(@connection.friends)+
  # fixme: if possible, join friend_names() with follower_names()

  def user_names(users)
    users.collect { |user| (user.class == String) ? '' : user.screen_name }
    # fixme: currently, it happens all the time that +users+ contain strings
    # rather than Twitter::User objects only. Fix that! This here '? :'
    # construct is nothing more but a foul hack
  end

  # returns a User object for the user with the given +user_id+
  def user_by_id(user_id)
    @connection.user(user_id)
  end # fixme: + add test

  # returns the nickname of the user with the id +user_id+
  def username_by_id(user_id)
    user_by_id(user_id).screen_name
  end # fixme: + add test

  def is_friend_with?(user_screen_name)
    @connection.friendship_exists?(@bot_name, user_screen_name)
  end # FIXME: + add test
#
#   def block_follower(user_screen_name)
#   end
end
