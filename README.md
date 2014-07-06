# Q3

## Summary

Simple Amazon SQS compatible API implementation with sinatra and redis.

## Concept

* simplicity
* no authentication, open like wiki
* no validation, just works as proxy to redis functions

## Usage

### global service

You can try q3 easily with global endpoint <http://q3-global.herokuapp.com/>.

	$ curl "http://q3-global.herokuapp.com/?Action=CreateQueue&QueueName=MyQueue001"
	<?xml version="1.0" encoding="UTF-8"?>
	<CreateQueueResponse>
	  <CreateQueueResult>
	    <QueueUrl>http://q3-global.herokuapp.com/*/MyQueue001</QueueUrl>
	  </CreateQueueResult>
	  <ResponseMetadata>
	    <RequestId>9bcf7831-59a3-456c-b5fe-e0674f322b79</RequestId>
	  </ResponseMetadata>
	</CreateQueueResponse>

You can use any Amazon SQS client.

	require 'aws-sdk'
	q3 = AWS::SQS.new(
		:sqs_endpoint => 'q3-global.herokuapp.com',
		:access_key_id => 'dummy',
		:secret_access_key => 'dummy',
		:use_ssl => false
	)
	
	queue = q3.queues.create('MyQueue001')
	queue.send_message('hello!')
	p queue.receive_message.body # => "hello!"

### as rack app

Install gem and you can invoke `q3` command to run api.

	$ gem install q3
	$ q3
	[2014-07-06 19:54:47] INFO  WEBrick 1.3.1
	[2014-07-06 19:54:47] INFO  ruby 2.0.0 (2014-02-24) [universal.x86_64-darwin13]
	== Sinatra/1.4.5 has taken the stage on 4567 for development with backup from WEBrick
	[2014-07-06 19:54:47] INFO  WEBrick::HTTPServer#start: pid=29495 port=4567

Or you can integrate q3 into your config.ru like this:

	require 'q3.rb'
	run Q3

## Actions

See for complete action list: [Welcome - Amazon Simple Queue Service](http://docs.aws.amazon.com/AWSSimpleQueueService/latest/APIReference/Welcome.html).

### implemented

 * Queue Operation
   * CreateQueue
   * ListQueues
   * GetQueueAttributes
   * GetQueueUrl
   * SetQueueAttributes
   * DeleteQueue
 * Message Operation
   * SendMessage
   * ReceiveMessage
   * ChangeMessageVisibility
   * DeleteMessage

### will be implemented

 * SendMessageBatch
 * ChangeMessageVisibilityBatch
 * DeleteMessageBatch
 * ListDeadLetterSourceQueues

### will not be implemented

 * AddPermission
 * RemovePermission

## Data Schema

| Key Name                                                | Type       | Content                        | Delete Timing                                 |
| ------------------------------------------------------- | ---------- | ------------------------------ | --------------------------------------------- |
| Queues                                                  | Set        | Queue Names                    | -                                             |
| Queues:${QueueName}                                     | Hash       | Queue Attributes               | DeleteQueue action                            |
| Queues:${QueueName}:Messages                            | List       | Message Ids                    | DeleteQueue action                            |
| Queues:${QueueName}:Messages:${MessageId}               | Hash       | Message Attributes             | expires due to MessageRetentionPeriod         |
| Queues:${QueueName}:Messages:${MessageId}:Delayed       | String     | Message Id                     | expires due to DelaySeconds                   |
| Queues:${QueueName}:Messages:${MessageId}:ReceiptHandle | String     | ReceiptHandle                  | expires due to VisibilityTimeout              |
| Queues:${QueueName}:ReceiptHandles:${ReceiptHandle}     | String     | Message Id                     | expires due to VisibilityTimeout              |

## TODO

 * https
 * mount on subdirectory
