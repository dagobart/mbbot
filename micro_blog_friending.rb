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
      DBM.open('followbacks') do  |db| 
        if ((!db[follower_screen_name]) || (db[follower_screen_name].length == 0)) then
          db[follower_screen_name] = DateTime.now.to_s
          puts message
          begin
          follow(follower_screen_name)
          rescue Twitter::TwitterError => e
            puts "We couldn't follow #{follower_screen_name}: #{e.message}"
          end
        end
      end
    end

    # leave everyone who left us:
    lost_followers.each do |follower_screen_name|
      message = "leaving #{follower_screen_name}"
      collected_messages += "#{message}\n"
      DBM.open('followerwelcomes') do  |db| 
        if ((!db[follower_screen_name]) || (db[follower_screen_name].length == 0)) then
          db[follower_screen_name] = nil
          puts message
          leave(follower_screen_name)
        end
      end
    end

    return collected_messages
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
      # FIXME: just learned that @connection.leave is a misnomer: @connection.leave means: get no longer notified by leavee's updates
    else
      @connection.friendship_destroy(user_screen_name)
    end
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
    num_followers = 100
    counter = 1
    follower_array = []
    until num_followers < 100 do
      query = { "page" => counter }
      follower_page = @connection.followers(query)
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
    until num_friends < 100 do
      query = { "page" => counter }
      friend_page = @connection.friends(query)
      num_friends = friend_page.length
      friend_array = friend_array + friend_page
      counter = counter + 1
    end
    user_names(friend_array)
  end # fixme: not yet tested with gem v0.4.1; for gem v0.4.1 this method consisted of a single line of code: +user_names(@connection.friends)+

  def user_names(users)
    users.collect { |user| user.screen_name }
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
    @connection.friendship_exists?(@connector.username, user_screen_name)
  end # FIXME: + add test
#
#   def block_follower(user_screen_name)
#   end
end
