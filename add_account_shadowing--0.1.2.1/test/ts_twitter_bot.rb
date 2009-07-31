require 'test/unit/testsuite'

tests_dir = File.join(File.dirname(__FILE__), '')
require (tests_dir + 'tc_micro_blog_connector')
require (tests_dir + 'tc_micro_blog_friending')
require (tests_dir + 'tc_micro_blog_messaging_io')

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

class TS_MOM_DSL
  def self.suite
    suite = Test::Unit::TestSuite.new

      suite << TC_MicroBlogConnector.suite
      suite << TC_MicroBlogFriending.suite
      suite << TC_MicroBlogMessagingIO.suite

      # assert false

    return suite
  end
end
