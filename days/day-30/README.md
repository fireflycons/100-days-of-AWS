## Task: Enable Internet Access for Private EC2 using NAT Instance
The Nautilus DevOps team is tasked with enabling internet access for an EC2 instance running in a private subnet. This instance should be able to upload a test file to a public S3 bucket once it can access the internet. To minimize costs, the team has decided to use a NAT Instance instead of a NAT Gateway.

The following components already exist in the environment:
1. A VPC named `xfusion-priv-vpc` and a private subnet named `xfusion-priv-subnet` have been created.
2. An EC2 instance named `xfusion-priv-ec2` is already running in the private subnet.
3. The EC2 instance is configured with a cron job that uploads a test file to the S3 bucket `xfusion-nat-31533` every minute. Upload will only succeed once internet access is established.

Your task is to:
- Create a new public subnet named `xfusion-pub-subnet` in the existing VPC.
- Launch a NAT Instance in the public subnet using an Amazon Linux 2023 AMI and name it `xfusion-nat-instance`. Configure this instance to act as a NAT instance. Make sure to use a custom security group for this instance.

After the configuration, verify that the test file `xfusion-test.txt` appears in the S3 bucket `xfusion-nat-31533`. This indicates successful internet access from the private EC2 instance via the NAT Instance.

**Note**: `iptables` is not installed by default on `Amazon Linux 2023`. You will need to install and enable it before configuring NAT setup.

---