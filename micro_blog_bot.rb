# -*- coding: utf-8 -*-
main_dir = File.join(File.dirname(__FILE__), '')
require (main_dir + 'micro_blog_connector')
require (main_dir + 'micro_blog_friending')
require (main_dir + 'micro_blog_messaging_io')
require (main_dir + 'Token') # FIXME: rename Token.rb to token.rb
require 'dbm'

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

class ShutdownException < StandardError # why +< StandardError+? -- Random choice
end

class MicroBlogBot
  # +message_streams_to_look_at+: array of kinds of messages the bot shall 
  # examine/process
  def initialize(alternative_shutdown_info_message = '', 
                 perform_followers_catch_up        = true, 
                 skip_unprocessed_messages         = false,
                 message_streams_to_look_at        = [:replies, :incoming_DMs])
    @connector =
         MicroBlogConnector.new( VALID_CONNECT_CREDENTIALS__DO_NOT_CHECK_IN )
    @friending = MicroBlogFriending.new(@connector)
         @talk = MicroBlogMessagingIO.new(@connector, @friending,
                                          skip_unprocessed_messages)

    @bot_name   = @connector.username
    @supervisor = @connector.supervisor

    @perform_followers_catch_up = perform_followers_catch_up
    @message_streams_to_look_at = message_streams_to_look_at

    @shutdown = false
    if alternative_shutdown_info_message.empty? then
      puts "To shut down the bot, on #{@connector.service_in_use.capitalize}," +
           " @#{@supervisor} must issue 'shutdown' to @#{@bot_name}."
      puts "Alternatively, on SIGINT, the bot will forget that it already"
      puts "processed the most recent received messages and re-process them"
      puts "the next time (and annoy followers by that).", ''
    else
      puts alternative_shutdown_info_message
    end
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
                    # fixme: could we move the hash to a yaml, so it'd
                    #        become morecomfortably to extend?

    puts @friending.follower_stats

    # as Twitter doesn't return correct follower/friends values all the
    # time, to catch up with new/lost followers, we need to take the lots
    # of traffic generating way of catching up. -- Since that _is_ costing
    # that lot of traffic, do it only once: here at start-up, and only if
    # we're actually on Twitter:  
    catch_up_with_followers(true) if !USE_GEM_0_4_1 && @perform_followers_catch_up

    return self
  end

  attr_reader :bot_name

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
    msg  = 'Starting up.'
    msg += ' Running on the old gem, unable to send DMs.' +
           ' Will send everything in public.'             if USE_GEM_0_4_1
    @talk.say(msg)
  end

  # be nice to new followers
  #
  # 
  # FIXME: currently, to figure out the new followers, we make a delta of
  # accounts/people we follow and those following us. That costs us two
  # Twitter GETs. Until now, the catch up took place every time we polled
  # for new messages. Which in turn quickly makes us hit the Twitter Rate
  # Limit.
  #
  # To fix this, catching up should be run not every time we look for new
  # incoming messages but independently of that, far more rarely.
  #
  # Also, the delta calculation causes lots of traffic. Did the µB service
  # come up with an easier way in the meantime yet?
  def catch_up_with_followers(enforce = false)
    welcome_message = "Welcome! Thanks for the follow! Send '@#{@bot_name}" +
                      ' help\' for help. You can DM me too! Note: I\'m not' +
                      ' always online.'

    # 'befriend' the new followers:
    results = @friending.catch_up_with_followers(enforce)

    # now welcome new followers:
    results['new_followers'].each do |new_follower|
      DBM.open('followerwelcomes') do  |db| 
        if ((!db[new_follower]) || (db[new_follower].length == 0)) then
          db[new_follower] = DateTime.now.to_s
          @talk.log "[status] Sending Welcome message to  #{new_follower}!"
          begin
            @talk.direct_msg(new_follower, welcome_message)
          # deal with tries to follow back suspended users:
          rescue USE_GEM_0_4_1 ? [] : Twitter::NotFound
            log '[status] We couldn\'t welcome' + 
                " #{follower_screen_name}: #{e.message}"
          end
        end
      end
    end
  end # FIXME: + add test
      # fixme: maybe this would be better put into the friending class, with
      #        an optional welcome string
      # fixme: wait.. do we have friending functionality here in the
      #        bot itself? Would be the wrong class for such.

  # +waittime+: Twitter suggests 60s: http://is.gd/j15G -- 15s gets us
  #             blacklisted on Twitter
  def operate(waittime = 75, dynamically_adapt_polling_frequency = false)
#    progress_message = nil
#    # progress_message = 'Just learned how to ...'
#    # @talk.destroy(@talk.say('test').id)
#    if progress_message then
#      msg = @talk.say(progress_message)
#      puts msg.id # so we could delete it manually any later
#    end

    min_waittime = waittime if dynamically_adapt_polling_frequency
    while (!@shutdown) do
      process_latest_received
      if dynamically_adapt_polling_frequency && messages_processed? then
        waittime = [(waittime + 1) / 2, min_waittime].max
      else
        waittime = [waittime * 3 / 2, 300].min # fixme: remove hard-coded 300s
      end                                      #      + hard-coded stepping too

      @talk.persist
      unless @shutdown
        @talk.log "[status] sleeping for #{ waittime } seconds...\n \b"
        sleep waittime

        # FIXME: do the catchup more rarely -- catching up costs >= 1 GET
        # -- thus making us close in to the Twitter per user/per IP limits
        # -- and a lot of traffic on our own side too. Mabe background the
        # call and/or disband it from the incoming messages polling. What
        # about workling+starling or similar?
        catch_up_with_followers if @perform_followers_catch_up
      end
    end
  end

  def process_latest_received
    @message_streams_to_look_at.each do |type|
      latest_processed_msg = nil

      msgs = @talk.get_latest_messages(false, type)
      # false to avoid to accidentally ^^^^^ persist the ID of any not yet
      # answered message

      # to enable a operate() caller to dynamically adapt their
      # polling frequency:
      @messages_processed = msgs.size > 0

      begin

        msgs.each do |msg|
          # update @shutdown:
          determine_shutdown(msg)
          
          act_upon_message(msg)
          # act_upon_message() should not raise any unhandled exceptions
          # which would disrupt our message ID persisting. As of 20090817,
          # the current implementation of act_upon_message() complies to
          # this requirement.

          latest_processed_msg = msg

          # To leave the each graciously on an issued 'shutdown' command,
          # we introduce a ShutdownException. By raising it, our jotting
          # down of the latest successfully processed message would fail.
          # Therefore we have to handle the down-jotting within the rescue.
          # To get the latest processed message there, we 'ab'use the
          # message parameter of the exception for storing the [non-string]
          # +msg+ there. Later, once we ask the exception for the value of
          # its 'message', we will get back the +msg+ we just stored there:
          raise ShutdownException.new(msg) if @shutdown
        end

        # Make sure we persist every message's ID we actually processed.
        # Either we'll have a ShutdownException, then the ID will be
        # stored by means of the rescue or we won't have an exception,
        # then the following +if+ conditional will get executed, and
        # thus the ID stored though.
        if latest_processed_msg then
          jot_down_latest_processed_message(type, latest_processed_msg)
        end

      rescue ShutdownException => exception
        jot_down_latest_processed_message(type, exception.message)
      end
    end
  end

  def messages_processed?
    @messages_processed
  end

  def jot_down_latest_processed_message(type, latest_processed_msg)
    @talk.set_latest_message_id(type,
                                @talk.processed_message_id(latest_processed_msg))
  end

  def determine_shutdown(msg)
    screen_name = msg['screen_name']
    text        = msg['text'].sub(/^@#{@bot_name}\s+/, '')

    @shutdown ||= ((text == 'shutdown') && (screen_name == @supervisor))
  end # FIXME: remove hard-coded strings incl. hard-coded 'shutdown'
      #         command

  # for derived classes, to ease to replace the default message processing,
  # act_upon_message() is the place.
  # +msg+: latest received message of any of @message_streams_to_look_at
  # as set during object creation
  def act_upon_message(msg)
    answer_message(msg)
  end
  #fixme: abstract away who's allowed to shutdown, too

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
           text = msg['text'];       text.sub!(/^@#{@bot_name}\s+/, '')

    if @shutdown then
      answer = "Shutting down, master. // @#{ @bot_name } is @#{ @connector.supervisor }'s #chat #bot based on @dagobart's #LGPL3 #Twitter (/Identica) chatbot framework." # fixme: remove hard-coded string
    else
      tokens = Token::new(text)
      command = tokens.next_token
      predicate = tokens.predicate

      answer = @bot_commands[command]

      if (answer.class == Proc) then
        answer = answer.call(predicate,msg)
      elsif (answer) then
        # puts answer + "\n"
      else
        answer = "Don't know how to handle your request of '#{text}'"
      end
    end

    msg2 = @talk.direct_msg(user_id, @talk.cut_to_tweet_length(answer))
    # fixme: re-enable post/reply threading by handing over +msg_id+,
    #        and using reply() rather than say() if direct message
    #        sending is not available/not possible
  end  # FIXME: remove hard-coded strings incl. hard-coded 'shutdown'
       #         command
       # fixme: + make it an option to answer publicly/privately

  # actually, I didn't grasp Ruby finalizing. If you do, feel free to
  # implement a better solution than this need to call shutdown explicitly
  # each time.
  def shutdown
    @talk.log 'shutting down...'
    @talk.shutdown 
    # fixme: store the ids of the latest processed msgs as a reply to the
    # bot, so every other instance of the bot can pick up that status and
    # start from there rather than reprocessing all the messages yet
    # processed by other instances of the bot. 
  end

  def notify_operator(msg)
    @talk.log "notifying operator (#{@supervisor}):"
    @talk.direct_message_to(@supervisor, msg)
  end
end


# sample code for a minimalist µB bot of your own:
#
# bot = MicroBlogBot.new
# bot.say_hello
# bot.operate
# bot.shutdown
#
# for a more advanced one, extend sample_chatbot.rb


# todo:
# + create gem
#   + check gem in to the usual gems repository
#   + announce gem
# + present the framework at FrOSCon
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
