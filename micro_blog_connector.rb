require 'rubygems'
gem('twitter', '>=0.4.1')
require 'twitter'
require 'yaml'
# require 'micro_blog_consts'
require File.join(File.dirname(__FILE__), 'micro_blog_consts')

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
  def initialize(config_file = DEFAULT_CONFIG_FILE)
    @account_data = YAML::load(File.open(config_file))

    # initialize read-only variables:
       @service_in_use = @account_data['account']['service']
             @username = @account_data[@service_in_use]['user']
             @password = @account_data[@service_in_use]['password']
            @peer_user = @account_data[@service_in_use]['peer'] # FIXME: add test for this
           @supervisor = @account_data[@service_in_use]['supervisor'] # FIXME: add test for this
    @use_alternative_api = @account_data[@service_in_use]['use_alternative_api']

    @service_lacks = Hash.new
    POSSIBLE_SHORTFALLS.each do |possible_shortfall|
      current_service_lacks_anything = (MISSING_FEATURES[service_in_use.downcase] != nil)
      @service_lacks[possible_shortfall] = (MISSING_FEATURES[service_in_use.downcase].find_index(possible_shortfall) != nil) if current_service_lacks_anything
    end

    # ensure we're not using some intendedly invalid credentials:
    assess_account_data

      # perform actual connect:
      if use_alternative_api? then
        begin
          @connection = Twitter::Base.new(@username, @password, :api_host => @use_alternative_api)
        rescue Twitter::CantConnect
          raise Twitter::CantConnect,
        	   "#{config_file}: Failed to connect to micro-blogging service provider '#{@service_in_use}'."
        end
      else
        @connection = Twitter::Base.new(@username, @password)
      end

    # finish initializing read-only variables:
    @user_id = @connection.user(@username).id   # ; puts @user_id; exit
  end # we even could implement a reconnect()--but skip that now

  attr_reader :connection, :user_id, :use_alternative_api, :service_in_use, :service_lacks, :peer_user, :supervisor, :username #, :password

  def errmsg(error)
    if error == Twitter::CantConnect
      "#{@service_in_use} says it couldn't connect. Translates to: is refusing to perform the desired action for us."
    else
      "something went wrong on #{@service_in_use} with the just before intended action."
    end
  end

  def use_alternative_api?
    @use_alternative_api != nil
  end

  # forces you to use non-default -- read: not known to the
  # world --  login data
  def assess_account_data
    if (@password == 'secret')
      raise StandardError,
           "\nPlease, use a serious password (or some other config but any of the default -- and intendedly invalid -- ones)!\n"
    end
  end
end
