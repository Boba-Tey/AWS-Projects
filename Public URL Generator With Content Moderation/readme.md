# 📸 Static webhosting, URL generation, content moderation using S3, Lambda & AWS Rekognition

### Goal of this project:
- Host a static website on S3 and allow users to upload their images
- Prevent inappropriate images from being processed using AWS Rekognition
- Send and receive API requests along with renaming the images using Lambda
- Save the processed images in another S3 and return their public URL

#
### The Contents:
- Head to the website hosted on S3 and click Browse
- Once you choose an image, click Upload File
- Rekognition will analyze the image
- If the image passes the check, Lambda will rename it (to avoid any naming conflicts)
- Lambda’s logic was written in python.
- You will then receive a text stating  Your Public URL is Ready
- Click the text to receive your image’s public URL (the image will be saved in another S3 bucket)

![first](https://github.com/user-attachments/assets/cb61b76e-fa76-4d28-98d9-36fd9e230447)

- However if Rekognition detects any illicit material, an error image will occur and the image won’t be uploaded.

![second](https://github.com/user-attachments/assets/a9589892-43ce-4292-81d2-2b669a1e0564)

#
### Project’s Architecture:

<img width="500" src="https://github.com/user-attachments/assets/3fffdb72-313b-4cc9-a488-53a47b8fb9e1" />

# [Follow Along] The Variables
```bash
REGION_CODE=ap-south-1

WEB_BUCKET=public-url-gen101
IMG_BUCKET=public-url-store101

FUNCTION_NAME=lambda_function
MAIN_FUNCTION=lambda_handler
```
# Step 1: Create your Lambda Function
```bash
aws lambda create-function \
    --function-name $FUNCTION_NAME \
    --region $REGION_CODE \
    --role arn:aws:iam::12345678910:role/lambda_apps \
    --runtime python3.10 \
    --handler $FUNCTION_NAME.$MAIN_FUNCTION \
    --zip-file fileb://$FUNCTION_NAME.zip \
    --timeout 10

aws lambda add-permission \
    --function-name $FUNCTION_NAME \
    --statement-id AllowPublicInvokeFunctionUrl \
    --action lambda:InvokeFunctionUrl \
    --principal "*" \
    --function-url-auth-type NONE

aws lambda create-function-url-config \
    --function-name $FUNCTION_NAME \
    --auth-type NONE \
    --cors '{
      "AllowMethods":["POST"], 
      "AllowOrigins":["*"], 
      "AllowHeaders":["content-type"]
      }'
echo "$FUNCTION_NAME has been successfully created in $REGION_CODE!"
```

# Step 2: Create an S3 bucket for storing user uploaded images
```bash
aws s3api create-bucket \
    --bucket $IMG_BUCKET \
    --region $REGION_CODE \
    --create-bucket-configuration LocationConstraint=$REGION_CODE 

aws s3api put-public-access-block \
  --bucket $IMG_BUCKET \
  --public-access-block-configuration '{
      "BlockPublicAcls": false,
      "IgnorePublicAcls": false,
      "BlockPublicPolicy": false,
      "RestrictPublicBuckets": false
    }'

aws s3api put-bucket-policy \
  --bucket $IMG_BUCKET \
  --policy file://img-bucket-policy.json
echo "$IMG_BUCKET has been successfully created in $REGION_CODE!"
```

# Step 3: Create an S3 bucket to host your static website
```bash
aws s3api create-bucket \
    --bucket $WEB_BUCKET \
    --region $REGION_CODE \
    --create-bucket-configuration LocationConstraint=$REGION_CODE
echo "$WEB_BUCKET has been successfully created in $REGION_CODE!"

aws s3 website s3://$WEB_BUCKET/ --index-document index.html

aws s3api put-public-access-block \
  --bucket $WEB_BUCKET \
  --public-access-block-configuration '{
      "BlockPublicAcls": false,
      "IgnorePublicAcls": false,
      "BlockPublicPolicy": false,
      "RestrictPublicBuckets": false
    }'

aws s3api put-bucket-policy \
  --bucket $WEB_BUCKET \
  --policy file://web-bucket-policy.json

aws s3 cp ./webpage s3://$WEB_BUCKET/ --recursive
echo "Webpage created, link: http://$WEB_BUCKET.s3-website.$REGION_CODE.amazonaws.com/"

```

