## Task: Creating a Private ECR Repository
The Nautilus DevOps team has been tasked with setting up a containerized application. They need to create a private Amazon Elastic Container Registry (ECR) repository to store their Docker images. Once the repository is created, they will build a Docker image from a Dockerfile located on the `aws-client` host and push this image to the ECR repository. This process is essential for maintaining and deploying containerized applications in a streamlined manner.

Create a private ECR repository named `xfusion-ecr`. There is a Dockerfile under `/root/pyapp` directory on `aws-client` host, build a docker image using this Dockerfile and push the same to the newly created ECR repo, the image tag must be `latest`.

---

1. Deploy infra with terraform.
1. For remaining steps, refer to [this](https://github.com/Srikanth0824/kodekloud-engineer/blob/main/100_Days_of_Cloud-AWS/Day28.md), picking up at "Capture your AWS account ID and region"

