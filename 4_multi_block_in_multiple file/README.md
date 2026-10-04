# How Terraform Handles Multiple `.tf` Files in One Directory

## Question

What happens when a directory contains multiple Terraform `.tf` files and we run:

```bash
terraform plan
```

---

## Short Answer

When we run `terraform plan`, Terraform reads **all `.tf` files available in the current working directory** and treats them as **one combined Terraform configuration**.

Terraform does not execute only `main.tf`. It evaluates all top-level `.tf` files in that directory.

---

## Example Directory Structure

Suppose our Terraform project contains the following files:

```text
terraform-project/
├── versions.tf
├── provider.tf
├── variables.tf
├── network.tf
├── storage.tf
├── compute.tf
├── outputs.tf
└── terraform.tfvars
```

The purpose of each file might be:

```text
versions.tf       -> Terraform and provider version requirements
provider.tf       -> Provider configuration
variables.tf      -> Input variable declarations
network.tf        -> VPC, subnet, route table and security resources
storage.tf        -> S3 buckets or other storage resources
compute.tf        -> EC2 instances or other compute resources
outputs.tf        -> Output value declarations
terraform.tfvars  -> Values assigned to input variables
```

When we execute:

```bash
terraform plan
```

Terraform reads all the relevant Terraform configuration files from the current directory.

Conceptually, Terraform treats them like this:

```text
versions.tf
      +
provider.tf
      +
variables.tf
      +
network.tf
      +
storage.tf
      +
compute.tf
      +
outputs.tf
      =
One Terraform configuration
```

---

## Important Point

Terraform does not treat each `.tf` file as a separate program.

All `.tf` files inside the same directory belong to the same Terraform module.

For example, a variable can be declared in `variables.tf`:

```hcl
variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "ap-south-1"
}
```

The same variable can be referenced from `provider.tf`:

```hcl
provider "aws" {
  region = var.aws_region
}
```

Similarly, a resource created in `network.tf` can be referenced from `compute.tf`.

### `network.tf`

```hcl
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "main-vpc"
  }
}
```

### `compute.tf`

```hcl
resource "aws_instance" "web_server" {
  ami           = "ami-xxxxxxxxxxxxxxxxx"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "web-server"
  }
}
```

Terraform understands the relationship even though the resources are declared in different files.

---

## Does Terraform Execute `main.tf` First?

No.

`main.tf` is not a mandatory filename, and Terraform does not treat it as the entry point of the project.

The name `main.tf` is only a commonly followed convention.

For example, these files:

```text
main.tf
variables.tf
outputs.tf
provider.tf
```

could also be named:

```text
compute.tf
inputs.tf
results.tf
aws-provider.tf
```

Terraform would still evaluate them as one configuration, provided they have the `.tf` extension and exist in the same directory.

> Do not design Terraform configurations based on file execution order. Dependencies should be expressed through resource references.

---

## How Terraform Determines Resource Order

Terraform determines the resource creation order from **dependencies**, not from filenames.

Consider the following example.

### `network.tf`

```hcl
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}
```

### `subnet.tf`

```hcl
resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
}
```

### `compute.tf`

```hcl
resource "aws_instance" "web_server" {
  ami           = "ami-xxxxxxxxxxxxxxxxx"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public.id
}
```

Terraform identifies the following dependency chain:

```text
aws_vpc.main
      ↓
aws_subnet.public
      ↓
aws_instance.web_server
```

Terraform understands that:

1. The VPC must exist first.
2. The subnet depends on the VPC.
3. The EC2 instance depends on the subnet.

It determines this order from references such as:

```hcl
vpc_id = aws_vpc.main.id
```

and:

```hcl
subnet_id = aws_subnet.public.id
```

The filenames do not control this order.

---

## Implicit Dependency

An implicit dependency is created when one resource directly references another resource.

```hcl
resource "aws_subnet" "public" {
  vpc_id = aws_vpc.main.id
}
```

Because the subnet references `aws_vpc.main.id`, Terraform automatically understands that the VPC must be handled before the subnet.

In most situations, implicit dependencies are recommended because Terraform can understand the relationship directly from the configuration.

---

## Explicit Dependency Using `depends_on`

Sometimes a dependency exists, but it is not visible through a direct resource attribute reference.

In such cases, we can use `depends_on`:

```hcl
resource "aws_instance" "web_server" {
  ami           = "ami-xxxxxxxxxxxxxxxxx"
  instance_type = "t2.micro"

  depends_on = [
    aws_iam_role_policy.web_server_policy
  ]
}
```

This explicitly tells Terraform that the IAM policy must be handled before the EC2 instance.

Use `depends_on` only when Terraform cannot identify the dependency through normal references.

---

## What Happens During `terraform plan`?

When we execute:

```bash
terraform plan
```

Terraform broadly performs the following operations:

1. Loads all top-level `.tf` and `.tf.json` configuration files from the current working directory.
2. Treats those files as one root-module configuration.
3. Loads variable values from applicable sources.
4. Validates references and configuration relationships.
5. Loads the existing Terraform state.
6. Communicates with providers when necessary to inspect the current infrastructure.
7. Compares the desired configuration with the current infrastructure and state.
8. Builds a dependency graph.
9. Displays the proposed actions.

The plan may show actions such as:

```text
+ create
~ update in-place
- destroy
-/+ replace
```

Running `terraform plan` previews the proposed changes. It does not normally apply those infrastructure changes.

---

## Sample Terraform Plan

```text
Terraform will perform the following actions:

  # aws_vpc.main will be created
  + resource "aws_vpc" "main" {
      + cidr_block = "10.0.0.0/16"
    }

  # aws_subnet.public will be created
  + resource "aws_subnet" "public" {
      + cidr_block = "10.0.1.0/24"
      + vpc_id     = (known after apply)
    }

  # aws_instance.web_server will be created
  + resource "aws_instance" "web_server" {
      + instance_type = "t2.micro"
      + subnet_id     = (known after apply)
    }

Plan: 3 to add, 0 to change, 0 to destroy.
```

Even though these resources may be defined in separate `.tf` files, Terraform generates one combined execution plan.

---

## What About Subdirectories?

Terraform does not automatically combine `.tf` files from nested directories with the root directory.

Example:

```text
terraform-project/
├── main.tf
├── variables.tf
└── modules/
    └── vpc/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

If `terraform plan` is run from `terraform-project/`, Terraform directly reads only the top-level configuration files in that root module.

The files inside `modules/vpc/` are treated as a separate module. To include them, declare a module block:

```hcl
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr = "10.0.0.0/16"
}
```

Terraform then loads the child module because it has been explicitly referenced.

---

## Invalid Duplicate Declarations

Splitting configuration across files does not allow us to declare the same resource address twice.

### `first.tf`

```hcl
resource "aws_s3_bucket" "data" {
  bucket = "example-data-bucket"
}
```

### `second.tf`

```hcl
resource "aws_s3_bucket" "data" {
  bucket = "another-data-bucket"
}
```

Both blocks use the same resource address:

```text
aws_s3_bucket.data
```

Terraform will return a duplicate resource configuration error.

Every resource of the same type must have a unique local name within the module.

A valid example would be:

```hcl
resource "aws_s3_bucket" "raw_data" {
  bucket = "example-raw-data-bucket"
}

resource "aws_s3_bucket" "processed_data" {
  bucket = "example-processed-data-bucket"
}
```

---

## Recommended File Organization

Terraform does not require a specific filename structure, but the following organization is commonly used:

```text
terraform-project/
├── versions.tf
├── providers.tf
├── variables.tf
├── locals.tf
├── data.tf
├── network.tf
├── security.tf
├── storage.tf
├── compute.tf
├── outputs.tf
└── terraform.tfvars
```

This improves:

- Readability
- Maintainability
- Team collaboration
- Code navigation
- Separation of concerns

However, splitting code into different files does not create separate Terraform executions. All files in the directory are still part of one module.

---

## Common Misunderstanding

### Incorrect understanding

```text
Terraform executes main.tf first,
then variables.tf,
then network.tf,
and finally outputs.tf.
```

### Correct understanding

```text
Terraform reads all configuration files in the directory,
treats them as one configuration,
and determines resource order from dependencies.
```

---

## Interview-Ready Answer

> When multiple `.tf` files are present in the same directory, Terraform loads all of them and treats them as a single module or configuration. It does not execute `main.tf` first or process resources based on filenames. Terraform builds a dependency graph using resource references and then creates a combined execution plan representing all required create, update, replace, or destroy actions.

---

## Quick Revision Notes

- Terraform reads all top-level `.tf` files in the current working directory.
- All those files are treated as one Terraform module.
- `main.tf` is a convention, not a mandatory entry-point file.
- File names do not determine resource execution order.
- Terraform determines order using resource dependencies.
- Resources can reference variables and resources declared in other files.
- Nested directories are not automatically included.
- Nested configurations must be referenced through module blocks.
- Duplicate resource addresses are not allowed.
- `terraform plan` creates one combined preview for the entire configuration.
- `terraform plan` does not normally modify infrastructure.

---

## One-Line Summary

> Multiple Terraform files in the same directory are combined into one configuration, and `terraform plan` evaluates them together based on dependencies rather than filename order.