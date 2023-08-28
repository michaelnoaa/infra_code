resource "aws_lambda_event_source_mapping" "my_event_source_mapping" { # event_map.tf
  event_source_arn                = aws_sqs_queue.my_queue.arn
  function_name                   = aws_lambda_function.my_lambda.function_name
  enabled                         = true
  # maximum_record_age_in_seconds = 300
  # parallelization_factor        = 1
  filter_criteria {
    filter {
      pattern = jsonencode( {
        body = {
          Records = {
            eventName = ["ObjectCreated:Put"],
            s3 = {
              object = {
                # key = [{ suffix = "idx"}] # {"key": [{ "suffix": "grib2.idx"}]}
                key = [{ suffix = "z.wrfsfcf18.grib2.idx"}]
              }
            }
          }
        }
      } )
    }
  }
}
