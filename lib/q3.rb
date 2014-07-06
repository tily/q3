%w(digest/md5 json sinatra/base builder redis redis-namespace).each {|x| require x }

class Q3 < Sinatra::Base
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
	UNDELETABLE_QUEUES = %w(FrontPage)

	def self.dispatch!
		@paths.each do |path, opts|
			[:get, :post].each do |x|
				send(x, path) do
					logger.info "RequestId: {request_id}"
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
		content_type 'application/xml'
	end

	action('CreateQueue') do
		timestamp = Time.now.to_i
		hash = CREATE_QUEUE.inject({'CreateTimestamp' => timestamp, 'LastModifiedTimestamp' => timestamp}) do |hash, attribute|
			hash[attribute] = params[attribute] || DEFAULTS[attribute]
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
		return_xml {|xml| xml.QueueUrl queue_url(params[:QueueName]) }
	end
	
	action('GetQueueAttributes', '/*/:QueueName') do
		delayed = redis.keys("Queues:#{params[:QueueName]}:Messages:*:Delayed").size
		not_visible = redis.keys("Queues:#{params[:QueueName]}:Messages:*:NotVisible").size
		messages = redis.zcount("Queues:#{params[:QueueName]}:Messages", '-inf', '+inf') - delayed - not_visible
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
		attributes = (1..10).to_a.inject({}) do |attributes, i|
			if (name = params["Attribute.#{i.to_s}.Name"]) && (value = params["Attribute.#{i.to_s}.Value"])
				attributes[name] = value
			end
			attributes
		end
		hash = SET_QUEUE_ATTRIBUTES.inject({'LastModifiedTimestamp' => Time.now.to_i}) do |hash, attribute|
			hash[attribute] = attributes[attribute] if attributes[attribute]
			hash
		end
		redis.hmset("Queues:#{params[:QueueName]}", hash.to_a.flatten)
		return_xml {}
	end
	
	action('DeleteQueue', '/*/:QueueName') do
		if !UNDELETABLE_QUEUES.include?(params[:QueueName])
			redis.keys("Queues:#{params[:QueueName]}*").each {|key| redis.del(key) }
			redis.srem("Queues", params[:QueueName])
		end
		return_xml {}
	end
	
	action('SendMessage', '/*/:QueueName') do
		delay_seconds = params['DelaySeconds'] || queue['DelaySeconds']
		# set message life according to message retention period
		message_id = SecureRandom.uuid
		redis.zadd("Queues:#{params[:QueueName]}:Messages", 1, message_id)
		redis.hmset("Queues:#{params[:QueueName]}:Messages:#{message_id}",
			'MessageId', message_id,
			'MessageBody', params[:MessageBody]
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
		visibility_timeout = params['VisibilityTimeout'] || queue['VisibilityTimeout']
		visible_messages = []
		message_ids = redis.zrange("Queues:#{params[:QueueName]}:Messages", 0, -1)
		message_ids.each do |message_id|
			next if redis.exists("Queues:#{params[:QueueName]}:Messages:#{message_id}:NotVisible")
			next if redis.exists("Queues:#{params[:QueueName]}:Messages:#{message_id}:Delayed")
			message_body = redis.hget("Queues:#{params[:QueueName]}:Messages:#{message_id}", 'MessageBody')
			recept_handle = SecureRandom.uuid
			redis.set("Queues:#{params[:QueueName]}:Messages:#{message_id}:NotVisible", recept_handle)
			redis.expire("Queues:#{params[:QueueName]}:Messages:#{message_id}:NotVisible", visibility_timeout)
			redis.hset("Queues:#{params[:QueueName]}:ReceiptHandles", recept_handle, message[:MessageId])
			visible_messages << {:MessageId => message_id, :MessageBody => message_body, :ReceptHandle => recept_handle}
			break if visible_messages.size >= 1
		end
		return_xml do |xml|
			visible_messages.each do |message|
				xml.Message do
					xml.MessageId     message[:MessageId]
					xml.ReceiptHandle message[:ReceptHandle]
					xml.MD5OfBody     Digest::MD5.hexdigest(message[:MessageBody])
					xml.Body          message[:MessageBody]
				end
			end
		end
	end
	
	action('ChangeMessageVisibility', '/*/:QueueName') do
		message_id = redis.hget("Queues:#{params[:QueueName]}:ReceptHandles", params[:ReceptHandle])
		redis.expire("Queues:#{params[:QueueName]}:Messages:#{message_id}:NotVisible", params['VisibilityTimeout'])
		return_xml {}
	end

	action('DeleteMessage', '/*/:QueueName') do
		message_id = redis.hget("Queues:#{params[:QueueName]}:ReceptHandles", params[:ReceptHandle])
		redis.zrem("Queues:#{params[:QueueName]}:Messages", message_id)
		redis.hdel("Queues:#{params[:QueueName]}:ReceptHandles", params[:ReceptHandle])
		return_xml {}
	end

	action('SendMessageBatch', '/*/:QueueName') do
		# not implemented yet
	end

	action('ChangeMessageVisibilityBatch', '/*/:QueueName') do
		# not implemented yet
	end
	
	action('DeleteMessageBatch', '/*/:QueueName') do
		# not implemented yet
	end
	
	helpers do
		def redis
			@redis ||= Redis::Namespace.new(:Q3, redis: Redis.connect)
		end
	
		def request_id
			@request_id ||= SecureRandom.uuid
		end

		def queue
			@queue ||= redis.hgetall("Queues:#{params[:QueueName]}")
		end
	
		def queue_url(queue_name)
			"http://#{env['HTTP_HOST']}/*/#{queue_name}"
		end
	
		def return_xml(&block)
			builder do |xml|
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
	end

	dispatch!
end
