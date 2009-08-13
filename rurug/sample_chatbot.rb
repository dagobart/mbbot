main_dir = File.join(File.dirname(__FILE__), '')
require (main_dir + 'micro_blog_bot')

default_err_msg = 'We had a Twitter Error.'
err_msgs = 
  {
    'Twitter::RateLimitExceeded' => default_err_msg,
        'Twitter::InformTwitter' => default_err_msg,
         'Twitter::TwitterError' => default_err_msg,
          'Twitter::Unavailable' => default_err_msg,
             'Twitter::NotFound' => default_err_msg,
             'Crack::ParseError' => 'We had a Parsing Error in the JSON Stream.',
               'SystemCallError' => 'We had a SystemCallError Error.',
                       'IOError' => 'We had an IOError Error.',
                'Timeout::Error' => 'We had a Timeout Error.'
  }

def handle_error(err)
  log("[error] #{ err_msgs(err.to_s) }" +
      " Sleeping and resetting.\nError: #{ err.message }\n")
  sleep 60
end

def start_and_run_bot
  handable_errors = [
                      Twitter::Unavailable,
                      Crack::ParseError, Timeout::Error,
                      SystemCallError, IOError
                    ]

  handable_errors += [
                       Twitter::NotFound, 
                       Twitter::TwitterError, 
                       Twitter::InformTwitter,
                       Twitter::RateLimitExceeded
                     ] unless USE_GEM_0_4_1
  # fixme: derive +handable_errors+ from +err_msgs+, somehow

  begin
    bot = MicroBlogBot.new
    bot.say_hello
    bot.operate(80) # Twitter recommends 75 seconds delay between updates
  rescue handable_errors => e
    handle_error(e); retry
  end
  bot.shutdown
end # fixme: modified error handling is not yet thoroughly tested
# fixme: move all the error handling procedures to micro_blog_bot itself

start_and_run_bot
