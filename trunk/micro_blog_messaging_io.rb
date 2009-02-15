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
  def initialize(connector)
    @connector = connector
    @connection = @connector.connection
    @latest_tweeds = YAML::load( File.open( LATEST_TWEED_ID_PERSISTENCY_FILE ) )
  end

  def say(msg)
    @connection.update(msg)
  end

  def destroy(message_id)
    @connection.destroy(message_id)
  end # fixme: add test

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

  def latest_message_received
    @latest_tweeds['inbox_latest'][@connector.service_in_use]
  end

  def latest_message_received=(new_latest_ID)
    @latest_tweeds['inbox_latest'][@connector.service_in_use] = new_latest_ID
  end

  # Note: During the collect, we do temp-store the latest received message id
  # to a temporary storage +latest_message_id+ rather than using
  # latest_message_received(). That's for performance: Using
  # latest_message_received would involve the use of several hashes rather
  # than just updating a single Fixnum.
  def get_latest_replies(perform_latest_message_id_update = true)
    latest_message_id = self.latest_message_received # 1st received on twitter: 1158336454

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

    self.latest_message_received = latest_message_id if perform_latest_message_id_update

    return latest_replies
  end

  def shutdown
    yaml_file = File.open( LATEST_TWEED_ID_PERSISTENCY_FILE, 'w' )
    yaml_file.write(@latest_tweeds.to_yaml)
    yaml_file.close
  end

  alias_method :persist, :shutdown
end
