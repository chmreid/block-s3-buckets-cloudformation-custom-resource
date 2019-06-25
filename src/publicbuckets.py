import os
import boto3
from crhelper import CfnResource

helper = CfnResource(json_logging=False, log_level='INFO', boto_level='CRITICAL')

@helper.update
@helper.create
def create(event, context):
  client = boto3.client('s3control')
  client.put_public_access_block(
    PublicAccessBlockConfiguration={
      "BlockPublicAcls": bool(event['ResourceProperties']['BlockPublicAcls'] == 'true'),
      "IgnorePublicAcls": bool(event['ResourceProperties']['IgnorePublicAcls'] == 'true'),
      "BlockPublicPolicy": bool(event['ResourceProperties']['BlockPublicPolicy'] == 'true'),
      "RestrictPublicBuckets": bool(event['ResourceProperties']['RestrictPublicBuckets'] == 'true')
    },
    AccountId=event['ResourceProperties']['AccountId']
  )

@helper.delete
def delete(event, context):
  client = boto3.client('s3control')
  client.put_public_access_block(
    PublicAccessBlockConfiguration={
      "BlockPublicAcls": not bool(event['ResourceProperties']['BlockPublicAcls'] == 'true'),
      "IgnorePublicAcls": not bool(event['ResourceProperties']['IgnorePublicAcls'] == 'true'),
      "BlockPublicPolicy": not bool(event['ResourceProperties']['BlockPublicPolicy'] == 'true'),
      "RestrictPublicBuckets": not bool(event['ResourceProperties']['RestrictPublicBuckets'] == 'true')
    },
    AccountId=event['ResourceProperties']['AccountId']
  )

def handler(event, context):
  helper(event, context)
