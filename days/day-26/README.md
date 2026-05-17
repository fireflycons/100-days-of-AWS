## Task: Configuring an EC2 Instance as a Web Server with Nginx
The Nautilus DevOps Team is working on setting up a new web server for a critical application. The team lead has requested you to create an EC2 instance that will serve as a web server using Nginx. This instance will be part of the initial infrastructure setup for the Nautilus project. Ensuring that the server is correctly configured and accessible from the internet is crucial for the upcoming deployment phase.

As a member of the Nautilus DevOps Team, your task is to create an EC2 instance with the following specifications:

1. **Instance Name**: The EC2 instance must be named `devops-ec2`.
2. **AMI**: Use any available `Ubuntu AMI` to create this instance.
3. **User Data Script**: Configure the instance to run a user data script during its launch. This script should:
    - Install the `Nginx` package.
    - Start the `Nginx` service.
4. **Security Group**: Ensure that the instance allows `HTTP traffic` on port `80` from the internet.

---