main_dir = File.join(File.dirname(__FILE__), '')
require (main_dir + 'micro_blog_bot')

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

class MicroBlogShadow < MicroBlogBot
  def initialize
    super("To shut down the bot, the user who's sharing their account with the\n" +
          "bot must post 'shutdown' (w/o quotes).\n" +
          "Alternatively, just interrupt it using C-C/^C or other means", false, true)

    # void some variables initialized by super class:
    @bot_commands = { '' => '' }
    @supervisor = ''
  end

  def process_latest_received
    msgs = @talk.get_latest_posts(false)
    # Set +false+ to avoid to     ^^^^^  accidentally
    # persist the ID of any not yet examined message.
 
    latest_sucessfully_examined = nil

      msgs.each do |msg|
        unless @shutdown then
          grasp_shutdown(msg)
      
          latest_sucessfully_examined = msg
        end
      end

    # Make sure we don't persist a message's ID unless we actually
    # examined it:
    if (latest_sucessfully_examined) then
      @talk.latest_post = 
        @talk.processed_message_id(latest_sucessfully_examined) # + 1
    end
  end

  def grasp_shutdown(msg)
    screen_name = msg['screen_name']
           text = msg['text'];
      timestamp = msg['created_at']; timestamp.gsub!(/ \+0000/, '')

    text = text.strip.downcase
    @shutdown ||= ( (screen_name == @bot_name) && (text == 'shutdown') )
 
    @talk.log "received '#{text}' by @#{screen_name} at #{timestamp}"
  end # FIXME: remove hard-coded strings incl. hard-coded 'shutdown' command
      # fixme: + destroy message if it was a shutdown message
      # FIXME: 20090729: msg deletion on identi.ca apparently doesn't work anymore.
      #                  Though, it'd be better if commands issued at the bot would
      #                  go deleted as soon as processed by the bot.
end

shadow = MicroBlogShadow.new
shadow.operate
shadow.shutdown
# if you want a more sophisticated/more sustainably running shadow bot, cf. ssample-bot.rb
