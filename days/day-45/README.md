## Task: CI/CD Automation Using AWS CodePipeline
The Nautilus DevOps team is responsible for managing and deploying applications efficiently. They want to streamline their CI/CD process using AWS CodePipeline and AWS S3. Your task is to set up a CI/CD pipeline that automates the deployment of a sample web application on an S3 bucket configured as a static website.

For this task, perform the following steps:
1. There is a bucket named `datacenter-source-21170` which contains a static website source code. Create a new S3 bucket named `datacenter-deployment-31991`. Configure the bucket to serve static website content and ensure the bucket is publicly accessible.
2. Create an AWS CodePipeline named `datacenter-webapp-pipeline` with the following stages:
    - **Source**: Source Provider - AWS S3, Bucket Name - `datacenter-source-21170`.
    - **Build**: Build Provider - AWS CodeBuild, Project Name - `datacenter-build-project`, Environment - Managed image, `aws/codebuild/amazonlinux2-x86_64-standard:4.0`, Linux, and set the Image version to `Always use the latest image` for this runtime version. Insert the necessary build commands in the Build commands section to directly upload the `index.html` file to the S3 bucket.

**Expected Outcome:**
When any changes made to the file `index.html` in `datacenter-source-21170` bucket, the pipeline should automatically build the project using the inserted build commands and deploy the `index.html` file to the `datacenter-deployment-31991` bucket. The S3 bucket should be configured to allow public access, and the website should be accessible via the S3 static website URL.

---