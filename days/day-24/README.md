## Task: Setting Up an Application Load Balancer for an EC2 Instance
The Nautilus DevOps team is currently working on setting up a simple application on the AWS cloud. They aim to establish an Application Load Balancer (ALB) in front of an EC2 instance where an Nginx server is currently running. While the Nginx server currently serves a sample page, the team plans to deploy the actual application later.

1. Set up an Application Load Balancer named `xfusion-alb`.
2. Create a target group named `xfusion-tg`.
3. Create a security group named `xfusion-sg` to open port `80` for the public.
4. Attach this security group to the ALB.
5. The ALB should route traffic on port `80` to port `80` of the `xfusion-ec2` instance.
6. Make appropriate changes in the default security group attached to the EC2 instance if necessary.

---