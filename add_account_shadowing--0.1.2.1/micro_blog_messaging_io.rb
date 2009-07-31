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
  # latest_tweeds.yaml to persist the ID of the latest received tweed.
  # Reason for not reusing the login credentials file is the risk of
  # accidentally kill that file, thus the login credentials might get lost.
  #
  # If you've got an idea how to improve the latest tweed ID storage, please
  # let me know. -- @dagobart/20090129
  def initialize(connector, skip_catchup = false)
    @connector = connector
    @connection = @connector.connection

    @bot_name   = @connector.username

    @latest_tweeds = YAML::load( File.open( LATEST_TWEED_ID_PERSISTENCY_FILE ) )
    if skip_catchup
      @latest_tweeds['inbox_latest'][@connector.service_in_use] = 
        @connection.timeline(:public, :count => 1).first.id.to_i
      # FIXME: get rid of above ugly hack (ugly because of direct 
      #        data access rather than using specialized methods)
      # fixme: get rid of [everywhere] hard-coded 'inbox_latest'
      # fixme: add test for the +skip_tweets_processing_catchup+ option
    end
  end # fixme: rename "latest_tweeds" to "latest_tweets" (typo)

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

  alias_method :latest_message_received,  :latest_mention_received
  alias_method :latest_message_received=, :latest_mention_received=

  def latest_mention_received
    @latest_tweeds['inbox_latest'][@connector.service_in_use]
  end

  def latest_mention_received=(new_latest_ID)
    @latest_tweeds['inbox_latest'][@connector.service_in_use] = new_latest_ID
  end

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
  def get_latest_mentions(perform_latest_mention_id_update = true)
    latest_mention_id = self.latest_mention_received # 1st received on Twitter: 1158336454

      latest_mentions = []
      @connection.replies(:since_id => latest_mention_id).each do |mention|
      # above     ^^^^^^^ 'replies' actually refers to mentions. Misnomer
      # of the Twitter 0.4.1 gem, but fault courtesy of twitter.com as they 
      # replaced replies by mentions.

        # take side-note(s):
        mention_id = mention.id.to_i
        latest_mention_id = mention_id if (mention_id > latest_mention_id.to_i)

        # perform actual collect:
        latest_mentions << {
			       'created_at' => mention.created_at,
				       'id' => mention_id,
			      'screen_name' => mention.user.screen_name,
				     'text' => mention.text,
				  'user_id' => mention.user.id
	                   }
      end
      # puts latest_mentions.pretty_inspect

    self.latest_mention_received = latest_mention_id if perform_latest_mention_id_update

    return latest_mentions
  end # fixme: replace string hash keys by symbol hash keys

  def get_latest_replies(perform_latest_reply_id_update = true)
    get_latest_mentions(perform_latest_reply_id_update).delete_if { |mention| 
      (@bot_name        == mention['screen_name']) || 
      (/^@#{@bot_name}/ !~ mention['text'])
      # The +!(sender_name == @bot_name)+ condition is there to prevent the 
      # bot from considering messages issued by itself as replies to it self 
      # (which might cause soliloquies).
    }
  end # fixme: + add tests
  # fixme: ^ unify get_latest_* methods to a core, e.g. get_latest_messages(), 
  # and call it by get_latest_replies(), get_latest_PMs(), get_latest_posts(),..
  # fixme: test against Twitter
  # fixme: + add post/PM id persistency

  # fixme: maybe we could speed up this method by avoiding write access when
  #        @latest_tweeds didn't change at all in between
  # fixme: what shall happen in case the file cannot be written, say disk full?
  def shutdown
    yaml_file = File.open( LATEST_TWEED_ID_PERSISTENCY_FILE, 'w' )
    yaml_file.write(@latest_tweeds.to_yaml)
    yaml_file.close
  end

  alias_method :persist, :shutdown
end
