require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Q3" do
	before do
		q3.queues.each {|queue| queue.delete }
	end

	after do
		q3.queues.each {|queue| queue.delete }
	end

	context 'Actions' do
		context 'Queue' do
			context "CreateQueue" do
				it 'should create queue' do
					client.create_queue(:queue_name => 'myqueue001')
					expect(client.list_queues[:queue_urls]).to include('http://localhost/*/myqueue001')
				end
			end
			
			context "ListQueues" do
				it 'should list queues' do
					1.upto(5) do |i|
						client.create_queue(:queue_name => "myqueue00#{i}")
					end
					expect(client.list_queues[:queue_urls]).to eq %w(
						http://localhost/*/myqueue001
						http://localhost/*/myqueue002
						http://localhost/*/myqueue003
						http://localhost/*/myqueue004
						http://localhost/*/myqueue005
					)
				end
			end
			
			context "GetQueueUrl" do
				it 'should get queue url' do
					client.create_queue(queue_name: 'myqueue001')
					res = client.get_queue_url(queue_name: 'myqueue001')
					expect(res[:queue_url]).to eq('http://localhost/*/myqueue001')
				end

				it 'should raise error when non existent queue is specified' do
					expect {
						client.get_queue_url(queue_name: 'myqueue002')
					}.to raise_error(AWS::SQS::Errors::NonExistentQueue)
				end
			end
			
			context "GetQueueAttributes" do
				it 'should get queue attributes' do
					now = (Time.now.to_f * 1000.0).to_i
					client.create_queue(queue_name: 'myqueue001')
					res = client.get_queue_attributes(queue_url: 'http://localhost/*/myqueue001')
        	                        expect(res[:attributes]["CreateTimestamp"].to_i).to be_within(5000).of(now)
					expect(res[:attributes]["LastModifiedTimestamp"].to_i).to be_within(5000).of(now)
					expect(res[:attributes]["VisibilityTimeout"]).to eq("30")
					expect(res[:attributes]["MessageRetentionPeriod"]).to eq("345600")
					expect(res[:attributes]["MaximumMessageSize"]).to eq("262144")
					expect(res[:attributes]["DelaySeconds"]).to eq("0")
					expect(res[:attributes]["ReceiveMessageWaitTimeSeconds"]).to eq("0")
					expect(res[:attributes]["ApproximateNumberOfMessages"]).to eq("0")
					expect(res[:attributes]["ApproximateNumberOfMessagesNotVisible"]).to eq("0")
					expect(res[:attributes]["ApproximateNumberOfMessagesDelayed"]).to eq("0")
				end

				it 'should get updated LastModifiedTimestamp' do
					past = (Time.now.to_f * 1000.0).to_i
					queue = q3.queues.create('myqueue001')
					sleep 3
					now = (Time.now.to_f * 1000.0).to_i
					queue.visibility_timeout = 1
					expect(queue.last_modified_timestamp.to_i).not_to be_within(2000).of(past)
					expect(queue.last_modified_timestamp.to_i).to be_within(2000).of(now)
				end

				it 'should get precise ApproximateNumberOfMessages*' do
					queue = q3.queues.create('myqueue001')

					queue.send_message('hello', delay_seconds: 5)
					queue.send_message('hello')
					queue.send_message('hello')
					queue.receive_message

					res = client.get_queue_attributes(queue_url: 'http://localhost/*/myqueue001')
					expect(res[:attributes]["ApproximateNumberOfMessages"]).to eq("1")
					expect(res[:attributes]["ApproximateNumberOfMessagesNotVisible"]).to eq("1")
					expect(res[:attributes]["ApproximateNumberOfMessagesDelayed"]).to eq("1")
				end
			end

			context "SetQueueAttributes" do
				it 'should set queue attributes' do
					client.create_queue(queue_name: 'myqueue001')
					client.set_queue_attributes(
						queue_url: 'http://localhost/*/myqueue001',
						attributes: {
							'VisibilityTimeout' => '1',
							'MessageRetentionPeriod' => '2',
							'MaximumMessageSize' => '3',
							'DelaySeconds' => '4',
							'ReceiveMessageWaitTimeSeconds' => '5',
						}
					)
					res = client.get_queue_attributes(queue_url: 'http://localhost/*/myqueue001')
					expect(res[:attributes]["VisibilityTimeout"]).to eq("1")
					expect(res[:attributes]["MessageRetentionPeriod"]).to eq("2")
					expect(res[:attributes]["MaximumMessageSize"]).to eq("3")
					expect(res[:attributes]["DelaySeconds"]).to eq("4")
					expect(res[:attributes]["ReceiveMessageWaitTimeSeconds"]).to eq("5")
				end
			end
			
			context "DeleteQueue" do
				it 'should delete queue' do
					client.create_queue(queue_name: 'myqueue001')
					client.delete_queue(queue_url: 'http://localhost/*/myqueue001')
					expect(client.list_queues[:queue_urls]).not_to include('http://localhost/*/myqueue001')
				end
			end
		end

		context 'Message' do
			context "SendMessage" do
				it 'should send message' do
					client.create_queue(queue_name: 'myqueue001')
					client.send_message(
						queue_url: 'http://localhost/*/myqueue001',
						message_body: 'hello'
					)
					res = client.receive_message(queue_url: 'http://localhost/*/myqueue001')
					expect(res[:messages].first[:body]).to eq('hello')
				end
			end
			
			context "ReceiveMessage" do
				it 'should receive message' do
					client.create_queue(queue_name: 'myqueue001')
					client.send_message(
						queue_url: 'http://localhost/*/myqueue001',
						message_body: 'hello'
					)
					res = client.receive_message(queue_url: 'http://localhost/*/myqueue001')
					expect(res[:messages].first[:body]).to eq('hello')
				end

				it 'should receive message attributes' do
					queue = q3.queues.create('myqueue001')
					sent_at = Time.now.to_i
					queue.send_message('hello')

					sleep 3
					now = Time.now.to_i
					message  = queue.receive_message(visibility_timeout: 1)
					expect(message.sender_id).to eq('*')
					expect(message.sent_timestamp.to_i).to be_within(1).of(sent_at)
					expect(message.approximate_first_receive_timestamp.to_i).to be_within(1).of(now)
					expect(message.approximate_receive_count.to_i).to eq(1)

					sleep 2
					message = queue.receive_message(visibility_timeout: 1)
					expect(message.approximate_receive_count.to_i).to eq(2)
				end

				it 'should receive message attributes' do
					queue = q3.queues.create('myqueue001')
					1.upto(10) do |i|
						queue.send_message("hello #{i}")
					end
					res = q3.client.receive_message(
						queue_url: 'http://localhost/*/myqueue001',
						max_number_of_messages: 5
					)
					expect(res[:messages].size).to eq(5)
				end
			end
			
			context "ChangeMessageVisibility" do
				it 'should change message visibility' do
					client.create_queue(queue_name: 'myqueue001')
					client.send_message(
						queue_url: 'http://localhost/*/myqueue001',
						message_body: 'hello'
					)
					res = client.receive_message(queue_url: 'http://localhost/*/myqueue001')
					receipt_handle = res[:messages].first[:receipt_handle]
					client.change_message_visibility(
						queue_url: 'http://localhost/*/myqueue001',
						receipt_handle: receipt_handle,
						visibility_timeout: 3,
					)
					sleep 5
					res = client.receive_message(queue_url: 'http://localhost/*/myqueue001')
					expect(res[:messages].first[:body]).to eq('hello')
				end
			end

			context "DeleteMessage" do
				it 'should delete message' do
					client.create_queue(queue_name: 'myqueue001')
					client.send_message(
						queue_url: 'http://localhost/*/myqueue001',
						message_body: 'hello'
					)
					res = client.receive_message(queue_url: 'http://localhost/*/myqueue001')
					receipt_handle = res[:messages].first[:receipt_handle]
					client.delete_message(
						queue_url: 'http://localhost/*/myqueue001',
						receipt_handle: receipt_handle
					)
					res = client.receive_message(queue_url: 'http://localhost/*/myqueue001')
					expect(res[:messages]).to be_empty
				end
			end
		end
	end

	context 'Features' do
		context 'Message Extention Period' do
			it 'with CreateQueue MessageExtentionPeriod' do
				queue = q3.queues.create('myqueue001', :message_retention_period => 3)

				queue.send_message('hello')
				message = queue.receive_message
				expect(message.body).to eq('hello')

				queue.send_message('hello')
				sleep 4
				message = queue.receive_message
				expect(message).to be_nil
			end

			it 'with SetQueueAttributes MessageExtentionPeriod' do
				queue = q3.queues.create('myqueue001')
				queue.message_retention_period = 3

				queue.send_message('hello')
				message = queue.receive_message
				expect(message.body).to eq('hello')

				queue.send_message('hello')
				sleep 4
				message = queue.receive_message
				expect(message).to be_nil
			end
		end

		context 'First In First Out' do
			it 'First in first out' do
				queue = q3.queues.create('myqueue001', :visibility_timeout => 3)

				1.upto(10) do |i|
					queue.send_message("hello #{i}")
				end

				1.upto(10) do |i|
					message = queue.receive_message
					expect(message.body).to eq("hello #{i}")
				end
			end
		end

		context 'Long Polling' do
			before do
				@queue = q3.queues.create('myqueue001')
			end

			context 'with CreateQueue ReceiveMessageWaitTimeSeconds' do
				before do
					@queue.wait_time_seconds = 3
				end

				it 'Timeouts in WaitTimeSeconds when no messages are received' do
					result = nil
					@queue.poll(:wait_time_seconds => nil, :idle_timeout => 4) do |message|
						result = message
					end
					expect(result).to be_nil
				end

				it 'Timeouts in WaitTimeSeconds when a message is received' do
					result = nil
					Thread.new do
						sleep 2
						@queue.send_message('hello')
					end
					@queue.poll(:wait_time_seconds => nil, :idle_timeout => 4) do |message|
						result = message
					end
					expect(result).not_to be_nil
				end
			end

			context 'with ReceiveMessage WaitTimeSeconds' do
				it 'Timeouts in WaitTimeSeconds when no messages are received' do
					result = nil
					@queue.poll(:wait_time_seconds => 3, :idle_timeout => 4) do |message|
						result = message
					end
					expect(result).to be_nil
				end

				it 'Timeouts in WaitTimeSeconds when a message is received' do
					result = nil
					Thread.new do
						sleep 2
						@queue.send_message('hello')
					end
					@queue.poll(:wait_time_seconds => 3, :idle_timeout => 4) do |message|
						result = message
					end
					expect(result).not_to be_nil
				end
			end
		end

		context 'Visibility Timeout' do
			it 'with CreateQueue VisibilityTimeout' do
				queue = q3.queues.create('myqueue001', :visibility_timeout => 3)

				queue.send_message('hello')
				message = queue.receive_message
				expect(message.body).to eq('hello')

				message = queue.receive_message
				expect(message).to be_nil

				sleep 4
				message = queue.receive_message
				expect(message.body).to eq('hello')
			end

			it 'with SetQueueAttributes VisibilityTimeout' do
				queue = q3.queues.create('myqueue001')
				queue.visibility_timeout = 3

				queue.send_message('hello')
				message = queue.receive_message
				expect(message.body).to eq('hello')

				message = queue.receive_message
				expect(message).to be_nil

				sleep 4
				message = queue.receive_message
				expect(message.body).to eq('hello')
			end

			it 'with ReceiveMessage VisibilityTimeout' do
				queue = q3.queues.create('myqueue001')

				queue.send_message('hello')
				message = queue.receive_message(visibility_timeout: 3)
				expect(message.body).to eq('hello')

				message = queue.receive_message
				expect(message).to be_nil

				sleep 4
				message = queue.receive_message
				expect(message.body).to eq('hello')
			end
		end

		context 'Delayed Message' do
			it 'with CreateQueue DelaySeconds' do
				queue = q3.queues.create('myqueue001', :delay_seconds => 3)
				queue.send_message('hello')
				message = queue.receive_message
				expect(message).to be_nil
				sleep 4
				message = queue.receive_message
				expect(message.body).to eq('hello')
			end

			it 'with SendMessage DelaySeconds' do
				queue = q3.queues.create('myqueue001')
				queue.send_message('hello', :delay_seconds => 3)
				message = queue.receive_message
				expect(message).to be_nil
				sleep 4
				message = queue.receive_message
				expect(message.body).to eq('hello')
			end
		end
	end
end
