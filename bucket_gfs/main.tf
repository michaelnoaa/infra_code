# terraform config / infrastructure for creating and managing an aws bucket
        
locals { # some local variables # main.tf
  region        = "us-east-1"               # this needs to be set like this for GSL or nothing seems to work / look right
  config_name   = "DSG_combine_GFS"         # Our base name for our various resources
  this_config   = path.root                 # the parent folder for this terraform config file # split('/')[-1]
  tagkey        = "noaa:oar:gsl:projectid"  # The projectid tagkey is required by GSL to track costs
  tagvalue      = "its-dsg-learning"        # The projectid tagvalue is required by GSL to track costs
  tagname       = "${local.config_name}_tagname" # Name used in AWS GUI. Convenient, but not required. Default Name is '-'
  dsgtagkey     = "noaa:oar:gsl:dsg"
  dsgtagvalue   = local.config_name
  projectkey    = "noaa:oar:gsl:dsg:project"
  account_id    = data.aws_caller_identity.current.account_id # my aws account_id
  config_name2  = replace(lower(local.config_name), "_", "-")
  bucket_name   = "${local.config_name2}-bucket"
} 
resource "time_static" "my_time" {} # use current time in terraform

provider "aws" { # provider.tf    
  region                 = local.region           
  default_tags { # any resources created with this provider will inherit these tags
    tags = {
      Name               = local.tagname        
      (local.tagkey)     = local.tagvalue
      (local.dsgtagkey)  = local.dsgtagvalue
      (local.projectkey) = local.dsgtagvalue
    }
  } 
}

data "aws_caller_identity" "current" {} # derive my account info into a variable

resource "aws_s3_bucket_lifecycle_configuration" "gfs_bucket_lifecycle" { # purger.tf
  bucket  = local.bucket_name
  rule {
    id = "Purger_lifecycle"
    status  = "Enabled"
    expiration {
      days = 2
    }
  }
}
resource "aws_s3_bucket" "gfs_bucket" { # bucket.tf
  bucket                 = local.bucket_name
  # force_destroy          = null
  tags = {
    Name                 = local.tagname
    AutoTag_CreateTime   = time_static.my_time.rfc3339
    AutoTag_Creator      = data.aws_caller_identity.current.arn
    "noaa:fismaid"       = "NOAA3500"
    "noaa:lineoffice"    = "oar"
    "noaa:programoffice" = "50-37-0000"
  } 
  tags_all = {
    Name                 = local.tagname
    AutoTag_CreateTime   = time_static.my_time.rfc3339
    AutoTag_Creator      = data.aws_caller_identity.current.arn
    "noaa:fismaid"       = "NOAA3500"
    "noaa:lineoffice"    = "oar"
    "noaa:programoffice" = "50-37-0000"
  }
}
