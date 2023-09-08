#!/usr/bin/env python3

'''This script is intended to run once per cycle to subset and combine 0.25 deg gfs grib files'''

import json
import boto3

my_bucket   = 'dsg-combine-gfs-bucket'
gfs_bucket  = 'noaa-gfs-bdp-pds'
end_pattern = "pgrb2.0p25.f064"  # pattern for the 64th hour forecast of the 0.25 degree GFS pgrb2
search_str  = ':(1|2|3|5|7) mb:' # our *not* variable regular expression for selecting grib fields
min_size    = 20 * 1024 * 1024   # minimum size for our (sandwiched) upload parts (aws enforces 5+ MB)

def handler(raw_event: dict, context: 'awslambdaric.lambda_context.LambdaContext'):
    '''Our default handler method for our lambda. Filter out all but our end_pattern, then merge.'''
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
    filename = message_key.split('/')[-1] # eg: gfs.t18z.pgrb2.0p25.f064
    ymd = message_key[4:12]               # eg: 20230811
    hour = filename[5:7]                  # runtime hour # eg: 18
    for fcst in range(0,65):              # loop through first 64 forecast files
        perform_merge(f'gfs.{ymd}/{hour}/atmos/gfs.t{hour}z.pgrb2.0p25.f{fcst:03d}')
    print(f'Lambda time remaining: {context.get_remaining_time_in_millis()/1000:.1f} seconds')

def get_idx_lines(bucket: str, key: str):
    '''Given an s3 object (assumed to be a grib file), retrieve and return its corresponding idx lines'''
    idx_obj_dict = s3.get_object(Bucket=bucket, Key=key + ".idx") # download our idx
    idx_content  = idx_obj_dict['Body'].read().decode() # read our content
    lines        = idx_content.split("\n") # create a list of our grib idx text lines
    while '' in lines: lines.remove('') # remove any empty lines
    return lines

def idx_to_byteranges(lines: list, search_str: str) -> dict:
    '''Given the lines of a grib idx and our variable regex, populate a dictionary with our wanted byte ranges'''
    import re
    expr = re.compile(search_str) # our grib variable Search expression
    byte_ranges = {} # initialize a dictionary # {byte-range-as-string: line}
    for n, line in enumerate(lines, start=1): # read each line in our idx file
        if not expr.search(line): # line does *not* match the string we are looking for
            parts = line.split(':')
            rangestart = int(parts[1]) # Get the beginning byte in the line we found
            if n+1 <= len(lines): # if there is a next line
                parts = lines[n].split(':')
                rangeend = int(parts[1]) # the beginning byte of the next line is our end
            else: # there isn't a next line, go to the end of the file.
                rangeend = ''
            byte_ranges[f'bytes={rangestart}-{rangeend}'] = line # Store the byte-range string as our dictionary key
            num, byte, date, var, level, forecast, _ = line.split(':')[0:7]
    return byte_ranges

def contig_ranges(byte_ranges: dict):
    '''Analyze our byte_ranges for contiguous sections of minimum size but no more than mem_max
    (our lambda buffer cripples at this point), also the last part of a multipart can be smaller.'''
    new_ranges = [] # initialize to hold our new contiguous range
    for n, this_range in enumerate(byte_ranges.keys(), start=1):
        start, end = this_range[6:].split('-')
        if len(new_ranges) == 0:
            new_ranges.append(f'bytes={start}-{end}')
        if n+1 > len(byte_ranges): continue # stop here unless there is a next line
        next_start, next_end = list(byte_ranges.keys())[n][6:].split('-')
        if end == next_start: # we have contigous pieces, updated the latest range with the next_end
            new_ranges[-1] = new_ranges[-1][: new_ranges[-1].find('-')+1 ] + next_end
        else:
            new_ranges.append(f'bytes={next_start}-')
    return new_ranges

def new_idx_line(prev_line: str, byte_range: str, file_size: int, next_line_no: int):
    '''Update and return the previous grib idx line with this new addition please.
    Given a previous grib idx line, the byte range of that grib var, a previous file_size,
    and a next line_no, return a new line_no, running size and new idx line.'''
    prev_line_no, prev_start, *other_vars = prev_line.split(':')
    start, end = byte_range[6:].split('-') # byte_range eg: "bytes=3400-5000"
    this_size = 0 # default to we're on the last grib idx line, size not important
    if end != '': # we're at our wit's end
        this_size = int(end) - int(start)
    new_size = file_size + this_size
    new_line_no = str( int(next_line_no) + 1 )
    new_line = ":".join([new_line_no, str(file_size+1)] + other_vars)
    return new_line_no, new_size, new_line

def build_parts(my_key: str):
    '''Build our desired byte ranges and the new grib index - for the given key / file'''
    my_key_b = my_key.replace("pgrb2","pgrb2b")
    new_lines = get_idx_lines(gfs_bucket, my_key) # the start of our new combined idx is the pgrb2 idx
    next_line_no = new_lines[-1].split(':')[0] # read last line to parse its record number
    lines = get_idx_lines(gfs_bucket, my_key_b) # get our pgrb2b file idx lines
    byte_ranges = idx_to_byteranges(lines, search_str) # produce our selective byteranges
    response = s3.head_object(Bucket=gfs_bucket, Key=my_key) # get the pgrb2 size
    new_size = response['ContentLength'] - 1 # our running size starts with the pgrb2 size
    for this_range in byte_ranges.keys(): # for each grib line or variable, tally our new idx as needed
        next_line_no, new_size, new_line = new_idx_line(byte_ranges[this_range], this_range, new_size, next_line_no)
        new_lines.append(new_line) # tally our idx (after recaluclating via new_idx_line())
    return new_lines, byte_ranges, new_size

def perform_upload(this_range: str, my_key: str, my_upload_id, parts_info: dict, buffer: bytes):
    '''We are uploading parts, but need to buffer until we have the minimum size required..
    Unless we have a range large enough, then we can CopySourceRange instead (faster, less memory)'''
    skip_buffer = False # default to using the buffer
    start, end = this_range[6:].split('-')
    my_key_b = my_key.replace("pgrb2","pgrb2b")
    size = 0 
    if end != '':
        size = int(end) - int(start)
        if size > min_size:
            skip_buffer = True
    else:
        response = s3.head_object(Bucket=gfs_bucket, Key=my_key_b) # get the pgrb2b meta info
        full_size = response['ContentLength'] - 1 # our full size starts with the pgrb2 size
        this_range = this_range + str(full_size)
        size  = full_size - int(start)
        skip_buffer = True
    if not skip_buffer:
        if this_range != "bytes=0-0" :
            # actually download the byte range and append to buffer, until we have our min_size, *then* upload_part()
            buf_response = s3.get_object(Bucket=gfs_bucket, Key=my_key_b, Range=this_range, ResponseContentType='binary/octet-stream')
            body = buf_response['Body'].read()
            buffer = buffer + body
        if len(buffer) >= min_size or (this_range == "bytes=0-0" and buffer != b''): # or we're on the last grib variable / byte range
            part_num = len(parts_info['Parts']) + 1
            print(f'uploading part #{part_num} from src_b: {my_key_b}, {this_range}, size: {len(buffer)/1024/1024:.2f}MB')
            response = s3.upload_part( # upload our next part from the buffer we've assembled
                Bucket     = my_bucket,
                Key        = my_key,
                UploadId   = my_upload_id,
                PartNumber = part_num,
                Body       = buffer
            )
            parts_info['Parts'].append( {'PartNumber': part_num, 'ETag': response['ETag'].strip('\"')} )
            buffer = b''
    elif this_range != "bytes=0-0": # we are skipping the buffer method
        part_num = len(parts_info['Parts']) + 1
        print(f'uploading part #{part_num} from src_b:{my_key_b}, {this_range}, size:{size/1024/1024:.2f} MB')
        response = s3.upload_part_copy( # upload our next part from the buffer we've assembled
            Bucket          = my_bucket,
            Key             = my_key,
            UploadId        = my_upload_id,
            PartNumber      = part_num,
            CopySource      = {'Bucket':gfs_bucket, 'Key':my_key_b},
            CopySourceRange = this_range
        )
        parts_info['Parts'].append( {'PartNumber': part_num, 'ETag': response['CopyPartResult']['ETag'].strip('\"')} )
    return buffer, parts_info

def perform_merge(source_key: str):
    '''Perform the copy, subset, combine that we are interested in for the given file'''
    from botocore.exceptions import ClientError
    global s3 # register our boto3 client once, and use that session throughout our thread
    print(f'running multipart upload, copying from: {source_key}')
    s3 = boto3.client('s3', region_name='us-east-1')
    try:
        new_lines, byte_ranges, size = build_parts(source_key) # build and upload our idx, get meta
        put_response = s3.put_object( # put our new idx file in the bucket
            Bucket=my_bucket, Key=source_key+'.idx', Body="\n".join(new_lines))
        response_m = s3.create_multipart_upload(
            Bucket = my_bucket,
            Key = source_key, # use the same source key (path and filename) for our new object
            ContentType = 'binary/octet-stream'
        )
        my_upload_id = response_m['UploadId']
        parts_info = {'Parts': []} # our parts dictionary to hold our part numbers and etags
        part_num = 1 # our first part of this multi part upload is the pgrb2 file
        response_c = s3.upload_part_copy( # upload the first part as a full copy of first file
            Bucket     = my_bucket,
            Key        = source_key,
            UploadId   = my_upload_id,
            PartNumber = part_num,
            CopySource = {'Bucket':gfs_bucket, 'Key':source_key}
        )
        parts_info['Parts'].append( # keep track of our parts to properly complete the upload
            {'PartNumber': part_num, 'ETag': response_c['CopyPartResult']['ETag'].strip('\"')}
        )
        new_ranges = contig_ranges(byte_ranges) # take advantage of any contiguous bytes
        buffer = b'' # initialize a buffer to hold our part content(s) to be uploaded
        for this_range in new_ranges: # upload contiguous range of bytes for chosen variables
            buffer, parts_info = perform_upload(
                this_range, source_key, my_upload_id, parts_info, buffer) # upload our fields
        buffer, parts_info = perform_upload("bytes=0-0", source_key, my_upload_id, parts_info, buffer) # trigger uploading final buffer
        # print(f'parts_info: {parts_info}')
        resonse_comp = s3.complete_multipart_upload( # complete the uploading of all parts
            Bucket          = my_bucket,
            Key             = source_key,
            UploadId        = my_upload_id,
            MultipartUpload = parts_info,
        )
        # print(f'resonse_comp: {resonse_comp}')
    except ClientError as ce:
        print(f'botocore.exceptions.ClientError occurred while performing the merge')
        print(f'DEBUG ClientError: {ce}')
        raise ce

if __name__ == '__main__': # Our test case for command line usage or verification
    perform_merge("gfs.20230817/12/atmos/gfs.t12z.pgrb2.0p25.f037")
