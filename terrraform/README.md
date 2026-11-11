# Portfolio EC2 with Terraform

Creates one **new** Ubuntu 24.04 `t3.micro` in the existing Mumbai network. The original EC2 instance is separate and remains running. This configuration reuses the original VPC, subnet, security group, and SSH key pair through data sources; it does not import or manage those resources.

Matches the original server's pinned Canonical AMI, encrypted 8 GiB gp3 disk, public IP assignment, standard CPU credits, and required IMDSv2 with a hop limit of 2. The subnet determines availability zone `ap-south-1a`. No software installation or website deployment is included yet.

## Files

- `main.tf`: local backend, existing-resource lookups, EC2 instance, and outputs.
- `provider.tf`: Terraform/provider requirements and AWS provider configuration.
- `variables.tf`: input variable definitions and validation.
- `terraform.tfvars`: values for this deployment; edit these to change settings.
- `.terraform.lock.hcl`: generated provider version and checksum lock file; keep it in version control.

## Local state

State is local, not remote: `terraform.tfstate` is written inside this folder when Terraform applies changes. No S3 bucket, DynamoDB table, or Terraform Cloud is used. Keep this state and its backups private and backed up; Terraform needs it to track the new instance. State, downloaded providers, and plan files are ignored by Git. Credentials and private key contents are not stored in the Terraform files.

## Initialize and review

With Terraform installed and the `portfolio` AWS profile authenticated:

```sh
cd /Users/Ayush/Desktop/WEB_RESUME/terrraform
terraform init
terraform fmt -check
terraform validate
terraform plan -out=portfolio.tfplan
```

The plan should contain **1 to add, 0 to change, 0 to destroy**. Review it before applying. The new instance, EBS storage, and public IPv4 can incur charges alongside the existing server.

## Create when ready

```sh
terraform apply portfolio.tfplan
terraform output
```

Use the displayed `ssh_command` to connect. The existing shared security group permits SSH from `49.36.24.81/32`; if your public IP changes, its SSH rule needs updating separately. HTTP port 80 is allowed, but a web server must be deployed before a website responds.

## Remove the Terraform instance when finished

```sh
terraform plan -destroy
terraform destroy
```

Review the destruction prompt. Only the Terraform-managed instance and its attached root disk are removed. The original instance, shared network, security group, and SSH key pair are outside this configuration's ownership.
