# CloudFormation custom resource for blocking public S3 buckets for an entire account

The custom resource in this repository enables you to use the newly added S3 feature for [blocking the creation of public S3 buckets in an AWS account](https://aws.amazon.com/blogs/aws/amazon-s3-block-public-access-another-layer-of-protection-for-your-accounts-and-buckets/). Please read my blog post for more information: [blocking account-wide creation of public S3 buckets through a CloudFormation custom resource](https://sanderknape.com/2018/11/blocking-account-wide-creation-public-s3-buckets-cloudformation-custom-resource/).

Note that this custom resource enables all features for blocking the creation of public S3 buckets. See the original blog post linked above for more information on the different features now available.

## Requirements

* AWS CLI with Administrator permission
* [Python 3 installed](https://www.python.org/downloads/)
* [Pipenv installed](https://github.com/pypa/pipenv)
    - `pip install pipenv`

## Usage

The project includes a Makefile to automate the build, and deployment of the necessary resources to the target AWS account using CloudFormation.
Before running make, set the following variable, either in the environment, or by passing it to the make executable using environment overrides
* AWS_DEFAULT_PROFILE
* S3_BUCKET

The following variables are optional, and are pre-defined within the Makefile.
* CFN_STACK_NAME
* CUSTOM_FUNCTION_OUTPUT_KEY_NAME
* LAMBDA_STACK_NAME
* S3_CONTROL_POLICY_NAME
* S3_CONTROL_ROLE_NAME
* S3_CONTROL_ROLE_PATH

The following variables are set to True by default, but can be adjusted based on your need. Reference for each of the options, and their effect is in [this](https://docs.aws.amazon.com/AmazonS3/latest/dev/access-control-block-public-access.html#access-control-block-public-access-options) AWS documentation.
* BLOCK_PUBLIC_ACLS
* BLOCK_PUBLIC_POLICY
* IGNORE_PUBLIC_ACLS
* RESTRICT_PUBLIC_BUCKETS

Once you decided how you are going to pass the environment variables to Make, running ```make``` without any targets will build, and deploy the stack to your account

### Examples:
```bash
export S3_BUCKET=my_bucket
export AWS_DEFAULT_PROFILE=123456789012
make
```
**or**
```bash
make \
-e S3_BUCKET=my_bucket \
-e AWS_DEFAULT_PROFILE=123456789012
```

## Options
The Makefile provides the following targets:
* **distclean** - Reverts the project directory to its original state
* **clean** - Removes the lambda source from the staging area, and deletes the compiled template
* **prereqs** - Uses pipenv to pull the required libraries for the Lambda function into pkg/
* **build** - Compiles the template, and uploads to the target S3 bucket
* **deploy** - Deploys the compiled CloudFormation templates, and executes the templates containing the lambda function in the account
* **destroy-stack** - Deletes the two active stacks from the account, reversing the policy defined by the lambda function
