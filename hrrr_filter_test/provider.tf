provider "aws" { # provider.tf
  region                 = local.region
  default_tags { # any resources created with this provider will inherit these tags
    tags = {
      Name               = local.tagname
      (local.tagkey)     = local.tagval
      (local.dsgtagkey)  = local.dsgtagval
      (local.projectkey) = local.dsgtagval
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
