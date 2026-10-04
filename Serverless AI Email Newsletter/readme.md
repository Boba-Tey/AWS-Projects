# Serverless AI Email Newsletter
> **A serverless architecture that allows users to subscribe to an Astronomy Newsletter. Subscribers periodically receive astronomy fun facts, while unverified users are automatically purged from the subscriber list on a scheduled basis.**

### Tools Used:
- **AWS CloudFormation:** Infrastructure as Code (IaC)
- **Docker:** Packaging Python libraries for Amazon Linux compatibility in AWS Lambda
- **Jenkins:** CI/CD pipeline automation for deploying and destroying infrastructure stages
- **AWS S3:** Hosting the static frontend website
- **AWS Lambda:** Serverless backend execution and processing logic
- **Amazon API Gateway:** REST API routing and endpoint management for AWS Lambda
- **Amazon Aurora DSQL:** Relational database for managing subscriber state and verification statuses
- **Amazon EventBridge Scheduler:** Periodic scheduling for sending emails and running list cleanup tasks
- **AWS IAM:** Fine-grained access control adhering to the Principle of Least Privilege

### Programming Languages Used:
- **Javascript**: Frontend UI logic
- **Python**: Backend Lambda runtime
- **PowerShell**: Used for automation in Jenkins pipeline stages

## Walkthrough

### 1) Users sign up for the newsletter on the static frontend hosted on S3.
<img src="Project Images/1.png">

### 2) After registering, users are prompted to check their email inbox for a verification link.
<img src="Project Images/2.png">

### 3) Subscribers receive an automated, verification email.
<img src="Project Images/3.png">

### 4) Clicking the verification link confirms the user and updates their status in Amazon Aurora DSQL.
<img src="Project Images/4.png">

### 5) If a user attempts to verify using an expired link, a clear expiration notice is shown.
<img src="Project Images/5.png">

### 6) If an active subscriber attempts to register again, the application notifies them of their current subscription.
<img src="Project Images/6.png">

### 7) If an unverified user was purged from the database during scheduled cleanup and clicks their link later, they receive this alert.
<img src="Project Images/7.png">

### 8) Subscribers receive scheduled newsletter emails featuring curated astronomy facts and an unsubscribe option.
<img src="Project Images/8.png">

### 9) Users can opt out at any time using the unsubscribe link included in every newsletter email.
<img src="Project Images/9.png">

### 10) Scheduled subscriber cleanup execution outputs and logs are tracked in Amazon CloudWatch Log Groups.
<img src="Project Images/10.png">

## Architecture Diagram
<img src="Project Images/diagram.jpg">

## Setup & Deployment Note
> Feel free to clone this repository and customize the template parameters according to your environment requirements. Run the included Jenkins **Deploy** or **Undeploy** pipelines to build or tear down the stack instantly.
