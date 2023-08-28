# see https://jazz-twk.medium.com/cloudwatch-agent-on-ec2-with-terraform-8cf58e8736de

# Create SSM Parameter resource, and load its value from file cw_agent_config.json
resource "aws_ssm_parameter" "cw_agent" {
  description = "Cloudwatch agent config to configure custom log"
  name        = "/cloudwatch-agent/config"
  type        = "String"
  value       = file("cw_agent_config.json")
}

# lambda context accesses..
#    print("Lambda function ARN:", context.invoked_function_arn)
#    print("CloudWatch log stream name:", context.log_stream_name)
#    print("CloudWatch log group name:",  context.log_group_name)
#    print("Lambda Request ID:", context.aws_request_id)
