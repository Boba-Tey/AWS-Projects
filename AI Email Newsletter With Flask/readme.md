# 🤖 AI-Generated Astronomy Newsletter: Serverless Cloud Automation with Lambda and Eventbridge

### Goal of this project:
- Allow users to subscribe and receive AI generated astronomy fun facts via email along with an option to cancel their subscription.
- Automate sending new emails based on a given time schedule
- Create a microservice architecture where each component functions independently

#
### The Contents:
- A frontend flask web app hosted on Elastic Beanstalk prompts the user to enter their email for subscribing to the astronomy newsletter.

<img width="1000" alt="1" src="https://github.com/user-attachments/assets/34ce2f45-1ef8-4abb-8538-4bb326f57cfa" />

- Once subscribed a POST request is sent to the backend code stored in AWS Lambda Communication between EB and Lambda is done through REST API. If the user is successfully registered, a confirmation page is displayed.

<img width="1000" alt="2" src="https://github.com/user-attachments/assets/31a99e22-0b5d-4e14-bbcc-61420a8a6d06" />

- The lambda function was written in python and contains modules such as:
> -  Boto 3: Interacts with AWS services programmatically in python
> - Gemini AI: Generates the newsletter’s content
> - Yagmail: Mails the  newsletter from the list of emails
- The user's email is saved to a Dynamo DB table with the primary key being their email while the sort key is their uniquely generated token (this comes in handy during cancellation)

<img width="1000" alt="3" src="https://github.com/user-attachments/assets/75141e92-def4-4781-88c5-acc653da48aa" />

- Gemini AI generates an astronomy related fun fact and the content is then sent to all the subscribed users via Yagmail.

<img width="1024" height="248" alt="4" src="https://github.com/user-attachments/assets/230335a4-27db-4be4-a5d9-154c2dde4748" />

- Event Bridge is then used to invoke the lambda function at the given interval. this way the users can get new emails every day or every week.

<img width="1000" alt="5" src="https://github.com/user-attachments/assets/3b5309f0-78bd-40bb-9349-efc149d87d9a" />

- If a user wishes to no longer receive any new emails, they can click the link below the email to unsubscribe (as seen in the previous image) Only the user is sent their unique token which is required for opting out of the newsletter, this ensures nobody else can trigger a cancellation with the user’s email alone. After successfully unsubscribing a cancellation page is displayed.

<img width="1000" alt="6" src="https://github.com/user-attachments/assets/1ff4e9ef-ee6c-473f-ac45-f189772cc6b7" />

#
### Project’s Architecture:
<img width="500" src="https://github.com/user-attachments/assets/e3b4c032-6ce2-41c2-a9a4-63457229f240" />

# [Follow Along] Add these variables to your bash file
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
