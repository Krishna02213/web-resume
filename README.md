# Website and AWS practice

| Folder | Purpose |
| --- | --- |
| `docker/` | Website source, Dockerfile, Nginx configuration, Compose, and Docker study notes. |
| `terraform/README.md` | Terraform study notes, including S3 and load balancing exercises. |
| `terraform-autoscaling/` | Current lab: seed EC2, Docker deployment, AMI, launch template, ALB, Auto Scaling group, and request/CPU scaling policies. |
| `terraform-loadbalancer/` | Terraform code and local state for the retained two-subnet lab network. The EC2 instances were terminated; `instances = {}` keeps them absent. |
| `terraform-website/` | Terraform code and local state for the earlier lab network. Its EC2 instance was previously terminated. Review `terraform plan` before applying this older exercise. |
| `.github/workflows/deploy.yml` | Builds the Docker image and tests Nginx and website files. Deployment to the terminated server was removed. |

## Auto Scaling lab

Flow: visitor → Application Load Balancer → target group → EC2 instances in the
Auto Scaling group → Docker container running Nginx and the website.

Terraform creates the network and a seed EC2 instance, installs Docker, copies
`docker/`, and builds and starts `portfolio:1.0`. It captures that server as an
AMI. A launch template uses the AMI to start matching website servers. The seed
server is separate from the scaling group.

- Group size: minimum 1, initially 1, maximum 3.
- Website port 80 accepts traffic only from the ALB security group.
- SSH accepts connections only from `ssh_cidr` in `terraform.tfvars`.
- Request test: target 100 requests per target per minute; sustained traffic
  caused automatic scaling from 1 to 3 healthy servers.
- CPU test: target 20% average group CPU; a temporary one-CPU Docker workload
  produced about 50% EC2 CPU and caused scaling from 1 to 3 healthy servers.
- The test container was stopped. The CPU policy remains enabled; the request
  policy is disabled so the tests are separate.
- Detailed monitoring supplies one-minute CPU metrics. With low load, the group
  subsequently returned to 1 instance.

From `terraform-autoscaling/`, use `terraform init`, `terraform validate`,
`terraform plan`, then `terraform apply` after reviewing the plan. Use
`terraform output` for the ALB URL. These commands change AWS resources and can
incur charges. State, saved plans, and private keys are excluded from Git.

## Earlier lab cleanup

The earlier two-server lab's EC2 servers and load balancer were deleted. Their Docker images,
container data, and server website files remain on these retained EBS disks:

- Server 1: `vol-09affd19585c9d8d7`
- Server 2: `vol-07e7c62db33265c1b`

These disks still incur storage charges. The local website files remain in `docker/`.

Keep the local `terraform.tfstate` files: they track networks that still exist.
Provider caches and old saved plans were removed. Run `terraform init` inside a
Terraform project before using it again.

The completed S3 exercise and cleanup backups are archived outside this workspace:

`/Users/Ayush/.local/share/web-resume-backups/workspace-cleanup-20261118-142720/`
