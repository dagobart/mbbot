require 'rubygems'
require 'yaml'
require File.join(File.dirname(__FILE__), 'micro_blog_consts')

# Unfortunately, the twitter gem supports identi.ca only prior to v0.5.0,
# therefore we need to use the old gem in case we want our bot to work on
# identi.ca too. Identi.ca support is tested only for v0.4.1 therefore we
# use that v0.4.1 as 'the old gem':
#
# FIXME:
# to avoid to always remember to manually flip +USE_IDENTICA+ to +true+
# or +false, I added an ugly hack that directly accesses a config file and
# hard-codes 'twitter' to be the indicator for +USE_IDENTICA+ to become
# +false+/+true+. The flip causes the twitter gem 0.4.1 (for identi.ca) or
# any later (for Twitter) to be loaded. (The reason for why this hack is
# this ugly -- has two hard-coded values and iterates what's essentially
# in initialize() yet --  is that I assume if I'd do it within
# initialize(), the scope of the gem operation would be restricted to that
# initialize() rather than applying to the whole program. -- If you've got
# a patch that fixes this, you're greatly welcome to contribute it!)
if YAML::load(File.open(VALID_CONNECT_CREDENTIALS__DO_NOT_CHECK_IN))['account']['service'] == 'twitter' then
  USE_IDENTICA = false
else
  USE_IDENTICA = true
end
USE_GEM_0_4_1 = USE_IDENTICA

## RuRUG: How to implement the gem version switch more elegantly?
## RuRUG: Is it possible to figure out the version of the loaded gem w/o using that USE_GEM_0_4_1 const?

# '=0.4.1' for identi.ca support, '>0.4.1' for Twitter support
#
# If you want to, you could set +USE_GEM_0_4_1+ to +true+ even if
# you'd set +USE_IDENTICA+ at the same time, so you could run your
# bot on the 0.4.1 version of the twitter gem with Twitter.
gem('twitter', USE_GEM_0_4_1 ? '=0.4.1' : '>0.4.1')

require 'twitter'


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
            @peer_user = @account_data[@service_in_use]['peer']
           @supervisor = @account_data[@service_in_use]['supervisor']
  @use_alternative_api = 
      @account_data[@service_in_use]['use_alternative_api']

    @service_lacks = Hash.new
    POSSIBLE_SHORTFALLS.each do |possible_shortfall|
      current_service_lacks_anything = (MISSING_FEATURES[service_in_use.downcase] != nil)
      @service_lacks[possible_shortfall] = (MISSING_FEATURES[service_in_use.downcase].find_index(possible_shortfall) != nil) if current_service_lacks_anything
    end

    # ensure we're not using some intendedly invalid credentials:
    assess_account_data

      # perform actual connect:
      if use_alternative_api? then
        unless USE_GEM_0_4_1
          raise "using an alterenative API but not twitter gem v0.4.1" 
          # The assumption is that using an alternative API -- declared
          # by the entries of the credentials YAML file -- together with
          # a twitter gem > 0.4.1 won't work. Hence, if using an
          # alternative API, the developer should flip the +USE_IDENTICA+
          # switch atop of this here file to TRUE, too, then.
          #
          # Explanation:
          # Using a twitter gem > 0.4.1 with the below connection code
          # won't work since Twitter::Base.new changed its interface//
          # expected params.
        end

        begin
          @connection = Twitter::Base.new(@username, @password, 
                                          :api_host => @use_alternative_api)
          rescue Twitter::CantConnect
           raise Twitter::CantConnect,
                 "#{config_file}: Failed to connect to micro-blogging" +
                                " service provider '#{@service_in_use}'."
        end

      # end-if use_alternative_api?

      else
        if USE_GEM_0_4_1 then
          @connection = Twitter::Base.new(@username, @password)
        else
          @auth = Twitter::HTTPAuth.new(@username, @password)
          @connection = Twitter::Base.new(@auth)
        end
      end

    # finish initializing read-only variables:
    user = @connection.user(@username) # ID determination apparently needs to be performed by two steps instead of one, otherwise the '.id' gets interpreted as a call of +Object.id+
    @user_id = user.id
  end # we even could implement a reconnect()--but skip that now

  attr_reader :connection, :user_id, :use_alternative_api, :service_in_use, :service_lacks, :peer_user, :supervisor, :username #, :password

  def errmsg(error)
    if error == Twitter::CantConnect
      "#{@service_in_use} says it couldn't connect. Translates to: is" +
        " refusing to perform the desired action for us."
    else
      "something went wrong on #{@service_in_use} with the just before" +
        " intended action."
    end
  end # FIXME: not yet tested: connecting Twitter with a current twitter gem

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
