# Terraform — short practice notes

Terraform creates and manages infrastructure from `.tf` code. AWS CLI performs AWS operations through terminal commands; Terraform compares code, state, and AWS to calculate the required changes.

## Our projects

| Folder | What we practised |
| --- | --- |
| `../terraform-website/` | VPC, public subnet, internet gateway, route table, route association, security group, SSH key pair, and EC2. |
| `../terraform-s3/` | Creating buckets, replacing a bucket after a name change, loops, variables, and S3 remote state. |
| `../terraform-loadbalancer/` | Two EC2 instances using `for_each`, Docker websites, an Application Load Balancer, and traffic testing. |
| This folder | Study notes only; run Terraform from the relevant project folder. |

Each project has its own state. Terraform reads all `.tf` files in the current project together; filenames organize the code.

## Files and their meaning

| File | Contents |
| --- | --- |
| `version.tf` | Terraform version, provider requirements, and our S3 backend configuration. |
| `provider.tf` | AWS region and authentication profile. |
| `main.tf` | Resources to create and their settings. |
| `variable.tf` or `variables.tf` | Input definitions: `type`, `description`, and optional `default`. |
| `terraform.tfvars` | Optional values that override variable defaults; our S3 project currently uses defaults instead. |
| `terraform.tfstate` | Terraform's resource records when using local state; never edit manually or commit to Git. |
| `terraform.tfstate.backup` | A previous local state snapshot; not the current remote state. |
| `.terraform.lock.hcl` | Exact provider selection and checksums; commit this file. |
| `.terraform/` | Downloaded providers and backend metadata; exclude from Git. |

Our AWS region is `ap-south-1` (Mumbai), and our local AWS profile is `portfolio`. `~> 6.0` permits AWS provider versions in the 6.x series.

## Basic commands

Run inside the project folder:

| Command | Meaning |
| --- | --- |
| `terraform init` | Prepares the backend and installs providers. |
| `terraform fmt` | Formats `.tf` code. |
| `terraform validate` | Checks configuration; does not deploy or prove AWS permissions. |
| `terraform plan` | Previews changes without applying them. |
| `terraform plan -out=practice.tfplan` | Saves a specific plan; keep plan files out of Git. |
| `terraform apply` | Builds a fresh plan and asks for approval before changing AWS. |
| `terraform apply practice.tfplan` | Executes the saved plan without another approval prompt. |
| `terraform state list` | Lists resources recorded in the selected state. |
| `terraform output` | Shows outputs such as an EC2 public IP. |
| `terraform destroy` | Proposes deleting all managed resources in this project's state; review before typing `yes`. |

Plan symbols: `+` create, `~` update, `-` delete, `-/+` delete and create a replacement. `known after apply` means AWS will provide the value later.

## S3: name changes and loops

Changing an S3 bucket name requires replacement. Terraform does not transfer objects to the replacement bucket. We kept practice buckets empty; with `force_destroy = false`, deletion of a non-empty bucket fails.

We first used `count = 3` and `count.index` to generate names ending in `0`, `1`, and `2`. We then switched to individually chosen names:

```hcl
variable "bucket_names" {
  type    = list(string)
  default = ["your-unique-bucket-a", "your-unique-bucket-b"]
}

resource "aws_s3_bucket" "practice" {
  for_each = { for name in var.bucket_names : name => name }
  bucket   = each.value
}
```

The `for` expression builds a map, and `for_each` creates one bucket per name. Add a name to create another bucket; remove a name to propose deleting that bucket. Names must be unique across AWS accounts in the shared S3 namespace, not just within the list. Our variable validation rejects duplicate list entries.

Switching from `count` to `for_each` changes Terraform resource addresses. Use `moved` blocks when preserving existing buckets; otherwise the plan may propose replacements. Always inspect the plan first.

## EC2 network and connection

Our website project created eight resources. The subnet's route table sends internet traffic (`0.0.0.0/0`) to the internet gateway. The EC2 instance needs a public IP, an SSH key, and security-group permission for SSH to be reachable.

```bash
ssh -i ~/.ssh/id_ed25519_portfolio_ec2 ubuntu@EC2_PUBLIC_IP
```

Restrict SSH port 22 to the required sources. HTTP port 80 serves the website. Terraform provisions the infrastructure; Docker runs the website on that infrastructure.

## State stored in S3

Our S3 project's backend is in `terraform-s3/version.tf`:

```hcl
terraform {
  backend "s3" {
    bucket       = "terraform-state-bucket-manual"
    key          = "terraform-s3/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
  }
}
```

The manually created bucket stores state. Versioning retains earlier versions; `use_lockfile` prevents competing Terraform operations. Protect state because it can contain sensitive values.

```bash
terraform init -migrate-state
terraform state list
```

Migration copies existing state after approval; it does not redeploy resources. Each project needs a different `key`, such as `terraform-website/terraform.tfstate`. Only the S3 project's migration has been confirmed so far. Do not delete the state bucket while projects depend on it.

## Login and the credential issue we encountered

```bash
aws login --profile portfolio
aws sts get-caller-identity --profile portfolio
```

Console sign-in and local CLI credentials are separate. When our S3 backend could not read browser-login credentials, we exported temporary credentials in the same terminal:

```bash
eval "$(aws configure export-credentials --profile portfolio --format env)"
```

For this workaround, we removed `profile` from the **backend**, which otherwise took priority over environment credentials. We kept `profile = "portfolio"` in the **AWS provider**. Exported credentials expire; refresh them when necessary, and never print or commit secrets.

## Two EC2 websites behind a load balancer

**Goal:** create all AWS infrastructure with Terraform, run the website with Docker on both servers, and access it through one load balancer address.

```text
Visitor → Application Load Balancer → Server 1 or Server 2 → Nginx container
```

### 1. Organize the Terraform files

Inside `terraform-loadbalancer/`:

| File | What we put there |
| --- | --- |
| `provider.tf` | Terraform/provider requirements, Mumbai region, and `portfolio` profile. |
| `variables.tf` | Defines `instances` as a map containing each server's type and subnet choice. |
| `terraform.tfvars` | Holds both servers' actual values in one place. |
| `main.tf` | Network, security rules, EC2 instances, load balancer, and outputs. |

Our `terraform.tfvars`:

```hcl
instances = {
  "website-server-1" = {
    instance_type = "t3.micro"
    subnet        = "a"
  }
  "website-server-2" = {
    instance_type = "t3.micro"
    subnet        = "b"
  }
}
```

The EC2 resource uses `for_each = var.instances`. `each.key` gives the server name; `each.value.instance_type` gives its type. The subnet choice `a` or `b` maps to the corresponding subnet ID. This creates both servers without duplicating the resource block.

### 2. Define the infrastructure

Our plan created **17 resources**:

| Resource | Number | Simple meaning |
| --- | ---: | --- |
| VPC | 1 | Our network: `10.20.0.0/16`. |
| Public subnets | 2 | Separate network sections in `ap-south-1a` and `ap-south-1b`. |
| Internet gateway | 1 | Connects the VPC to the internet. |
| Route table | 1 | Routes `0.0.0.0/0` through the internet gateway. |
| Route associations | 2 | Applies the route table to both subnets. |
| Security groups | 2 | Firewall rules for the load balancer and servers. |
| SSH key pair | 1 | Registers our existing public key for server login. |
| EC2 instances | 2 | Ubuntu servers, one in each subnet. |
| Application Load Balancer (ALB) | 1 | Receives visitors' requests and distributes them. |
| Target group | 1 | Groups the servers and checks their websites. |
| Target attachments | 2 | Registers both servers using `for_each`. |
| HTTP listener | 1 | Listens on port 80 and forwards requests to the target group. |

The ALB allows public HTTP traffic on port 80. The servers allow HTTP only from the ALB security group and SSH on port 22 only from our current public IP (`/32` means one IP).

Each server has an encrypted 8 GB gp3 root disk, deleted on termination. Its `user_data` startup script installs and starts Docker. `depends_on` makes the servers wait for internet routing to exist. This script installs Docker; it does **not** copy or run our website.

### 3. Create the infrastructure

Run these on the **Mac**, inside `terraform-loadbalancer/`:

```bash
terraform init
terraform validate
terraform plan
terraform apply
terraform output
```

We reviewed `17 to add, 0 to change, 0 to destroy`, then approved `apply` with `yes`. Outputs gave both public IPs and the website URL. The ALB provides a **DNS address**, not a fixed IP to use in the browser.

### 4. Deploy the website on each server

Repeat these steps for **both** servers. Replace `SERVER_IP` with the relevant public IP from `terraform output`.

On the **Mac** (prompt starts with `Ayush@`), upload the website and connect:

```bash
scp -i ~/.ssh/id_ed25519_portfolio_ec2 -r /Users/Ayush/Desktop/WEB_RESUME/docker ubuntu@SERVER_IP:/home/ubuntu/portfolio
ssh -i ~/.ssh/id_ed25519_portfolio_ec2 ubuntu@SERVER_IP
```

This copy command assumes `~/portfolio` does not already exist, as in our first upload. `scp` transfers local files; `ssh` opens a remote terminal.

On **EC2** (prompt starts with `ubuntu@`):

```bash
sudo cloud-init status --wait
sudo docker --version
cd ~/portfolio
sudo docker build -t portfolio:1.0 .
sudo docker run -d --name portfolio --restart unless-stopped -p 80:80 portfolio:1.0
curl -I http://localhost
```

`cloud-init` waits for startup setup. `build` packages the website. `run` starts Nginx in a container. We received `200 OK` on each server. `localhost` here means that EC2 server, not the Mac.

Terraform created the infrastructure; these SSH commands deployed the application. Our existing GitHub Actions workflow still targets the earlier single server; we did not convert it to deploy to this pair.

### 5. Fix the SSH timeout we encountered

Our Mac's public IP changed, so its new connections no longer matched the SSH rule. On the Mac we checked:

```bash
curl https://checkip.amazonaws.com
```

We changed the SSH rule's CIDR in `main.tf` to the new IP followed by `/32`, then ran `terraform plan` and `terraform apply`. The result was **0 added, 1 changed, 0 destroyed**: only the security group changed.

A `Broken pipe` message means the SSH session disconnected; reconnect using `ssh`. It does not by itself mean the server or website stopped.

### 6. Test the load balancer

We opened the `website_url` output with `http://` and saw the website. In the AWS Console, **EC2 → Target Groups → website-targets → Targets** showed **2 Healthy, 0 Unhealthy**. The health check requests `/` on port 80 and expects HTTP `200`.

To see which server answered, we created a test file inside each running container:

```bash
# Run on server 1:
sudo docker exec portfolio sh -c 'echo "Server 1" > /usr/share/nginx/html/server.txt'

# Run on server 2:
sudo docker exec portfolio sh -c 'echo "Server 2" > /usr/share/nginx/html/server.txt'
```

On the **Mac**, we sent ten requests through the ALB:

```bash
for i in {1..10}; do
  curl -fsS --max-time 10 http://website-alb-119868455.ap-south-1.elb.amazonaws.com/server.txt
done
```

We saw both `Server 1` and `Server 2`, confirming traffic reached both servers. Responses do not have to alternate exactly. This tested distribution; we have not tested a server failure. The test files exist only in those containers and disappear when the containers are replaced.

### Cleanup when the exercise is finished

The EC2 instances, disks, public IPv4 addresses, and ALB can incur charges. When ready, run `terraform destroy` from **terraform-loadbalancer/** and review its deletion plan before approving. This deployment has **not** been destroyed as part of these notes.
