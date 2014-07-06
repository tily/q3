# Q3

## Summary

Simple Amazon SQS compatible API implementation with sinatra and redis.

## Concept

* simplicity
* no authentication, open like wiki
* no validation, just works as proxy to redis functions

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
| Queues                                                  | Sorted Set | Queue Names                    | -                                             |
| Queues:${QueueName}                                     | Hash       | Queue Attributes               | DeleteQueue action                            |
| Queues:${QueueName}:Messages                            | Sorted Set | Message Ids                    | DeleteQueue action                            |
| Queues:${QueueName}:Messages:${MessageId}               | Hash       | Message Attributes             | expires due to MessageRetentionPeriod         |
| Queues:${QueueName}:Messages:${MessageId}:Delayed       | String     | Message Id                     | expires due to DelaySeconds                   |
| Queues:${QueueName}:Messages:${MessageId}:ReceiptHandle | String     | ReceiptHandle                  | expires due to VisibilityTimeout              |
| Queues:${QueueName}:ReceiptHandles:${ReceiptHandle}     | String     | Message Id                     | expires due to VisibilityTimeout              |

## TODO

 * https
 * mount on subdirectory
