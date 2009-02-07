main_dir = File.join(File.dirname(__FILE__), '')
require (main_dir + 'micro_blog_connector')
require (main_dir + 'micro_blog_friending')
require (main_dir + 'micro_blog_messaging_io')

class MicroBlogBot
  def initialize
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
#       progress_message = '@peqi Don\'t know. I haven\'t done anything about feeds. I think, it just was the default when I signed up.'
    @talk.say(progress_message) if progress_message

    process_latest_received
  end

  def process_latest_received
    begin

      @talk.get_latest_replies.each do |msg|
        echo_back(msg)
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
  def echo_back(msg)
        user_id = msg['user_id']; return if user_id == @connector.user_id # for identica
    screen_name = msg['screen_name']
         msg_id = msg['id']
      timestamp = msg['created_at']; timestamp.gsub!(/ \+0000/, '')
           text = msg['text'];       text.sub!(/^@logbot\s+/, '')

    command = text.strip.downcase
    answer = @bot_commands[command]
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
#   + intensive/intensify parsing via class inheritant
# + put bot commands to a hash, so creation of derivate bots might be as
#   simple as modifying that hash.
#   + also, if possible and useful, we could assign +block+s as (some of) the
#     hash's values to even handle functionality accessible by commands
# + ramp up a v0.1 release
# + enable message destruction
#   + make message/reply tests to immediately clean up after themselves
# + create perma-runnable version
# + add tests for MicroBlogBot
# + purge all those test messages caused so far
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
