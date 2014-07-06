require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

AWS.config(:logger => Logger.new($stdout))
AWS.config(:log_level => :debug)
AWS.config(:http_wire_trace => true)

describe "Q3" do
	before do
		client.list_queues[:queue_urls].each do |queue_url|
			client.delete_queue(:queue_url => queue_url)
		end
	end

	after do
		client.list_queues[:queue_urls].each do |queue_url|
			client.delete_queue(:queue_url => queue_url)
		end
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
					now = Time.now.to_i
					client.create_queue(queue_name: 'myqueue001')
					res = client.get_queue_attributes(queue_url: 'http://localhost/*/myqueue001')
        	                        expect(res[:attributes]["CreateTimestamp"].to_i).to be_within(5).of(now)
					expect(res[:attributes]["LastModifiedTimestamp"].to_i).to be_within(5).of(now)
					expect(res[:attributes]["VisibilityTimeout"]).to eq("30")
					expect(res[:attributes]["MessageRetentionPeriod"]).to eq("345600")
					expect(res[:attributes]["MaximumMessageSize"]).to eq("262144")
					expect(res[:attributes]["DelaySeconds"]).to eq("0")
					expect(res[:attributes]["ReceiveMessageWaitTimeSeconds"]).to eq("0")
					expect(res[:attributes]["ApproximateNumberOfMessages"]).to eq("0")
					expect(res[:attributes]["ApproximateNumberOfMessagesNotVisible"]).to eq("0")
					expect(res[:attributes]["ApproximateNumberOfMessagesDelayed"]).to eq("0")
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
end
