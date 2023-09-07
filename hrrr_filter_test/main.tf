locals { # some local variables # main.tf
  region        = "us-east-1"              # this needs to be set like this for GSL or nothing seems to work / look right
  config_name   = "DSG_HRRR_filter_test"   # Our base name for our various resources
  this_config   = path.root                # the parent folder for this terraform config file # split('/')[-1]
  tagkey        = "noaa:oar:gsl:projectid" # The projectid tagkey is required by GSL to track costs
  tagvalue      = "its-dsg-learning"       # The projectid tagvalue is required by GSL to track costs
  tagname       = "${local.config_name}_tagname" # Name used in AWS GUI. Convenient, but not required. Default Name is '-'
  dsgtagkey     = "noaa:oar:gsl:dsg"
  dsgtagvalue   = local.config_name
  account_id    = data.aws_caller_identity.current.account_id # my aws account_id
  exec_role     = "arn:aws:iam::${local.account_id}:role/GSL-LambdaS3EC2Execution" # cloud admin provided role
  sns_topic     = "arn:aws:sns:us-east-1:123901341784:NewHRRRObject" # New data notifications for HRRR, only Lambda and SQS protocols allowed
  autotags      = {
    "noaa:fismaid"       = "NOAA3500"
    "noaa:lineoffice"    = "oar"
    "noaa:programoffice" = "50-37-0000"
  }
}
