# hrrr_filter_test

- configuration and execution code for detecting and logging the hrrr data cycle
- can be used to perform any cycle wise functions by modifying the execution code
- to manage your own set of resources, change 'config_name' under your locals in main.tf

- model / common config file structure (many tf files)
- example of embedding the lambda function code within the config

## Resource management workflow

- ```terraform init``` loads terraform libraries for your specified resources
- ```terraform plan```
- ```terraform apply <-auto-approve>```
- ```terraform destroy <-auto-approve>``` when ready to destroy infrastructure

- to view your lambda logs

```aws logs tail --follow --region us-east-1 /aws/lambda/${local.config_name}_function```

- to view log stream info # parse_log_stream to see sorted human times

```aws logs describe-log-streams  --region us-east-1 --log-group-name /aws/lambda/DSG_HRRR_filter_test_function```

```aws logs describe-log-groups --region us-east-1 --log-group-name-pattern DSG_combine_GFS_function```
  
## references
- [NODD HRRR information](https://registry.opendata.aws/noaa-hrrr-pds/)
- [terraform aws modules api](https://registry.terraform.io/search/modules?namespace=terraform-aws-modules)
