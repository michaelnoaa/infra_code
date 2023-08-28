resource "aws_sqs_queue" "my_queue" { # queue.tf
  name                       = "${local.config_name}_queue"
  visibility_timeout_seconds = 30
  tags_all = {
    Name                     = local.tagname
    (local.tagkey)           = local.tagvalue
  }
  policy                     = <<EOF
{
  "Version": "2012-10-17",
  "Id": "__default_policy_ID",
  "Statement": [
    {
      "Action": "SQS:*",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${local.account_id}:root"
      },
      "Resource": "arn:aws:sqs:${local.region}:${local.account_id}:${local.config_name}_queue",
      "Sid": "__owner_statement"
    },
    {
      "Action": "SQS:SendMessage",
      "Condition": {
        "ArnLike": {
          "aws:SourceArn": "${local.sns_topic}"
        }
      },
      "Effect": "Allow",
      "Principal": {
        "AWS": "*"
      },
      "Resource": "arn:aws:sqs:${local.region}:${local.account_id}:${local.config_name}_queue",
      "Sid": "topic-subscription-${local.sns_topic}"
    }
  ]
}
EOF
}
