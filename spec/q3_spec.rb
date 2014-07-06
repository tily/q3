require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

#AWS.config(:logger => Logger.new($stdout))
AWS.config(:log_level => :debug)
#AWS.config(:http_wire_trace => true)

describe "Q3" do
	before do
		sqs.list_queues[:queue_urls].each do |queue_url|
			sqs.delete_queue(:queue_url => queue_url)
		end
	end

	after do
		sqs.list_queues[:queue_urls].each do |queue_url|
			sqs.delete_queue(:queue_url => queue_url)
		end
	end

	context 'Actions' do
		context 'Queue' do
			context "CreateQueue" do
				it 'should create queue' do
					sqs.create_queue(:queue_name => 'myqueue001')
					expect(sqs.list_queues[:queue_urls]).to include('http://localhost/*/myqueue001')
				end
			end
			
			context "ListQueues" do
				it 'should list queues' do
					1.upto(5) do |i|
						sqs.create_queue(:queue_name => "myqueue00#{i}")
					end
					expect(sqs.list_queues[:queue_urls]).to eq %w(
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
					sqs.create_queue(queue_name: 'myqueue001')
					res = sqs.get_queue_url(queue_name: 'myqueue001')
					expect(res[:queue_url]).to eq('http://localhost/*/myqueue001')
				end

				it 'should raise error when non existent queue is specified' do
					expect {
						sqs.get_queue_url(queue_name: 'myqueue002')
					}.to raise_error(AWS::SQS::Errors::NonExistentQueue)
				end
			end
			
			context "GetQueueAttributes" do
				it 'should get queue attributes' do
					now = Time.now.to_i
					sqs.create_queue(queue_name: 'myqueue001')
					res = sqs.get_queue_attributes(queue_url: 'http://localhost/*/myqueue001')
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
					sqs.create_queue(queue_name: 'myqueue001')
					sqs.set_queue_attributes(
						queue_url: 'http://localhost/*/myqueue001',
						attributes: {
							'VisibilityTimeout' => '1',
							'MessageRetentionPeriod' => '2',
							'MaximumMessageSize' => '3',
							'DelaySeconds' => '4',
							'ReceiveMessageWaitTimeSeconds' => '5',
						}
					)
					res = sqs.get_queue_attributes(queue_url: 'http://localhost/*/myqueue001')
					expect(res[:attributes]["VisibilityTimeout"]).to eq("1")
					expect(res[:attributes]["MessageRetentionPeriod"]).to eq("2")
					expect(res[:attributes]["MaximumMessageSize"]).to eq("3")
					expect(res[:attributes]["DelaySeconds"]).to eq("4")
					expect(res[:attributes]["ReceiveMessageWaitTimeSeconds"]).to eq("5")
				end
			end
			
			context "DeleteQueue" do
				it 'should delete queue' do
					sqs.create_queue(queue_name: 'myqueue001')
					sqs.delete_queue(queue_url: 'http://localhost/*/myqueue001')
					expect(sqs.list_queues[:queue_urls]).not_to include('http://localhost/*/myqueue001')
				end
			end
		end

		context 'Message' do
			context "SendMessage" do
				it 'should send message' do
					sqs.create_queue(queue_name: 'myqueue001')
					sqs.send_message(
						queue_url: 'http://localhost/*/myqueue001',
						message_body: 'hello'
					)
					res = sqs.receive_message(queue_url: 'http://localhost/*/myqueue001')
					expect(res[:messages].first[:body]).to eq('hello')
				end
			end
			
			context "ReceiveMessage" do
				it 'should receive message' do
					sqs.create_queue(queue_name: 'myqueue001')
					sqs.send_message(
						queue_url: 'http://localhost/*/myqueue001',
						message_body: 'hello'
					)
					res = sqs.receive_message(queue_url: 'http://localhost/*/myqueue001')
					expect(res[:messages].first[:body]).to eq('hello')
				end
			end
			
			context "ChangeMessageVisibility" do
				it 'should change message visibility' do
				end
			end

			context "DeleteMessage" do
				it 'should delete message' do
					sqs.create_queue(queue_name: 'myqueue001')
					sqs.send_message(
						queue_url: 'http://localhost/*/myqueue001',
						message_body: 'hello'
					)
					res = sqs.receive_message(queue_url: 'http://localhost/*/myqueue001')
					receipt_handle = res[:messages].first[:receipt_handle]
					sqs.delete_message(
						queue_url: 'http://localhost/*/myqueue001',
						receipt_handle: receipt_handle
					)
					res = sqs.receive_message(queue_url: 'http://localhost/*/myqueue001')
					expect(res[:messages]).to be_empty
				end
			end
		end
	end
end
