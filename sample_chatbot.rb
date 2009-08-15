main_dir = File.join(File.dirname(__FILE__), '')
require (main_dir + 'micro_blog_bot_runner')

# 1. overwrite whatever you like method of
# MicroBlogBot within your own derivate of it:
class SampleBot < MicroBlogBot
end

# 2. then have MicroBlogBotRunner run
# it for you, including error handling
MicroBlogBotRunner.new(SampleBot.new).run

# you could even overwrite parts of
# MicroBlogBotRunner if you'd like
