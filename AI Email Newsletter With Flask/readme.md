# Read The Project Documentation Here: 
```
https://www.notion.so/AI-Email-Newsletter-With-Flask-21dc243503228000ad13f169626074df
```

# Add these variables to your bash file
```bash
#!/bin/bash
set -e

REGION_CODE=ap-south-1

BUCKET_NAME=ai-newsletter-app101
LAMBDA_FILE_NAME=email_schedule.zip
FLASK_FILE_NAME=application.zip

FUNCTION_NAME=lambda_function
MAIN_FUNCTION=lambda_handler
FUNCTION_ARN="arn:aws:lambda:ap-south-1:123456789012:function:lambda_function"

TABLE_NAME=email_list

EVENT_NAME=email_scheduler   
EVENT_ARN="arn:aws:iam::123456789012:role/eventbridge-scheduler"  
```

# Step 1: Make a S3 bucket
```bash
aws s3api create-bucket \
    --bucket $BUCKET_NAME \
    --region $REGION_CODE \
    --create-bucket-configuration LocationConstraint=$REGION_CODE
echo "$BUCKET_NAME has been successfully created in $REGION_CODE!"
```

# Step 2: Upload email_schedule.zip to the bucket
```bash
aws s3api put-object \
    --bucket $BUCKET_NAME \
    --key $LAMBDA_FILE_NAME \
    --body main/$LAMBDA_FILE_NAME
echo "$LAMBDA_FILE_NAME added to $BUCKET_NAME!"
```

# Step 3: Create the Lambda Function
```bash
aws lambda create-function \
    --function-name $FUNCTION_NAME \
    --region $REGION_CODE \
    --role arn:aws:iam::992382676630:role/lambda_apps \
    --runtime python3.10 \
    --handler $FUNCTION_NAME.$MAIN_FUNCTION \
    --code S3Bucket=$BUCKET_NAME,S3Key=$S3_FILE_NAME \
    --environment file://lambda_app/env.json \
    --timeout 30
echo "$FUNCTION_NAME has been successfully created in $REGION_CODE!"
```

# Step 4: Create DynamoDB Table
```bash
aws dynamodb create-table \
  --table-name $TABLE_NAME \
  --region $REGION_CODE \
  --attribute-definitions \
    AttributeName=email,AttributeType=S \
    AttributeName=token,AttributeType=S \
  --key-schema \
    AttributeName=email,KeyType=HASH \
    AttributeName=token,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST
echo "$TABLE_NAME has been successfully created in $REGION_CODE!"
```

# Step 5: Upload application.zip to the bucket
```bash
aws s3api put-object \
    --bucket $BUCKET_NAME \
    --key $FLASK_FILE_NAME \
    --body main/$FLASK_FILE_NAME
echo "$FLASK_FILE_NAME added to $BUCKET_NAME!"
```

# Step 6: Create your Elastic Beanstalk
```bash
aws elasticbeanstalk create-application \
  --application-name my-app \
  --region $REGION_CODE \
  --description "My Flask App"
echo "App created"

aws elasticbeanstalk create-application-version \
  --application-name my-app \
  --region $REGION_CODE \
  --version-label v1 \
  --source-bundle S3Bucket=$BUCKET_NAME,S3Key=$FLASK_FILE_NAME
echo "App version created"

aws elasticbeanstalk create-environment \
  --application-name my-app \
  --environment-name my-app-env \
  --region $REGION_CODE \
  --cname-prefix my-app-testing123 \
  --version-label v1 \
  --solution-stack-name "64bit Amazon Linux 2023 v4.5.2 running Python 3.13" \
  --option-settings file://options.json
echo "Elastic beanstalk is in progress..."
```

# Step 7: Create a Scheduled Eventbridge
```bash
aws scheduler create-schedule \
    --name "email_invoke" \
    --region $REGION_CODE \
    --description "send ai generated emails at a given intreval." \
    --schedule-expression "rate(2 minutes)" \
    --schedule-expression-timezone "Asia/Kolkata" \
    --flexible-time-window Mode=OFF \
    --target 'Arn='"$FUNCTION_ARN"',RoleArn='"$EVENT_ARN"',Input="{\"action\":\"schedule_email\"}"'
echo "$EVENT_NAME has been successfully created in $REGION_CODE!"

```
