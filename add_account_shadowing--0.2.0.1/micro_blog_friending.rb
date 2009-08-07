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
  end # FIXME: return array of new followers/leavers instead, so we can do
      # anything with that info. Such as welcoming the new followers with
      # some 'howto' message,

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
