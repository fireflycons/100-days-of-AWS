# 100 Days of Cloud - AWS (using terraform)

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
