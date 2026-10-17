# Terraform Notes - Variables (Input Variables, Locals, Outputs) with AWS

> **Note:** These notes combine the official Terraform documentation with the topics covered in the AWS Terraform variables video: input variables, locals, output variables, variable precedence, and the plan/apply/destroy workflow.

---

## Quick Answer

Terraform has **three kinds of "variables"**, and each has a different job:

| Kind | Block | Reference | Job |
|---|---|---|---|
| **Input variable** | `variable "name" {}` | `var.name` | Value comes **INTO** the configuration |
| **Local value** | `locals {}` | `local.name` | Helper value computed **INSIDE** the configuration |
| **Output value** | `output "name" {}` | *(shown after apply)* | Value goes **OUT** of the configuration |

### Python analogy

```python
def create_bucket(environment):              # input variable  -> var.environment
    bucket_name = f"ashish-{environment}"    # local value     -> local.bucket_name
    ...
    return bucket_id                         # output value    -> output "bucket_id"
```

```text
variable  ->  comes IN
locals    ->  used INSIDE
output    ->  goes OUT
```

---

# Part 1: Input Variables

## What is an Input Variable?

An **input variable** lets us pass values into Terraform code instead of **hardcoding** them.

It works like a **function parameter** in Python.

## Why Do We Need Variables?

### Without variables (hardcoded)

```hcl
resource "aws_s3_bucket" "logs" {
  bucket = "ashish-dev-logs"
  tags = {
    Environment = "dev"
  }
}

resource "aws_instance" "web" {
  ami           = "ami-xxxxxxxxxxxxxxxxx"
  instance_type = "t2.micro"
  tags = {
    Environment = "dev"
  }
}
```

**Problem:** to move from `dev` to `prod`, you must find and edit **every** place `"dev"` appears. Miss one, and your resources are inconsistent.

### With variables

```hcl
variable "environment" {
  type    = string
  default = "dev"
}

resource "aws_s3_bucket" "logs" {
  bucket = "ashish-${var.environment}-logs"
  tags = {
    Environment = var.environment
  }
}

resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = var.instance_type
  tags = {
    Environment = var.environment
  }
}
```

Now change `environment` **in one place**, and every resource follows.

### Benefits

- Reusable code
- No hardcoding
- Same code for **dev, staging, and prod**
- Change a setting once, not in every resource
- Easier to maintain
- Values can be validated

---

## Basic Syntax

```hcl
variable "variable_name" {
  description = "What this variable is for"
  type        = string
  default     = "some