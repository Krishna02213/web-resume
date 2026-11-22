# Website and AWS practice

| Folder | Purpose |
| --- | --- |
| `docker/` | Website source, Dockerfile, Nginx configuration, Compose, and Docker study notes. |
| `terraform/README.md` | Terraform study notes, including S3 and load balancing exercises. |
| `terraform-autoscaling/` | Current lab: seed EC2, Docker deployment, AMI, launch template, ALB, Auto Scaling group, and request/CPU scaling policies. |
| `terraform-loadbalancer/` | Earlier two-subnet lab code; all its AWS resources were destroyed. |
| `terraform-website/` | Earlier single-server lab code; all its AWS resources were destroyed. Review the plan before reusing it. |
| `.github/workflows/deploy.yml` | Builds the Docker image and tests Nginx and website files. Deployment to the terminated server was removed. |

## Auto Scaling lab

Flow: visitor → Application Load Balancer → target group → EC2 instances in the
Auto Scaling group → Docker container running Nginx and the website.

Terraform creates the network and a seed EC2 instance, installs Docker, copies
`docker/`, and builds and starts `portfolio:1.0`. It captures that server as an
AMI. A launch template uses the AMI to start matching website servers. The seed
server is separate from the scaling group and Terraform stops it after the AMI is ready. Its disk and the AMI snapshot still use storage.

- Group size: minimum 1, initially 1, maximum 3.
- Website port 80 accepts traffic only from the ALB security group.
- SSH accepts connections only from `ssh_cidr` in `terraform.tfvars`.
- Both target-tracking policies are enabled: 100 requests per server per minute
  and 50% average CPU across the group.
- Either policy can add servers; both must agree before servers are removed.
  The group stays between 1 and 3 servers. Scaling takes time; 100 requests is
  a target rate, not a total request counter or a hard traffic limit.
- Detailed monitoring supplies one-minute CPU metrics.
- Change the instance type, SSH IP, server limits, and policy targets together
  in `terraform-autoscaling/terraform.tfvars`.

Deployment steps:

1. `terraform init` downloads the AWS provider.
2. `terraform validate` checks the configuration.
3. `terraform plan -out=deploy-website.tfplan` previews and saves the changes.
4. `terraform apply deploy-website.tfplan` creates the network, deploys Docker
   on the seed server, captures an AMI, and creates the ALB, group, and policies.
5. `terraform output -raw website_url` prints the public website address.
6. `terraform destroy` removes this lab when practice is finished.

From `terraform-autoscaling/`, use `terraform init`, `terraform validate`,
`terraform plan`, then `terraform apply` after reviewing the plan. Use
`terraform output` for the ALB URL. These commands change AWS resources and can
incur charges. State, saved plans, and private keys are excluded from Git.

## Earlier lab cleanup

On November 20, the earlier lab networks, instances, retained EBS disks,
AMIs, snapshots, and load balancers were destroyed. Their Terraform code remains
for study. The website source is still in `docker/`.

Keep Terraform state files locally. They track resources created by the current
lab. Provider caches, state, saved plans, and private keys are excluded from Git.

The completed S3 exercise and cleanup backups are archived outside this workspace:

`/Users/Ayush/.local/share/web-resume-backups/workspace-cleanup-20261118-142720/`
