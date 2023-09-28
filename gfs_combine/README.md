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

```aws logs tail --follow --region us-east-1 /aws/lambda/DSG_combine_GFS_function --since 6h```

- List files produced for cycle (replace 'dsg-combine-gfs-bucket' with your bucket name)

```aws s3 ls s3://dsg-combine-gfs-bucket/public/data/grib/ftp/7/0/96/0_1038240_0/``` 

- Copy a grib file from the cloud prepared bucket

```aws s3 cp s3://dsg-combine-gfs-bucket/public/data/grib/ftp/7/0/96/0_1038240_0/2326412000057 .``` 
- Diff the cloud grib file with the corresponding cfd merged file

```diff 2326412000057 /public/data/grib/ftp/7/0/96/0_1038240_0/```
- Diff the *synced* cloud grib file with the corresponding cfd merged file

```diff /public/data/grids/gfs/0p25deg/cloud_merged/96/0_1038240_0/2326418000009 /public/data/grids/gfs/0p25deg/grib2/```
- Verify ScanGrib can scan the cloud file

```/usr/local/rtoper/bin/ScanGrib 2326412000057```
- Verify corresponding variables within the cloud prepared idx (applies to gfs_boto_combine.py only)

```aws s3 cp s3://dsg-combine-gfs-bucket/public/data/grib/ftp/7/0/96/0_1038240_0/2326412000057.idx .``` 

```tail 2326412000057.idx```

## Sample cron for keeping a local copy of the grib files
```0,5,10,15 4,10,16,22 * * * aws --profile data_depot s3 sync --exclude "*.idx" s3://dsg-combine-gfs-bucket/public/data/grib/ftp/7/0/ /public/data/grids/gfs/0p25deg/cloud_merged/```

## references
- [NODD GFS information page](https://registry.opendata.aws/noaa-gfs-bdp-pds/)
- [terraform aws modules api](https://registry.terraform.io/search/modules?namespace=terraform-aws-modules)
- [boto3 s3 api](https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/s3.html)
