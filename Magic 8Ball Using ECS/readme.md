# Read The Project Documentation Here: 
 https://www.notion.so/Magic-8-ball-Website-using-ECS-249c24350322803ba101c88609c19d1c?source=copy_link

# Setup
```bash
#!/bin/bash
set -e

ACCOUNT_ID=ID
REGION=ap-south-1
```

# Step 1: Create a private ECR repo and push your Docker image to ECR
```bash
aws ecr create-repository --repository-name magic-8ball-website 
echo "Repo created!"

aws ecr get-login-password --region $REGION | \
    docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

docker tag magic-8ball-website:latest $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/magic-8ball-website:latest
docker push $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/magic-8ball-website:latest
echo "Docker image pushed to ECR"
```

# Step 2: Create the Task definiton
```bash
aws ecs register-task-definition --cli-input-json file://task-definition.json
echo "Task definition created"
```

# Step 3: Create an Instance Profile and attach your role
```bash
aws iam create-instance-profile --instance-profile-name ecs-instance-profile

aws iam add-role-to-instance-profile \
    --instance-profile-name ecs-instance-profile \
    --role-name ecs-instance-role
echo "Created and added ecs-instance-role to instance profile"
```

# Step 4: Create an ECS Cluster
```bash
aws ecs create-cluster --cluster-name magic-8ball-cluster
echo "Cluster created"
```

# Step 5: Create a Launch Template
```bash
aws ec2 create-launch-template --cli-input-json file://launch-template.json
echo "Created launch template"
```

# Step 6: Create an ASG and attach the launch template to it
```bash
aws autoscaling create-auto-scaling-group \
    --auto-scaling-group-name ecs-asg \
    --launch-template "LaunchTemplateName=ecs-launch-template,Version=\$Latest" \
    --min-size 1 \
    --max-size 2 \
    --desired-capacity 1 \
    --default-instance-warmup 300 \
    --new-instances-protected-from-scale-in \
    --vpc-zone-identifier subnet-0d26e94749efb964b,subnet-01a9065da4fefb7e3,subnet-05531fbe0e2788a3b
echo "Created ASG"
```

# Step 7: Create and attach a Capacity Provider
```bash
aws ecs create-capacity-provider --cli-input-json file://capacity-provider.json
echo "Created and attached capacity provider to ASG"
```

# Optional: to delete the Capacity Provider
```bash
aws ecs delete-capacity-provider --capacity-provider ec2-capacity-provider
echo "Deleted Capacity Provider"
```

# Step 8: Update ECS Cluster with the Capacity Provider
```bash
aws ecs put-cluster-capacity-providers \
  --cluster magic-8ball-cluster \
  --capacity-providers ec2-capacity-provider \
  --default-capacity-provider-strategy capacityProvider=ec2-capacity-provider,weight=1,base=0
echo "Attched Capacity Provider to ECS Cluster"
```

# Step 9: Create a Target Group
```bash
aws elbv2 create-target-group \
    --name http-target \
    --protocol HTTP \
    --port 80 \
    --target-type instance \
    --vpc-id vpc-02a7eebd4d3022a1a
echo "Created a Target Group for port 80"
```

# Step 10: Create an Application Load Balancer
```bash
aws elbv2 create-load-balancer \
    --name magic-8ball-alb \
    --subnets subnet-0d26e94749efb964b subnet-01a9065da4fefb7e3
echo "Created ALB"
```

# Step 11: Create a Listener
```bash
aws elbv2 create-listener \
    --load-balancer-arn ARN \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn=ARN
echo "Created a Listender on port 80"
```

# Step 12: Create a Service in the ecs cluster
```bash
aws ecs create-service \
    --cluster magic-8ball-cluster \
    --service-name magic-8ball-service \
    --capacity-provider-strategy capacityProvider=ec2-capacity-provider,weight=1,base=0 \
    --load-balancers '[{
        "targetGroupArn": "ARN",
        "containerName": "magic-8ball-container",
        "containerPort": 80
    }]' \
    --task-definition magic-8ball-task \
    --desired-count 1 \
    --role ecs-service-role
echo "Created new Service"

```

