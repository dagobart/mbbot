main_dir = File.join(File.dirname(__FILE__), '')
require (main_dir + 'micro_blog_connector')
require (main_dir + 'micro_blog_friending')
require (main_dir + 'micro_blog_messaging_io')
require (main_dir + 'micro_blog_bot')
require (main_dir + 'Token')
require 'dbm'

begin
  bot = MicroBlogBot.new
  bot.say_hello
  bot.operate(80) # 75 seconds between updates, which is what Twitter recommends
rescue Twitter::Unavailable => e
  puts "We had a Twitter Error. Sleeping and resetting.\nError: #{e.message}\n"
  sleep 60
  retry
#rescue Twitter::NotFound, Twitter::TwitterError, Twitter::InformTwitter => e
#  puts "We had a Twitter Error. Sleeping and resetting.\nError: #{e.message}\n"
#  sleep 60
#  retry
rescue Crack::ParseError => e
  puts "We had a Parsing Error in the JSON Stream. Sleeping and resetting.\nError: #{e.message}\n"
  sleep 60
  retry
rescue SystemCallError => e
  puts "We had a SystemCallError Error. Sleeping and resetting.\nError: #{e.message}\n"
  sleep 60
  retry
rescue IOError => e
  puts "We had an IOError Error. Sleeping and resetting.\nError: #{e.message}\n"
  sleep 60
  retry
rescue Timeout::Error => e
  puts "We had a Timeout Error. Sleeping and resetting.\nError: #{e.message}\n"
  sleep 60
  retry
end
bot.shutdown
