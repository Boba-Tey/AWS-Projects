# 😋 Serverless ordering and tracking chatbot using Amazon Lex, Lambda, DynamoDB and S3

### Goal of this project:
- Create a chatbot with Amazon Lex
- Reply to user queries using intents, slots and sample utterances
- DynamoDB for storing Order IDs
- Lambda for order, image mapping and querying Dynamo DB
- S3 for storing order images

#
### The Contents:
- Initiate conversation with the chatbot using a sample utterance (like hi, hello, hey)
- This triggers the ordering intent
- Amazon Lex then asks the user their order, for this a custom slot type was used and keywords (like cheese, grill cheese) were tagged to the menu item “Grill Cheese sandwich”
- After noting, the bot sends a confirmation card asking the user if it should place the order?

<img height="513" alt="1" src="https://github.com/user-attachments/assets/361513ca-4fbd-48f2-baa1-807d94e02d9b" />
&nbsp;
<img height="513" alt="2" src="https://github.com/user-attachments/assets/b1af0630-2b2a-4aba-8e6e-21941a969b5e" />

- If the user confirms their order, Lambda generates an order ID and saves it to DynamoDB. Lex then informs the user about the order being placed and the keyword/utterance to use for tracking their order
- However if the user denies to place an order, Lex ceases the ordering processing

<img height="253" alt="3" src="https://github.com/user-attachments/assets/2d7a3f88-cbf2-4321-a423-7e9fbfa9f50a" />
&nbsp;
<img height="142" alt="4" src="https://github.com/user-attachments/assets/66d11ff5-2be8-4d62-835f-31ce0fe1ad32" />

- Here in the tracking intent, the user says a variant of the utterance “Where is my order?”
- Lex then prompts the user for their order ID

<img height="169" alt="5" src="https://github.com/user-attachments/assets/e04caa47-20c1-46ac-9019-76832087c6ee" />

- Lambda will query DynamoDb and check if the order ID provided is correct, the bot will then mention the order name and show a progress image (which is stored in an S3 bucket)
- The image varies based on which sandwich was ordered.

<img height="510" alt="6" src="https://github.com/user-attachments/assets/a146a9fb-4bd3-4371-a65b-9d0eda7481d6" />
&nbsp;
<img height="510" alt="7" src="https://github.com/user-attachments/assets/b97ae101-a766-4a9a-8d35-0726c4b772c9" />

- If the user says a wrong order id or utterance, the fallback intent will be triggered

<img height="242" alt="8" src="https://github.com/user-attachments/assets/0c70cd17-3a15-42b3-a39b-41f765b09b9f" />
&nbsp;
<img height="141" alt="9" src="https://github.com/user-attachments/assets/82d1f451-02b5-4c95-8a90-810b9b3ab95d" />

#
### Project’s Architecture:

![diagram](https://github.com/user-attachments/assets/897a2bc6-fdab-48a0-8868-6d0fd13210bd)

# [Follow Along] Variables 
```bash
#!/bin/bash
set -e

REGION=ap-southeast-1 # Amazon Lex isn't in ap-south-1 (Mumbai) as of writing

BUCKET_NAME=sandwitch-bot-images
FILE_NAME=bread.jpg

FUNCTION_NAME=lambda_function
MAIN_FUNCTION=lambda_handler

BOT_NAME=sandwitch-bot
BOT_ROLE=arn:aws:iam::ACCOUNT_ID:role/aws-service-role/lexv2.amazonaws.com/AWSServiceRoleForLexV2Bots_M383NX0ZTC
BOT_ID=ID
BOT_VERSION=DRAFT
LOCALE_ID=en_US
INTENT_ID=ID
SLOT_TYPE_ID=ID
```

# Optional: Create an S3 bucket to host images for your Chatbot
```bash
aws s3api create-bucket \
    --bucket $BUCKET_NAME \
    --region $REGION \
    --create-bucket-configuration LocationConstraint=$REGION

aws s3api put-public-access-block \
  --bucket $BUCKET_NAME \
  --public-access-block-configuration '{
      "BlockPublicAcls": false,
      "IgnorePublicAcls": false,
      "BlockPublicPolicy": false,
      "RestrictPublicBuckets": false
    }'

aws s3api put-bucket-policy \
  --bucket $BUCKET_NAME \
  --policy file://bucket-policy.json
echo "$BUCKET_NAME has been successfully created in $REGION!"
```

# Upload the image and return it's URL
```bash
aws s3api put-object \
    --region $REGION \
    --body $FILE_NAME \
    --bucket $BUCKET_NAME \
    --key $FILE_NAME \
    --content-type "image/jpg"
echo "Successfully uploaded $FILE_NAME to $BUCKET_NAME"
echo "URL: https://$BUCKET_NAME.s3.amazonaws.com/$FILE_NAME"
```

# Step 1: Create the bot
```bash
aws lexv2-models create-bot \
    --bot-name $BOT_NAME \
    --description "Order a sandwich" \
    --region $REGION \
    --role-arn $BOT_ROLE \
    --data-privacy '{"childDirected": false}' \
    --idle-session-ttl-in-seconds 300
echo "$BOT_NAME created in $REGION"
```

# Step 2: Add voice to the bot
```bash
aws lexv2-models create-bot-locale \
  --bot-id $BOT_ID \
  --bot-version $BOT_VERSION \
  --region $REGION \
  --locale-id en_US \
  --description "English locale" \
  --nlu-intent-confidence-threshold 0.40 \
  --voice-settings '{"voiceId": "Stephen", "engine": "neural"}'
echo "Added language and voice to $BOT_NAME"
```

# Step 3: Create the slot type
```bash
aws lexv2-models create-slot-type \
    --slot-type-name Sandwiches \
    --slot-type-values file://slot-type.json \
    --value-selection-setting '{"resolutionStrategy": "TopResolution"}' \
    --region $REGION \
    --bot-id $BOT_ID \
    --bot-version $BOT_VERSION \
    --locale-id $LOCALE_ID
echo "Slot-type created!"
```

# Step 4: Create a blank Intent (Do the Same process for any new intent)
```bash
aws lexv2-models create-intent \
    --intent-name Ordering \
    --description "Start the ordering process" \
    --region $REGION \
    --bot-id $BOT_ID \
    --bot-version $BOT_VERSION \
    --locale-id $LOCALE_ID
echo "Intent created"
```

# Step 5: Create a slot
```bash
aws lexv2-models create-slot \
    --slot-name sandwich \
    --cli-input-json file://slot-settings.json  \
    --region $REGION \
    --slot-type-id $SLOT_TYPE_ID \
    --bot-id $BOT_ID \
    --bot-version $BOT_VERSION \
    --locale-id $LOCALE_ID \
    --intent-id $INTENT_ID
echo "Slot created"
```

# Step 6: Create the Lambda Function
```bash
aws lambda create-function \
    --function-name $FUNCTION_NAME \
    --region $REGION \
    --role arn:aws:iam::ACCOUNT_ID:role/lambda_apps \
    --runtime python3.10 \
    --handler $FUNCTION_NAME.$MAIN_FUNCTION \
    --zip-file fileb://$FUNCTION_NAME.zip \
    --timeout 10
echo "$FUNCTION_NAME has been successfully created in $REGION!"
```

# Step 7: Create DynamoDB Table
```bash
aws dynamodb create-table \
    --table-name OrderList \
    --region $REGION \
    --attribute-definitions \
        AttributeName=OrderID,AttributeType=S \
    --key-schema \
        AttributeName=OrderID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST
echo "OrderList has been successfully created in $REGION!"
```

# Step 8: Get the Slot ID
```bash
aws lexv2-models list-slots \
    --bot-id $BOT_ID \
    --bot-version $BOT_VERSION \
    --locale-id $LOCALE_ID \
    --intent-id $INTENT_ID \
    --output json \
    --region $REGION | grep -B 1 "sandwich" | grep "slotId" | awk -F': ' '{print $2}' | tr -d '", '
echo "Slot ID returned"
```

# Step 9: Update Intent
```bash
aws lexv2-models update-intent \
    --intent-id "$INTENT_ID" \
    --intent-name Ordering \
    --cli-input-json file://intent-settings.json \
    --region "$REGION" \
    --bot-id "$BOT_ID" \
    --bot-version $BOT_VERSION \
    --locale-id "$LOCALE_ID"
echo "Updated Intent"
```

# Step 10: Build the bot
```bash
aws lexv2-models build-bot-locale \
    --region $REGION \
    --bot-id $BOT_ID \
    --bot-version $BOT_VERSION \
    --locale-id $LOCALE_ID
echo "Built $BOT_NAME"

```


