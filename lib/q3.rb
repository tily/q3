%w(digest/md5 sinatra/base builder redis redis-namespace redis/pool).each {|x| require x }

$redis = Redis::Namespace.new(:Q3, redis: Redis::Pool.new(url: ENV['REDISTOGO_URL'] || 'redis://localhost:6379/15'))

class Q3 < Sinatra::Base
	configure do
		enable :logging
	end

	DEFAULTS = {
		'VisibilityTimeout'             => 30,
		'MaximumMessageSize'            => 262144,
		'MessageRetentionPeriod'        => 345600,
		'DelaySeconds'                  => 0,
		'ReceiveMessageWaitTimeSeconds' => 0,
	}
	CREATE_QUEUE = %w(
		VisibilityTimeout MessageRetentionPeriod MaximumMessageSize DelaySeconds ReceiveMessageWaitTimeSeconds
	)
	SET_QUEUE_ATTRIBUTES = %w(
		DelaySeconds MaximumMessageSize MessageRetentionPeriod Policy ReceiveMessageWaitTimeSeconds
		VisibilityTimeout RedrivePolicy
	)

	def self.dispatch!
		@paths.each do |path, opts|
			[:get, :post].each do |x|
				send(x, path) do
					if opt = opts.find {|opt| opt[:action] == params['Action'] }
						instance_eval(&opt[:block])
					end
				end
			end
		end
	end
	
	def self.action(action, path='/', &block)
		@paths ||= Hash.new {|h, k| h[k] = [] }
		@paths[path] << {action: action, block: block}
	end

	before do
		logger.info "#{request_id}: request start with path = #{request.path_info}, params = #{params}"
		content_type 'application/xml'
	end

	after do
		logger.info "#{request_id}: request end with #{response.body}"
	end

	action('CreateQueue') do
		halt 400, return_error_xml('Sender', 'MissingParameter', '') if params['QueueName'].nil?
		timestamp = now
		hash = CREATE_QUEUE.inject({'CreateTimestamp' => timestamp, 'LastModifiedTimestamp' => timestamp}) do |hash, attribute|
			hash[attribute] = attributes[attribute] || DEFAULTS[attribute]
			hash
		end
		redis.sadd("Queues", params[:QueueName])
		redis.hmset("Queues:#{params[:QueueName]}", *hash.to_a)
		return_xml {|xml| xml.QueueUrl queue_url("#{params[:QueueName]}") }
	end
	
	action('ListQueues') do
		return_xml do |xml|
			redis.smembers('Queues').each {|queue_name| xml.QueueUrl queue_url(queue_name) }
		end
	end
	
	action('GetQueueUrl') do
		validate_queue_existence
		return_xml {|xml| xml.QueueUrl queue_url(params[:QueueName]) }
	end
	
	action('GetQueueAttributes', '/*/:QueueName') do
		validate_queue_existence
		delayed = redis.keys("Queues:#{params[:QueueName]}:Messages:*:Delayed").size
		not_visible = redis.keys("Queues:#{params[:QueueName]}:Messages:*:ReceiptHandle").size
		messages = redis.llen("Queues:#{params[:QueueName]}:Messages") - delayed - not_visible
		return_xml do |xml|
			queue.each do |name, value|
				xml.Attribute { xml.Name name; xml.Value value }
			end
			xml.Attribute { xml.Name 'ApproximateNumberOfMessages'           ; xml.Value messages    }
			xml.Attribute { xml.Name 'ApproximateNumberOfMessagesNotVisible' ; xml.Value not_visible }
			xml.Attribute { xml.Name 'ApproximateNumberOfMessagesDelayed'    ; xml.Value delayed     }
		end
	end
	
	action('SetQueueAttributes', '/*/:QueueName') do
		validate_queue_existence
		hash = SET_QUEUE_ATTRIBUTES.inject({'LastModifiedTimestamp' => now}) do |hash, attribute|
			hash[attribute] = attributes[attribute] if attributes[attribute]
			hash
		end
		redis.hmset("Queues:#{params[:QueueName]}", hash.to_a.flatten)
		return_xml {}
	end
	
	action('DeleteQueue', '/*/:QueueName') do
		validate_queue_existence
		redis.keys("Queues:#{params[:QueueName]}*").each {|key| redis.del(key) }
		redis.srem("Queues", params[:QueueName])
		return_xml {}
	end
	
	action('SendMessage', '/*/:QueueName') do
		validate_queue_existence
		delay_seconds = params['DelaySeconds'] || queue['DelaySeconds']
		message_id = SecureRandom.uuid
		redis.rpush("Queues:#{params[:QueueName]}:Messages", message_id)
		redis.hmset("Queues:#{params[:QueueName]}:Messages:#{message_id}",
			'MessageId', message_id,
			'MessageBody', params[:MessageBody],
			'SenderId', '*',
			'SentTimestamp', now,
			'ApproximateReceiveCount', 0
		)
		redis.expire("Queues:#{params[:QueueName]}:Messages:#{message_id}", queue['MessageRetentionPeriod'])
		if delay_seconds.to_i > 0
			redis.set("Queues:#{params[:QueueName]}:Messages:#{message_id}:Delayed", message_id)
			redis.expire("Queues:#{params[:QueueName]}:Messages:#{message_id}:Delayed", delay_seconds)
		end
		return_xml do |xml|
			xml.MD5OfMessageBody Digest::MD5.hexdigest(params[:MessageBody])
			xml.MessageId message_id
		end
	end
	
	action('ReceiveMessage', '/*/:QueueName') do
		validate_queue_existence
		wait_time_seconds = params['WaitTimeSeconds'] || queue['ReceiveMessageWaitTimeSeconds']
		max_number_of_messages = params['MaxNumberOfMessages'] ? params['MaxNumberOfMessages'].to_i : 1
		visibility_timeout = params['VisibilityTimeout'] || queue['VisibilityTimeout']
		visible_messages = []
		message_ids = redis.lrange("Queues:#{params[:QueueName]}:Messages", 0, -1)
		message_ids.each do |message_id|
			next if redis.exists("Queues:#{params[:QueueName]}:Messages:#{message_id}:ReceiptHandle")
			next if redis.exists("Queues:#{params[:QueueName]}:Messages:#{message_id}:Delayed")
			message = redis.hgetall("Queues:#{params[:QueueName]}:Messages:#{message_id}")
			message['ApproximateFirstReceiveTimestamp'] ||= now
			message['ApproximateReceiveCount'] = (message['ApproximateReceiveCount'].to_i + 1).to_s
			redis.hmset("Queues:#{params[:QueueName]}:Messages:#{message_id}", message.to_a.flatten)
			receipt_handle = SecureRandom.uuid
			redis.set("Queues:#{params[:QueueName]}:Messages:#{message_id}:ReceiptHandle", receipt_handle)
			redis.expire("Queues:#{params[:QueueName]}:Messages:#{message_id}:ReceiptHandle", visibility_timeout)
			redis.set("Queues:#{params[:QueueName]}:ReceiptHandles:#{receipt_handle}", message_id)
			redis.expire("Queues:#{params[:QueueName]}:ReceiptHandles:#{receipt_handle}", visibility_timeout)
			visible_messages << {:MessageId => message_id, :MessageBody => message['MessageBody'], :ReceiptHandle => receipt_handle, :Attributes => message}
			break if visible_messages.size >= max_number_of_messages
		end
		return_xml do |xml|
			visible_messages.each do |message|
				xml.Message do
					xml.MessageId     message[:MessageId]
					xml.ReceiptHandle message[:ReceiptHandle]
					xml.MD5OfBody     Digest::MD5.hexdigest(message[:MessageBody])
					xml.Body          message[:MessageBody]
					%w(SenderId SentTimestamp ApproximateFirstReceiveTimestamp ApproximateReceiveCount).each do |name|
						xml.Attribute { xml.Name name; xml.Value message[:Attributes][name] }
					end
				end
			end
		end
	end
	
	action('ChangeMessageVisibility', '/*/:QueueName') do
		validate_queue_existence
		message_id = redis.get("Queues:#{params[:QueueName]}:ReceiptHandles:#{params[:ReceiptHandle]}")
		redis.expire("Queues:#{params[:QueueName]}:Messages:#{message_id}:ReceiptHandle", params['VisibilityTimeout'])
		redis.expire("Queues:#{params[:QueueName]}:ReceiptHandles:#{params[:ReceiptHandle]}", params['VisibilityTimeout'])
		return_xml {}
	end

	action('DeleteMessage', '/*/:QueueName') do
		validate_queue_existence
		message_id = redis.get("Queues:#{params[:QueueName]}:ReceiptHandles:#{params[:ReceiptHandle]}")
		redis.lrem("Queues:#{params[:QueueName]}:Messages", 0, message_id)
		redis.del("Queues:#{params[:QueueName]}:ReceiptHandles:#{params[:ReceiptHandle]}")
		return_xml {}
	end

	action('SendMessageBatch', '/*/:QueueName') do
		validate_queue_existence
		# not implemented yet
	end

	action('ChangeMessageVisibilityBatch', '/*/:QueueName') do
		validate_queue_existence
		# not implemented yet
	end
	
	action('DeleteMessageBatch', '/*/:QueueName') do
		validate_queue_existence
		# not implemented yet
	end
	
	helpers do
		def redis
			$redis
		end
	
		def request_id
			@request_id ||= SecureRandom.uuid
		end

		def queue
			@queue ||= redis.hgetall("Queues:#{params[:QueueName]}")
		end
	
		def queue_url(queue_name)
			"http://#{request.host}/*/#{queue_name}"
		end

		def attributes
			@attributes ||= (1..10).to_a.inject({}) do |attributes, i|
				if (name = params["Attribute.#{i.to_s}.Name"]) && (value = params["Attribute.#{i.to_s}.Value"])
					attributes[name] = value
				end
				attributes
			end
		end
	
		def return_xml(&block)
			builder do |xml|
				xml.instruct!
				xml.tag!("#{params['Action']}Response") do
					xml.tag!("#{params['Action']}Result") do
						block.call(xml)
					end
					xml.ResponseMetadata { xml.RequestId request_id }
				end
			end
		end
	
		def return_error_xml(type, code, message)
			builder do |xml|
				xml.instruct!
				xml.ErrorResponse do
					xml.Error do
						xml.Type type
						xml.Code code
						xml.Message message
					end
					xml.ResponseMetadata { xml.RequestId request_id }
				end
			end
		end

		def validate_queue_existence
			halt 400, return_error_xml('Sender', 'NonExistentQueue', 'The specified queue does not exist for this wsdl version.') if queue.empty?
		end

		def now
			(Time.now.to_f * 1000.0).to_i
		end
	end

	dispatch!
end
