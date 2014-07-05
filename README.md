# Q3

## Summary

Simple Amazon SQS compatible API implementation with sinatra and redis.

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
   * SendMessageBatch
   * ReceiveMessage
   * ChangeMessageVisibility
   * ChangeMessageVisibilityBatch
   * DeleteMessage
   * DeleteMessageBatch

### will be implemented

 * ListDeadLetterSourceQueues

### will not be implemented

 * AddPermission
 * RemovePermission

## Data Schema

| Key Name                                            | Type       | Content                   | Delete Timing                                 |
| --------------------------------------------------- | ---------- | ------------------------- | --------------------------------------------- |
| Queues                                              | Sorted Set | Queue Names               | note deleted                                  |
| Queues:${QueueName}                                 | Hash       | Queue Attributes          | DeleteQueue action                            |
| Queues:${QueueName}:Messages                        | Sorted Set | MessageIds                | programatically deleted when Hash was expired |
| Queues:${QueueName}:Messages:${MessageId}           | Hash       | Message Attributes        | automatically expires                         |
| Queues:${QueueName}:Messages:${MessageId}:Delayed   | String     | ${MessageId} is delayed   | automatically expires                         |
| Queues:${QueueName}:Messages:${MessageId}:Invisible | String     | ${MessageId} is invisible | automatically expires                         |

## TODO

 * https
 * mount on subdirectory

