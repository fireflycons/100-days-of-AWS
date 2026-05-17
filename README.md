# KodeKloud 100 Days of Cloud - AWS (using terraform)

This repo contains terraform solutions to all the tasks where infrastructure needs to be deployed. It does *not* contain solutions to additional tasks that might be required after the infrastructure is deployed, if those tasks cannot be done from terraform.

Where days are missing are for those tasks that either cannot be done using terraform, or the question states to use the CLI for all tasks.

For complete solutions you can refer to other peoples repos such as https://github.com/Srikanth0824/kodekloud-engineer/tree/main/100_Days_of_Cloud-AWS

## Install terraform on the lab terminal

For each lab, paste and run these commands into the lab terminal to set up terraform.

```bash
curl -Lo terraform.zip https://releases.hashicorp.com/terraform/1.15.2/terraform_1.15.2_linux_amd64.zip
unzip terraform.zip
mv terraform /usr/local/bin/
```


## Solutions

- [Day 01](days/day-01/) - Create Key Pair
- [Day 02](days/day-02/) - Create Security Group
- [Day 03](days/day-03/) - Create Subnet
- [Day 04](days/day-04/) - Enable Bucket Versioning
- [Day 05](days/day-05/) - Create GP3 Volume
- [Day 06](days/day-06/) - Launch EC2 Instance
- [Day 10](days/day-10/) - Attach Elastic IP to EC2 Instance
- [Day 11](days/day-11/) - Attach Elastic Network Interface to EC2 Instance
- [Day 12](days/day-12/) - Attach Volume to EC2 Instance
- [Day 13](days/day-13/) - Creating an AMI from an Existing EC2 Instance
- [Day 15](days/day-15/) - Create Volume Snapshot
- [Day 16](days/day-16/) - Creating an IAM User
- [Day 17](days/day-17/) - Create IAM Group
- [Day 18](days/day-18/) - Create Read-Only IAM Policy for EC2 Console Access
- [Day 19](days/day-19/) - Attach IAM Policy to IAM User
- [Day 20](days/day-20/) - Create IAM Role for EC2 with Policy Attachment
- [Day 21](days/day-21/) - Setting Up an EC2 Instance with an Elastic IP for Application Hosting
- [Day 22](days/day-22/) - Configuring Secure SSH Access to an EC2 Instance
- [Day 24](days/day-24/) - Setting Up an Application Load Balancer for an EC2 Instance
- [Day 25](days/day-25/) - Setting Up an EC2 Instance and CloudWatch Alarm
- [Day 26](days/day-26/) - Configuring an EC2 Instance as a Web Server with Nginx
- [Day 27](days/day-27/) - Configuring a Public VPC with an EC2 Instance for Internet Access
- [Day 28](days/day-28/) - Creating a Private ECR Repository
- [Day 29](days/day-29/) - Establishing Secure Communication Between Public and Private VPCs via VPC Peering
- [Day 30](days/day-30/) - Enable Internet Access for Private EC2 using NAT Instance
- [Day 31](days/day-31/) - Configuring a Private RDS Instance for Application Development
- [Day 32](days/day-32/) - Snapshot and Restoration of an RDS Instance
- [Day 33](days/day-33/) - Create a Lambda Function
- [Day 35](days/day-35/) - Deploying and Managing Applications on AWS
- [Day 37](days/day-37/) - Managing EC2 Access with S3 Role-based Permissions
- [Day 38](days/day-38/) - Deploying Containerized Applications with Amazon ECS
- [Day 39](days/day-39/) - Hosting a Static Website on AWS S3
- [Day 41](days/day-41/) - Securing Data with AWS KMS
- [Day 42](days/day-42/) - Building and Managing NoSQL Databases with AWS DynamoDB
- [Day 43](days/day-43/) - Scaling and Managing Kubernetes Clusters with Amazon EKS
- [Day 45](days/day-45/) - Enable Internet Access for Private EC2 using NAT Gateway
- [Day 46](days/day-46/) - Event-Driven Processing with Amazon S3 and Lambda
- [Day 47](days/day-47/) - Integrating AWS SQS and SNS for Reliable Messaging
- [Day 48](days/day-48/) - Automating Infrastructure Deployment with AWS CloudFormation
- [Day 49](days/day-49/) - Centralized Audit Logging with VPC Peering

