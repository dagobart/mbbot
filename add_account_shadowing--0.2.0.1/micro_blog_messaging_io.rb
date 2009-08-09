# require 'micro_blog_friending'
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
  def initialize(connector, skip_catchup = false)
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
  #        message ID

  # returns the ID of the most current message currently receivable from the uB
  # service 
  def now_current_message_id
    return @connection.timeline(:public, :count => 1).first.id.to_i
  end

  def skip_catchup # FIXME: initializes values invalidly since every kind of msg stream may have its own counter
    latest_message = now_current_message_id

    [:own_timeline, :public_timeline, :friends_timeline, 
     :incoming_DMs, :mentions, :replies].each do |msg_type|
       @latest_messages[msg_type.to_s] = 
         { @connector.service_in_use => latest_message }
    end
    # puts @latest_messages.pretty_inspect
  end # fixme: add tests
  # fixme: create global array const that lists all the msg_types,
  #        and use that const above

  def say(msg)
    @connection.update(msg)
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
      @connection.update(msg, {
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
  end # fixme: replace string hash keys by symbol hash keys
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
  end # fixme: replace string hash keys by symbol hash keys
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
    message_id_current_prior_to_catching_up = self.now_current_message_id

      if    type == :own_timeline     then
           msgs = process_timeline_messages(
                    @connection.timeline(:user,
                                         :since_id => latest_message_id))
      elsif type == :public_timeline  then
           msgs = process_timeline_messages(
                    @connection.timeline(:public,
                                         :since_id => latest_message_id))
      elsif type == :friends_timeline then
           msgs = process_timeline_messages(
                    @connection.timeline(:friends,
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
                                 message_id_current_prior_to_catching_up)
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
      update_message_counter(type, message_id_current_prior_to_catching_up)
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
