require 'test/unit/testsuite'
# require 'test/unit/ui/console/testrunner'
# require 'micro_blog_consts'
# require 'micro_blog_connector'
# require 'micro_blog_friending'
# require 'micro_blog_messaging_io'
require 'tc_micro_blog_connector'
require 'tc_micro_blog_friending'
require 'tc_micro_blog_messaging_io'

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
#
# Test::Unit::UI::Console::TestRunner.run(TS_MOM_DSL)
