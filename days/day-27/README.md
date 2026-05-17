## Task: Configuring a Public VPC with an EC2 Instance for Internet Access
The Nautilus DevOps Team has received a request from the Networking Team to set up a new public VPC to support a set of public-facing services. This VPC will host various resources that need to be accessible over the internet. As part of this setup, you need to ensure the VPC has public subnets with automatic IP assignment for resources. Additionally, a new EC2 instance will be launched within this VPC to host public applications that require SSH access. This setup will enable the Networking Team to deploy and manage public-facing applications.

Create a public VPC named `devops-pub-vpc`, and a subnet named `devops-pub-subnet` under the same, make sure public IP is being auto assigned to resources under this subnet. Further, create an EC2 instance named `devops-pub-ec2` under this VPC. Make sure SSH port `22` is open for this instance and accessible over the internet.

---