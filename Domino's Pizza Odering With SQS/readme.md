# 🍽️ Domino’s look alike website hosted on Elastic beanstalk and order handling with SQS, Lambda

### Goal of this project:
- Create a frontend Domino’s ecommerce website to browse and order your meals
- Handle user sessions, prompt them to add their email and address for delivery
- Use SQS to hold onto user’s order incase the order processing backend goes down
- Lambda (with python) as the backend for processing the user’s order
- Yagmail for sending conformation emails

#
### The Contents:
- Browse and add the pizza of your choice to the cart via vising the Elastic Beanstalk URL

<img width="1000" alt="1" src="https://github.com/user-attachments/assets/9e160a00-f3bb-414c-8472-287f19bc1853" />

- Review the items you added (the cart’s value is persistent even if you refresh the webpage)

<img width="1000" alt="2" src="https://github.com/user-attachments/assets/67e9fe20-9417-49f1-a75a-2b2cad329890" />

- Once the order is placed, the user will be requested to check their email for order conformation, payment and address details

<img width="1000" alt="3" src="https://github.com/user-attachments/assets/cadb0c96-aa29-4871-a0ad-94bfe8e8a8c3" />

- The order details will be converted into json and sent to SQS
- SQS will hold onto the message/json incase lambda or any backend process fails in order to avoid loosing order details
- Lambda will poll for your order details from SQS and process it
- Once the processing is complete, a conformation email will be sent to the user via yagmail

<img width="1000" alt="4" src="https://github.com/user-attachments/assets/a67f530f-5d13-4337-89a4-d6cb8f7ef89c" />

- The website is also responsive (with support for mobile screens)

<img width="797" height="643" alt="5" src="https://github.com/user-attachments/assets/14458675-eccb-4f52-bcd9-c76c1c5cdd60" />

#
### Project’s Architecture:

![diagram](https://github.com/user-attachments/assets/7b970b9d-f721-4609-8422-9564650778a5)

# [Follow Along] Variables And Setup
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


