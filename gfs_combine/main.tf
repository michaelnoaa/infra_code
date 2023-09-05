# terraform config / infrastructure for live processing of the first 64 hours of forecasts for the 0.25 degree GFS

locals { # some local variables # main.tf
  region        = "us-east-1"              # this needs to be set like this for GSL or nothing seems to work / look right
  config_name   = "DSG_combine_GFS"        # Our base name for our various resources
  this_config   = path.root                # the parent folder for this terraform config file # split('/')[-1]
  tagkey        = "noaa:oar:gsl:projectid" # The projectid tagkey is required by GSL to track costs
  tagvalue      = "its-dsg-learning"       # The projectid tagvalue is required by GSL to track costs
  tagname       = "${local.config_name}_tagname" # Name used in AWS GUI. Convenient, but not required. Default Name is '-'
  account_id    = data.aws_caller_identity.current.account_id # my aws account_id
  exec_role     = "arn:aws:iam::${local.account_id}:role/GSL-LambdaS3EC2Execution" # cloud admin provided role
  sns_topic     = "arn:aws:sns:us-east-1:123901341784:NewGFSObject" # New data notifications for GFS, only Lambda and SQS protocols allowed
}

provider "aws" { # provider.tf
  region             = local.region
  default_tags { # any resources created with this provider will inherit these tags
    tags = {
      Name           = local.tagname
      (local.tagkey) = local.tagvalue
    }
  }
}

data "aws_caller_identity" "current" {} # derive my account info into a variable
resource "time_static" "my_time" {} # use current time in terraform
## output variables are output to the screen for convenience when uncommented
# output "current_time" { value = time_static.my_time.rfc3339 }
# output "account_id"   { value = data.aws_caller_identity.current.account_id }
# output "caller_arn"   { value = data.aws_caller_identity.current.arn }
# output "caller_user"  { value = data.aws_caller_identity.current.user_id }

resource "aws_sqs_queue" "my_queue" { # queue.tf
  name                       = "${local.config_name}_queue"
  visibility_timeout_seconds = 900 # should be greater than configured lambda timeout (900 secs)
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
          "key": [ { "prefix": "gfs.2023" } ]
      }
    }
  }
}
EOF
}

data "archive_file" "my_lambda_zip_file" { # our lambda script zipped, with content from a file
  type        = "zip"
  output_path = ".terraform/lambda_tmp/gfs_cat_lambda.zip"
  source {
    filename  = "gfs_boto_cat.py"
    content   = file("gfs_boto_cat.py")
  }
}

resource "aws_lambda_function" "my_lambda" { # lambda.tf
  function_name                  = "arn:aws:lambda:${local.region}:${local.account_id}:function:${local.config_name}_function"
  filename                       = data.archive_file.my_lambda_zip_file.output_path
  source_code_hash               = data.archive_file.my_lambda_zip_file.output_base64sha256
  handler                        = "gfs_boto_cat.handler"
  role                           = local.exec_role
  runtime                        = "python3.11"
  timeout                        = 900 # aws lambdas allow for up to 15 minutes (or 900 seconds)
  reserved_concurrent_executions = 2   # prevent unwanted simultaneous executions
  tags = {
    AutoTag_CreateTime   = time_static.my_time.rfc3339
    AutoTag_Creator      = data.aws_caller_identity.current.arn
    "noaa:fismaid"       = "NOAA3500"
    "noaa:lineoffice"    = "oar"
    "noaa:programoffice" = "50-37-0000"
  }
  tags_all = {
    AutoTag_CreateTime   = time_static.my_time.rfc3339
    AutoTag_Creator      = data.aws_caller_identity.current.arn
    "noaa:fismaid"       = "NOAA3500"
    "noaa:lineoffice"    = "oar"
    "noaa:programoffice" = "50-37-0000"
  }
}

resource "aws_lambda_event_source_mapping" "my_event_source_mapping" { # event_map.tf
  event_source_arn                = aws_sqs_queue.my_queue.arn
  function_name                   = aws_lambda_function.my_lambda.function_name
  enabled                         = true
  # maximum_record_age_in_seconds = 300
  # parallelization_factor        = 1
  # console paste: {body={Records:{eventName:["ObjectCreated:Put"],s3:{object:{key:[{suffix:"pgrb2.0p25.f064"}]}}}}}
  filter_criteria {
    filter {
      pattern = jsonencode( {
        body = {
          Records = {
            eventName = ["ObjectCreated:Put"],
            s3 = {
              object = {
                # key = [{ suffix = "idx"}]
                key = [{ suffix = "pgrb2.0p25.f064"}]
              }
            }
          }
        }
      } )
    }
  }
}
