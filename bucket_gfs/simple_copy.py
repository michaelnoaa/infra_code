#!/usr/bin/python3

# simple copy file to s3 bucket

import boto3

dest_bucket = "dsg-combine-gfs-bucket"
s3 = boto3.client('s3')
source_file = "README_s3.txt"
s3.put_object(Bucket=dest_bucket, Key=source_file, Body=open(source_file, 'rb'))
