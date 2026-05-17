## Task: Centralized Audit Logging with VPC Peering
The Nautilus DevOps team needs to build a secure and scalable log aggregation setup within their AWS environment. The goal is to gather log files from an internal EC2 instance running in a private VPC, transfer them securely to another EC2 instance in a public VPC, and then push those logs to a secure S3 bucket.

1. A VPC named `nautilus-priv-vpc` already exists with a private subnet named `nautilus-priv-subnet`, a route table named `nautilus-priv-rt`, and an EC2 instance named `nautilus-priv-ec2` (using `ubuntu` image). This instance uses the SSH key pair `nautilus-key.pem` already available on the AWS client host at `/root/.ssh/`.
2. Your task is to:
    - Create a new VPC named `nautilus-pub-vpc`.
    - Create a subnet named `nautilus-pub-subnet` and a route table named `nautilus-pub-rt` under this public VPC.
    - Attach an internet gateway to `nautilus-pub-vpc` and configure the public route table to enable internet access.
    - Launch an EC2 instance named `nautilus-pub-ec2` into the public subnet using the same key pair as the private instance.
    - Create an IAM role named `nautilus-s3-role` with `PutObject` permission to an S3 bucket and attach it to the public EC2 instance.
    - Create a new private S3 bucket named `nautilus-s3-logs-27334`.
    - Configure a VPC Peering named `nautilus-vpc-peering` between the private and public VPCs.
    - Modify both `nautilus-priv-rt` and `nautilus-pub-rt` to route each other's CIDR blocks through the peering connection.
    - On the private instance, configure a cron job to push the `/var/log/boots.log` file to the public instance (using `scp` or `rsync`).
    - On the public instance, configure a cron job to push that same file to the created S3 bucket.
    - The uploaded file must be stored in the S3 bucket under the path `nautilus-priv-vpc/boot/boots.log`.

---