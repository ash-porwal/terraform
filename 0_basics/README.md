# Terraform Fundamentals

A beginner-friendly guide covering Terraform basics, installation, workflow commands, providers, initialization files, HCL syntax, and commonly used top-level blocks.

---

## Table of Contents

1. [What is Terraform?](#what-is-terraform)
2. [Why choose Terraform over Ansible or other tools?](#why-choose-terraform-over-ansible-or-other-tools)
3. [Installing Terraform](#installing-terraform)
4. [Configuring the PATH](#configuring-the-path)
5. [VS Code extension](#vs-code-extension)
6. [Terraform basic workflow](#terraform-basic-workflow)
7. [How Terraform communicates with cloud providers](#how-terraform-communicates-with-cloud-providers)
8. [Terraform dependency lock file](#terraform-dependency-lock-file)
9. [The `.terraform` directory](#the-terraform-directory)
10. [Terraform language and configuration files](#terraform-language-and-configuration-files)
11. [HCL syntax](#hcl-syntax)
12. [Terraform top-level blocks](#terraform-top-level-blocks)
13. [Complete example](#complete-example)
14. [Quick interview revision](#quick-interview-revision)

---

# What is Terraform?

Terraform is an **Infrastructure as Code**, or **IaC**, tool created by HashiCorp. It allows us to define, provision, modify, and destroy infrastructure by writing configuration files instead of manually creating resources through a cloud portal.

For example, Terraform can manage:

- AWS EC2 instances and S3 buckets
- Azure virtual machines and storage accounts
- Google Cloud resources
- Virtual networks, subnets, and security groups
- Databases and Kubernetes resources
- DNS, SaaS platforms, and many other API-managed services

Terraform uses a **declarative approach**. We describe the desired result, and Terraform determines which operations are required to reach it.

```hcl
resource "aws_s3_bucket" "data_bucket" {
  bucket = "example-data-bucket"
}
```

In this example, we declare that an S3 bucket should exist. Terraform works out how to create and manage it through the AWS provider.

## Interview-ready definition

> Terraform is an Infrastructure as Code tool developed by HashiCorp that uses declarative configuration files to provision and manage infrastructure across cloud platforms and other API-based services.

---

# Why choose Terraform over Ansible or other tools?

Terraform and Ansible overlap in some areas, but their primary purposes are different.

## Terraform's primary purpose

Terraform is mainly used for **infrastructure provisioning and lifecycle management**.

Examples:

- Create a VPC
- Create virtual machines
- Create storage accounts
- Create databases
- Create IAM roles
- Create Kubernetes clusters
- Update or destroy managed infrastructure

## Ansible's primary purpose

Ansible is mainly used for **configuration management and application setup**.

Examples:

- Install packages on a server
- Configure Nginx
- Update operating-system settings
- Copy files onto machines
- Start or stop services
- Deploy applications

## Practical comparison

| Area | Terraform | Ansible |
|---|---|---|
| Primary use | Infrastructure provisioning | Configuration management |
| Approach | Declarative | Mostly declarative task automation |
| State | Maintains Terraform state | Usually does not maintain infrastructure state in the same way |
| Cloud support | Uses providers for many platforms | Uses collections and modules |
| Dependency handling | Builds a resource dependency graph | Normally processes tasks in playbook order |
| Typical example | Create an EC2 instance | Install and configure software on the EC2 instance |

## When should we use which tool?

Use **Terraform** when the main requirement is to create and manage infrastructure.

Use **Ansible** when the infrastructure already exists and the main requirement is to configure operating systems, software, or applications.

They can also be used together:

```text
Terraform -> Creates the infrastructure
Ansible   -> Configures software on that infrastructure
```

> Terraform is not universally better than Ansible. The correct tool depends on whether the primary requirement is infrastructure provisioning or configuration management.

## Why teams choose Terraform

- Supports multiple cloud and API-based platforms through providers
- Uses readable, declarative configuration
- Produces an execution plan before applying changes
- Maintains state to map configuration to managed resources
- Supports reusable modules
- Fits well with Git and CI/CD workflows
- Calculates dependencies between resources

---

# Installing Terraform

Terraform CLI is distributed as a command-line executable.

## Windows: manual installation

1. Open the official Terraform installation page:
   - [Install Terraform](https://developer.hashicorp.com/terraform/install)
2. Download the Windows binary for your processor architecture.
3. Extract the downloaded ZIP file.
4. The extracted package contains `terraform.exe`.
5. Move `terraform.exe` to a permanent directory, for example:

```text
C:\terraform
```

6. Add that directory to the Windows `PATH` environment variable.
7. Open a new terminal and verify the installation:

```powershell
terraform version
```

## macOS with Homebrew

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

Verify:

```bash
terraform version
```

## Linux

Use the package-manager instructions for your Linux distribution from the official installation page:

- [Install Terraform](https://developer.hashicorp.com/terraform/install)

After installation, verify:

```bash
terraform version
```

---

# Configuring the PATH

The `PATH` environment variable tells the operating system where it can find executable programs such as `terraform.exe`.

## Set Terraform PATH on Windows

Suppose `terraform.exe` is stored here:

```text
C:\terraform\terraform.exe
```

Add the containing folder, not the executable itself, to `PATH`:

```text
C:\terraform
```

Steps:

1. Search for **Environment Variables** from the Windows Start menu.
2. Open **Edit the system environment variables**.
3. Select **Environment Variables**.
4. Under User variables or System variables, select `Path`.
5. Select **Edit**.
6. Select **New**.
7. Add:

```text
C:\terraform
```

8. Save the changes.
9. Close and reopen VS Code or the terminal.
10. Verify:

```powershell
terraform version
```

If the command is not recognized, check the following:

```powershell
where.exe terraform
```

## PATH on macOS or Linux

If Terraform was installed manually, move the binary into a directory already present in `PATH`, such as `/usr/local/bin`, or add its directory to the shell's `PATH`.

Verify:

```bash
which terraform
terraform version
```

---

# VS Code extension

Install the official extension:

```text
HashiCorp Terraform
```

Publisher:

```text
HashiCorp
```

It provides Terraform language support such as syntax highlighting, formatting, validation assistance, and language-server features.

Installation steps:

1. Open VS Code.
2. Open **Extensions**.
3. Search for `HashiCorp Terraform`.
4. Confirm that the publisher is **HashiCorp**.
5. Select **Install**.

> The VS Code extension improves the editing experience, but Terraform CLI must still be installed separately to run Terraform commands.

---

# Terraform basic workflow

The five beginner workflow commands are:

```text
terraform init
terraform validate
terraform plan
terraform apply
terraform destroy
```

A typical learning workflow is:

```text
Write configuration
       ↓
terraform init
       ↓
terraform validate
       ↓
terraform plan
       ↓
terraform apply
       ↓
terraform destroy, when cleanup is required
```

## 1. `terraform init`

```bash
terraform init
```

### Purpose

Initializes the current Terraform working directory.

It commonly:

- Initializes the configured backend
- Downloads required provider plugins
- Downloads referenced modules
- Creates or updates initialization metadata
- Prepares the directory for other Terraform commands

Run it:

- When starting a Terraform project
- After cloning an existing Terraform project
- After adding or changing a provider requirement
- After adding or changing a module source
- After changing backend configuration

> `terraform init` is safe to run multiple times.

---

## 2. `terraform validate`

```bash
terraform validate
```

### Purpose

Checks whether the Terraform configuration is syntactically valid and internally consistent.

It can detect issues such as:

- Invalid syntax
- Unsupported arguments
- Invalid references
- Incorrect value types
- Missing required arguments that can be determined during validation

It does **not** prove that provider credentials are valid or that remote cloud APIs will accept every operation.

The working directory normally needs to be initialized before validation because provider plugins and modules may be required.

---

## 3. `terraform plan`

```bash
terraform plan
```

### Purpose

Creates and displays an execution plan.

Terraform compares:

```text
Desired configuration
        vs
Terraform state and current remote objects
```

The plan shows proposed actions such as:

```text
+   create
~   update in place
-   destroy
-/+ replace
```

`terraform plan` is a preview. It does not normally perform the proposed infrastructure changes.

A plan can be saved:

```bash
terraform plan -out=tfplan
```

The exact saved plan can then be applied:

```bash
terraform apply tfplan
```

---

## 4. `terraform apply`

```bash
terraform apply
```

### Purpose

Executes the proposed infrastructure changes.

Without a saved plan file, Terraform:

1. Creates a fresh plan.
2. Displays the proposed changes.
3. Requests approval.
4. Calls provider APIs to make the changes.
5. Updates Terraform state.

Apply a previously saved plan:

```bash
terraform apply tfplan
```

Skip interactive approval:

```bash
terraform apply -auto-approve
```

> Use `-auto-approve` carefully because it removes the manual confirmation step.

---

## 5. `terraform destroy`

```bash
terraform destroy
```

### Purpose

Destroys all resources managed by the current Terraform configuration, state, and workspace.

Terraform first displays a destruction plan and normally requests confirmation.

Skip the prompt:

```bash
terraform destroy -auto-approve
```

> Review the destruction plan carefully. This command may permanently delete infrastructure and data.

---

## Useful additional command: `terraform fmt`

Although the requested beginner workflow contains five commands, this command is also very useful:

```bash
terraform fmt
```

It formats Terraform configuration into the standard style.

---

# How Terraform communicates with cloud providers

Terraform does not contain built-in logic for every cloud platform. It uses plugins called **providers**.

Examples:

```text
AWS        -> hashicorp/aws
Azure      -> hashicorp/azurerm
Google     -> hashicorp/google
Kubernetes -> hashicorp/kubernetes
```

## Communication flow

```text
Terraform configuration
          ↓
Terraform Core
          ↓
Provider plugin
          ↓
Cloud or service API
          ↓
AWS, Azure, GCP, Kubernetes, etc.
```

A provider translates Terraform resource configuration into API operations understood by the target platform.

## Provider requirement example

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

## Provider configuration example

```hcl
provider "aws" {
  region = "ap-south-1"
}
```

## Resource example

```hcl
resource "aws_s3_bucket" "data" {
  bucket = "example-data-bucket"
}
```

When `terraform init` runs, Terraform installs the declared provider. During plan and apply operations, the provider communicates with the target API using configured authentication.

> Avoid hardcoding credentials in `.tf` files. Use the authentication mechanism recommended by the selected provider, such as environment variables, workload identities, CLI credentials, or assigned roles.

---

# Terraform dependency lock file

The Terraform dependency lock file is named:

```text
.terraform.lock.hcl
```

## Purpose

It records the exact provider versions selected by Terraform and provider package checksums.

Example structure:

```hcl
provider "registry.terraform.io/hashicorp/aws" {
  version     = "5.x.x"
  constraints = "~> 5.0"
  hashes = [
    "h1:example-checksum"
  ]
}
```

## Why it is useful

- Keeps provider selections consistent for team members and pipelines
- Prevents unintended provider upgrades during normal initialization
- Records checksums used to verify downloaded provider packages
- Makes dependency changes visible in version-control reviews

Terraform creates or updates the lock file during `terraform init`.

The lock file currently tracks **provider dependencies**, not remote module version selections.

## Should it be committed to Git?

Yes. For a normal root-module project, commit `.terraform.lock.hcl` so team members and automation can use the same provider selections.

Do not manually edit it. Use Terraform commands, such as the following, when intentionally upgrading providers:

```bash
terraform init -upgrade
```

---

# The `.terraform` directory

After running:

```bash
terraform init
```

Terraform creates a hidden working directory named:

```text
.terraform/
```

Depending on the configuration and Terraform version, this directory can contain locally cached or initialized working data such as:

- Provider plugins or references to provider packages
- Downloaded child modules
- Backend initialization metadata
- Other local data needed by the initialized working directory

Example structure:

```text
project/
├── main.tf
├── variables.tf
├── outputs.tf
├── .terraform.lock.hcl
└── .terraform/
```

## Should `.terraform/` be committed to Git?

Normally, no. It is generated locally and can be recreated by running:

```bash
terraform init
```

A typical `.gitignore` entry is:

```gitignore
.terraform/
```

Do not confuse these two items:

```text
.terraform/          -> Generated working directory; normally ignored
.terraform.lock.hcl  -> Dependency lock file; normally committed
```

---

# Terraform language and configuration files

Terraform configuration is normally stored in plain-text files with the extension:

```text
.tf
```

Example:

```text
main.tf
providers.tf
variables.tf
outputs.tf
```

These files are called **Terraform configuration files**.

Terraform also supports a JSON-based variant with the extension:

```text
.tf.json
```

Example:

```text
main.tf.json
```

The terms **configuration files** and **Terraform files** are the clearest terms. Some teams may informally call them manifest files, but Terraform's official documentation generally uses **configuration files**.

## Terraform working directory

Terraform CLI commands normally operate on the current working directory containing the root module's `.tf` or `.tf.json` files.

Example:

```text
my-terraform-project/
├── versions.tf
├── providers.tf
├── main.tf
├── variables.tf
└── outputs.tf
```

Run commands from that directory:

```bash
cd my-terraform-project
terraform init
terraform validate
terraform plan
```

Terraform evaluates all top-level `.tf` and `.tf.json` files in the directory as one module. File names are mainly for human organization; Terraform does not execute `main.tf` first and then the remaining files in filename order.

Nested directories are treated as separate modules and are not included automatically. They must be referenced with a `module` block.

---

# HCL syntax

Terraform configuration primarily uses the Terraform language, whose native syntax is based on **HCL**, meaning **HashiCorp Configuration Language**.

The major syntax concepts are:

- Blocks
- Block labels
- Arguments
- Identifiers
- Expressions
- Comments

> CLI commands such as `terraform plan` are not part of HCL syntax. They are Terraform CLI commands executed in a terminal.

## Generic block syntax

```hcl
block_type "label_1" "label_2" {
  argument_name = expression

  nested_block {
    nested_argument = expression
  }
}
```

## Explanation

### Block type

```hcl
resource
```

The block type states what kind of object is being declared.

### Labels

```hcl
"aws_instance" "web"
```

Labels identify or classify the block. Different block types accept different numbers and meanings of labels.

### Argument

```hcl
instance_type = "t3.micro"
```

An argument assigns a value to a name.

### Identifier

```hcl
instance_type
```

An identifier is a name used for an argument, local value, variable, resource name, or another language object.

### Expression

```hcl
"t3.micro"
```

An expression represents a value. Expressions may be literal values, references, operations, conditionals, function calls, or collection expressions.

### Nested block

```hcl
tags {
  # This particular shape is only an illustration.
}
```

A nested block is a block placed inside another block. Whether it is allowed depends on the schema of the parent block.

## Real example

```hcl
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = "t3.micro"

  tags = {
    Name = "web-server"
  }
}
```

Breakdown:

```text
resource         -> Block type
aws_instance     -> First label: resource type
web              -> Second label: local resource name
ami               -> Argument name
var.ami_id        -> Reference expression
instance_type     -> Argument name
"t3.micro"        -> String expression
tags              -> Argument name
{ Name = ... }    -> Object expression
```

## Comments

```hcl
# Single-line comment
// Single-line comment

/*
Multi-line comment
*/
```

---

# Terraform top-level blocks

Top-level blocks are declared directly in a Terraform module's configuration files.

## 1. `terraform` settings block

Configures Terraform itself, including required Terraform versions, provider requirements, and backend or cloud settings.

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

Important points:

- The block has no label.
- It does not create infrastructure.
- Provider requirements belong inside this block.

---

## 2. `provider` block

Configures a provider plugin.

```hcl
provider "aws" {
  region = "ap-south-1"
}
```

Breakdown:

```text
provider -> Block type
aws      -> Provider's local name
region   -> Provider configuration argument
```

Declaring a provider requirement and configuring a provider are related but different:

```text
required_providers -> Tells Terraform which provider to install
provider block     -> Configures an installed provider
```

---

## 3. `resource` block

Declares infrastructure that Terraform should create or manage.

```hcl
resource "aws_s3_bucket" "data" {
  bucket = "example-data-bucket"
}
```

Breakdown:

```text
resource      -> Block type
aws_s3_bucket -> Resource type
 data          -> Local resource name
bucket        -> Resource argument
```

Reference it as:

```hcl
aws_s3_bucket.data
```

Reference one of its attributes:

```hcl
aws_s3_bucket.data.id
```

---

## 4. `variable` input-variable block

Declares an input that can be supplied from outside the module.

```hcl
variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}
```

Reference it as:

```hcl
var.environment
```

Values can come from sources such as:

- A default value
- A `.tfvars` file
- An automatically loaded variable file
- The `-var` or `-var-file` command-line option
- An environment variable using the `TF_VAR_` naming convention
- A parent module, when the variable belongs to a child module

---

## 5. `output` block

Exposes a value from a module and displays root-module outputs after apply.

```hcl
output "bucket_name" {
  description = "Name of the data bucket"
  value       = aws_s3_bucket.data.bucket
}
```

Access root-module outputs with:

```bash
terraform output
```

A parent module can reference a child-module output as:

```hcl
module.storage.bucket_name
```

---

## 6. `locals` local-value block

Defines reusable expressions within a module.

```hcl
locals {
  project_name = "data-platform"
  environment  = var.environment
  common_tags = {
    Project     = local.project_name
    Environment = local.environment
    ManagedBy   = "Terraform"
  }
}
```

Reference local values with:

```hcl
local.project_name
local.common_tags
```

Important distinction:

```text
variable -> Input supplied to a module
local    -> Internal reusable value calculated inside a module
output   -> Value exposed by a module
```

---

## 7. `data` source block

Reads information that already exists instead of declaring a new managed resource.

```hcl
data "aws_caller_identity" "current" {}
```

Reference it as:

```hcl
data.aws_caller_identity.current.account_id
```

Another example:

```hcl
data "aws_vpc" "existing" {
  id = "vpc-xxxxxxxx"
}
```

Reference:

```hcl
data.aws_vpc.existing.cidr_block
```

Difference:

```text
resource block -> Creates or manages an object
 data block     -> Reads information about an existing object
```

---

## 8. `module` block

Calls a reusable Terraform module.

```hcl
module "network" {
  source = "./modules/network"

  vpc_cidr    = "10.0.0.0/16"
  environment = var.environment
}
```

Breakdown:

```text
module      -> Block type
network     -> Local name of the module call
source      -> Location of the child module
vpc_cidr    -> Input passed to the child module
environment -> Input passed to the child module
```

Reference an output from the child module:

```hcl
module.network.vpc_id
```

## Referencing is not a separate top-level block

Terraform does not have a generic top-level block named `calling` or `referencing`.

References are expressions used inside arguments:

```hcl
var.environment
local.common_tags
aws_s3_bucket.data.id
data.aws_vpc.existing.id
module.network.vpc_id
```

The `module` block performs a module call. Other objects are referenced using expressions.

---

# Complete example

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region for the deployment"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

locals {
  bucket_name = "example-${var.environment}-data-bucket"

  common_tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "data" {
  bucket = local.bucket_name
  tags   = local.common_tags
}

output "aws_account_id" {
  description = "AWS account ID used by the provider"
  value       = data.aws_caller_identity.current.account_id
}

output "bucket_name" {
  description = "Name of the created S3 bucket"
  value       = aws_s3_bucket.data.bucket
}
```

Suggested commands:

```bash
terraform fmt
terraform init
terraform validate
terraform plan
terraform apply
terraform output
terraform destroy
```

> The bucket name in a real run must be globally unique, and valid cloud credentials must be configured before planning or applying provider-backed resources.

---

# Recommended project structure

```text
terraform-project/
├── versions.tf
├── providers.tf
├── variables.tf
├── locals.tf
├── data.tf
├── main.tf
├── outputs.tf
├── terraform.tfvars
├── .terraform.lock.hcl
└── .gitignore
```

Example `.gitignore`:

```gitignore
# Local Terraform working directory
.terraform/

# Terraform state can contain sensitive values
*.tfstate
*.tfstate.*

# Saved plans
*.tfplan

# Local variable files may contain secrets
*.tfvars
*.tfvars.json

# Keep the dependency lock file committed
!.terraform.lock.hcl
```

> Decide how variable files are handled based on the project. Non-sensitive example files such as `example.tfvars` may be committed, while files containing credentials or secrets must not be committed.

---

# Quick interview revision

## What is Terraform?

> Terraform is a declarative Infrastructure as Code tool that provisions and manages infrastructure through configuration files and provider APIs.

## Terraform versus Ansible

> Terraform primarily provisions infrastructure, while Ansible primarily configures systems and applications. They can be used together rather than treated as direct replacements in every scenario.

## Five beginner workflow commands

```text
terraform init     -> Initialize the working directory
terraform validate -> Check syntax and internal consistency
terraform plan     -> Preview proposed infrastructure changes
terraform apply    -> Execute proposed changes
terraform destroy  -> Remove managed infrastructure
```

## How does Terraform communicate with providers?

> Terraform uses provider plugins that translate Terraform configuration into API requests for platforms such as AWS, Azure, and Google Cloud.

## What is the lock file?

> `.terraform.lock.hcl` records selected provider versions and checksums so provider installation remains consistent and verifiable.

## What is `.terraform/`?

> `.terraform/` is a generated local working directory containing initialized data such as providers, modules, and backend-related metadata. It is normally excluded from Git.

## What files contain Terraform configuration?

```text
.tf      -> Native Terraform/HCL syntax
.tf.json -> JSON-based Terraform syntax
```

## What are the major HCL concepts?

```text
Blocks, labels, arguments, identifiers, expressions, and comments
```

## What are the common top-level blocks?

```text
terraform
provider
resource
variable
output
locals
data
module
```

---

# Official references

- [Terraform documentation](https://developer.hashicorp.com/terraform)
- [Install Terraform](https://developer.hashicorp.com/terraform/install)
- [Terraform CLI commands](https://developer.hashicorp.com/terraform/cli/commands)
- [Terraform workflow](https://developer.hashicorp.com/terraform/cli/run)
- [Terraform language files](https://developer.hashicorp.com/terraform/language/files)
- [Terraform providers](https://developer.hashicorp.com/terraform/language/providers)
- [Terraform dependency lock file](https://developer.hashicorp.com/terraform/language/files/dependency-lock)
