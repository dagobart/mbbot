main_dir = File.join(File.dirname(__FILE__), '')
require (main_dir + 'micro_blog_connector')
require (main_dir + 'micro_blog_friending')
require (main_dir + 'micro_blog_messaging_io')

class TwitterBot
  def initialize
    @connector =
          MicroBlogConnector.new( VALID_CONNECT_CREDENTIALS__DO_NOT_CHECK_IN )
    @friending = MicroBlogFriending.new(@connector)
    @talk = MicroBlogMessagingIO.new(@connector)

    begin
      puts @friending.follower_stats
      @friending.catch_up_with_followers
    rescue Twitter::CantConnect
      puts @connector.errmsg(Twitter::CantConnect)
    end
  end

  def operate
    progress_message = nil
      # progress_message = 'Just learned how to ...'
#       progress_message = 'Just got my tests wrapped with a testsuite.'
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

    if text.strip.downcase == 'ping' then
      answer = "@#{ screen_name } Pong"
    elsif text.strip.downcase == 'ping?' then
      answer = "@#{ screen_name } Pong!"
    else
      answer = "@#{ screen_name } [echo:] On #{ timestamp } you asked me:  #{ text }"
    end

    answer = "#{answer[0,136]}..." if answer.length > 140

    # puts answer, msg_id, user_id
    @talk.reply(answer, msg_id, user_id)
  end

  # actually, I didn't grasp Ruby finalizing. If you do, feel free to
  # implement a better solution than this need to call shutdown explicitly
  # each time.
  def shutdown
    @talk.shutdown
  end
end

bot = TwitterBot.new
bot.operate
bot.shutdown

# todo:
# + add functionality to parse/act on/answer updates (w/o parser, at first)
# + fix identica issue on status vs reply
# + ramp up a v0.1 release
# + add tests for TwitterBot
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
