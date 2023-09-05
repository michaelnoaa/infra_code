# gfs_combine

- configuration and execution code for detecting and logging 0.25 deg GFS data cycle
- processing to merge the pgrb2 and prgb2b files - as per 'DSG rtoper' ways
- to scale beyond the 64hr forecast, try a new lambda trigger every 64 hours
- to scale the transfers, depending on buffering in play, trigger once per file/object
- to manage your own set of resources, change 'config_name' under your locals in main.tf


- example of referring to lambda code within a file / script, from config
- counter example infrastructure config file structure (all in main.tf)

## Sample verification workflow
- view your lambda logs

```aws logs tail --follow --region us-east-1 /aws/lambda/${local.config_name}_function```

- List files produced for cycle (replace 'dsg-combine-gfs-bucket' with your bucket name)

```aws s3 ls s3://dsg-combine-gfs-bucket/gfs.20230826/12/atmos/``` 

- Copy a grib file from the cloud prepared bucket

```aws s3 cp s3://dsg-combine-gfs-bucket/gfs.20230826/12/atmos/gfs.t12z.pgrb2.0p25.f051 .``` 
- Diff the cloud grib file with the corresponding cfd file

```diff /public/data/grib/ftp/7/0/96/0_1038240_0/2323812000051 gfs.t12z.pgrb2.0p25.f051```
- Verify ScanGrib can scan the cloud file

```/usr/local/rtoper/bin/ScanGrib gfs.t12z.pgrb2.0p25.f051```
- Verify corresponding variables within the cloud prepared idx (applies to gfs_boto_combine.py only)

```aws s3 cp s3://dsg-combine-gfs-bucket/gfs.20230826/12/atmos/gfs.t12z.pgrb2.0p25.f051.idx .``` 

```tail gfs.t12z.pgrb2.0p25.f051.idx```

## references
- [NODD GFS information page](https://registry.opendata.aws/noaa-gfs-bdp-pds/)
- [terraform aws modules api](https://registry.terraform.io/search/modules?namespace=terraform-aws-modules)
- [boto3 s3 api](https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/s3.html)
