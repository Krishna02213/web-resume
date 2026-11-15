# Terraform — short practice notes

Terraform creates and manages infrastructure from `.tf` code. AWS CLI performs AWS operations through terminal commands; Terraform compares code, state, and AWS to calculate the required changes.

## Our projects

| Folder | What we practised |
| --- | --- |
| `../terraform-website/` | VPC, public subnet, internet gateway, route table, route association, security group, SSH key pair, and EC2. |
| `../terraform-s3/` | Creating buckets, replacing a bucket after a name change, loops, variables, and S3 remote state. |
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
