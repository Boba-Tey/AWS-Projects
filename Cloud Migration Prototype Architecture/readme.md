# 🏗️ Cloud Migration Prototype Architecture Using CloudFormation
This prototype was developed to accelerate our ongoing cloud migration initiative. It demonstrates automated and repeatable infrastructure deployment on AWS using CloudFormation.

The template provisions a foundational, highly-available, and secure network infrastructure:
- **VPC & Availability:** A Virtual Private Cloud (VPC) spanning two Availability Zones (AZs), each AZ includes dedicated Public and Private Subnets.
  
- **Internet Egress:** An Internet Gateway (IGW) provides direct internet access to the Public Subnets. Two redundant NAT Gateways (one per Public Subnet) ensures the Private Subnets have secure, outbound-only internet connectivity for updates, patching, and repository access.
  
- **High Availability & Scaling:**
  - **Application Load Balancers (ALBs)** are deployed in both the Public and Private tiers to evenly distribute traffic.
  - **Auto Scaling Groups (ASGs)** manage the desired instance count and automatically handles scaling and health checks for the Public and Private tiers.
    
- **Project Value:** This solution showcases the speed, repeatability, and seamless deployment of complex, production-ready cloud infrastructure using an Infrastructure-as-Code (IaC) approach.

# Project Diagram:
![diagram](https://github.com/user-attachments/assets/0c9caf1f-75d4-48d3-a137-5cd7d6ba7912)
