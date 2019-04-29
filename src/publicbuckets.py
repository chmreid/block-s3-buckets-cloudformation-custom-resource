import os
import boto3
from crhelper import CfnResource

helper = CfnResource(json_logging=False, log_level='INFO', boto_level='CRITICAL')

@helper.create
def create(event, context):
    client = boto3.client('s3control')
    client.put_public_access_block(
        PublicAccessBlockConfiguration={
            "BlockPublicAcls": bool(os.environ['BPA'] == 'true'),
            "IgnorePublicAcls": bool(os.environ['IPA'] == 'true'),
            "BlockPublicPolicy": bool(os.environ['BPP'] == 'true'),
            "RestrictPublicBuckets": bool(os.environ['RPB'] == 'true')
        },
        AccountId=os.environ['ACCOUNT_ID']
    )

@helper.delete
def delete(event, context):
    client = boto3.client('s3control')
    client.put_public_access_block(
        PublicAccessBlockConfiguration={
            "BlockPublicAcls": not bool(os.environ['BPA'] == 'true'),
            "IgnorePublicAcls": not bool(os.environ['IPA'] == 'true'),
            "BlockPublicPolicy": not bool(os.environ['BPP'] == 'true'),
            "RestrictPublicBuckets": not bool(os.environ['RPB'] == 'true')
        },
        AccountId=os.environ['ACCOUNT_ID']
    )

def handler(event, context):
    helper(event, context)
