all: deploy
.PHONY: clean build deploy destroy-stack

clean:
	-rm -rf pkg requirements.txt Pipfile.lock templates/packaged.yaml

requirements.txt:
	@echo 'Building requirements list...'
	@pipenv install
	@pipenv lock -r > requirements.txt

pkg/: requirements.txt templates/template.yaml
	@echo 'Building lambda package from requirements and source...'
	@pip install -r requirements.txt -t pkg/
	@cp src/publicbuckets.py pkg/

# Magic sauce
profile =
ifneq ($(origin AWS_DEFAULT_PROFILE), undefined)
	profile = --profile $(AWS_DEFAULT_PROFILE)
endif
s3bucket =
ifneq ($(origin S3_BUCKET), undefined)
	s3bucket = $(S3_BUCKET)
endif
lambdastackname = security-lambda-s3control
ifneq ($(origin LAMBDA_STACK_NAME), undefined)
	lambdastackname = $(LAMBDA_STACK_NAME)
endif
cfnstackname = security-s3control
ifneq ($(origin CFN_STACK_NAME), undefined)
	cfnstackname = $(CFN_STACK_NAME)
endif
s3controlpolicyname = lambda-policy-s3control
ifneq ($(origin S3_CONTROL_POLICY_NAME), undefined)
	s3controlpolicyname = $(S3_CONTROL_POLICY_NAME)
endif
s3controlrolename = lambda-role-s3control
ifneq ($(origin S3_CONTROL_ROLE_NAME), undefined)
	s3controlrolename = $(S3_CONTROL_ROLE_NAME)
endif
s3controlrolepath = /
ifneq ($(origin S3_CONTROL_ROLE_PATH), undefined)
	s3controlrolepath = $(S3_CONTROL_ROLE_PATH)
endif
customfunctionoutputkeyname = custom-resource-block-public-s3-buckets
ifneq ($(origin CUSTOM_FUNCTION_OUTPUT_KEY_NAME), undefined)
	customfunctionoutputkeyname = $(CUSTOM_FUNCTION_OUTPUT_KEY_NAME)
endif
bpa = True
ifneq ($(origin bpa), undefined)
	bpa = $(BLOCK_PUBLIC_ACLS)
endif
ipa = True
ifneq ($(origin ipa), undefined)
	ipa = $(IGNORE_PUBLIC_ACLS)
endif
bpp = True
ifneq ($(origin bpp), undefined)
	bpp = $(BLOCK_PUBLIC_POLICY)
endif
rpb = True
ifneq ($(origin rpb), undefined)
	rpb = $(RESTRICT_PUBLIC_BUCKETS)
endif
parameteroverrides = 'S3ControlPolicyName=$(s3controlpolicyname)' \
	'S3ControlRoleName=$(s3controlrolename)' \
	'S3ControlRolePath=$(s3controlrolepath)' \
	'CustomFunctionOutputKeyName=$(customfunctionoutputkeyname)' \
	'BlockPublicAcls'=$(bpa)' \
	'IgnorePublicAcls'=$(ipa)' \
	'BlockPublicPolicy'=$(bpp)' \
	'RestrictPublicBuckets'=$(rpb)'

templates/packaged.yaml: pkg/
	@echo 'Attempting to compile cloudformation from template...'
	aws $(profile) cloudformation package --template-file templates/template.yaml --output-template-file templates/packaged.yaml --s3-bucket $(s3bucket)

build: templates/packaged.yaml

deploy: build
	@echo "Attempting to deploy compiled cloudformation..."
	@aws $(profile) cloudformation deploy --template-file templates/packaged.yaml --stack-name $(lambdastackname) --parameter-overrides $(parameteroverrides) --capabilities CAPABILITY_NAMED_IAM
	@aws $(profile) cloudformation deploy --template-file templates/stack.yaml --stack-name $(cfnstackname) --parameter-overrides $(parameteroverrides)

destroy-stack:
	@echo "Attempting to destroy stack..."
	@aws $(profile) cloudformation delete-stack --stack-name $(cfnstackname)
	@echo "Waiting for $(cfnstackname) to be deleted..."
	@aws $(profile) cloudformation wait stack-delete-complete --stack-name $(cfnstackname)
	@aws $(profile) cloudformation delete-stack --stack-name $(lambdastackname)
	@echo "Waiting for $(lambdastackname) to be deleted..."
	@aws $(profile) cloudformation wait stack-delete-complete --stack-name $(lambdastackname)
