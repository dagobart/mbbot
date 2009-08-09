main_dir = File.join(File.dirname(__FILE__), '')
# require (main_dir + 'micro_blog_connector')
# require (main_dir + 'micro_blog_friending')
# require (main_dir + 'micro_blog_messaging_io')
# require (main_dir + 'Token') # FIXME: rename Token.rb to token.rb
require 'dbm'
%w{ Token micro_blog_connector micro_blog_friending micro_blog_messaging_io   }.each do |lib|
    require(main_dir + lib)
end

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
    @connector =
         MicroBlogConnector.new( VALID_CONNECT_CREDENTIALS__DO_NOT_CHECK_IN )
    @friending = MicroBlogFriending.new(@connector)
    @talk = MicroBlogMessagingIO.new(@connector, @friending)

    @bot_name   = @connector.username
    @supervisor = @connector.supervisor

    @shutdown = false
    puts "To shut down the bot, @#{@supervisor} must issue 'shutdown'" + 
         " to @#{@bot_name}."
    puts "Alternatively, on SIGINT, the bot will forget that it already"
    puts "processed the most recent received messages and re-process them"
    puts "the next time (and annoy followers by that).", ''

    @bot_commands = {
    		      'about' => "@#{ @bot_name } is a #chat #bot built" +
                                 " by @dagobart in #Ruby on top of" +
                                 " J.Nunemaker's #Twitter gem. Want to" +
                                 " join development?",
    		      'help'  => lambda { |c, m| 
                                           self.handle_help_command(c, m) },
    		      'ping'  => 'Pong',
    		      'ping?' => 'Pong!',
    		      'time?' => 'For getting to know the current time,' + 
                                 ' following @timebot might be helpful.' + 
                                 ' (That one\'s *not* by @dagobart.)',
    		      'sv' => "@#{@supervisor} is my supervisor.",
    		    } # note: all hash keys must be lower case

    puts @friending.follower_stats
  end

  def handle_help_command(predicate,msg)
    help_commands = {
      'about' => "Try 'help' for help. Add other Help text here. You can" +
                 " DM me too!",
      'help'  => "Ask for general help with 'help' or get help for" +
                  " commands with 'help CMD'",
      'ping'  => "The simplest of commands - use 'ping' to get a 'pong'" +
                 " response.",
    }
    tokens = Token::new(predicate)
    command = tokens.next_token
    if (command) then
      response = help_commands[command]
      if (response) then
        return response
      end
    end
    return 'You may aim any of these commands at me: about help ping'
  end

  def say_hello
    if USE_GEM_0_4_1 then
      @talk.say('Starting up. Running on the old gem, cannot send DMs.')
    else
      @talk.say('Starting up.')
    end
  end

  # be nice to new followers
  def catch_up_with_followers
    welcome_message = "Welcome! Thanks for the follow! Send" +
                      " '@#{@bot_name} help' for help. You can DM me too!"

    @friending.new_followers.each do |new_follower|
      DBM.open('followerwelcomes') do  |db| 
        if ((!db[new_follower]) || (db[new_follower].length == 0)) then
          db[new_follower] = DateTime.now.to_s
          puts "Sending Welcome message to  #{new_follower}!"
          @talk.direct_msg(new_follower, welcome_message)
        end
      end
    end
        
    unless USE_GEM_0_4_1 then
      @friending.catch_up_with_followers
    else     # in twitter gem v0.4.1 a Twitter::CantConnect may be raised,
      begin  #  therefore handle it:
        @friending.catch_up_with_followers
      rescue Twitter::CantConnect
        puts @connector.errmsg(Twitter::CantConnect)
      end
    end
  end # FIXME: + add test

  # +waittime+: Twitter suggests 60s: http://is.gd/j15G -- 15s gets us
  #             blacklisted on Twitter
  def operate(waittime = 75)
    progress_message = nil
    # progress_message = 'Just learned how to ...'
    # @talk.destroy(@talk.say('test').id)
    if progress_message
      msg = @talk.say(progress_message)
      puts msg.id # so we could delete it manually any later
    end

    while (!@shutdown) do
      catch_up_with_followers
      process_latest_received
      @talk.persist
      unless @shutdown
        puts "#{ Time.now }: sleeping for #{waittime} seconds..."
        sleep waittime
      end
    end
  end # FIXME: + somewhere add a general output-to-console state() method

  # FIXME: if a reply and a DM get received during the same run of 
  # process_latest_received(), the DM will not be answered, not even by 
  # the next run of process_latest_received()
  def process_latest_received
    sorted_replies = @talk.get_latest_replies.sort{|a,b| a['id'].to_i <=> b['id'].to_i}
    sorted_replies.each do |msg|
      if (@talk.latest_message_received <= msg['id'].to_i) then
        if USE_GEM_0_4_1 then # twitter gem v0.4.1 may raise an error
          begin
            answer_message(msg)
          rescue Twitter::CantConnect
            puts @connector.errmsg(Twitter::CantConnect)
          end
        else
          answer_message(msg)
        end
        @talk.latest_message_received = msg['id'].to_i + 1
      else
        puts "Skipping ID: " + msg['id'].to_s + "\t" + msg['text'].to_s + "\n"
      end
    end
    
    tdirect_msgs = @talk.get_latest_direct_msgs
    sorted_direct_msgs = tdirect_msgs.sort{|a,b| a['id'].to_i <=> b['id'].to_i}
    sorted_direct_msgs.each do |direct_msg|
      if (@talk.latest_direct_message_received <= direct_msg['id'].to_i) then
        if USE_GEM_0_4_1 then # twitter gem v0.4.1 may raise an error
          begin
            answer_message(direct_msg)
          rescue Twitter::CantConnect
            puts @connector.errmsg(Twitter::CantConnect)
          end
        else
          answer_message(direct_msg)
        end
        @talk.latest_direct_message_received = direct_msg['id'].to_i + 1
      else
        puts "Skipping ID: " + direct_msg['id'].to_s + "\t" + direct_msg['text'].to_s + "\n"
      end
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
           text = msg['text'];       text.sub!(/^@\S+\s+/, '')
                         # formerly: text.sub!(/^@#{@bot_name}\s+/, '')

      tokens = Token::new(text)
      command = tokens.next_token
      predicate = tokens.predicate

    	@shutdown ||= (
                       (command == 'shutdown') && 
                       (screen_name == @connector.supervisor)
                      )

	    if @shutdown then
	      answer = "Shutting down, master. // @#{ @bot_name } is @#{ @connector.supervisor }'s #chat #bot based on @dagobart's #LGPL3 #Twitter (/Identica) chatbot framework."
	    else
	      answer = @bot_commands[command]
	    end
	    if (answer.class == Proc) then
	      answer = answer.call(predicate,msg)
            elsif (answer) then
	      puts answer + "\n"
	    else
	      answer = "Don't know how to handle your request of '#{text}'"
	    end

	    answer = @talk.cut_to_tweet_length(answer)

	    msg2 = @talk.direct_msg(user_id, answer)

# line seems to contradict new, sophisticated process_latest_received(),
# hence (?) dsifry commented this here line of code out:
#
#    # avoid, that the next time the bot is going to poll for new messages,
#    # it won't consider its own ones
#    @talk.latest_message_received = msg.id
  end # fixme: + make it an option to answer publicly/privately

  # actually, I didn't grasp Ruby finalizing. If you do, feel free to
  # implement a better solution than this need to call shutdown explicitly
  # each time.
  def shutdown
    @talk.shutdown
  end
end


# sample code for a minimalist µB bot of your own:
#
# bot = MicroBlogBot.new
# bot.say_hello
# bot.operate
# bot.shutdown
#
# for a more advanced one, extend sample-bot.rb


# todo:
# + create gem
#   + check gem in to the usual gems repository
#   + announce gem
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
# . summed up the lessons learned at: http://is.gd/j7T6
# . terminology questions: followee, tweed, Twitter-compatibility, reply
# . needed to patch underlaying Twitter gem
