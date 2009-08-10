require File.join(File.dirname(__FILE__), 'micro_blog_friending')

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

class MicroBlogMessagingIO
  # Note:
  # Instead of re-using the login credentials file named by
  # +VALID_CONNECT_CREDENTIALS__DO_NOT_CHECK_IN+, we currently use
  # +latest_tweeds.yaml+ to persist the IDs of the latest received messages.
  # Reason for not reusing the login credentials file is the risk of
  # accidentally kill that file, thus the login credentials might get lost.
  #
  # If you've got an idea how to improve the latest message ID storage,
  # please let me know. -- @dagobart/20090129
  #
  # The +friending+ param refers to a +MicroBlogFriending+ object. Give
  # to it the +MicroBlogFriending+ object that is used by micro_blog_bot.rb 
  # too. It is needed in case sending direct messages fails (or is impossible
  # at all because the underlying twitter gem -- e.g. v0.4.1 -- doesn't
  # support sending direct messages).
  def initialize(connector, friending, skip_catchup = false)
    @message_type__message_stream_type = {
            :own_timeline => :user,
         :public_timeline => :public,
        :friends_timeline => :friends
    } # fixme: make this a const, and move it to the consts file

    @friending = friending

    @connector = connector
    @connection = @connector.connection
    @bot_name   = @connector.username

    @latest_messages =    # fixme: rename ..._TWEED_... to ..._TWEET_...
      YAML::load( File.open( LATEST_TWEED_ID_PERSISTENCY_FILE ) )
    self.skip_catchup if skip_catchup
    # puts @latest_messages.inspect; exit
  end
  # FIXME: in case of missing initial values (= missing entries in the yaml
  #        file) for the service the bot currently is assigned to, we should
  #        issue an initialization of all missing values to the now current
  #        message ID, just like with skip_catchup()

  # +@connection.timeline+ doesn't exist for twitter gem > v0.6.12, therefore
  # we add a timeline() method of our own
  #
  # fixme: add an interfacing class that provides an interface between gems
  # that enables (us) to access µB services and, to the other side, provides
  # a common interface to the bot; also, the class should feature
  # functionality which the respective gem currently lacks, say -- which is
  # missing in twitter gem 0.6.12 -- a public_timeline(). --- Then remove all
  # the stuff that deals with different gem versions/µB services from the
  # core bot classes and leave such stuff to the interfacing class only
  # Particularly, I've got the twitter4r gem in mind and alternative µB
  # services such as what is used on github.
  def timeline(message_stream_type, options = {})
    if USE_GEM_0_4_1 then
      return @connection.timeline(message_stream_type, options)
    else
      if    message_stream_type ==    :user then
        return @connection.user_timeline(options)
      elsif message_stream_type ==  :public then    # fixme: patched new method
        return @connection.public_timeline(options) # into 0.6.12 twitter gem
      elsif message_stream_type == :friends then
        return @connection.friends_timeline(options)
      else
        return nil
      end
    end
  end

  # returns the ID of the most current message currently receivable from the uB
  # service 
  def now_current_message_id(message_type)
    message_stream_type = @message_type__message_stream_type[message_type]

    if message_stream_type then
      messages_stream = timeline(message_stream_type, :count => 1)
    elsif (message_type == :incoming_DMs) then
      messages_stream = @connection.direct_messages(:count => 1)
    elsif (message_type == :mentions) ||
          (message_type == :replies)  then
      messages_stream = @connection.replies(:count => 1)
    end       # The above 'replies' ^^^^^^^ actually refers to mentions.
              # Misnomer of the Twitter 0.4.1 gem, but fault courtesy of
              # twitter.com as they replaced replies by mentions.

    return messages_stream.first.id.to_i
  end

  def now_current_message_ids
    message_types = @message_type__message_stream_type.keys +
                    [:incoming_DMs, :mentions, :replies]

      msg_ids = Hash.new
      message_types.each do |key|
        msg_ids[key] = now_current_message_id(key)
      end

    return msg_ids
  end

  def add_to_hash(hash, key, value)
    if (hash) then
      hash[key] = value
    else
      hash = { key => value }
    end

    return hash
  end

  def skip_catchup
    @latest_messages[:incoming_DMs.to_s] = 
      add_to_hash(@latest_messages[:incoming_DMs.to_s], 
                  @connector.service_in_use, 
                  now_current_message_id(:incoming_DMs)
                 )

    now_current_public_message_id = now_current_message_id(:public_timeline)

    [:public_timeline,
     :mentions, :replies,
     :own_timeline, :friends_timeline].each do |msg_type|
      @latest_messages[msg_type.to_s] = 
        add_to_hash(@latest_messages[msg_type.to_s], 
                    @connector.service_in_use, now_current_public_message_id)
    end
    # puts @latest_messages.pretty_inspect; exit
  end # fixme: add tests

  def cut_to_tweet_length(msg)
    return ( (msg.length > 140) ? "#{ msg[0, 136] }..." : msg )
  end

  def prepend_username_to_message(username, msg)
    return "@#{ username } #{ msg }"
  end

  def log(msg)
    puts "#{ Time.now }: #{ msg }"
  end

  def say(msg)
    @connection.update(msg)
    
    # help//support us learn about new developments in our relationships
    # to our followees:
    log((msg =~ /^@/) ? msg : "[post] #{ msg }")
  end

  def direct_msg(user_id, msg)
    username = @friending.username_by_id(user_id)
    public_version_of_message = 
      cut_to_tweet_length( prepend_username_to_message( username, msg ) )

    if USE_GEM_0_4_1 then # twitter gem 0.4.1 cannot DM
      # a +return+ must be w/i an if rather than in a +return ... if...+
      return say(public_version_of_message)
    end

    begin
      @connection.direct_message_create(user_id, msg)

      # help//support us learn about new developments in our relationships
      # to our followees:
      log("d #{ username } #{ msg }")
    rescue Twitter::TwitterError => e
      puts "*** Twitter Error in sending a direct message to @#{ username }: " + e.message
      puts "    attempting regular reply"
      say(public_version_of_message)
    end
  end

  def destroy(message_id)
    @connection.destroy(message_id)
  end # fixme: add test
      # FIXME: apparently doesn't work with Twitter gem 0.4.1 for
      #        identi.ca (anymore?)

 # chances are that Twitter needs both pieces of data, in_reply_to_status_id
  # and in_reply_to_user_id to get the message threading right. (You can
  # verify that by having a look at the look of the bot's replies within its
  # Twitter web page: If there's a "in reply to" threading got through, i.e.
  # got applied -- otherwise not.)
  def reply(msg, in_reply_to_status_id = nil, in_reply_to_user_id = nil)
    if in_reply_to_status_id && in_reply_to_user_id then
      @connection.update(msg, 
                         {
      			   :in_reply_to_status_id => in_reply_to_status_id,
        		     :in_reply_to_user_id => in_reply_to_user_id
                         }
      			)
    else
      say(msg)
    end
  end

  # 14 sample tweet IDs as they appeared on Twitter, i.e. the sort order is
  # not manually made but given by Twitter:
  # 3203232261
  # 3203230178    3202827120
  # 3203177496    3202821667
  # 3203161937    3202820108     3202286801
  # 3202893076    3202546161     3202270208
  #               3202516689     3202268364
  #                              3202259068
  #
  # fixme: make yaml file paragraph headlines match the xxx of +latest_xxx+/
  #  +latest_xxx=+, so it gets easier [for humans] to see the connection
  #  between the yaml file chunks and the methods here in the class
  def get_latest_message_id(type) # 1st received on Twitter: 1158336454
    return @latest_messages[type.to_s][@connector.service_in_use]
  end  # fixme: + add tests

  def set_latest_message_id(type, new_latest_ID)
    @latest_messages[type.to_s][@connector.service_in_use] = new_latest_ID
  end # fixme: + add tests


  # 1st message received on Twitter: 1158336454
  def latest_mention=(new_latest_ID)
    set_latest_message_id(:mentions, new_latest_ID)
  end # fixme: + add tests
  alias_method :latest_mention_received=, # Deprecated. Old name
               :latest_mention=
  alias_method :latest_message_received=, # Deprecated. Old name
               :latest_mention=

  def latest_mention
    return get_latest_message_id(:mentions)
  end # fixme: + add tests
  alias_method :latest_mention_received, # Deprecated. Old name
               :latest_mention
  alias_method :latest_message_received, # Deprecated. Old name
               :latest_mention


  def latest_direct_message_received
    @latest_messages['direct_latest'][@connector.service_in_use]
  end

  def latest_direct_message_received=(new_latest_ID)
    @latest_messages['direct_latest'][@connector.service_in_use] = 
      new_latest_ID
  end

 # Note: During the collect, we do temp-store the latest received message id
  # to a temporary storage +latest_message_id+ rather than using
  # latest_mention_received(). That's for performance: Using
  # latest_mention_received() would involve the use of several hashes rather
  # than just updating a single fixnum.
  def get_latest_replies(perform_latest_message_id_update = true)
    latest_message_id = self.latest_mention_received

      latest_replies = []
      @connection.replies(:since_id => latest_message_id).each do |reply|
        msg = reply.text

        # though Twitter handles replies correctly, identi.ca falsely claims
        # everything to be a reply that just contains '@logbot' (i.e. the
        # bot's user name) _somewhere_ in a message body, so even if
        # completely unrelated, such as '@dagobart, @logbot is great'.
        # Therefore, we fix that by +(/^@#{bot_name}/ =~ msg)+ below; the
        # attached +!(sender_name == bot_name)+ is only there to prevent the
        # bot from chatting with itself.
        bot_name = @connector.username
        sender_name = reply.user.screen_name

        if (/^@#{bot_name}/ =~ msg) && !(sender_name == bot_name) then # FIXME: add tests for both of these conditions
          # take side-note(s):
          id = reply.id.to_i
          latest_message_id = id if (id > latest_message_id.to_i)

          # perform actual collect:
          latest_replies << {
			       'created_at' => reply.created_at,
				       'id' => id,
			      'screen_name' => sender_name,
				     'text' => msg,
				  'user_id' => reply.user.id
			    }
        # else
        #  puts "'#{msg}'"
        end
      end
      # puts latest_replies.pretty_inspect

    self.latest_mention_received = latest_message_id if perform_latest_message_id_update

    return latest_replies
  end

  def get_latest_direct_msgs(perform_latest_message_id_update = false)
    latest_direct_message_id = self.latest_direct_message_received

       latest_direct_msgs = []
       @connection.direct_messages(:since_id => latest_direct_message_id).each do |direct_msg|
         msg = direct_msg.text

         # though Twitter handles replies correctly, identi.ca falsely claims
         # everything to be a reply that just contains '@logbot' (i.e. the
         # bot's user name) _somewhere_ in a message body, so even if
         # completely unrelated, such as '@dagobart, @logbot is great'.
         # Therefore, we fix that by +(/^@#{bot_name}/ =~ msg)+ below; the
         # attached +!(sender_name == bot_name)+ is only there to prevent the
         # bot from chatting with itself.
         bot_name = @connector.username
         sender_screen_name = direct_msg.sender_screen_name
         sender_id = direct_msg.sender_id

         if !(sender_screen_name == bot_name) then
           # take side-note(s):
           id = direct_msg.id.to_i
           if (id > latest_direct_message_id.to_i) then
             latest_direct_message_id = id
           end

           # perform actual collect:
             latest_direct_msgs << {
                          'created_at' => direct_msg.created_at,
                                  'id' => id,
                         'screen_name' => sender_screen_name,
                                'text' => msg,
                             'user_id' => sender_id
                       }
         # else
         #  puts "'#{msg}'"
         end
       end
       # puts latest_replies.pretty_inspect

     self.latest_direct_message_received = latest_direct_message_id if perform_latest_message_id_update

    return latest_direct_msgs
  end

  def shutdown
    yaml_file = File.open( LATEST_TWEED_ID_PERSISTENCY_FILE, 'w' )
    yaml_file.write(@latest_messages.to_yaml)
    yaml_file.close
  end

  alias_method :persist, :shutdown
end
