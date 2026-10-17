# Terraform Notes - Project File Structure and Best Practices

## Quick Answer

Terraform does **not** care how you name or split your files. It reads **all `.tf` files in a folder** and treats them as **one configuration**.

But putting everything into a single `main.tf` quickly becomes messy. So the industry follows a **standard file layout**, where each file has **one clear job**.

```text
One giant main.tf   ->   hard to read, hard to review, easy to break
Separate files      ->   readable, maintainable, team-friendly
Modules + envs      ->   reusable, scalable, production-ready
```

> File names are **conventions, not rules**. Terraform would work exactly the same if all blocks were in one file. Splitting is purely for humans.

---

# Part 1: The Standard File Layout (Beginner)

```text
project/
├── versions.tf               # Terraform + provider version requirements
├── providers.tf              # Provider configuration
├── backend.tf                # Where state is stored (e.g. S3)
├── variables.tf              # Input variable declarations
├── locals.tf                 # Local values (reduce repetition)
├── main.tf                   # Core resources
├── outputs.tf                # Output values
├── terraform.tfvars          # Variable values (DON'T commit if sensitive)
├── terraform.tfvars.example  # Safe template for teammates (commit this)
├── .terraform.lock.hcl       # Provider lock file (commit this)
└── .gitignore                # Keep secrets and junk out of Git
```

## Quick Reference Table

| File | What goes in it | Commit to Git? |
|---|---|---|
| `versions.tf` | `required_version`, `required_providers` | ✅ Yes |
| `providers.tf` | `provider "aws" { ... }` blocks | ✅ Yes |
| `backend.tf` | `backend "s3" { ... }` | ✅ Yes (no secrets inside) |
| `variables.tf` | `variable` blocks (declarations) | ✅ Yes |
| `locals.tf` | `locals { ... }` | ✅ Yes |
| `main.tf` | `resource`, `data`, `module` blocks | ✅ Yes |
| `outputs.tf` | `output` blocks | ✅ Yes |
| `terraform.tfvars` | Actual variable values | ❌ No, if it has secrets or personal values |
| `terraform.tfvars.example` | Dummy values as a template | ✅ Yes |
| `.terraform.lock.hcl` | Exact provider versions + checksums | ✅ Yes |
| `.gitignore` | Ignore rules | ✅ Yes |
| `.terraform/` | Downloaded providers/modules | ❌ No |
| `*.tfstate`, `*.tfstate.backup` | State (contains secrets) | ❌ Never |

---

## 1. `versions.tf` - Version Requirements

Pins the **Terraform CLI version** and **provider versions**, so everyone on the team uses compatible versions.

```hcl
terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
```

> `~> 6.0` means any **6.x** version, but not 7.0, which may have breaking changes.

---

## 2. `providers.tf` - Provider Configuration

Configures **how** to connect to each platform. Keeps `main.tf` clean.

```hcl
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}
```

> `default_tags` automatically adds the same tags to every AWS resource, so you don't repeat them in each resource block.

### Multiple regions/accounts (aliases)

```hcl
provider "aws" {
  alias  = "us_east"
  region = "us-east-1"
}
```

Used in a resource with `provider = aws.us_east`.

> **Never** put access keys in `providers.tf`. Use `AWS_PROFILE`, environment variables, or IAM roles.

### `versions.tf` vs `providers.tf`

| `versions.tf` | `providers.tf` |
|---|---|
| **Which** provider and **which version** to download | **How** to configure it (region, tags, alias) |
| Used by `terraform init` | Used by `plan` / `apply` |

> Some teams put both in one `providers.tf`. That's fine for small projects. Splitting them is cleaner as the project grows.

---

## 3. `backend.tf` - Remote State Storage

Tells Terraform **where to store the state file**.

```hcl
terraform {
  backend "s3" {
    bucket       = "ashish-terraform-state-2026"
    key          = "dev/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

> **Yes, you can have more than one `terraform {}` block** across files. Terraform merges them. But each setting (like `backend` or `required_providers`) should be defined only once.

### Backend rules to remember

- **No variables** in the backend block (`var.` won't work).
- **No credentials** inside it.
- After changing it, run `terraform init` again.
- For multiple environments, use a **partial backend** (`backend "s3" {}`) and pass values with `-backend-config` (see Part 3).

---

## 4. `variables.tf` - Input Declarations

Declares **what inputs exist**. Separates the "knobs" from the resource logic.

```hcl
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Deployment environment"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_name" {
  description = "Project name used in resource names"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}
```

### Good habits

- Always add `description` and `type`.
- Add `validation` for values with a fixed set of options.
- Mark secrets with `sensitive = true`.
- Keep variables **alphabetical** or **grouped by topic**, so they're easy to find.

---

## 5. `locals.tf` - Reduce Repetition

Locals are **internal helper values** computed once and reused everywhere.

```hcl
locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = "ashish"
  }
}
```

### Without locals (repetitive)

```hcl
resource "aws_s3_bucket" "logs" {
  bucket = "${var.project_name}-${var.environment}-logs"
  tags   = { Project = var.project_name, Environment = var.environment, ManagedBy = "Terraform" }
}

resource "aws_s3_bucket" "data" {
  bucket = "${var.project_name}-${var.environment}-data"
  tags   = { Project = var.project_name, Environment = var.environment, ManagedBy = "Terraform" }
}
```

### With locals (clean)

```hcl
resource "aws_s3_bucket" "logs" {
  bucket = "${local.name_prefix}-logs"
  tags   = local.common_tags
}

resource "aws_s3_bucket" "data" {
  bucket = "${local.name_prefix}-data"
  tags   = local.common_tags
}
```

> Change the naming pattern **once** in `locals.tf`, and every resource follows.

### Variable vs local

| `variable` | `local` |
|---|---|
| Input from **outside** (tfvars, CLI, env) | Computed **inside** the module |
| Can be overridden by the user | Cannot be overridden |
| `var.name` | `local.name` |

---

## 6. `main.tf` - Core Resources

The heart of the project: `resource`, `data`, and `module` blocks.

```hcl
resource "aws_s3_bucket" "data" {
  bucket = "${local.name_prefix}-data"
}

resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id

  versioning_configuration {
    status = "Enabled"
  }
}
```

### When `main.tf` gets too big: split by logical unit

```text
project/
├── network.tf     # VPC, subnets, route tables, NAT
├── security.tf    # Security groups, IAM roles and policies
├── compute.tf     # EC2, Auto Scaling, Lambda
├── storage.tf     # S3 buckets, EBS
├── database.tf    # RDS, DynamoDB
└── data.tf        # data sources
```

> Organise by **logical unit**, not one giant file. Someone looking for a security group knows to open `security.tf`.

---

## 7. `outputs.tf` - Output Values

```hcl
output "data_bucket_name" {
  description = "Name of the data bucket"
  value       = aws_s3_bucket.data.bucket
}

output "data_bucket_arn" {
  description = "ARN of the data bucket"
  value       = aws_s3_bucket.data.arn
}
```

Always add a `description`. Mark secrets with `sensitive = true`.

---

## 8. `terraform.tfvars` - Variable Values

```hcl
environment   = "dev"
project_name  = "ashish-data"
instance_type = "t3.micro"
```

- **Loaded automatically** by Terraform.
- ❌ **Don't commit** it if it contains secrets, account IDs, or personal values.
- ✅ Committing **non-sensitive** environment files (like `envs/dev.tfvars`) is common and fine. Pick one approach per project.

> Secrets (passwords, tokens) should never be in any tfvars file. Use `TF_VAR_` environment variables or a secrets manager such as AWS Secrets Manager.

---

## 9. `terraform.tfvars.example` - Template for Teammates

A **safe copy** with dummy values, committed to Git, so teammates know what to fill in.

```hcl
# Copy this file to terraform.tfvars and fill in your values.
# Do NOT put secrets here. Use TF_VAR_<name> environment variables for those.

environment   = "dev"             # dev | staging | prod
project_name  = "your-project"
instance_type = "t3.micro"
# db_password -> set via: export TF_VAR_db_password="..."
```

### How a teammate uses it

```bash
cp terraform.tfvars.example terraform.tfvars        # Linux/macOS
Copy-Item terraform.tfvars.example terraform.tfvars # PowerShell
# edit terraform.tfvars with real values
terraform init
terraform plan
```

> Terraform **ignores** `.example` files because they don't end in `.tfvars`, so the template never gets loaded by accident.

---

## 10. `.gitignore` - Keep Secrets and Junk Out of Git

```gitignore
# Local provider/module downloads
.terraform/

# State files (contain secrets in plain text)
*.tfstate
*.tfstate.*

# Variable files (may contain secrets)
*.tfvars
*.tfvars.json

# Keep safe templates
!*.tfvars.example

# Saved plans (can contain sensitive values)
*.tfplan
*.plan

# Crash logs
crash.log
crash.*.log

# Override files (local, personal overrides)
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# CLI config files
.terraformrc
terraform.rc

# Debug logs
*.log
```

### ⚠️ Do NOT ignore

```text
.terraform.lock.hcl   -> commit it; keeps provider versions consistent
```

> Common mistake: adding `.terraform*` to `.gitignore`. That pattern also ignores `.terraform.lock.hcl`. Use `.terraform/` (with the slash) instead.

> If a secret was **already committed**, adding it to `.gitignore` is not enough. It's still in Git history. Rotate the secret immediately.

---

## Putting It Together: Complete Small Project

```text
s3-demo/
├── versions.tf
├── providers.tf
├── backend.tf
├── variables.tf
├── locals.tf
├── main.tf
├── outputs.tf
├── terraform.tfvars.example
└── .gitignore
```

How the files connect:

```text
terraform.tfvars  --values-->  variables.tf  --var.x-->  locals.tf  --local.x-->  main.tf  --attrs-->  outputs.tf
                                                                                     ↑
                                                        versions.tf + providers.tf + backend.tf (setup)
```

### Commands

```bash
terraform fmt          # format all files
terraform init         # download providers, configure backend
terraform validate     # check correctness
terraform plan
terraform apply
```

---

# Part 2: Pro-Level Structure - Modules

As projects grow, separate files aren't enough. **Modules** package related resources into **reusable building blocks**.

## What is a Module?

> A module is simply **a folder of `.tf` files**. The folder you run Terraform in is the **root module**. Folders you call with a `module` block are **child modules**.

## Module Structure

```text
project/
├── modules/
│   ├── networking/
│   │   ├── main.tf          # VPC, subnets, route tables
│   │   ├── variables.tf     # inputs: vpc_cidr, azs, ...
│   │   ├── outputs.tf       # outputs: vpc_id, subnet_ids
│   │   └── README.md        # how to use this module
│   ├── compute/
│   │   ├── main.tf          # EC2, Auto Scaling
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── security/
│       ├── main.tf          # security groups, IAM
│       ├── variables.tf
│       └── outputs.tf
├── main.tf                  # calls the modules
├── variables.tf
├── outputs.tf
├── versions.tf
├── providers.tf
└── backend.tf
```

> Every module has the **same 3 core files**: `main.tf`, `variables.tf`, `outputs.tf`. Variables are the module's **inputs**, and outputs are its **return values**.

> **Child modules should not contain `provider` or `backend` blocks.** They inherit providers from the root module. A child module may still declare `required_providers` (in its own `versions.tf`) to state which providers it needs.

## Calling Modules from the Root `main.tf`

```hcl
module "networking" {
  source = "./modules/networking"

  vpc_cidr    = var.vpc_cidr
  name_prefix = local.name_prefix
}

module "security" {
  source = "./modules/security"

  vpc_id      = module.networking.vpc_id        # output -> input
  name_prefix = local.name_prefix
}

module "compute" {
  source = "./modules/compute"

  subnet_ids         = module.networking.private_subnet_ids
  security_group_ids = [module.security.app_sg_id]
  instance_type      = var.instance_type
  name_prefix        = local.name_prefix
}
```

Terraform builds the dependency order automatically: networking → security → compute.

> After adding or changing a module `source`, run `terraform init` so Terraform installs it.

## How to Split Into Modules

The video groups modules **by type of resource**. In practice, group by **logical component that changes together**:

| Module | Contains |
|---|---|
| `networking` | VPC, subnets, route tables, NAT/Internet gateways |
| `security` | Security groups, IAM roles and policies, KMS keys |
| `compute` | EC2, launch templates, Auto Scaling, Lambda |
| `storage` | S3 buckets, lifecycle rules, versioning |
| `database` | RDS, parameter groups, subnet groups |

### Good module habits

- Each module does **one job** well.
- Expose only useful outputs.
- Give every variable a `description` and `type`.
- Avoid hard-coded values; accept them as variables.
- Don't make modules too tiny (one module per resource adds complexity without benefit).
- Add a `README.md` to each module.
- Pin versions when using modules from Git or the Terraform Registry:

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"
}
```

---

# Part 3: Pro-Level Structure - Multiple Environments

Real projects have **dev**, **staging**, and **prod**. The infrastructure is the same shape, but sizes and settings differ.

| Setting | dev | staging | prod |
|---|---|---|---|
| Instance type | `t3.micro` | `t3.small` | `t3.large` |
| Instance count | 1 | 2 | 4 |
| Multi-AZ database | No | No | Yes |
| Deletion protection | No | No | Yes |

There are **two common approaches**.

---

## Approach A: One Root Module + Environment `.tfvars` (Video's Recommendation)

**Don't duplicate code.** Keep **one** root module and inject different values per environment.

```text
project/
├── modules/
│   ├── networking/
│   ├── compute/
│   └── security/
├── envs/
│   ├── dev.tfvars
│   ├── staging.tfvars
│   └── prod.tfvars
├── backend/
│   ├── dev.s3.tfbackend
│   ├── staging.s3.tfbackend
│   └── prod.s3.tfbackend
├── main.tf
├── variables.tf
├── locals.tf
├── outputs.tf
├── versions.tf
├── providers.tf
└── backend.tf              # backend "s3" {}  (partial)
```

### `envs/dev.tfvars`

```hcl
environment    = "dev"
instance_type  = "t3.micro"
instance_count = 1
```

### `envs/prod.tfvars`

```hcl
environment    = "prod"
instance_type  = "t3.large"
instance_count = 4
```

### ⚠️ Each environment needs its OWN state

Using different tfvars against the **same state** would make prod overwrite dev. So combine tfvars with a **separate backend key** per environment.

### `backend.tf` (partial configuration)

```hcl
terraform {
  backend "s3" {}
}
```

### `backend/dev.s3.tfbackend`

```hcl
bucket       = "ashish-terraform-state-2026"
key          = "dev/terraform.tfstate"
region       = "ap-south-1"
encrypt      = true
use_lockfile = true
```

### `backend/prod.s3.tfbackend`

```hcl
bucket       = "ashish-terraform-state-2026"
key          = "prod/terraform.tfstate"
region       = "ap-south-1"
encrypt      = true
use_lockfile = true
```

### Deploy

```bash
# Dev
terraform init -reconfigure -backend-config="backend/dev.s3.tfbackend"
terraform plan  -var-file="envs/dev.tfvars"
terraform apply -var-file="envs/dev.tfvars"

# Prod
terraform init -reconfigure -backend-config="backend/prod.s3.tfbackend"
terraform plan  -var-file="envs/prod.tfvars"
terraform apply -var-file="envs/prod.tfvars"
```

> ⚠️ The `init` and `-var-file` must **match**. Running prod tfvars against the dev backend is a classic mistake. Many teams wrap these commands in a script or CI pipeline to avoid it.

**Pros:** no duplicated code; every environment is guaranteed to have the same shape.
**Cons:** easy to mix up backend and tfvars by hand; environments can't easily differ in structure.

---

## Approach B: Separate Folder per Environment

Each environment has its **own small root folder** that calls the **shared modules**.

```text
project/
├── modules/
│   ├── networking/
│   ├── compute/
│   └── security/
└── environments/
    ├── dev/
    │   ├── main.tf           # calls ../../modules/*
    │   ├── variables.tf
    │   ├── outputs.tf
    │   ├── versions.tf
    │   ├── providers.tf
    │   ├── backend.tf        # key = "dev/terraform.tfstate"
    │   └── terraform.tfvars
    ├── staging/
    │   └── ...
    └── prod/
        ├── main.tf
        ├── backend.tf        # key = "prod/terraform.tfstate"
        └── ...
```

### `environments/dev/main.tf`

```hcl
module "networking" {
  source = "../../modules/networking"

  vpc_cidr    = "10.10.0.0/16"
  name_prefix = "ashish-dev"
}

module "compute" {
  source = "../../modules/compute"

  subnet_ids    = module.networking.private_subnet_ids
  instance_type = "t3.micro"
  name_prefix   = "ashish-dev"
}
```

### Deploy

```bash
cd environments/dev
terraform init
terraform apply

cd ../prod
terraform init
terraform apply
```

**Pros:** each folder has its own backend, so you can't accidentally apply to the wrong state; very clear; environments can differ (for example, prod has an extra WAF).
**Cons:** some repeated wiring code across folders.

---

## Which Approach to Choose?

| | A: One root + tfvars | B: Folder per environment |
|---|---|---|
| Code duplication | None | Small (module calls) |
| Risk of wrong environment | Higher (must match backend + tfvars) | Lower (folder = environment) |
| Environments can differ | Hard | Easy |
| Best for | Learning, identical environments, CI-driven deploys | Most production teams |

> **Both** rely on **modules** for the real logic and **separate state per environment**. That's the key principle, whichever layout you pick.

### What about Terraform workspaces?

`terraform workspace new dev` gives one backend **multiple state files**. It's simple, but all environments share the same backend and credentials, and it's easy to forget which workspace is selected. Many teams prefer Approach A or B for real environments.

---

# Best Practices Summary

| # | Practice | Why |
|---|---|---|
| 1 | Split files by purpose (`versions`, `providers`, `backend`, `variables`, `locals`, `main`, `outputs`) | Readability |
| 2 | Split large `main.tf` by logical unit (`network.tf`, `compute.tf`) | Easy to find things |
| 3 | Use `.gitignore` for `.terraform/`, `*.tfstate`, `*.tfvars`, `*.tfplan` | Protects secrets |
| 4 | Commit `.terraform.lock.hcl` | Consistent provider versions |
| 5 | Commit `terraform.tfvars.example`, not real tfvars | Teammates know what to fill in |
| 6 | Keep secrets out of all files | Use `TF_VAR_` or a secrets manager |
| 7 | Use `locals` and `default_tags` | No repetition |
| 8 | Use modules for reusable components | DRY code, consistent environments |
| 9 | Separate state per environment | A dev mistake can't break prod |
| 10 | Pin Terraform, provider, and module versions | Predictable builds |
| 11 | Run `terraform fmt` and `validate` before every commit | Clean, correct code |
| 12 | Add `description` to variables and outputs | Self-documenting code |
| 13 | Use consistent naming (`snake_case` for Terraform names) | Readability |

---

## Naming Conventions

| Item | Convention | Example |
|---|---|---|
| Terraform names (resources, variables, outputs) | `snake_case` | `aws_s3_bucket.data_lake`, `var.instance_type` |
| Single main resource of a type in a module | `this` or `main` | `aws_vpc.this` |
| Real cloud resource names | `kebab-case` with prefix | `ashish-dev-data` |
| Don't repeat the type in the name | ❌ `aws_s3_bucket.s3_bucket_data` | ✅ `aws_s3_bucket.data` |
| Booleans | `enable_` / `is_` prefix | `enable_versioning` |

---

## Hands-on Practice

### Exercise 1: Refactor a single file

1. Take an old project with everything in `main.tf`.
2. Move blocks into `versions.tf`, `providers.tf`, `variables.tf`, `locals.tf`, `outputs.tf`.
3. Run:

```bash
terraform fmt
terraform validate
terraform plan
```

Expected:

```text
No changes. Your infrastructure matches the configuration.
```

> Moving blocks between files **never** changes infrastructure, because Terraform reads all files as one. This proves splitting is purely organisational.

### Exercise 2: Add `.gitignore` and a template

1. Create `.gitignore` from Part 1.
2. Create `terraform.tfvars.example`.
3. Run `git status` and confirm `terraform.tfstate`, `.terraform/`, and `terraform.tfvars` are **not** listed, but `.terraform.lock.hcl` **is**.

### Exercise 3: Build a module

1. Create `modules/storage/` with `main.tf`, `variables.tf`, `outputs.tf` for an S3 bucket.
2. Call it twice from the root `main.tf` (`logs` and `data`).
3. Run `terraform init`, then `terraform plan`.

### Exercise 4: Two environments

Set up Approach A with `envs/dev.tfvars` + `backend/dev.s3.tfbackend`, deploy dev, then switch to a second environment and confirm two separate state files exist in S3.

---

## Common Mistakes

| Mistake | Fix |
|---|---|
| Everything in one huge `main.tf` | Split by purpose and logical unit |
| Thinking Terraform reads files in a specific order | It reads all files together; order comes from dependencies |
| Committing `terraform.tfstate` or real `.tfvars` | Add them to `.gitignore` |
| Ignoring `.terraform.lock.hcl` | Commit it; use `.terraform/` not `.terraform*` |
| Putting secrets in `.tfvars` or `.example` | Use `TF_VAR_` or a secrets manager |
| `provider` or `backend` blocks inside child modules | Keep them in the root module only |
| Defining `backend` or `required_providers` twice | Define each setting once |
| Copy-pasting code for each environment | Use modules + tfvars or env folders |
| Same state for dev and prod | Separate backend key/bucket per environment |
| Mismatched `-backend-config` and `-var-file` | Script it or use folder-per-environment |
| Tiny modules for every single resource | Group resources that change together |
| Forgetting `terraform init` after adding a module | Run `init` to install it |

---

## Interview Questions

### Q1. Does Terraform require a specific file structure?

> No. Terraform reads all `.tf` files in a directory as one configuration. The standard layout is a convention for readability and maintainability.

### Q2. What goes in `versions.tf` vs `providers.tf`?

> `versions.tf` declares `required_version` and `required_providers` (which provider and version to install). `providers.tf` configures providers (region, tags, aliases).

### Q3. Why use `locals.tf`?

> To define reusable computed values, such as name prefixes and common tags, so they aren't repeated across resources.

### Q4. What should be in `.gitignore` for Terraform?

> `.terraform/`, `*.tfstate`, `*.tfstate.*`, sensitive `*.tfvars` files, saved plan files, crash logs, and override files. `.terraform.lock.hcl` should be committed.

### Q5. What is `terraform.tfvars.example` for?

> A committed template with dummy values that shows teammates which variables to set, without exposing real values or secrets.

### Q6. What is a module, and why use one?

> A folder of Terraform files that packages related resources. Modules make code reusable, consistent across environments, and easier to maintain.

### Q7. Should child modules have provider or backend blocks?

> No. Child modules inherit provider configuration from the root module, and only the root module has a backend.

### Q8. How do you manage dev, staging, and prod?

> Either one root module with environment-specific `.tfvars` and a separate backend config per environment, or a separate root folder per environment that calls shared modules. In both cases, each environment has its own state.

### Q9. Why must each environment have separate state?

> So changes in one environment can't affect another, and a mistake in dev can't modify or destroy prod.

### Q10. Does moving blocks between `.tf` files change infrastructure?

> No. Terraform treats all files in the directory as one configuration, so moving blocks between files produces no plan changes.

---

## Quick Revision

- Terraform reads **all `.tf` files together**; file names are conventions.
- `versions.tf` = versions; `providers.tf` = provider config; `backend.tf` = state location.
- `variables.tf` = inputs; `locals.tf` = reusable internal values; `outputs.tf` = return values.
- `main.tf` = resources; split into `network.tf`, `compute.tf`, etc. when large.
- `terraform.tfvars` = values (don't commit if sensitive); `.example` = safe template (commit).
- `.gitignore`: `.terraform/`, `*.tfstate*`, `*.tfvars`, `*.tfplan`; **keep** `.terraform.lock.hcl`.
- Modules = reusable folders with `main.tf`, `variables.tf`, `outputs.tf`; no provider/backend blocks.
- Environments: one root + tfvars **or** folder per environment; **always separate state**.
- Pin versions, use `fmt` + `validate`, add descriptions, use `snake_case`.

---

## One-Line Summary

> Organise Terraform code by splitting files by purpose (versions, providers, backend, variables, locals, main, outputs), protecting secrets with `.gitignore` and a `.tfvars.example` template, packaging reusable components into modules, and giving each environment its own values and its own state.

---

## Official References

- [Terraform style guide (file names and structure)](https://developer.hashicorp.com/terraform/language/style)
- [Files and directories](https://developer.hashicorp.com/terraform/language/files)
- [Modules overview](https://developer.hashicorp.com/terraform/language/modules)
- [Standard module structure](https://developer.hashicorp.com/terraform/language/modules/develop/structure)
- [Partial backend configuration](https://developer.hashicorp.com/terraform/language/backend#partial-configuration)
- [Terraform .gitignore template (GitHub)](https://github.com/github/gitignore/blob/main/Terraform.gitignore)
