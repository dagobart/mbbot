require 'test/unit'

require File.join(File.dirname(__FILE__), '..', 'micro_blog_messaging_io')

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
  attr_reader :connector, :connection
  attr_accessor :latest_tweeds
end
class TC_MicroBlogMessagingIO < Test::Unit::TestCase
  def setup
    @mb_services = KNOWN_MICRO_BLOGGING_SERVICES

    service_is_available = SERVICE_IS_AVAILABLE
    service__config_file = MB_SERVICE__CFG_FILE

    @latest_message_received = Hash.new
      @connector__message_io = Hash.new
                  @connector = Hash.new
                 @message_io = Hash.new

    service__config_file.each do |mb_service, config_file|
      if service_is_available[mb_service] then
         connector = MicroBlogConnector.new(config_file)
        message_io = MicroBlogMessagingIO.new(connector)

        @connector__message_io[connector] = message_io

           @connector[mb_service] = connector
          @message_io[mb_service] = message_io
        @latest_message_received[mb_service] =
               message_io.latest_tweeds['inbox_latest'][mb_service].to_i
      end
    end
  end

  def test_initialize
    @connector__message_io.each do |c,io|
       assert_same c, io.connector
       assert_same c.connection, io.connection
    end

    KNOWN_MIN_TWEED_ID.each do |mb_service, min_tweed_id|
      assert @latest_message_received[mb_service] >= min_tweed_id if SERVICE_IS_AVAILABLE[mb_service]
    end
  end

  def test_say
    @connector__message_io.each do |connector, io|
      message = "test: say(#{rand.to_s})"
      result = io.say(message)

        assert_same Twitter::Status, result.class
        assert result.id != nil
        assert_equal message, result.text
        assert_equal connector.username, result.user.screen_name

      io.connection.destroy(result.id) unless connector.service_lacks['destroy']
    end
  end

  def test_reply
    @connector__message_io.each do |connector, io|
      pilot_fish = io.say("test: say(#{rand.to_s})")
      message = "test: reply(#{pilot_fish.id}, #{rand.to_s})"
      result = io.reply(message, pilot_fish.id, pilot_fish.user.id)

        assert_same Twitter::Status, result.class
        assert result.id != nil
        assert_equal pilot_fish.id, result.in_reply_to_status_id
        assert_equal message, result.text
        assert_equal connector.username, result.user.screen_name
        assert_equal pilot_fish.user.id, result.user.id

      unless connector.service_lacks['destroy']
        io.connection.destroy(result.id)
        io.connection.destroy(pilot_fish.id)
      end
    end
  end

  def test_latest_message_received__read
    @message_io.each do |mb_service, io|
      assert_equal @latest_message_received[mb_service],
                   io.latest_message_received.to_i
    end
  end

  def test_latest_message_received__write
    @message_io.values.each do |io|
      value = rand.to_s
      assert_equal value, io.latest_message_received = value

      # bonus: do an additional read test:
      assert_equal value, io.latest_message_received
    end
  end

  def test_get_latest_replies
    @message_io.each do |mb_service, io|
      ancient_msg_max_id = KNOWN_MIN_TWEED_ID[mb_service]

        io.latest_message_received = ancient_msg_max_id
        latest_replies = io.get_latest_replies(false)
        latest_reply = latest_replies.last

      assert_equal ancient_msg_max_id, io.latest_message_received
      assert latest_replies.size > 0
      assert_not_nil latest_reply
      assert_same Hash, latest_reply.class
      assert ancient_msg_max_id < latest_reply['id']

        recent_replies = io.get_latest_replies(true)
        latest_reply = recent_replies.first
        # puts mb_service, recent_replies.pretty_inspect, recent_replies.first.pretty_inspect

      assert       ancient_msg_max_id < io.latest_message_received
      assert       ancient_msg_max_id < latest_reply['id']
      assert_equal io.latest_message_received, latest_reply['id']
    end
  end # FIXME: unify whether or not IDs shall be Fixnums or Strings

  def test_shutdown
    msg_io_for_compare = []
      conn_for_compare = []
    KNOWN_MICRO_BLOGGING_SERVICES.each do |mb_service|
      if SERVICE_IS_AVAILABLE[mb_service] then
        msg_io_for_compare << @message_io[mb_service]
          conn_for_compare << @connector[mb_service]
      end
    end
    assert_not_nil msg_io_for_compare
    1.upto(msg_io_for_compare.size - 1) do |index|
      assert_equal msg_io_for_compare[0].latest_tweeds,
                   msg_io_for_compare[index].latest_tweeds
    end
    message_io = msg_io_for_compare[0]
    connector  =   conn_for_compare[0]

      orig_latest_tweeds = message_io.latest_tweeds

        # Note:
        # w/o the two to_s, the later equality assertion fails
        # although it displays exactly the same values for both
        # values compared, i.e. for +new_latest_tweeds+ and for
        # what gets compared to it.
        new_latest_tweeds = {
        		      'inbox_latest' =>
        		    	{
        		    	  'identica' => rand.to_s,
        		    	  'twitter'  => rand.to_s
        		    	}
        		    }
        message_io.latest_tweeds = new_latest_tweeds
        message_io.shutdown

        message_io = MicroBlogMessagingIO.new(connector)

        assert_equal new_latest_tweeds, message_io.latest_tweeds

      message_io.latest_tweeds = orig_latest_tweeds
      message_io.shutdown

    message_io = MicroBlogMessagingIO.new(connector)
    assert_equal orig_latest_tweeds, message_io.latest_tweeds
  end # FIXME: if possible, unify whether it's to be latest_tweeds or latest_message_received
end
