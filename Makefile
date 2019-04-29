# Magic sauce
profile =
ifneq ($(origin AWS_DEFAULT_PROFILE), undefined)
	profile = --profile $(AWS_DEFAULT_PROFILE)
endif
s3bucket =
ifneq ($(origin S3_BUCKET), undefined)
	s3bucket = $(S3_BUCKET)
endif
s3prefix =
ifneq ($(origin S3_PREFIX), undefined)
	s3prefix = --s3-prefix $(S3_PREFIX)
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
bpa = true
ifneq ($(origin BLOCK_PUBLIC_ACLS), undefined)
	bpa = $(BLOCK_PUBLIC_ACLS)
endif
ipa = true
ifneq ($(origin IGNORE_PUBLIC_ACLS), undefined)
	ipa = $(IGNORE_PUBLIC_ACLS)
endif
bpp = true
ifneq ($(origin BLOCK_PUBLIC_POLICY), undefined)
	bpp = $(BLOCK_PUBLIC_POLICY)
endif
rpb = true
ifneq ($(origin RESTRICT_PUBLIC_BUCKETS), undefined)
	rpb = $(RESTRICT_PUBLIC_BUCKETS)
endif
parameteroverrides = 'S3ControlPolicyName=$(s3controlpolicyname)' \
	'S3ControlRoleName=$(s3controlrolename)' \
	'S3ControlRolePath=$(s3controlrolepath)' \
	'CustomFunctionOutputKeyName=$(customfunctionoutputkeyname)' \
	'BlockPublicAcls=$(bpa)' \
	'IgnorePublicAcls=$(ipa)' \
	'BlockPublicPolicy=$(bpp)' \
	'RestrictPublicBuckets=$(rpb)'

all: deploy
.PHONY: distclean clean prereqs package build test deploy destroy-stack

distclean: clean
	-rm -rf requirements.txt Pipfile.lock pkg/

clean:
	-rm -rf pkg/publicbuckets.py templates/packaged.yaml

prereqs: requirements.txt
package: pkg/publicbuckets.py
build: templates/packaged.yaml

requirements.txt:
	@echo 'Building requirements list...'
	@pipenv install
	@pipenv lock -r > requirements.txt
	@pip install -r requirements.txt -t pkg/

pkg/publicbuckets.py: clean requirements.txt pkg/ src/publicbuckets.py
	@echo 'Copy lambda source to package staging location...'
	@cp src/publicbuckets.py pkg/

templates/packaged.yaml: pkg/publicbuckets.py
	@echo 'Attempting to compile cloudformation from template...'
	aws $(profile) cloudformation package \
	--template-file templates/template.yaml \
	--output-template-file templates/packaged.yaml \
	--s3-bucket $(s3bucket) \
	$(s3prefix)

deploy: build
	@echo "Attempting to deploy resources for custom lambda..."
	@aws $(profile) cloudformation deploy \
	--template-file templates/packaged.yaml \
	--stack-name $(lambdastackname) \
	--parameter-overrides $(parameteroverrides) \
	--capabilities CAPABILITY_NAMED_IAM
	@echo "Sleeping for 60 seconds to ensure that IAM role is available to the \
	lambda service..."
	@sleep 60
	@echo "Attempting to execute custom lambda..."
	@aws $(profile) cloudformation deploy --template-file templates/stack.yaml \
	--stack-name $(cfnstackname) --parameter-overrides $(parameteroverrides)
	@echo "Waiting for $(cfnstackname) to be complete..."
	@aws $(profile) cloudformation wait stack-create-complete \
	--stack-name $(cfnstackname)
	@echo "Applying termination protection..."
	@aws $(profile) cloudformation update-termination-protection \
	--enable-termination-protection \
	--stack-name $(cfnstackname)
	@aws $(profile) cloudformation update-termination-protection \
	--enable-termination-protection \
	--stack-name $(lambdastackname)

destroy-stack:
	@echo "Removing termination protection..."
	@aws $(profile) cloudformation update-termination-protection \
	--no-enable-termination-protection \
	--stack-name $(cfnstackname)
	@aws $(profile) cloudformation update-termination-protection \
	--no-enable-termination-protection \
	--stack-name $(lambdastackname)
	@echo "Attempting to destroy stack..."
	@aws $(profile) cloudformation delete-stack --stack-name $(cfnstackname)
	@echo "Waiting for $(cfnstackname) to be deleted..."
	@aws $(profile) cloudformation wait stack-delete-complete \
	--stack-name $(cfnstackname)
	@aws $(profile) cloudformation delete-stack --stack-name $(lambdastackname)
	@echo "Waiting for $(lambdastackname) to be deleted..."
	@aws $(profile) cloudformation wait stack-delete-complete \
	--stack-name $(lambdastackname)
