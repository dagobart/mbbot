require 'rubygems'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "mbbot"
    gemspec.summary = "eases to build services for micro-blogging services such as Twitter and StatusNet"
    gemspec.description = "easy to use framework to build services, chatbots, gateways atop Twitter/StatusNet"
    gemspec.email = "Wolfram.R.Sieber@GMail.com"
    gemspec.homepage = "http://github.com/dagobart/mbbot"
    gemspec.authors = ["Wolfram R. Sieber", "David Sifry (contributor)"]
    gemspec.add_dependency("twitter", ["=0.4.1"])
    ## too bad the gemspec doesn't allow for the special requirements of the
    ## µB bot framework -- two versions of the same gem:
    # gemspec.add_dependency("twitter", ["=0.4.1"])
    # gemspec.add_dependency("twitter", ['=0.6.12'])

    # gemspec is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
rescue LoadError
  puts "Jeweler not available. Install it with: sudo gem install technicalpickles-jeweler -s http://gems.github.com"
end

task :test => :check_dependencies
 
task :default => :test