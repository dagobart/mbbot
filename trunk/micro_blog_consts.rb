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

# After tons of hassles with disrupted Ruby/Rails/RubyGems installations --
# http://is.gd/hvM9 -- I gave in and gave another Debian Ruby/Rails a try,
# that is Debian Lenny's Ruby. Currently -- that is just before release of
# Debian Lenny -- if not perfect, it looks usable. I hope backports.org will
# keep us up to date with Ruby/Rails/RubyGems once Lenny's released.
#
# To get this here Twitter bot up and running, additionally to the default
# Debian ruby package, you need the following:
#
# deb: ruby-dev => mkmf
# gem: twitter => core gem
#      echoe => fix rubygems

# Obviously, as you don't want  to be held legally responsible for any kind
# of abusive action taken through your bot account, you don't want to share
# your actual login data for the ~Twitter bot with the rest of us. Neither do
# I.
#    Hence, to the repository I check in false login data in the form of some
# yaml files, so everyone easily can get the idea of what format the yaml
# shall be in. On the other hand, I keep another set of yaml files that hold
# valid login data for the bots I am using for development.
#    As much as the next one I dislike software packages checked out somewhere
# else only to find them disrupt. Therefore, Prior to every update to the
# repository, I make sure the bot code refers to files that are actually
# there even if filled with invalid data -- the latter will be pointed out by
# mechanisms inside the bot, while the prior just leaves the inexperienced
# clueless: "What *are* these files, that error message is talking about?"
#    In the past, I eased the swap-in/swap-out process by having the another
# set of yaml files named just like those checked in to the repository, with
# the only exception that they are prepended with  a "my-".
#    Though, still the files names were hard-coded all around. This changes
# by now, collecting them all below.
#    Still the advice holds true: Copy the checked in/checked out credential
# files to some own ones, patch them to have valid credentials and make sure
# that the names of these valid files are assigned to
# VALID_TWITTER_CREDENTIALS__DO_NOT_CHECK_IN and
# VALID_IDENTICA_CREDENTIALS__DO_NOT_CHECK_IN respectively.
config_dir      = File.join(File.dirname(__FILE__), 'config', '')
fixtures_dir    = File.join(File.dirname(__FILE__), 'test',   'fixtures', '')
credentials_dir = File.join(File.dirname(__FILE__), 'config', 'credentials', '')

 INVALID_TWITTER_CREDENTIALS                = credentials_dir +    'twitterbot.yaml'
INVALID_IDENTICA_CREDENTIALS                = credentials_dir +     'identibot.yaml'
VALID_TWITTER_CREDENTIALS__DO_NOT_CHECK_IN  = credentials_dir + 'my-twitterbot.yaml'
VALID_IDENTICA_CREDENTIALS__DO_NOT_CHECK_IN = credentials_dir +  'my-identibot.yaml'
VALID_CONNECT_CREDENTIALS__DO_NOT_CHECK_IN  = credentials_dir + 'my-bot.yaml'

INVALID_CONNECT_CREDENTIALS = INVALID_TWITTER_CREDENTIALS
DEFAULT_CONFIG_FILE = INVALID_CONNECT_CREDENTIALS

FIXTURES__ORIGINAL_TWITTERBOT = fixtures_dir + 'original-twitterbot.yaml'
FIXTURES__OTHER_ENABLED_WITH_INVALID_API_URI =
	         fixtures_dir + 'other-enabled_with_invalid_api_URI.yaml'

MB_SERVICE__CFG_FILE =
	{
	 'identica' => VALID_IDENTICA_CREDENTIALS__DO_NOT_CHECK_IN,
	  'twitter' =>  VALID_TWITTER_CREDENTIALS__DO_NOT_CHECK_IN
	}
KNOWN_MICRO_BLOGGING_SERVICES = MB_SERVICE__CFG_FILE.keys
KNOWN_MIN_TWEED_ID = {
		       'identica' => 2068347,
		        'twitter' => 1164876335
		     }
LATEST_TWEED_ID_PERSISTENCY_FILE = config_dir + 'latest_tweeds.yaml'

MISSING_FEATURES =
    {
      'identica' => ['follow', 'leave'],
      'twitter'  => []
    }
POSSIBLE_SHORTFALLS = MISSING_FEATURES.values.flatten.uniq

# As downtimes happen more often than not, we now support
# skipping down services.
#
# How to know how to initialize this hash's values?
# : If lots of tests fail with a Twitter::CantConnect
#   though you changed little or even nothing, that's an
#   indicator, that the respective micro-blogging service
#   is temporarily down. -- I experienced this mostly on
#   Twitter, never on Identi.ca -- dagobart/20090203
SERVICE_IS_AVAILABLE = {'twitter'  => true,
			'identica' => true}