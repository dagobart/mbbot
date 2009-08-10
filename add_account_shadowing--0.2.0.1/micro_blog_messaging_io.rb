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


  # fixme: make yaml file paragraph headlines match the xxx of +latest_xxx+/
  #  +latest_xxx=+, so it gets easier [for humans] to see the connection
  #  between the yaml file chunks and the methods here in the class
  def get_latest_message_id(type) # 1st received on Twitter: 1158336454
    return @latest_messages[type.to_s][@connector.service_in_use]
  end  # fixme: + add tests

  def set_latest_message_id(type, new_latest_ID)
    @latest_messages[type.to_s][@connector.service_in_use] = new_latest_ID
  end # fixme: + add tests


  def latest_mention=(new_latest_ID)
    set_latest_message_id(:mentions, new_latest_ID)
  end # fixme: + add tests
  alias_method :latest_mention_received=, # Deprecated. Old name
               :latest_mention=

  def latest_mention
    return get_latest_message_id(:mentions)
  end # fixme: + add tests
  alias_method :latest_mention_received, # Deprecated. Old name
               :latest_mention


  def latest_reply=(new_latest_ID)
    set_latest_message_id(:replies, new_latest_ID)
  end # fixme: + add tests
  alias_method :latest_reply_received=, # Deprecated. Old name
               :latest_reply=

  def latest_reply
    return get_latest_message_id(:replies)
  end # fixme: + add tests
  alias_method :latest_reply_received, # Deprecated. Old name
               :latest_reply


  def latest_own_timeline_message=(new_latest_ID)
    set_latest_message_id(:own_timeline, new_latest_ID)
  end # fixme: + add tests
  alias_method :latest_post=,                # convenience shorthand 
               :latest_own_timeline_message=

  def latest_own_timeline_message
    return get_latest_message_id(:own_timeline)
  end # fixme: + add tests
  alias_method :latest_post,                # convenience shorthand 
               :latest_own_timeline_message


  def latest_public_timeline_message=(new_latest_ID)
    set_latest_message_id(:public_timeline, new_latest_ID)
  end # fixme: + add tests

  def latest_public_timeline_message
    return get_latest_message_id(:public_timeline)
  end # fixme: + add tests


  def latest_friends_timeline_message=(new_latest_ID)
    set_latest_message_id(:friends_timeline, new_latest_ID)
  end # fixme: + add tests
  alias_method :latest_friend_message=,          # convenience shorthand 
               :latest_friends_timeline_message=

  def latest_friends_timeline_message
    return get_latest_message_id(:friends_timeline, new_latest_ID)
  end # fixme: + add tests
  alias_method :latest_friend_message,          # convenience shorthand 
               :latest_friends_timeline_message


  def latest_incoming_DM=(new_latest_ID)
    set_latest_message_id(:incoming_DMs, new_latest_ID)
  end # fixme: + add tests
  alias_method :latest_DM=,         # convenience shorthand
               :latest_incoming_DM=

  def latest_incoming_DM
    return get_latest_message_id(:incoming_DMs, new_latest_ID)
  end # fixme: + add tests
  alias_method :latest_DM,         # convenience shorthand
               :latest_incoming_DM


  # +type+ - any of these: [:own_timeline, :public_timeline, :friends_timeline,
  #  :mentions, :replies, :incoming_DMs]
  # +latest_received_message_id+ - the ID of the most currently received message
  #  i.e.: Usually, whenever the bot polls for new messages, it does so for the
  #  messages between the latest one polled and the most current one available
  #  at the service. The ID of that most current one received is the ID you'd
  #  provide as +latest_received_message_id+.
  #
  # Note: Why do we store the +latest_received_message_id+ rather than the ID
  #  of the latest message of the given type? Because: The latest messages poll
  #  covers all the messages received in between of the previously latest known
  #  message and the now latest known message. Therefore processing covers all
  #  that range also, even if there are messages past the latest known message
  #  _of_ _type_. But none of those messages past the latest one of +type+,
  #  well, _is_ of +type+. Therefore, for the next poll, it's safe to skip
  #  that remainder too. Therefore, we store +latest_received_message_id+, not
  #  the ID of the latest known message of +type+.
  def update_message_counter(type, latest_received_message_id)
    set_latest_message_id(type, latest_received_message_id)
  end # fixme: + add tests


  def process_timeline_messages(messages)
    processed_messages = []

      messages.each do |msg|
        processed_messages << {
	  		         'created_at' => msg.created_at,
				         'id' => msg.id.to_i,
			        'screen_name' => msg.user.screen_name,
				       'text' => msg.text,
				    'user_id' => msg.user.id
	  		    }
      end

    processed_messages
  end # fixme: ^ replace string hash keys by symbol hash keys
      # fixme: + add tests

  def process_private_messages(messages)
    processed_messages = []

      messages.each do |msg|
        processed_messages << {
	  		         'created_at' => msg.created_at,
				         'id' => msg.id.to_i,
			        'screen_name' => msg.sender_screen_name,
				       'text' => msg.text,
				    'user_id' => msg.sender_id
	  		       }
      end

    processed_messages
  end # fixme: ^ replace string hash keys by symbol hash keys
      # fixme: + add tests

  # types of message streams/messages:
  # * private direct messages ("DMs")
  # ** incoming DMs
  # ** outgoing DMs
  #
  # * global public timeline
  # ** incoming globally visible messages
  # *** mentions of self (immediately readable//accessible as 'mentions')
  # **** replies/public messages directed at self
  # ** no outgoing messages
  #
  # * friends' timeline
  # ** incoming for self visible messages
  # *** mentions of self (immediately readable//accessible as 'mentions')
  # **** replies/public messages directed at self ("replies")
  # ** no outgoing messages
  #
  # * own timeline
  # ** outgoing own posts
  # ** no incoming messages
  #
  # message streams yet known as relevant:
  # * incoming DMs: for commands, requests
  # * replies: for commands, requests
  # * friends' timeline: for incoming messages forwarding
  # * own timeline: for shadow bot commanding
  # * mentions: for got-mentioned detection/connecting with not yet known peers
  # ** + add method that gets mentions only, ie. w/o replies in between
  #(* public timeline: for keyword detection)
  def get_latest_messages(perform_latest_message_id_update = true, 
                          type = :mentions)
    msgs = []
    latest_message_id = @latest_messages[type.to_s][@connector.service_in_use]
    message_ids_current_prior_to_catching_up = self.now_current_message_ids

      message_stream_type = @message_type__message_stream_type[type]

      if   message_stream_type then
           msgs = process_timeline_messages(
#                    @connection.timeline(message_stream_type, # replacement
                                 timeline(message_stream_type, # not yet tested
                                          :since_id => latest_message_id))
      elsif type == :incoming_DMs     then
           msgs = process_private_messages(
                    @connection.direct_messages(:since_id => latest_message_id))
      elsif (type == :mentions)       ||   # both in one conditional since 
            (type == :replies)        then #  replies is a subset of mentions
           msgs = process_timeline_messages(
                    @connection.replies(:since_id  => latest_message_id))
                    # The above ^^^^^^^ 'replies' actually refers to mentions.
                    # Misnomer of the Twitter 0.4.1 gem, but fault courtesy of
                    # twitter.com as they replaced replies by mentions.
                    #
        # as every persistent update of the latest message counter saves 
        # processing the next time we poll, and as we by now already know the
        # latest ID of :mentions, let's update their counter quickly:
        if perform_latest_message_id_update then
          update_message_counter(:mentions,
                          message_ids_current_prior_to_catching_up[:mentions])
        end
      end # fixme: simplify the if/elsif conditions

      if (type == :replies) then
        # ...then we fetched the mentions so far, thence now we need to
        # filter out everything that's a mention, not a true reply: 
        msgs.delete_if { |message|
          (@bot_name        == message['screen_name']) || 
          (/^@#{@bot_name}/ !~ message['text'])
          # fixme: replace string hash keys by symbol hash keys
        }
        # The +(@bot_name == message['screen_name'])+ condition is
        # there to prevent the bot from considering messages issued by
        # itself as replies to it self (which might cause soliloquies).
      end
      # puts msgs.pretty_inspect

    if perform_latest_message_id_update then
      update_message_counter(type, 
                             message_ids_current_prior_to_catching_up[type])
    end

    return msgs
  end # fixme: + add tests

  # Mentions are messages that mention the user's screen name pretended by an 
  # '@' character, e.g. @dagobart.
  # Replies are a subset of mentions: Mentions that start with the @-prepended
  # mention of the user's name are replies.
  #
  # Note: During the collect, we do temp-store the latest received message id
  # to a temporary storage +latest_message_id+ rather than using
  # latest_mention_received(). That's for performance: Using
  # latest_mention_received would involve the use of several hashes rather
  # than just updating a single Fixnum.
  def get_latest_mentions(perform_latest_reply_id_update = true)
    get_latest_messages(perform_latest_reply_id_update, :mentions)
  end # fixme: + add tests

  def get_latest_replies(perform_latest_reply_id_update = true)
    get_latest_messages(perform_latest_reply_id_update, :replies)
  end # fixme: + add tests

  def get_latest_own_timeline_messages(perform_latest_reply_id_update = true)
    get_latest_messages(perform_latest_reply_id_update, :own_timeline)
  end # fixme: + add tests
  alias_method :get_latest_posts, :get_latest_own_timeline_messages
  # FIXME: add get_latest_*() for the other possible message streams

  # fixme: maybe we could speed up this method by avoiding write access when
  #        @latest_messages didn't change at all in between
  # fixme: what shall happen in case the file cannot be written, say disk full?
  def shutdown
    yaml_file = File.open( LATEST_TWEED_ID_PERSISTENCY_FILE, 'w' )
    yaml_file.write(@latest_messages.to_yaml)
    yaml_file.close
  end

  alias_method :persist, :shutdown
end
