resource "aws_sns_topic_subscription" "my_subscribe" { # subscription.tf
  topic_arn            = local.sns_topic
  endpoint             = aws_sqs_queue.my_queue.arn
  protocol             = "sqs"
  raw_message_delivery = true
  filter_policy_scope  = "MessageBody"
  filter_policy        = <<EOF
{
  "Records": {
    "eventName": [ "ObjectCreated:Put" ],
    "s3": {
      "object": {
          "key": [ { "prefix": "hrrr.2023" } ]
      }
    }
  }
}
EOF
}
