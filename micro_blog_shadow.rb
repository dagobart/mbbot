main_dir = File.join(File.dirname(__FILE__), '')
require (main_dir + 'micro_blog_bot')

# This piece of software is released under the
# Lesser GNU General Public License version 3.
#
# Copyright (c) 2009 by Wolfram R. Sieber <Wolfram.R.Sieber@GMail.com>
#
#
# Follow me on Twitter or Identi.ca, where you'll find me as @dagobart
# but under the first name/last name pseudonyme A.F.
#
# 
# The aim of +MicroBlogShadow+ is to shadow the activities of the
# account owner, listen for and execute commands found in their
# output stream, and to inject the results of those commands back
# into the very same output stream.
#
# Suggestions? Please let me know.

class MicroBlogShadow < MicroBlogBot
  def initialize
    super("To shut down the bot, the user who's sharing their account with\n" +
          "the bot must post 'shutdown' (w/o quotes).\n" +
          "Alternatively, just interrupt it using C-C/^C or other means", 
          false, true, [:own_timeline])

    # void some variables initialized by super class:
    @bot_commands = { }
  end

  def act_upon_message(msg)
    screen_name = msg['screen_name']
       msg_text = msg['text'];
      timestamp = msg['created_at']; timestamp.gsub!(/ \+0000/, '')

    text = msg_text.strip.downcase
 
    @talk.log "received '#{msg_text}' by @#{screen_name} at #{timestamp}"
  end # FIXME: remove hard-coded strings
      # FIXME: 20090729: on identi.ca, msg deletion apparently doesn't
      #                  work. Though, it'd be better if commands
      #        issued at the bot would go deleted as soon as processed
      #        by the bot.
      # fixme: + destroy message if it was a bot command
end

shadow = MicroBlogShadow.new
shadow.operate
shadow.shutdown
# if you want a more sophisticated/more sustainably running 
# shadow bot, cf. sample_chatbot.rb
