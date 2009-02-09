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

class MicroBlogBot
  def initialize
    @shutdown = false

    @connector =
         MicroBlogConnector.new( VALID_CONNECT_CREDENTIALS__DO_NOT_CHECK_IN )
    @friending = MicroBlogFriending.new(@connector)
    @talk = MicroBlogMessagingIO.new(@connector)

    @bot_name = @connector.username
    @bot_commands = {
    		      'about' => "@#{ @bot_name } is a #chat #bot built by @dagobart in #Ruby on top of @jnunemaker's #Twitter and #Identica gem. Want to join development?",
    		      'help'  => 'You may aim any of these commands at me: about help ping time?',
    		      'ping'  => 'Pong',
    		      'ping?' => 'Pong!',
    		      'time?' => 'For getting to know the current time, following @timebot might be helpful. (That one\'s *not* by @dagobart.)',
    		    } # note: all hash keys must be lower case

    begin
      puts @friending.follower_stats

        # be nice to new followers:
        @friending.new_followers.each do |new_follower|
          @talk.say("@#{ new_follower }: Welcome! Thanks for following me. If you've got any questions, try '@#{ @connector.username } help'. Note: I'm not always online.")
        end # FIXME: + add test for this

      @friending.catch_up_with_followers
    rescue Twitter::CantConnect
      puts @connector.errmsg(Twitter::CantConnect)
    end
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
      sleep 15
    end
  end

  def process_latest_received
    begin

      @talk.get_latest_replies.each do |msg|
        answer_message(msg)
      end

    rescue Twitter::CantConnect
      puts @connector.errmsg(Twitter::CantConnect)
    end
  end

  # . Uses ~Twitter message threading, i.e. refers to the message ID we're
  #   responding to.
  # * On identi.ca, from its creation on, the bot account had itself as
  #   friend and follower. Also, whatever it posts -- e.g. replies to other
  #   users' requests -- the bot sees as replies to itself. This holds true
  #   only for identi.ca. But this would imply: Once the bot gets running
  #   continuously, it would deadlock itself by reacting on and replying to
  #   its own messages over and over again. Therefore, to avoid such, this
  #   method quits as soon as we realize we are about to talk to ourselves,
  #   i.e. the bot is going to talk to itself.
  def answer_message(msg)
        user_id = msg['user_id']; return if user_id == @connector.user_id # for identica
    screen_name = msg['screen_name']
         msg_id = msg['id']
      timestamp = msg['created_at']; timestamp.gsub!(/ \+0000/, '')
           text = msg['text'];       text.sub!(/^@logbot\s+/, '')

    command = text.strip.downcase
    @shutdown = (command == 'shutdown') && (screen_name == 'dagobart')
    if @shutdown then
      answer = 'Shutting down, master. // @logbot is an #LGPL3 #chat #bot for micro-blogging services such as #Twitter and #Identica.'
    else
      answer = @bot_commands[command]
    end
    answer = "Don't know how to handle your #{ timestamp } request  '#{ text }'" unless answer
    answer = "@#{ screen_name }: #{ answer }"

    answer = "#{answer[0,136]}..." if answer.length > 140

    @talk.reply(answer, msg_id, user_id)
    puts answer # help//support us learn about new developments in our
  end		# relationships to our followees

  # actually, I didn't grasp Ruby finalizing. If you do, feel free to
  # implement a better solution than this need to call shutdown explicitly
  # each time.
  def shutdown
    @talk.shutdown
  end
end

bot = MicroBlogBot.new
bot.operate
bot.shutdown


# todo:
# + create perma-runnable version
# + if possible and useful, allow +block+s as values for the @bot_commands
#   hash, so developing own derivate bots would become dead-simple: Just
#   inherit your bot, then change the commands hash as you like.
#   + intensify parsing via inheritant
# + add tests for MicroBlogBot
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
# + read on that official Twitter/Identica documentation has to say on bots
# + read documentation of jnunemaker's Twitter gem/ask him whether or not
#   he'd like it if I'd contribute any
# + join forces with other ~Twitter bots' developers
# + delete old 'help' responses after a while, say a few days
