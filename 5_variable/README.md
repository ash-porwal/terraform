# Terraform Notes - Input Variables

---

## What is a Variable in Terraform?

An **input variable** lets us pass values into Terraform code instead of **hardcoding** them.

It works like a **function parameter** in Python.

```python
def create_server(instance_type):
    ...
```

```hcl
variable "instance_type" {
  type = string
}
```

### Why do we need variables?

Without variables (hardcoded):

```hcl
resource "aws_instance" "web" {
  instance_type = "t2.micro"
}
```

Problem: to use `t3.large` in production, we have to **edit the code**.

With variables:

```hcl
resource "aws_instance" "web" {
  instance_type = var.instance_type
}
```

Now the same code works for **dev, test, and prod**. We only change the value.

### Benefits

- Reusable code
- No hardcoding
- Same code for multiple environments
- Easier to maintain
- Values can be validated

---

## Basic Syntax

```hcl
variable "variable_name" {
  description = "What this variable is for"
  type        = string
  default     = "some value"  
}
```

> **Note:** If a variable has a `default` value, Terraform will not prompt for input when you run `terraform plan` or `terraform apply`. It uses the default value automatically.
>
> To override the default, pass a new value with the `-var` flag in the format `variable_name=value`:
>
> ```bash
> terraform plan -var="my_name=Ashish Porwal"
> ```
>
> The value passed through `-var` takes precedence over the default value defined in the variable block.

---
```hcl
# Example, we created variable name like below 

variable "my_name" {
  type    = string
  default = "Ashish"
}
```

| Command | Value used |
|---|---|
| `terraform plan` | `Ashish` (default, no prompt) |
| `terraform plan -var="my_name=Ashish Porwal"` | `Ashish Porwal` (overridden) |
---


| Argument | Purpose | Required? |
|---|---|---|
| `description` | Explains what the variable is for | Optional (recommended) |
| `type` | Data type allowed | Optional (recommended) |
| `default` | Value used when nothing else is provided | Optional |
| `validation` | Custom rule to check the value | Optional |
| `sensitive` | Hides the value in CLI output | Optional |
| `nullable` | Whether `null` is allowed | Optional (default `true`) |

> A variable **without** a `default` is a **required variable**. If no value is supplied, Terraform **prompts** you for it at run time.

---

## How to Reference a Variable

Use the `var.` prefix:

```hcl
var.<variable_name>
```

Example:

```hcl
variable "my_name" {
  type    = string
  default = "Ashish"
}

output "greeting" {
  value = "Hello, ${var.my_name}"
}
```

Output:

```text
greeting = "Hello, Ashish"
```

### String interpolation

```hcl
"${var.environment}-bucket"
```

If `environment = "dev"` → result is `dev-bucket`.

---

## Variable Types

### Primitive types

#### 1. `string`

```hcl
variable "environment" {
  type    = string
  default = "dev"
}
```

#### 2. `number`

```hcl
variable "instance_count" {
  type    = number
  default = 2
}
```

#### 3. `bool`

```hcl
variable "enable_monitoring" {
  type    = bool
  default = true
}
```

### Collection types

#### 4. `list` - ordered, duplicates allowed, accessed by index

```hcl
variable "availability_zones" {
  type    = list(string)
  default = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
}
```

Access:

```hcl
var.availability_zones[0]   # "ap-south-1a"
```
> **Note:** If a `list` variable has no `default` value, Terraform prompts for it when you run `terraform plan` or `terraform apply`. The value must be entered in list format, using square brackets and double-quoted strings:
>
> ```text
> var.availability_zones
>   Enter a value: ["ap-south-1a", "ap-south-1b"]
> ```
>
> If you enter only `ap-south-1a` without the list syntax, Terraform returns an error because the value does not match the `list(string)` type.

### Overriding a list default from the command line

The same list syntax is used with the `-var` flag.

**Linux / macOS (Bash):**

```bash
terraform plan -var='availability_zones=["ap-south-1a", "ap-south-1b"]'
```

**Windows PowerShell:**

```powershell
terraform plan -var='availability_zones=[\"ap-south-1a\", \"ap-south-1b\"]'
```

> **Tip:** Quoting lists on the command line can be tricky, especially in PowerShell. A `.tfvars` file is easier and avoids quoting issues:
>
> ```hcl
> # terraform.tfvars
> availability_zones = ["ap-south-1a", "ap-south-1b"]
> ```
>
> ```bash
> terraform plan
> ```

### Input format by variable type

| Type | Example input |
|---|---|
| `string` | `ap-south-1a` |
| `number` | `3` |
| `bool` | `true` |
| `list(string)` | `["ap-south-1a", "ap-south-1b"]` |
| `map(string)` | `{ dev = "t2.micro", prod = "t3.large" }` |


#### 5. `set` - unordered, no duplicates, no index access

```hcl
variable "allowed_ports" {
  type    = set(number)
  default = [22, 80, 443]
}
```

#### 6. `map` - key-value pairs, all values of the same type

```hcl
variable "instance_types" {
  type = map(string)
  default = {
    dev  = "t2.micro"
    prod = "t3.large"
  }
}
```

Access:

```hcl
var.instance_types["dev"]   # "t2.micro"
```

### Structural types

#### 7. `object` - named attributes, each can have a different type

```hcl
variable "database" {
  type = object({
    engine  = string
    storage = number
    backup  = bool
  })

  default = {
    engine  = "postgres"
    storage = 20
    backup  = true
  }
}
```

Access:

```hcl
var.database.engine   # "postgres"
```

#### 8. `tuple` - fixed length, each position has its own type

```hcl
variable "server_info" {
  type    = tuple([string, number, bool])
  default = ["web-server", 2, true]
}
```

#### 9. `any`

```hcl
variable "anything" {
  type = any
}
```

Terraform works out the type from the value supplied. Use it sparingly. Specific types catch mistakes earlier.

### Quick type comparison

| Type | Ordered? | Duplicates? | Same value type? | Access |
|---|---|---|---|---|
| `list` | Yes | Yes | Yes | `[index]` |
| `set` | No | No | Yes | Loop only |
| `map` | Keys | Unique keys | Yes | `["key"]` |
| `object` | Attributes | Unique attributes | No | `.attribute` |
| `tuple` | Yes | Yes | No | `[index]` |

---

## Ways to Assign Values to Variables

### 1. Default value

```hcl
variable "environment" {
  default = "dev"
}
```

### 2. Interactive prompt

If there is no default and no other value is provided:

```text
var.environment
  Enter a value:
```

### 3. Command line: `-var`

```bash
terraform plan -var="environment=prod"
terraform apply -var="environment=prod" -var="instance_count=3"
```

### 4. `terraform.tfvars` file (auto-loaded)

```hcl
# terraform.tfvars
environment    = "prod"
instance_count = 3
```

Terraform loads it **automatically**. No flag is needed.

### 5. `*.auto.tfvars` files (auto-loaded)

```text
dev.auto.tfvars
common.auto.tfvars
```

Also loaded automatically, in **alphabetical order of filename**.

### 6. Custom tfvars file: `-var-file`

```bash
terraform apply -var-file="prod.tfvars"
```

Used for environment-specific files such as `dev.tfvars` and `prod.tfvars`. These are **not** auto-loaded, so you must pass them with the flag.

### 7. Environment variables: `TF_VAR_<name>`

**Linux / macOS:**

```bash
export TF_VAR_environment="staging"
terraform plan
```

**Windows PowerShell:**

```powershell
$env:TF_VAR_environment = "staging"
terraform plan
```

> The part after `TF_VAR_` must match the variable name exactly.

---

## Variable Precedence (Very Important for Interviews)

If the same variable is set in multiple places, **the later source wins**.

From **lowest** to **highest** priority:

```text
1. default value in the variable block       (lowest)
2. Environment variables (TF_VAR_*)
3. terraform.tfvars
4. terraform.tfvars.json
5. *.auto.tfvars / *.auto.tfvars.json   (alphabetical order)
6. -var and -var-file on the command line    (highest)
```

> If `-var` and `-var-file` are used together, the one that comes **later on the command line** wins.

### Example

```hcl
variable "environment" {
  default = "dev"
}
```

```bash
export TF_VAR_environment="staging"
```

```hcl
# terraform.tfvars
environment = "test"
```

```bash
terraform plan -var="environment=prod"
```

**Final value: `prod`**, because the command line has the highest precedence.

### Easy way to remember

> **The closer the value is to the command you run, the higher its priority.**

---

## Variable Validation

Validation lets us reject bad values **before** Terraform makes any changes.

```hcl
variable "environment" {
  type = string

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "Environment must be dev, test, or prod."
  }
}
```

If someone passes `environment = "qa"`:

```text
Error: Invalid value for variable
Environment must be dev, test, or prod.
```

### More examples

**Number range:**

```hcl
variable "instance_count" {
  type = number

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 5
    error_message = "Instance count must be between 1 and 5."
  }
}
```

**String length:**

```hcl
variable "project_name" {
  type = string

  validation {
    condition     = length(var.project_name) >= 3
    error_message = "Project name must be at least 3 characters."
  }
}
```

**Regex pattern:**

```hcl
variable "instance_type" {
  type = string

  validation {
    condition     = can(regex("^t3\\.", var.instance_type))
    error_message = "Only t3 instance types are allowed."
  }
}
```

---

## Sensitive Variables

Used for secrets such as passwords, API keys, and tokens.

```hcl
variable "db_password" {
  type      = string
  sensitive = true
}
```

Plan output:

```text
password = (sensitive value)
```

### Important points

- `sensitive = true` hides the value in **CLI output** (plan and apply).
- The value is **still stored in the state file** in plain text, so the state file must be protected.
- Do not put secrets in `.tfvars` files that get committed to Git.
- Prefer `TF_VAR_` environment variables or a secret manager for secrets.
- An output that uses a sensitive variable must also be marked `sensitive = true`, or Terraform shows an error.

```hcl
output "db_password" {
  value     = var.db_password
  sensitive = true
}
```

---

## Hands-on Practice (No Cloud Account Needed)

These examples only use `variable` and `output` blocks, so no cloud resources are created. This is the same idea as the first Terraform file.

### `variables.tf`

```hcl
variable "my_name" {
  description = "My name"
  type        = string
  default     = "Ashish"
}

variable "experience_years" {
  description = "Years of experience"
  type        = number
  default     = 4
}

variable "is_learning_terraform" {
  description = "Am I learning Terraform?"
  type        = bool
  default     = true
}

variable "skills" {
  description = "My skills"
  type        = list(string)
  default     = ["Python", "SQL", "PySpark", "AWS", "Terraform"]
}

variable "environment_regions" {
  description = "Region per environment"
  type        = map(string)
  default = {
    dev  = "ap-south-1"
    prod = "us-east-1"
  }
}

variable "environment" {
  description = "Current environment"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be dev or prod."
  }
}
```

### `outputs.tf`

```hcl
output "intro" {
  value = "Hi, I am ${var.my_name} with ${var.experience_years} years of experience."
}

output "learning_status" {
  value = var.is_learning_terraform
}

output "first_skill" {
  value = var.skills[0]
}

output "all_skills" {
  value = var.skills
}

output "current_region" {
  value = var.environment_regions[var.environment]
}
```

### Run it

```bash
terraform init
terraform plan
terraform apply
```

### Try overriding values

```bash
terraform apply -var="my_name=Ashish Porwal"
terraform apply -var="environment=prod"
terraform apply -var="environment=qa"     # Validation fails
```

### Try a tfvars file

```hcl
# terraform.tfvars
my_name          = "Ashish"
experience_years = 5
environment      = "prod"
```

```bash
terraform apply
```

---

## Recommended File Structure

```text
terraform-project/
├── providers.tf
├── variables.tf       # variable declarations
├── main.tf            # resources using var.xxx
├── outputs.tf         # output blocks
├── terraform.tfvars   # actual values (auto-loaded)
├── dev.tfvars         # dev values (use with -var-file)
└── prod.tfvars        # prod values (use with -var-file)
```

### Declaration vs assignment

| File | What it does |
|---|---|
| `variables.tf` | **Declares** variables (name, type, default, validation) |
| `terraform.tfvars` | **Assigns** values to the declared variables |

> `variables.tf` says **"what inputs exist."**
> `terraform.tfvars` says **"what values to use."**

---

## Common Mistakes

| Mistake | Fix |
|---|---|
| Using `variable.name` instead of `var.name` | Always use `var.` |
| Expecting `dev.tfvars` to load automatically | Use `-var-file="dev.tfvars"` or rename it to `dev.auto.tfvars` |
| Assigning a value in tfvars to a variable that isn't declared | Declare it in a `variable` block first |
| Committing secrets in `.tfvars` | Use `TF_VAR_` or a secret manager |
| Thinking `sensitive = true` encrypts the value | It only hides CLI output; the state still has the value |
| Wrong type, such as `"abc"` for a `number` | Match the declared type |

---

## Interview Questions

### Q1. What is an input variable in Terraform?

> An input variable is a parameter that lets us pass values into Terraform configuration at run time, so the same code can be reused across environments without hardcoding.

### Q2. How do you reference a variable?

> Using `var.<variable_name>`, for example `var.environment`.

### Q3. What happens if a variable has no default and no value is given?

> Terraform prompts for the value interactively. In non-interactive runs, such as CI/CD, it fails with an error.

### Q4. What are the ways to assign variable values?

> Default value, interactive prompt, `-var` flag, `-var-file` flag, `terraform.tfvars`, `*.auto.tfvars`, and `TF_VAR_` environment variables.

### Q5. Explain variable precedence.

> From lowest to highest: default, `TF_VAR_` environment variables, `terraform.tfvars`, `terraform.tfvars.json`, `*.auto.tfvars` in alphabetical order, then `-var` and `-var-file` in command-line order. The last source wins.

### Q6. Difference between `terraform.tfvars` and `prod.tfvars`?

> `terraform.tfvars` is loaded automatically. `prod.tfvars` must be passed explicitly with `-var-file="prod.tfvars"`.

### Q7. Does `sensitive = true` make a value secure?

> It only hides the value in CLI output. The value is still stored in plain text in the state file, so the state must be secured, for example with an encrypted remote backend and access control.

### Q8. Difference between `list` and `set`?

> A list is ordered, allows duplicates, and supports index access. A set is unordered, has unique values, and has no index access.

### Q9. Difference between `map` and `object`?

> In a map, all values must be the same type. In an object, each attribute can have a different type.

### Q10. Difference between input variable, local value, and output?

```text
variable -> Input that comes INTO the module
locals   -> Internal helper value calculated INSIDE the module
output   -> Value that goes OUT of the module
```

---

## Quick Revision

- Variables remove hardcoding and make code reusable.
- Declare with `variable "name" { }` and reference with `var.name`.
- No `default` means the variable is required, and Terraform prompts for it.
- Types: `string`, `number`, `bool`, `list`, `set`, `map`, `object`, `tuple`, `any`.
- `terraform.tfvars` and `*.auto.tfvars` are auto-loaded.
- Other `.tfvars` files need `-var-file`.
- Environment variables use the `TF_VAR_<name>` format.
- Precedence: default < `TF_VAR_` < `terraform.tfvars` < `.tfvars.json` < `*.auto.tfvars` < CLI flags.
- `validation` blocks reject invalid values early.
- `sensitive = true` hides output but does **not** encrypt state.

---

## One-Line Summary

> Terraform input variables parameterize configuration so the same code can be reused across environments. Values can come from defaults, tfvars files, environment variables, or CLI flags, with CLI flags taking the highest precedence.

---

## Official Reference

- [Terraform Input Variables](https://developer.hashicorp.com/terraform/language/values/variables)
- [Protect Sensitive Input Variables](https://developer.hashicorp.com/terraform/tutorials/configuration-language/sensitive-variables)
