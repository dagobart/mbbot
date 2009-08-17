main_dir = File.join(File.dirname(__FILE__), '')
require (main_dir + 'micro_blog_bot_runner')

# 1. overwrite whatever you like method of MicroBlogBot within your own
# derivate of it.
# Most likely, you want to overwrite initialize(), act_upon_message()
# and handle_help_command(), as that is where your bot's functionality
# will go, while mostly everything else will be handled by MicroBlogBot
# more or less autonomously.
class SampleBot < MicroBlogBot
end

# 2. then have MicroBlogBotRunner run
# it for you, including error handling
MicroBlogBotRunner.new(SampleBot.new).run

# you could even overwrite parts of
# MicroBlogBotRunner if you'd like


# for another example of a (non-chat) bot, see micro_blog_shadow.rb
