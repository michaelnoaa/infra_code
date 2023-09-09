#!/usr/bin/env python3

'''This script is intended to run once per cycle to concat 0.25 deg gfs grib files'''

import json
import boto3

my_bucket   = 'dsg-combine-gfs-bucket'
gfs_bucket  = 'noaa-gfs-bdp-pds'
end_pattern = "pgrb2.0p25.f064"  # pattern for the 64th hour forecast of the 0.25 degree GFS pgrb2

def handler(raw_event: dict, context: 'awslambdaric.lambda_context.LambdaContext'):
    '''Our default handler method for our lambda. Filter out all but our end_pattern'''
    # print("Lambda function memory limits in MB:", context.memory_limit_in_mb) # 128 MB
    # print(f"Received raw event: {raw_event}")
    body = json.loads(raw_event["Records"][0]["body"])
    # print(f"body: {body}") 
    message = ''
    if "Message" in body.keys():
      message = json.loads(body["Message"])
    elif "Records" in body.keys():
      message = body
    print(f"Received raw message: {message}")
    message_key = message["Records"][0]["s3"]["object"]["key"]
    # message_key eg: gfs.20230811/18/atmos/gfs.t18z.pgrb2.0p25.f064
    print(f"DSG Filtered object key: {message_key}")
    if not message_key.endswith(end_pattern):
      print(f"Not the droids we're looking for, moving on..")
      return                              # exit our lambda, nothing to do
    filename = message_key.split('/')[-1] # gfs.t18z.pgrb2.0p25.f064
    ymd = message_key[4:12]               # 20230811
    hour = filename[5:7]                  # runtime hour # 18
    for fcst in range(0,65):              # loop through first 64 forecast files
        perform_cat(f'gfs.{ymd}/{hour}/atmos/gfs.t{hour}z.pgrb2.0p25.f{fcst:03d}')
    print(f'Lambda time remaining: {context.get_remaining_time_in_millis()/1000:.1f} seconds')

def gfs_part_copy(upload_id: str, parts_info: dict, source_key: str, part_key: str):
    '''convenience method for uploading a gfs part of a multipart upload'''
    part_num = len(parts_info['Parts']) + 1
    print(f'uploading part #{part_num} from source: {part_key}')
    response_c = s3.upload_part_copy(Bucket = my_bucket, Key = source_key, UploadId = upload_id,
                      PartNumber = part_num, CopySource = {'Bucket': gfs_bucket, 'Key': part_key} )
    parts_info['Parts'].append( # keep track of our parts to properly complete the upload
        {'PartNumber': part_num, 'ETag': response_c['CopyPartResult']['ETag'].strip('\"')} )
    return upload_id, parts_info

def perform_cat(source_key: str):
    '''Perform a simple concatenation of the prgb2 and prgb2b files for the given key'''
    from botocore.exceptions import ClientError
    global s3
    my_key_b = source_key.replace("pgrb2","pgrb2b")
    print(f'running perform_cat(), copying from: {source_key}')
    s3 = boto3.client('s3', region_name='us-east-1')
    try:
        response_m = s3.create_multipart_upload( # prepare for uploading our parts
                         Bucket = my_bucket, Key = source_key, ContentType = 'binary/octet-stream' )
        upload_id = response_m['UploadId']
        parts_info = {'Parts': []} # init our parts dictionary to hold our part numbers and etags
        upload_id, parts_info = gfs_part_copy(upload_id, parts_info, source_key, source_key) # pgrb2
        upload_id, parts_info = gfs_part_copy(upload_id, parts_info, source_key, my_key_b) # pgrb2b
        resonse_comp = s3.complete_multipart_upload( Bucket = my_bucket, # complete the parts upload
                           Key = source_key, UploadId = upload_id, MultipartUpload = parts_info, )
        # print(f'resonse_comp: {resonse_comp}')
    except ClientError as ce:
        print(f'botocore.exceptions.ClientError occurred while performing the merge')
        print(f'DEBUG ClientError: {ce}')
        raise ce

if __name__ == '__main__': # Our test case for command line usage or verification
    perform_cat("gfs.20230817/12/atmos/gfs.t12z.pgrb2.0p25.f037")
