main_dir = File.join(File.dirname(__FILE__), '')
require (main_dir + 'micro_blog_bot')

class MicroBlogBotRunner
  def initialize(bot_to_run = MicroBlogBot.new,
                 waittime = nil)
    @bot = bot_to_run
    initialize_waittime(waittime)

    initialize_error_messages
    @handable_errors = @err_msgs.keys

    return self
  end

  # start and run bot:
  def run(dynamically_adapt_polling_frequency = true)
    first_run = true

    begin
      if first_run then
        @bot.say_hello
        first_run = false
      end

        # main bot run loop:
        @bot.operate(@waittime, dynamically_adapt_polling_frequency)

    rescue @handable_errors => e
      handle_error(e); retry
    end
    # fixme: modified error handling is not yet thoroughly tested

    @bot.shutdown
  end

private

  def initialize_waittime(waittime = nil)
    unless waittime then
      unless USE_IDENTICA then
        waittime = 80  # Twitter recommends 75 seconds delay between updates
      else
        waittime = 45  # Identica is often happy with 20s, but sometimes it
                       # penalizes you with a 95s delay
        # fixme: remove hard-coded values
      end
    end

    @waittime = waittime
  end

  def initialize_error_messages
    default_err_msg = 'We had a Twitter Error.' 

    @err_msgs =
      {
        Twitter::Unavailable => default_err_msg,
           Crack::ParseError => 'We had a Parsing Error in the JSON Stream.',
             SystemCallError => 'We had a SystemCallError Error.',
              Timeout::Error => 'We had a Timeout Error.',
                     IOError => 'We had an IOError Error.'
      }

    if USE_GEM_0_4_1 then
      @err_msgs.merge!({ Twitter::CantConnect => default_err_msg })
      #
      # note:
      # Twitter::CantConnect (often) happens if a shutdown takes..took
      # place before all the received messages got processed -- in
      # other words: if there get messages issued to be sent although
      # the connection was already closed, e.g. by a shutdown.
      #
      # That's usually a programming mistake, not something that should
      # be handled automatically. #fixme
    else # we assume current gem is v0.6.12
      @err_msgs.merge!({    Twitter::NotFound => default_err_msg,
                   Twitter::RateLimitExceeded => default_err_msg,
                       Twitter::InformTwitter => default_err_msg,
                        Twitter::TwitterError => default_err_msg,
                       })
                      # fixme: make these errmsgs more 'speaking' again
    end
  end
  # fixme: remove hard-coded 'Twitter' (^+service_in_use+):

  def handle_error(err)
    log("[error] #{ @err_msgs[err] }" +
        " Sleeping and resetting.\nError: #{ err.message }\n")
    if (!USE_GEM_0_4_1 && (err == Twitter::CantConnect))       ||
       ( USE_GEM_0_4_1 && (err == Twitter::RateLimitExceeded)) then
      log('       Performing a heavy 900s delay to deal with exceeded limit')
      sleep 900 # do a heavy delay when Twitter::RateLimitExceeded
    else
      sleep 60
    end
end
end
# fixme: could this class be integrated with MicroBlogBot? Would it make sense?
