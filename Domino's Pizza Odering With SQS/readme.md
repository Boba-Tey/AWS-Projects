# Read The Project Documentation Here: 
 https://www.notion.so/Domino-s-Pizza-Ordering-With-SQS-230c24350322809bb497cb70834a911d?source=copy_link

# Variables And Setup
```bash
#!/bin/bash
set -e

REGION_CODE=ap-south-1

LAMBDA_FILE_NAME=lambda_function.zip
FLASK_FILE_NAME=application.zip

BUCKET_NAME=pizza-flask-website101
SQS_NAME=pizza-queue
FUNCTION_NAME=lambda_function
MAIN_FUNCTION=lambda_handler
FUNCTION_ARN="arn:aws:lambda:ap-south-1:992382676630:function:lambda_function"
```

# Step 1: Create the Lambda Function
```bash
aws lambda create-function \
    --function-name $FUNCTION_NAME \
    --region $REGION_CODE \
    --role arn:aws:iam::992382676630:role/lambda_apps \
    --runtime python3.10 \
    --handler $FUNCTION_NAME.$MAIN_FUNCTION \
    --zip-file fileb://$LAMBDA_FILE_NAME \
    --environment file://env.json \
    --timeout 15
echo "$FUNCTION_NAME has been successfully created in $REGION_CODE!"
```

# Step 2: Create SQS Que
```bash
aws sqs create-queue \
  --queue-name $SQS_NAME \
  --region $REGION_CODE \
  --attributes file://sqs-attributes.json
echo "$SQS_NAME has been successfully created in $REGION_CODE!"
```

# Step 3: Link the Lambda Function with the SQS
```bash
aws lambda create-event-source-mapping \
  --function-name $FUNCTION_NAME \
  --event-source-arn arn:aws:sqs:$REGION_CODE:992382676630:$SQS_NAME \
  --batch-size 1 \
  --enabled
echo "Mapped Successfully!"
```

# Step 4: Create a bucket and upload your flask .zip file into it
```bash
aws s3api create-bucket \
    --bucket $BUCKET_NAME \
    --region $REGION_CODE \
    --create-bucket-configuration LocationConstraint=$REGION_CODE
echo "$BUCKET_NAME has been successfully created in $REGION_CODE!"

aws s3 cp $FLASK_FILE_NAME s3://$BUCKET_NAME/$FLASK_FILE_NAME
echo "$FLASK_FILE_NAME has been successfully uploaded to $BUCKET_NAME!"
```

# Step 5: Create your Elastic Beanstalk
```bash
aws elasticbeanstalk create-application \
  --application-name dominos-app \
  --region $REGION_CODE \
  --description "My Flask App"
echo "App created"

aws elasticbeanstalk create-application-version \
  --application-name dominos-app \
  --region $REGION_CODE \
  --version-label v1 \
  --source-bundle S3Bucket=$BUCKET_NAME,S3Key=$FLASK_FILE_NAME
echo "App version created"

aws elasticbeanstalk create-environment \
  --application-name dominos-app \
  --environment-name dominos-app-env \
  --region $REGION_CODE \
  --cname-prefix my-dominos-app123 \
  --version-label v1 \
  --solution-stack-name "64bit Amazon Linux 2023 v4.5.2 running Python 3.13" \
  --option-settings file://options.json
echo "Elastic beanstalk is in progress..."

```

