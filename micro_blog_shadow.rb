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

class ShutdownException < StandardError # why +< StandardError+? -- Random choice
end

class MicroBlogShadow < MicroBlogBot
  def initialize
    super("To shut down the bot, the user who's sharing their account with the\n" +
          "bot must post 'shutdown' (w/o quotes).\n" +
          "Alternatively, just interrupt it using C-C/^C or other means", false, true)

    # void some variables initialized by super class:
    @bot_commands = { }
    @supervisor = ''
  end

  def process_latest_received
    msgs = @talk.get_latest_posts(false)
    # Set +false+ to avoid to     ^^^^^  accidentally
    # persist the ID of any not yet examined message.

    begin

      msgs.each do |msg|
        grasp_shutdown(msg)
        # As of 20090814, grasp_shutdown() does only basic boolean, string
        # and hash operations, so no chance that it'd raise an exception.
        # Therefore, below we need to deal with our own ShutdownException
        # at all.

        # msg is the latest successfully examined message. We need to
        # store it to persist it to the latest messages yaml file later.
        # As our scope currently is the +each+, we need to find a way
        # to get the +msg+ to outside of that scope. We achieve that by
        # raising an exception and 'ab'using the message parameter of
        # the exception for storing the [non-string] +msg+ there. Later,
        # once we ask the exception for the value of its 'message', we
        # will get back the +msg+ we just stored there:
        raise ShutdownException.new(msg) if @shutdown
      end

    rescue ShutdownException => exception
      @talk.latest_post = @talk.processed_message_id(exception.message)
    end
  end # fixme: + destroy message if it was a bot command
  # FIXME: port this method to micro_blog_bot.rb

  def grasp_shutdown(msg)
    screen_name = msg['screen_name']
       msg_text = msg['text'];
      timestamp = msg['created_at']; timestamp.gsub!(/ \+0000/, '')

    text = msg_text.strip.downcase
    @shutdown ||= ( (screen_name == @bot_name) && (text == 'shutdown') )
 
    @talk.log "received '#{msg_text}' by @#{screen_name} at #{timestamp}"
  end # FIXME: remove hard-coded strings incl. hard-coded 'shutdown'
      #         command
      # FIXME: 20090729: on identi.ca, msg deletion apparently doesn't
      #                  work. Though, it'd be better if commands
      #        issued at the bot would go deleted as soon as processed
      #        by the bot.
end

shadow = MicroBlogShadow.new
shadow.operate
shadow.shutdown
# if you want a more sophisticated/more sustainably running 
# shadow bot, cf. sample_chatbot.rb
