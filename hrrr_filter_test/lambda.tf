resource "aws_lambda_function" "my_lambda" { # lambda.tf
  function_name                  = "arn:aws:lambda:${local.region}:${local.account_id}:function:${local.config_name}_function"
  filename                       = "${data.archive_file.my_lambda_zip_inline.output_path}"
  source_code_hash               = "${data.archive_file.my_lambda_zip_inline.output_base64sha256}"
  handler                        = "hrrr_sample_lambda.handler"
  role                           = local.exec_role
  runtime                        = "python3.11"
  reserved_concurrent_executions = 2 # prevent unwanted simultaneous executions
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

data "archive_file" "my_lambda_zip_inline" { # our lambda script zipped, with inline content
  type        = "zip"
  output_path = ".terraform/lambda_tmp/hrrr_sample_lambda.zip"
  source {
    filename  = "hrrr_sample_lambda.py"
    content   = <<EOF
import json

end_pattern = "z.wrfsfcf18.grib2.idx" # the 18th hour forecast of the surface hrrr
def handler(raw_event: dict, context: 'awslambdaric.lambda_context.LambdaContext'):
    """"our default handler method for our lambda. Filter out using our end_pattern"""
    # print("Lambda function memory limits in MB:", context.memory_limit_in_mb)
    print(f"Received raw event: {raw_event}")
    body = json.loads(raw_event["Records"][0]["body"])
    # print(f"body: {body}") 
    message = ''
    if "Message" in body.keys():
      message = json.loads(body["Message"])
    elif "Records" in body.keys():
      message = body
    print(f"Received raw message: {message}")
    message_key = message["Records"][0]["s3"]["object"]["key"]
    print(f"DSG Filtered object key: {message_key}")
    if not message_key.endswith(end_pattern):
      print(f"Not the droids we're looking for, moving on..")
      return # not an object matching our end_pattern
    # print(f', continuing to download and process data files..')
    filename = message_key.split('/')[-1]
    ymd = message_key[5:13]
    hour = filename[6:8] # runtime hour
    fcst = 18 # for fcst in range(0,19):
    print(f'download path is: hrrr.{ymd}/conus/hrrr.t{hour}z.wrfsfcf{fcst:02d}.grib2')
    ## path: hrrr.20230816/conus/hrrr.t06z.wrfsfcf17.grib2.idx
    print(f'Lambda time remaining: {context.get_remaining_time_in_millis()/1000:.1f} seconds')
EOF
  }
}
