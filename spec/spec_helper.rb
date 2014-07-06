$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'rspec'
require 'q3'
require 'aws-sdk'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

RSpec.configure do |config|
  
end

#AWS.config(
#	logger: Logger.new($stdout),
#	log_level: :debug,
#	http_wire_trace: true
#)

def q3
	@q3 ||= AWS::SQS.new(
		:sqs_endpoint => 'localhost',
		:access_key_id => 'dummy',
		:secret_access_key => 'dummy',
		:use_ssl => false
	)
end

def client
  q3.client
end
