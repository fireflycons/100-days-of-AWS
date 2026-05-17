## Task: Automating Infrastructure Deployment with AWS CloudFormation

The Nautilus DevOps team needs to implement a Lambda function using a CloudFormation stack. Create a CloudFormation template named `/root/nautilus-lambda.yml` on the AWS client host and configure it to create the following components. The stack name must be `nautilus-lambda-app`.
1. Create a Lambda function named `nautilus-lambda`.
2. Use the Runtime `Python`.
3. The function should print the body `Welcome to KKE AWS Labs!`.
4. Ensure the status code is `200`.
5. Create and use the IAM role named `lambda_execution_role`.

---