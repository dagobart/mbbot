require 'rubygems'
gem('twitter', '>=0.4.1')
require('twitter')

# After tons of hassles with disrupted Ruby/Rails/RubyGems installations --
# http://is.gd/hvM9 -- I gave in an gave another Debian Ruby/Rails a try, that
# is Debian Lenny's Ruby. Currently -- that is just before release of Debian
# Lenny -- if not perfect, it looks usable. I hope backports.org will keep us
# up to date with Ruby/Rails/RubyGems once Lenny's released.
#
# To get this here Twitter bot up and running, additionally to the default
# Debian ruby package, you need the following:
#
# deb: ruby-dev => mkmf
# gem: twitter => core gem
#      echoe => fix rubygems
#
#
# Note: Before you can exec any Twitter interactions through your bot, you
# need to replace +logbot+ and +botpassword+ below with a valid combination.
#
class TwitterLogBot
  def initialize
    @bot = Twitter::Base.new('logbot', 'botpassword')
#     @bot.update('Now also learned how to auto-leave lost followers.')
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
    @bot.create_friendship(user_screen_name)
    @bot.follow(user_screen_name)
  end

  def leave(user_screen_name)
    @bot.leave(user_screen_name)
    @bot.destroy_friendship(user_screen_name)
  end

  def new_followers
    follower_names - friend_names
  end

  def lost_followers
    friend_names - follower_names
  end

  def follower_names
    result = []
    @bot.followers.collect { |follower| result << follower.screen_name }

    return result
  end

  def friend_names
    result = []
    @bot.friends.collect { |friend| result << friend.screen_name }

    return result
  end
end

bot = TwitterLogBot.new

puts 'friends:', bot.friend_names
puts 'followers:', bot.follower_names
puts 'new followers:', bot.new_followers
puts 'lost followers:', bot.lost_followers

bot.catch_up_with_followers
bot.leave('michellegggssee')

# todo:
# + add reading auth data from config file, so check-in/-out becomes less a hassle
# + add functionality to read/post updates, use distinct class for this