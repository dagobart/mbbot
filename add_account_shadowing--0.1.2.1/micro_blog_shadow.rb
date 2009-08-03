main_dir = File.join(File.dirname(__FILE__), '')
require (main_dir + 'micro_blog_connector')
require (main_dir + 'micro_blog_friending')
require (main_dir + 'micro_blog_messaging_io')

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

class MicroBlogShadow
  def initialize
    @connector =
         MicroBlogConnector.new( VALID_CONNECT_CREDENTIALS__DO_NOT_CHECK_IN )
    @friending = MicroBlogFriending.new(@connector)
    @talk = MicroBlogMessagingIO.new(@connector)

    @bot_name = @connector.username

    @shutdown = false
    puts "To shut down the bot, the user who's sharing their account with the"
    puts "bot must post 'shutdown' (w/o quotes)."
    puts "Alternatively, just interrupt it using C-C/^C or other means"

    @bot_name = @connector.username

    puts @friending.follower_stats
  end

  def operate
    progress_message = nil
    # progress_message = 'Just learned how to ...'
    # @talk.destroy(@talk.say('test').id)
    if progress_message
      msg = @talk.say(progress_message)
      puts msg.id # so we could delete it manually any later
    end

    while (!@shutdown) do
      process_latest_received
      @talk.persist
      sleep 15 unless @shutdown # Twitter suggests 60s: http://is.gd/j15G -- 15s gets us blacklisted on Twitter
    end
  end

  def process_latest_received
    begin
      # msgs = @talk.get_latest_updates
      msgs = @talk.get_latest_posts(true)
      msgs.each do |msg|
        grasp_shutdown(msg)
#        @talk.destroy(msg['id'].to_i) if (msg['screen_name'] == @bot_name) && (msg['text'] == 'shutdown')
      end
      puts "#{Time.now}: nothing happens" if ((msgs == nil) || (msgs.size == 0))
 
    rescue Twitter::CantConnect
      puts @connector.errmsg(Twitter::CantConnect)
    end
  end # FIXME: 20090729: msg deletion on identi.ca apparently doesn't work anymore. Though, it'd be better if commands issued at the bot would go deleted as soon as processed by the bot.

  # . Uses ~Twitter message threading, i.e. refers to the message ID we're
  #   responding to.
  # * On identi.ca, from its creation on, the bot account had itself as
  #   friend and follower. Also, whatever it posts -- e.g. replies to other
  #   users' requests -- the bot sees as replies to itself. This holds true
  #   only for identi.ca. But this would imply: Once the bot gets running
  #   continuously, it would deadlock itself by reacting to and replying to
  #   its own messages over and over again. Therefore, to avoid such, this
  #   method quits as soon as we realize we are about to talk to ourselves,
  #   i.e. the bot is going to talk to itself.
  def grasp_shutdown(msg)
         msg_id = msg['id']
        user_id = msg['user_id']
    screen_name = msg['screen_name']
           text = msg['text'];

    received_tweet = text.strip.downcase
    @shutdown ||= (
                   (screen_name == @connector.supervisor) && 
                   (
                    (received_tweet =~  /^@#{@bot_name}\s+shutdown/) || 
                    (received_tweet == '[d] shutdown')
                   )
                  ) || (
                        (screen_name == @bot_name) &&
                        (received_tweet == 'shutdown')
                  )

    puts "#{Time.now}: received '#{received_tweet}' from #{msg['created_at']}"
  end # FIXME: remove hard-coded 'shutdown' command

  # actually, I didn't grasp Ruby finalizing. If you do, feel free to
  # implement a better solution than this need to call shutdown explicitly
  # each time.
  def shutdown
    @talk.shutdown
  end
end

shadow = MicroBlogShadow.new
shadow.operate
shadow.shutdown


# todo:
# + create gem
#   + check gem in to the usual gems repository
#   + announce gem
# + if possible and useful, allow +block+s as values for the @bot_commands
#   hash, so developing own derivate bots would become dead-simple: Just
#   inherit your bot, then change the commands hash as you like.
#   + intensify parsing via inheritant
# + Don't attempt to follow back any users whose accounts are under Twitter
#   investigation, such as @michellegggssee.
# + make sure that if users change their screen names, nothing is going to
#   break
# + learn to deal with errors like this: "in `handle_response!': Twitter is
#   returning a 400: Bad Request (Twitter::CantConnect)" -- which actually
#   can be (witnessed!) some fail whale thing at the other end, cf. commit
#   #10, which *looked* broken because of that error, though after getting a
#   new IP address, it was gone, ie. it indeed was a fail of Twitter, not of
#   the bot code.
# + read on what the official Twitter/Identica documentation has to say on bots
# + read documentation of jnunemaker's Twitter gem/ask him whether or not
#   he'd like it if I'd contribute any
# + join forces with other ~Twitter bots' developers
# + delete old 'help' responses after a while, say a few days
# . terminology questions: followee, tweed, Twitter-compatibility, reply
