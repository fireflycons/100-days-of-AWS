## Task: Managing EC2 Access with S3 Role-based Permissions
The Nautilus DevOps team needs to set up an application on an EC2 instance to interact with an S3 bucket for storing and retrieving data. To achieve this, the team must create a private S3 bucket, set appropriate IAM policies and roles, and test the application functionality.

**Task:**
1. **EC2 Instance Setup:**
    - An instance named `datacenter-ec2` already exists.
    - The instance requires access to an S3 bucket.
2. **Setup SSH Keys:**
    - Create new SSH key pair (`id_rsa` and `id_rsa.pub`) on the `aws-client` host and add the public key to the `root` user's authorized keys on the EC2 instance.
3. **Create a Private S3 Bucket:**
    - Name the bucket `datacenter-s3-13685`.
    - Ensure the bucket is private.
4. **Create an IAM Policy and Role:**
    - Create an IAM policy allowing `s3:PutObject`, `s3:ListBucket` and `s3:GetObject` access to `datacenter-s3-13685`.
    - Create an IAM role named `datacenter-role`.
    - Attach the policy to the IAM role.
    - Attach this role to the `datacenter-ec2` instance.
5. **Test the Access:**
    - SSH into the EC2 instance and try to upload a file to `datacenter-s3-13685` bucket using following command:
      `aws s3 cp <your-file> s3://datacenter-s3-13685/`
    - Now run following command to list the upload file:
      `aws s3 ls s3://datacenter-s3-13685/`

---

1. Deploy infrastructure with terraform.
1. When deployment is complete, the public key required for the EC2 instance will be output.
1. Refer to [this](https://github.com/Srikanth0824/kodekloud-engineer/blob/main/100_Days_of_Cloud-AWS/Day37.md) for remaining steps.
