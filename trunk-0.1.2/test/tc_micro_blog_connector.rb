require 'test/unit'

require File.join(File.dirname(__FILE__), '..', 'micro_blog_connector')

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

class MicroBlogConnector
  attr_reader :password
end
class TC_MicroBlogConnector < Test::Unit::TestCase
  def setup
      twitter_config_file = nil
     identica_config_file = nil

    # comment away the following two lines for check-in,
    # uncomment them for actual testing:
     twitter_config_file =
                    VALID_TWITTER_CREDENTIALS__DO_NOT_CHECK_IN
    identica_config_file =
                   VALID_IDENTICA_CREDENTIALS__DO_NOT_CHECK_IN

    service_is_available = SERVICE_IS_AVAILABLE
    if service_is_available['twitter'] then
      @twitter_connector =
                   MicroBlogConnector.new(twitter_config_file)
    else
      @twitter_connector = nil
    end

    if service_is_available['identica'] then
      @identica_connector =
                  MicroBlogConnector.new(identica_config_file)
    else
      @identica_connector = nil
    end

    @connectors = [@twitter_connector, @identica_connector]
    @connectors.delete(nil)
  end

  def test_initialize_in_general
    # assert false # make sure test gets executed at all

    assert_raise StandardError do MicroBlogConnector.new end
    assert_raise StandardError do
      invalid_connector = MicroBlogConnector.new(FIXTURES__ORIGINAL_TWITTERBOT)
    end

    assert_raise Twitter::CantConnect do
      MicroBlogConnector.new(FIXTURES__OTHER_ENABLED_WITH_INVALID_API_URI)
    end
  end

  def test_initialize_twitter
    # assert false # make sure test gets executed at all

    # do nothing when Twitter is down:
    return if @twitter_connector == nil

    assert_equal 'twitter',  @twitter_connector.service_in_use
    assert_equal 'logbot',   @twitter_connector.username
    assert       'secret' != @twitter_connector.password
    assert_equal  nil,       @twitter_connector.use_alternative_api
    assert                  !@twitter_connector.use_alternative_api?
    assert_equal '19619847', @twitter_connector.user_id

    MISSING_FEATURES['twitter'].each do |shortfall|
      assert @twitter_connector.service_lacks[shortfall]
    end
  end

  def test_initialize_identica
    # assert false # make sure test gets executed at all

    # do nothing when Identi.ca is down:
    return if @identica_connector == nil

    assert_equal 'identica', @identica_connector.service_in_use
    assert_equal 'logbot',   @identica_connector.username
    assert       'secret' != @identica_connector.password
    assert_equal 'identi.ca/api',
                             @identica_connector.use_alternative_api
    assert                  @identica_connector.use_alternative_api?
    assert_equal '36999',    @identica_connector.user_id

    MISSING_FEATURES['identica'].each do |shortfall|
      assert @identica_connector.service_lacks[shortfall]
    end
  end

  def test_errmsg
    # assert false # make sure test gets executed at all

    @connectors.each do |connector|
      assert '' != connector.errmsg(Twitter::CantConnect)
    end
  end
end
