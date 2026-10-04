## Public URL Generator With Content Moderation
> **This serverless architecture lets users upload and generate a public link for their image as long as the content provided is appropriate in nature.**

### Tools Used:
- **Terraform:** Infrastructure as Code (IaC)
- **S3 Buckets:** Static website hosting and image storage
- **AWS Lambda:** Serverless backend logic and event handling
- **Amazon Rekognition:** Automated image content moderation
- **API Gateway:** Middleware routing REST API endpoints to Lambda functions
- **DynamoDB:** Temporary state management for image verification status via TTL
- **IAM:** Least-privilege roles and access control policies
- **CloudWatch:** Logging and monitoring for Lambda functions

### Programming Languages Used:
- **JavaScript:** Frontend UI logic
- **Node JS:** Backend Lambda runtime

## Walkthrough

### 1) After an image is submitted and passes verification, the user receives a public link
<img src="Project Images/1.png">

### 2) Outcome when an image fails content verification
<img src="Project Images/2.png">

### 3) Outcome when an image size exceeds 2 MB (Validated on both frontend and backend)
<img src="Project Images/3.png">

### 4) Outcome when an image format is unsupported (Validated on both frontend and backend)
<img src="Project Images/4.png">


## Architecture Diagram
<img src="Project Images/diagram.jpg">

## Setup And Deployment Note
> *Feel free to clone this repository and customize the variable values to match your requirements.*

**1. Initialize Infrastructure (Main Directory):**
```bash
terraform init
```

**2. Setup Backend Dependencies (Lambda Directory):**
```bash
cd lambdacode
npm install
```
