require 'test/unit/testsuite'

# main_dir  = File.join(File.dirname(__FILE__), '..', '')
# require (main_dir + 'micro_blog_consts')
# require (main_dir + 'micro_blog_connector')
# require (main_dir + 'micro_blog_friending')
# require (main_dir + 'micro_blog_messaging_io')

tests_dir = File.join(File.dirname(__FILE__), '')
require (tests_dir + 'tc_micro_blog_connector')
require (tests_dir + 'tc_micro_blog_friending')
require (tests_dir + 'tc_micro_blog_messaging_io')

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
