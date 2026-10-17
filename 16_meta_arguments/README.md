# Terraform Notes - Meta-Arguments (Beginner to Pro)

## Table of Contents

1. [What Are Meta-Arguments?](#what-are-meta-arguments)
2. [Part 1: `count`](#part-1-count---make-n-copies)
3. [Part 2: `for_each`](#part-2-for_each---one-copy-per-item)
4. [Part 3: `count` vs `for_each`](#part-3-count-vs-for_each)
5. [Part 4: `depends_on`](#part-4-depends_on---wait-for-this-first)
6. [Part 5: `provider` and `providers`](#part-5-provider-and-providers)
7. [Part 6: `lifecycle`](#part-6-lifecycle---control-create-update-and-destroy)
8. [Part 7: Meta-Arguments on Modules](#part-7-meta-arguments-on-modules)
9. [Part 8: Pro Patterns](#part-8-pro-patterns)
10. [Part 9: Refactoring Safely](#part-9-refactoring-safely-moved-import-removed)
11. [Part 10: CLI Commands with Instance Keys](#part-10-cli-commands-with-instance-keys)
12. [Part 11: Hands-on Practice (Free)](#part-11-hands-on-practice-free-no-cloud-account)
13. [Common Errors](#common-errors)
14. [Common Mistakes](#common-mistakes)
15. [Interview Questions](#interview-questions)
16. [Quick Revision](#quick-revision)

---

# What Are Meta-Arguments?

**Meta-arguments** are special arguments **built into Terraform itself**. They work on **any resource**, whatever the provider (AWS, Azure, GitHub, local).

- **Normal arguments** describe **what** the resource is: `bucket`, `instance_type`, `name`. They come from the **provider**.
- **Meta-arguments** tell Terraform **how** to create and manage the resource. They come from **Terraform**.

```hcl
resource "aws_instance" "web" {
  count         = 3              # meta-argument  -> "make 3 of these"
  ami           = var.ami_id     # normal argument (AWS provider)
  instance_type = "t3.micro"     # normal argument (AWS provider)
}
```

### Real-life analogy: ordering food

| Instruction to the kitchen | Meta-argument |
|---|---|
| "Make **3** of this dish" | `count` |
| "Make **one for each** friend, with their own name on it" | `for_each` |
| "Serve the starter **before** the main course" | `depends_on` |
| "Cook this one at the **other branch's** kitchen" | `provider` |
| "Bring the new plate **before** taking the old one away" / "**Never** throw this plate away" | `lifecycle` |

The dish itself (spicy, extra cheese) = normal arguments.

## The 5 Meta-Arguments at a Glance

| Meta-argument | What it does | One-line example |
|---|---|---|
| `count` | Creates **N copies** of a resource | `count = 3` |
| `for_each` | Creates **one copy per item** in a map or set | `for_each = toset(["dev", "prod"])` |
| `depends_on` | Forces Terraform to **wait** for another object | `depends_on = [aws_s3_bucket.config]` |
| `provider` | Uses a **specific provider configuration** (e.g. another region) | `provider = aws.us_east` |
| `lifecycle` | Changes **how** a resource is created, updated, or destroyed | `lifecycle { prevent_destroy = true }` |

## Where Can You Use Them?

| Meta-argument | `resource` | `data` | `module` |
|---|---|---|---|
| `count` | ✅ | ✅ | ✅ |
| `for_each` | ✅ | ✅ | ✅ |
| `depends_on` | ✅ | ✅ | ✅ |
| `provider` | ✅ | ✅ | ❌ (modules use `providers`, plural) |
| `lifecycle` | ✅ (all settings) | Only `precondition` / `postcondition` | ❌ |

---

# Part 1: `count` - Make N Copies

## The problem

You need 3 IAM users. Without `count`, you copy-paste:

```hcl
resource "aws_iam_user" "user1" { name = "dev-user-0" }
resource "aws_iam_user" "user2" { name = "dev-user-1" }
resource "aws_iam_user" "user3" { name = "dev-user-2" }
```

Repetitive, and painful to change.

## The solution

```hcl
resource "aws_iam_user" "team" {
  count = 3
  name  = "dev-user-${count.index}"
}
```

`count.index` is the **position number** of the current copy, **starting from 0**.

| Copy | `count.index` | Name created |
|---|---|---|
| 1st | `0` | `dev-user-0` |
| 2nd | `1` | `dev-user-1` |
| 3rd | `2` | `dev-user-2` |

### Plan output

```text
  # aws_iam_user.team[0] will be created
  # aws_iam_user.team[1] will be created
  # aws_iam_user.team[2] will be created

Plan: 3 to add, 0 to change, 0 to destroy.
```

## Using `count` with a list

```hcl
variable "user_names" {
  type    = list(string)
  default = ["ashish", "rahul", "priya"]
}

resource "aws_iam_user" "team" {
  count = length(var.user_names)
  name  = var.user_names[count.index]
}
```

| Address | `count.index` | Name |
|---|---|---|
| `aws_iam_user.team[0]` | 0 | `ashish` |
| `aws_iam_user.team[1]` | 1 | `rahul` |
| `aws_iam_user.team[2]` | 2 | `priya` |

## Create a resource only sometimes (on/off switch)

The most common real-world use of `count`:

```hcl
variable "create_bucket" {
  type    = bool
  default = true
}

resource "aws_s3_bucket" "optional" {
  count  = var.create_bucket ? 1 : 0
  bucket = "ashish-optional-bucket-2026"
}
```

- `true` → `count = 1` → bucket created
- `false` → `count = 0` → nothing created

## Referring to `count` resources

Because there are now **many** copies, you must say **which one**:

```hcl
aws_iam_user.team[0].name        # one copy
aws_iam_user.team[*].name        # all copies, as a list (splat)
length(aws_iam_user.team)        # how many copies
```

### Referring to an optional (0 or 1) resource safely

```hcl
output "optional_bucket_arn" {
  value = one(aws_s3_bucket.optional[*].arn)   # the ARN, or null if not created
}
```

> `one()` returns the single element, or `null` when the list is empty. `aws_s3_bucket.optional[0].arn` would **fail** when `count = 0`.

> ❌ `aws_iam_user.team.name` fails with **"Missing resource instance key"**. You need `[0]` or `[*]`.

## `count` rules

| Rule | Detail |
|---|---|
| Must be a **whole number ≥ 0** | `count = 2.5` or `-1` fails |
| Must be **known before apply** | Can't depend on IDs that show `(known after apply)` |
| Can't be **sensitive** | Wrap with `nonsensitive()` only if truly safe |
| Can't be used with `for_each` in the same block | Pick one |

## ⚠️ The `count` trap: removing an item from the middle

Copies are tracked by **position**. Remove `"rahul"` from the middle:

```hcl
default = ["ashish", "priya"]
```

```text
Before:  [0] ashish   [1] rahul   [2] priya
After:   [0] ashish   [1] priya   (no [2])
```

Terraform sees:

- `team[1]` changes from `rahul` → `priya` (updated or **replaced**)
- `team[2]` is no longer needed → **destroyed**

You only wanted to remove `rahul`, but `priya` gets affected too. For real resources like databases, that can mean **data loss**.

> **Lesson:** Use `count` for **identical copies** or an **on/off switch**. If items have names and may be removed, use **`for_each`**.

---

# Part 2: `for_each` - One Copy per Item

`for_each` creates one copy for **each item** in a **map** or a **set of strings**. Each copy is tracked by its **key (name)**, not its position.

## With a set of strings

```hcl
resource "aws_iam_user" "team" {
  for_each = toset(["ashish", "rahul", "priya"])
  name     = each.key
}
```

Addresses:

```text
aws_iam_user.team["ashish"]
aws_iam_user.team["priya"]
aws_iam_user.team["rahul"]
```

### Now remove `"rahul"`

```text
  # aws_iam_user.team["rahul"] will be destroyed

Plan: 0 to add, 0 to change, 1 to destroy.
```

✅ Only `rahul` is removed. `ashish` and `priya` aren't touched.

## `each.key` and `each.value`

| `for_each` gets | `each.key` | `each.value` |
|---|---|---|
| Set `["ashish", "rahul"]` | the item (`"ashish"`) | the same item (`"ashish"`) |
| Map `{ logs = "ashish-logs-2026" }` | the key (`"logs"`) | the value (`"ashish-logs-2026"`) |

## With a map

```hcl
variable "buckets" {
  type = map(string)
  default = {
    logs = "ashish-logs-2026"
    data = "ashish-data-2026"
  }
}

resource "aws_s3_bucket" "this" {
  for_each = var.buckets

  bucket = each.value
  tags = {
    Purpose = each.key
  }
}
```

| Address | `each.key` | `each.value` |
|---|---|---|
| `aws_s3_bucket.this["data"]` | `data` | `ashish-data-2026` |
| `aws_s3_bucket.this["logs"]` | `logs` | `ashish-logs-2026` |

## With a map of objects (most powerful)

Each item can carry several settings:

```hcl
variable "servers" {
  type = map(object({
    instance_type = string
    environment   = string
  }))

  default = {
    web = { instance_type = "t3.micro", environment = "dev" }
    api = { instance_type = "t3.small", environment = "dev" }
  }
}

resource "aws_instance" "this" {
  for_each = var.servers

  ami           = var.ami_id
  instance_type = each.value.instance_type

  tags = {
    Name        = each.key
    Environment = each.value.environment
  }
}
```

Two servers, each with its own size, from one block.

### Optional attributes with defaults (Terraform 1.3+)

```hcl
variable "servers" {
  type = map(object({
    instance_type = optional(string, "t3.micro")
    environment   = optional(string, "dev")
    monitoring    = optional(bool, false)
  }))

  default = {
    web = {}                                  # uses all defaults
    api = { instance_type = "t3.small" }      # overrides one setting
  }
}
```

## Referring to `for_each` resources

```hcl
aws_s3_bucket.this["logs"].arn                              # one copy
{ for k, b in aws_s3_bucket.this : k => b.arn }             # map of all (name => arn)
[for b in aws_s3_bucket.this : b.arn]                       # list of all
values(aws_s3_bucket.this)[*].arn                           # list of all (alternative)
keys(aws_s3_bucket.this)                                    # list of keys
```

```hcl
output "bucket_arns" {
  value = { for k, b in aws_s3_bucket.this : k => b.arn }
}
```

> The splat `[*]` doesn't work directly on `for_each` resources, because they're a **map**, not a list. Use a `for` expression or `values(...)[*]`.

## `for_each` rules

| Rule | Example / detail |
|---|---|
| Only a **map** or **set of strings** | Convert lists: `for_each = toset(var.user_names)` |
| Keys must be **known before apply** | Can't use generated IDs that show `(known after apply)` |
| Values can't be **sensitive** | Sensitive values can't be used as `for_each` arguments |
| Can't use `count` and `for_each` together | Pick one |
| Keys should be **stable** | Changing a key = destroy old + create new |

### Error if you pass a list

```text
Error: Invalid for_each argument
The given "for_each" argument value is unsuitable: the "for_each" argument
must be a map, or set of strings, and you have provided a value of type tuple.
```

Fix: `for_each = toset(["a", "b"])`

### Lists of objects → convert to a map

`toset()` only works for strings. For a **list of objects**, build a map with a unique key:

```hcl
variable "users" {
  default = [
    { name = "ashish", team = "data" },
    { name = "priya",  team = "devops" },
  ]
}

resource "aws_iam_user" "this" {
  for_each = { for u in var.users : u.name => u }

  name = each.key
  tags = { Team = each.value.team }
}
```

---

# Part 3: `count` vs `for_each`

| | `count` | `for_each` |
|---|---|---|
| Input | A whole number | A map or set of strings |
| Tracked by | Position `[0]`, `[1]` | Key `["name"]` |
| Inside the block | `count.index` | `each.key`, `each.value` |
| Remove from middle | ⚠️ Shifts positions; affects others | ✅ Only that item is affected |
| Different settings per copy | Awkward | ✅ Easy with a map of objects |
| All copies as a list | `resource[*].attr` | `[for r in resource : r.attr]` |
| Best for | Identical copies, on/off switch | Named items with their own settings |

### Decision guide

```text
Do the copies have names / different settings?
   ├── Yes ──> for_each
   └── No
        ├── Just turning one resource on/off? ──> count = condition ? 1 : 0
        └── N identical copies, never removed from the middle? ──> count
```

> **Simple rule:** If the copies have **names**, use `for_each`. If they're **identical** or it's an **on/off switch**, use `count`.

---

# Part 4: `depends_on` - "Wait for This First"

## Implicit dependency (automatic, preferred)

Terraform normally works out the order by itself from **references**:

```hcl
resource "aws_s3_bucket" "data" {
  bucket = "ashish-data-2026"
}

resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id     # <- reference = automatic dependency

  versioning_configuration {
    status = "Enabled"
  }
}
```

Terraform sees `aws_s3_bucket.data.id`, so it creates the bucket first. **No `depends_on` needed.**

## Explicit dependency (`depends_on`)

Sometimes a dependency is **hidden**: one resource needs another, but there's **no reference** in the code.

### Example 1: a script uses a bucket by name

```hcl
resource "aws_s3_bucket" "config" {
  bucket = "ashish-app-config-2026"
}

resource "aws_instance" "app" {
  ami           = var.ami_id
  instance_type = "t3.micro"

  user_data = <<-EOT
    #!/bin/bash
    aws s3 cp s3://ashish-app-config-2026/app.conf /etc/app.conf
  EOT

  depends_on = [aws_s3_bucket.config]
}
```

> 💡 **Better:** use a reference so the dependency becomes automatic:
> `aws s3 cp s3://${aws_s3_bucket.config.bucket}/app.conf /etc/app.conf`

### Example 2: IAM permissions must exist before use (classic real case)

A Lambda needs its IAM **policy attached** before it runs. The function references the **role**, but not the **policy attachment**:

```hcl
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "app" {
  function_name = "ashish-app"
  role          = aws_iam_role.lambda.arn      # references the role only
  # ...

  depends_on = [aws_iam_role_policy_attachment.lambda_logs]
}
```

## `depends_on` rules

| Rule | Detail |
|---|---|
| It's a **list** | `depends_on = [a, b]` |
| **No quotes** | ✅ `[aws_s3_bucket.config]` ❌ `["aws_s3_bucket.config"]` |
| Whole objects only | `aws_s3_bucket.config` or `module.network`, not `aws_s3_bucket.config.id` |
| Affects **destroy order** too | The dependent is destroyed first |
| Must be **static** | No conditionals or variables inside |

## ⚠️ Pro caution: `depends_on` has a cost

- On a **data source**, `depends_on` can delay reading it until **apply**, so its values become `(known after apply)` and that spreads to everything using it.
- On a **module**, the **whole module** waits for the dependency, which can create big, slow, noisy plans.
- **Use references first.** Add `depends_on` only for genuinely hidden dependencies, with a comment explaining why.

```hcl
  # Needed: Lambda fails on first invoke if the log policy isn't attached yet
  depends_on = [aws_iam_role_policy_attachment.lambda_logs]
```

---

# Part 5: `provider` and `providers`

## The problem

Your default AWS region is Mumbai (`ap-south-1`), but one resource must be created elsewhere.

Real example: **ACM certificates used by CloudFront must be in `us-east-1`**.

## The solution: `alias` + `provider`

### `providers.tf`

```hcl
# Default provider (no alias)
provider "aws" {
  region = "ap-south-1"
}

# Second configuration with a nickname
provider "aws" {
  alias  = "us_east"
  region = "us-east-1"
}
```

### `main.tf`

```hcl
# Uses the default provider -> Mumbai
resource "aws_s3_bucket" "mumbai" {
  bucket = "ashish-mumbai-bucket-2026"
}

# Uses the aliased provider -> N. Virginia
resource "aws_acm_certificate" "cloudfront_cert" {
  provider          = aws.us_east
  domain_name       = "example.com"
  validation_method = "DNS"
}
```

| Rule | Detail |
|---|---|
| Resources with **no** `provider` | Use the **default** (non-aliased) provider |
| Syntax | `provider = aws.us_east` (**no quotes**) |
| Must be **static** | Can't choose a provider with a variable or conditional |
| Common uses | Multiple **regions**, multiple **AWS accounts** |

## Pro: multiple AWS accounts

```hcl
provider "aws" {
  alias  = "prod"
  region = "ap-south-1"

  assume_role {
    role_arn = "arn:aws:iam::111122223333:role/TerraformDeploy"
  }
}

resource "aws_s3_bucket" "prod_logs" {
  provider = aws.prod
  bucket   = "ashish-prod-logs-2026"
}
```

## In modules: `providers` (plural)

```hcl
module "backup_storage" {
  source = "./modules/storage"

  providers = {
    aws = aws.us_east
  }
}
```

Everything inside that module now uses the `us-east-1` provider.

## Pro: a module that needs **two** providers (`configuration_aliases`)

Example: a module that replicates a bucket from a primary region to a DR region.

### Inside the module: `modules/replicated-bucket/versions.tf`

```hcl
terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 6.0"
      configuration_aliases = [aws.primary, aws.dr]
    }
  }
}
```

### Inside the module: `main.tf`

```hcl
resource "aws_s3_bucket" "primary" {
  provider = aws.primary
  bucket   = "${var.name}-primary"
}

resource "aws_s3_bucket" "dr" {
  provider = aws.dr
  bucket   = "${var.name}-dr"
}
```

### Root module calls it

```hcl
module "replicated" {
  source = "./modules/replicated-bucket"
  name   = "ashish-data-2026"

  providers = {
    aws.primary = aws
    aws.dr      = aws.us_east
  }
}
```

> **Rule:** Child modules should **not** contain `provider` blocks. They receive providers from the root module.

---

# Part 6: `lifecycle` - Control Create, Update and Destroy

`lifecycle` is a **block** with several settings:

```hcl
lifecycle {
  create_before_destroy = true
  prevent_destroy       = true
  ignore_changes        = [tags]
  replace_triggered_by  = [aws_s3_object.app_config]

  precondition {
    condition     = var.instance_type != "t2.micro"
    error_message = "t2.micro is not allowed."
  }

  postcondition {
    condition     = self.public_ip != ""
    error_message = "Instance must have a public IP."
  }
}
```

| Setting | In simple words |
|---|---|
| `create_before_destroy` | "Build the new one **before** removing the old one" |
| `prevent_destroy` | "**Never** let Terraform delete this" |
| `ignore_changes` | "Don't undo changes to **these** attributes" |
| `replace_triggered_by` | "**Recreate** me when **that** changes" |
| `precondition` | "**Check** this rule **before** creating/changing" |
| `postcondition` | "**Check** this rule **after** creating/changing" |

---

## 6.1 `create_before_destroy`

Some changes can't be made in place, so Terraform must **replace** the resource. By default:

```text
1. Destroy old   ->   2. Create new      (gap = downtime)
```

With `create_before_destroy = true`:

```text
1. Create new    ->   2. Destroy old     (no gap)
```

```hcl
resource "aws_launch_template" "app" {
  name_prefix   = "ashish-app-"          # generated unique name
  image_id      = var.ami_id
  instance_type = "t3.micro"

  lifecycle {
    create_before_destroy = true
  }
}
```

### Plan symbols

| Symbol | Meaning |
|---|---|
| `-/+` | Destroy, then create (default replacement) |
| `+/-` | Create, then destroy (`create_before_destroy`) |

### ⚠️ Unique-name problem

Old and new exist **at the same moment**, so a **fixed unique name** fails:

```text
Error: creating S3 Bucket (ashish-data-2026): BucketAlreadyExists
```

Fix: use `name_prefix` (where the resource supports it) or a generated suffix.

### Pro detail: it spreads to dependencies

If a resource has `create_before_destroy = true`, Terraform applies the same create-before-destroy behaviour to the **resources it depends on** when they're replaced together. Otherwise the ordering would be impossible. You'll see `+/-` on those too.

---

## 6.2 `prevent_destroy`

Protects important resources from being deleted by mistake.

```hcl
resource "aws_s3_bucket" "prod_data" {
  bucket = "ashish-prod-data-2026"

  lifecycle {
    prevent_destroy = true
  }
}
```

Any plan that would delete it **fails**:

```text
Error: Instance cannot be destroyed

Resource aws_s3_bucket.prod_data has lifecycle.prevent_destroy set, but the
plan calls for this resource to be destroyed.
```

| Point | Detail |
|---|---|
| Blocks **replacement** too | A change that forces replace also fails |
| Blocks `terraform destroy` for **everything** | The whole plan is rejected |
| ⚠️ Deleting the block removes the protection | It only works while the block is in code |
| Add a second layer | Provider options like `deletion_protection = true` (RDS) or `force_destroy = false` (S3) |

---

## 6.3 `ignore_changes`

"If this attribute changes **outside Terraform**, leave it alone."

### Example 1: tags changed by another team or tool

```hcl
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = "t3.micro"

  tags = {
    Name = "web"
  }

  lifecycle {
    ignore_changes = [tags]
  }
}
```

### Example 2: ignore just **one** tag (pro)

A security scanner adds a `LastScanned` tag. Ignore only that key:

```hcl
lifecycle {
  ignore_changes = [tags["LastScanned"]]
}
```

### Example 3: Auto Scaling changes the capacity

```hcl
resource "aws_autoscaling_group" "app" {
  # ...
  desired_capacity = 2

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}
```

### Example 4: AMI updated by a pipeline

```hcl
lifecycle {
  ignore_changes = [ami]
}
```

### Ignore everything

```hcl
lifecycle {
  ignore_changes = all
}
```

Terraform creates the resource, then never updates it. Use rarely.

### Rules

- Attribute names are written **without quotes**: `[tags, ami]`.
- The value in your code is still used at **creation**. `ignore_changes` only affects later **updates**.
- It also ignores **your own** code changes to that attribute. Changing `ami` in code does nothing while it's ignored.

---

## 6.4 `replace_triggered_by` (Terraform 1.2+)

"Recreate this resource whenever **that other resource** changes."

```hcl
resource "aws_s3_object" "app_config" {
  bucket = aws_s3_bucket.config.id
  key    = "app.conf"
  source = "app.conf"
  etag   = filemd5("app.conf")
}

resource "aws_instance" "app" {
  ami           = var.ami_id
  instance_type = "t3.micro"

  lifecycle {
    replace_triggered_by = [aws_s3_object.app_config]
  }
}
```

Update `app.conf` → the S3 object changes → the instance is **recreated** and picks up the new config at startup.

### Trigger on one attribute

```hcl
replace_triggered_by = [aws_s3_object.app_config.etag]
```

### Trigger on a variable (using `terraform_data`, Terraform 1.4+)

`replace_triggered_by` only accepts **resources**, not variables. Wrap the variable:

```hcl
resource "terraform_data" "app_version" {
  input = var.app_version
}

resource "aws_instance" "app" {
  # ...
  lifecycle {
    replace_triggered_by = [terraform_data.app_version]
  }
}
```

> `terraform_data` is the built-in replacement for the older `null_resource`.

---

## 6.5 `precondition` and `postcondition` (Terraform 1.2+)

Custom checks with your own error message.

```hcl
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = var.instance_type

  lifecycle {
    # Checked BEFORE the resource is created or changed
    precondition {
      condition     = !(var.environment == "prod" && var.instance_type == "t2.micro")
      error_message = "Production must not use t2.micro."
    }

    # Checked AFTER, using "self" = this resource
    postcondition {
      condition     = self.public_ip != ""
      error_message = "The web server must have a public IP."
    }
  }
}
```

### On a data source

```hcl
data "aws_ami" "app" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["ashish-app-*"]
  }

  lifecycle {
    postcondition {
      condition     = self.architecture == "x86_64"
      error_message = "The selected AMI must be x86_64."
    }
  }
}
```

### Validation vs precondition vs check

| Feature | Where | Can see | On failure |
|---|---|---|---|
| Variable `validation` | `variable` block | That variable (1.9+: other values too) | Error |
| `precondition` | Resource / data / output | Anything | Error, before the change |
| `postcondition` | Resource / data | `self` + anything | Error, after the change |
| `check` block (1.5+) | Top level | Anything | **Warning** only |

---

## `lifecycle` rule: values must be static

```hcl
lifecycle {
  prevent_destroy = var.protect     # ❌ Error: Variables may not be used here.
}
```

```hcl
lifecycle {
  prevent_destroy = true            # ✅
}
```

> Exception: `precondition` and `postcondition` **conditions** can use variables and expressions. The other lifecycle settings must be fixed values.

---

# Part 7: Meta-Arguments on Modules

Modules support `count`, `for_each`, `depends_on`, and `providers` (Terraform 0.13+).

```hcl
# for_each: one module copy per environment
module "app" {
  source   = "./modules/app"
  for_each = toset(["dev", "staging"])

  environment = each.key
}

# count: on/off switch for a whole module
module "monitoring" {
  source = "./modules/monitoring"
  count  = var.enable_monitoring ? 1 : 0
}

# depends_on: wait for another module
module "database" {
  source     = "./modules/database"
  depends_on = [module.network]
}

# providers: use another region
module "dr_backup" {
  source = "./modules/storage"
  providers = {
    aws = aws.us_east
  }
}
```

### Referencing

```hcl
module.app["dev"].url                         # for_each module
{ for k, m in module.app : k => m.url }       # all for_each module outputs
one(module.monitoring[*].dashboard_url)       # optional count module
```

### Resource addresses inside module copies

```text
module.app["dev"].aws_s3_bucket.this
module.app["staging"].aws_s3_bucket.this
module.monitoring[0].aws_cloudwatch_dashboard.main
```

> `lifecycle` can't be set on a `module` block. Put it on the resources **inside** the module.

> A module that contains its own `provider` blocks can't use `count`, `for_each`, or `depends_on`. Another reason to keep providers in the root module.

---

# Part 8: Pro Patterns

## 8.1 Nested loops with `flatten` (for_each over pairs)

Goal: give **each user** access to **each bucket**.

```hcl
locals {
  users   = ["ashish", "priya"]
  buckets = ["logs", "data"]

  user_bucket_pairs = flatten([
    for u in local.users : [
      for b in local.buckets : {
        user   = u
        bucket = b
      }
    ]
  ])
}

resource "aws_iam_user_policy" "access" {
  for_each = { for p in local.user_bucket_pairs : "${p.user}-${p.bucket}" => p }

  name   = "access-${each.value.bucket}"
  user   = each.value.user
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject"]
      Resource = "arn:aws:s3:::ashish-${each.value.bucket}-2026/*"
    }]
  })
}
```

Resulting keys:

```text
["ashish-logs"]  ["ashish-data"]  ["priya-logs"]  ["priya-data"]
```

> Pattern: **flatten** to a list of objects → **convert to a map** with a unique, readable key → `for_each`.

`setproduct()` is another way to build all combinations:

```hcl
for_each = { for pair in setproduct(local.users, local.buckets) : "${pair[0]}-${pair[1]}" => pair }
```

## 8.2 Chaining `for_each` resources

Feed one `for_each` resource into another. The keys line up automatically:

```hcl
resource "aws_s3_bucket" "this" {
  for_each = var.buckets
  bucket   = each.value
}

resource "aws_s3_bucket_versioning" "this" {
  for_each = aws_s3_bucket.this          # same keys: "logs", "data"

  bucket = each.value.id
  versioning_configuration {
    status = "Enabled"
  }
}
```

`each.value` here is the **whole bucket object**, so `each.value.id` works.

## 8.3 Filtering items with `if`

```hcl
resource "aws_s3_bucket_versioning" "prod_only" {
  for_each = { for k, v in var.buckets_config : k => v if v.versioning }
  # ...
}
```

## 8.4 Feature flags for nested blocks: `dynamic` (related, not a meta-argument)

`count` and `for_each` work on **whole resources**. To repeat a **nested block** inside one resource, use a `dynamic` block:

```hcl
variable "ingress_ports" {
  default = [22, 80, 443]
}

resource "aws_security_group" "web" {
  name = "ashish-web-sg"

  dynamic "ingress" {
    for_each = var.ingress_ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}
```

| | Meta-argument `for_each` | `dynamic` block `for_each` |
|---|---|---|
| Repeats | Whole resources / modules | Nested blocks inside one resource |
| Iterator | `each.key`, `each.value` | `<block_name>.key`, `<block_name>.value` |
| Accepts lists | ❌ (map or set) | ✅ (any collection) |

> Optional nested block (on/off): `for_each = var.enable_logging ? [1] : []`.

## 8.5 Fixing "for_each value depends on resource attributes"

```text
Error: Invalid for_each argument
The "for_each" map includes keys derived from resource attributes that cannot
be determined until apply.
```

**Cause:** the keys come from something created in the same run (an ID or generated name).

**Fixes:**

1. ✅ Use keys **you write** (names from variables), and put the unknown values in `each.value`.
2. Split the work into two applies, or `-target` the dependency first (last resort).

```hcl
# ❌ keys unknown until apply
for_each = toset(aws_subnet.private[*].id)

# ✅ keys known (names); values can be unknown
for_each = aws_subnet.private          # if aws_subnet.private uses for_each with fixed keys
```

---

# Part 9: Refactoring Safely (`moved`, `import`, `removed`)

## 9.1 Adding `count` to an existing single resource

Terraform handles this **automatically**: the existing `aws_s3_bucket.data` becomes `aws_s3_bucket.data[0]` with no replacement.

## 9.2 Switching from `count` to `for_each` ⚠️

Addresses change from `[0]` to `["name"]`. Without help, Terraform would **destroy and recreate** every resource.

Use `moved` blocks (Terraform 1.1+):

```hcl
resource "aws_iam_user" "team" {
  for_each = toset(["ashish", "rahul", "priya"])
  name     = each.key
}

moved {
  from = aws_iam_user.team[0]
  to   = aws_iam_user.team["ashish"]
}

moved {
  from = aws_iam_user.team[1]
  to   = aws_iam_user.team["rahul"]
}

moved {
  from = aws_iam_user.team[2]
  to   = aws_iam_user.team["priya"]
}
```

```text
  # aws_iam_user.team[0] has moved to aws_iam_user.team["ashish"]
  ...
Plan: 0 to add, 0 to change, 0 to destroy.
```

✅ No resources are recreated. Keep `moved` blocks for a while, especially in shared modules, so every user's state migrates.

## 9.3 Moving resources into a module copy

```hcl
moved {
  from = aws_s3_bucket.logs
  to   = module.storage["logs"].aws_s3_bucket.this
}
```

## 9.4 Importing existing resources into `for_each` (Terraform 1.7+)

```hcl
locals {
  existing_buckets = {
    logs = "ashish-logs-2026"
    data = "ashish-data-2026"
  }
}

import {
  for_each = local.existing_buckets
  to       = aws_s3_bucket.this[each.key]
  id       = each.value
}

resource "aws_s3_bucket" "this" {
  for_each = local.existing_buckets
  bucket   = each.value
}
```

## 9.5 Stop managing one copy without deleting it (Terraform 1.7+)

Remove the key from the map, then add:

```hcl
removed {
  from = aws_s3_bucket.this

  lifecycle {
    destroy = false
  }
}
```

> `removed` targets a whole resource (all its instances). To drop a single instance from state without destroying it, use `terraform state rm 'aws_s3_bucket.this["logs"]'`.

---

# Part 10: CLI Commands with Instance Keys

Addresses with `[ ]` and `" "` need careful quoting.

| Shell | Example |
|---|---|
| Bash / Zsh | `terraform state show 'aws_s3_bucket.this["logs"]'` |
| PowerShell 7.3+ | `terraform state show 'aws_s3_bucket.this["logs"]'` |
| Windows PowerShell 5.1 | `terraform state show 'aws_s3_bucket.this[\"logs\"]'` |
| cmd | `terraform state show "aws_s3_bucket.this[\"logs\"]"` |

### Useful commands

```bash
terraform state list                                              # see all instance addresses
terraform state show 'aws_iam_user.team["ashish"]'               # one instance
terraform plan -replace='aws_instance.this["web"]'                # recreate one copy
terraform destroy -target='aws_s3_bucket.this["logs"]'            # one-off delete
terraform state mv 'aws_iam_user.team[0]' 'aws_iam_user.team["ashish"]'  # CLI alternative to moved
```

> 💡 Copy the exact address from `terraform state list` to avoid typos.

### Test expressions first in the console

```bash
terraform console
> toset(["a", "b", "a"])
> { for u in var.users : u.name => u }
> keys(aws_s3_bucket.this)
```

---

# Part 11: Hands-on Practice (Free, No Cloud Account)

These exercises use the **`local` provider**, which creates text files on your laptop. No AWS account, no cost.

### `versions.tf`

```hcl
terraform {
  required_version = ">= 1.7.0"

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}
```

```bash
terraform init
```

### Exercise 1: `count`

```hcl
resource "local_file" "numbered" {
  count    = 3
  filename = "${path.module}/count-file-${count.index}.txt"
  content  = "This is file number ${count.index}"
}
```

```bash
terraform apply
terraform state list
```

You'll see `local_file.numbered[0]`, `[1]`, `[2]`, and three new files.

### Exercise 2: on/off switch

```hcl
variable "create_extra" {
  type    = bool
  default = false
}

resource "local_file" "extra" {
  count    = var.create_extra ? 1 : 0
  filename = "${path.module}/extra.txt"
  content  = "I only exist when create_extra = true"
}

output "extra_file" {
  value = one(local_file.extra[*].filename)
}
```

```bash
terraform apply                              # nothing created, output is null
terraform apply -var="create_extra=true"     # file created
```

### Exercise 3: `for_each`

```hcl
resource "local_file" "topics" {
  for_each = toset(["variables", "outputs", "state"])
  filename = "${path.module}/${each.key}.txt"
  content  = "My notes on Terraform ${each.key}"
}
```

Remove `"outputs"` from the set and run `terraform plan`. **Only** `local_file.topics["outputs"]` is destroyed.

### Exercise 4: See the `count` trap yourself

```hcl
variable "names" {
  default = ["a", "b", "c"]
}

resource "local_file" "trap" {
  count    = length(var.names)
  filename = "${path.module}/trap-${var.names[count.index]}.txt"
  content  = var.names[count.index]
}
```

1. `terraform apply`
2. Change the list to `["a", "c"]`
3. `terraform plan` → `trap[1]` is **replaced** and `trap[2]` is **destroyed**

### Exercise 5: Fix the trap with `moved`

1. Reset the list to `["a", "b", "c"]` and `terraform apply`.
2. Change the resource to `for_each = toset(var.names)`, with `filename = "${path.module}/trap-${each.key}.txt"` and `content = each.key`.
3. Add `moved` blocks: `trap[0]` → `trap["a"]`, `trap[1]` → `trap["b"]`, `trap[2]` → `trap["c"]`.
4. `terraform plan` → only moves, **0 to add, 0 to destroy**.
5. Remove `"b"` → only `trap["b"]` is destroyed.

### Exercise 6: Map of objects

```hcl
variable "notes" {
  default = {
    terraform = { level = "intermediate", pages = 40 }
    pyspark   = { level = "advanced",     pages = 25 }
  }
}

resource "local_file" "notes" {
  for_each = var.notes
  filename = "${path.module}/${each.key}-notes.txt"
  content  = "Topic: ${each.key}, level: ${each.value.level}, pages: ${each.value.pages}"
}

output "note_files" {
  value = { for k, f in local_file.notes : k => f.filename }
}
```

### Exercise 7: `depends_on`

```hcl
resource "local_file" "first" {
  filename = "${path.module}/first.txt"
  content  = "I am created first"
}

resource "local_file" "second" {
  filename   = "${path.module}/second.txt"
  content    = "I wait for first.txt"
  depends_on = [local_file.first]
}
```

Watch the log: `first` finishes **before** `second` starts.

### Exercise 8: `prevent_destroy`

Add inside `local_file.first`:

```hcl
lifecycle {
  prevent_destroy = true
}
```

```bash
terraform destroy     # Error: Instance cannot be destroyed
```

Remove the `lifecycle` block, then `terraform destroy` works.

### Exercise 9: `ignore_changes`

```hcl
resource "local_file" "ignored" {
  filename = "${path.module}/ignored.txt"
  content  = "version 1"

  lifecycle {
    ignore_changes = [content]
  }
}
```

1. `terraform apply`
2. Change `content` to `"version 2"`
3. `terraform plan` → **No changes**

### Exercise 10: `replace_triggered_by` with `terraform_data`

```hcl
variable "app_version" {
  default = "1.0"
}

resource "terraform_data" "version" {
  input = var.app_version
}

resource "local_file" "app" {
  filename = "${path.module}/app.txt"
  content  = "static content"

  lifecycle {
    replace_triggered_by = [terraform_data.version]
  }
}
```

```bash
terraform apply
terraform plan -var="app_version=2.0"    # local_file.app will be replaced
```

### Exercise 11: `precondition`

```hcl
variable "environment" {
  default = "dev"
}

resource "local_file" "env" {
  filename = "${path.module}/env.txt"
  content  = var.environment

  lifecycle {
    precondition {
      condition     = contains(["dev", "prod"], var.environment)
      error_message = "Environment must be dev or prod."
    }
  }
}
```

```bash
terraform plan -var="environment=qa"     # fails with your message
```

### Clean up

```bash
terraform destroy
```

---

# Common Errors

| Error | Cause | Fix |
|---|---|---|
| `Missing resource instance key` | Referencing `resource.name.attr` on a `count`/`for_each` resource | Add `[0]`, `["key"]`, `[*]`, or a `for` expression |
| `Invalid for_each argument ... type tuple` | Passed a list | `toset()` or convert to a map |
| `Invalid for_each argument ... cannot be determined until apply` | Keys depend on new resource attributes | Use static keys; put unknowns in values |
| `Invalid count argument ... cannot be determined until apply` | `count` depends on unknown values | Base `count` on variables/known values |
| `"count" and "for_each" ... mutually exclusive` | Both in one block | Use one |
| `Instance cannot be destroyed` | `prevent_destroy = true` | Remove it intentionally, or don't replace/destroy |
| `Variables may not be used here` | Variable inside `lifecycle` setting | Use a literal |
| `Invalid index` | `[0]` on a resource with `count = 0` | Use `one(resource[*].attr)` |
| `BucketAlreadyExists` during replace | `create_before_destroy` with fixed name | Use `name_prefix` or generated names |
| `Unsupported attribute` on `for_each` splat | `resource[*]` on a map | Use `values(resource)[*]` or a `for` expression |
| `Module ... contains provider configuration` | Using `count`/`for_each` on a module with provider blocks | Move providers to the root; pass with `providers` |

---

# Common Mistakes

| Mistake | Fix |
|---|---|
| Using `count` for named items | Use `for_each` |
| Removing middle items from a `count` list | Use `for_each`, or plan carefully |
| Changing `for_each` keys casually | Changing a key = destroy + create; use `moved` |
| Switching `count` → `for_each` without `moved` | Add `moved` blocks to avoid recreation |
| Adding `depends_on` everywhere | Use references; `depends_on` only for hidden dependencies |
| Quotes in `depends_on`, `provider`, `ignore_changes` | Write references without quotes |
| Variables inside `lifecycle` settings | Use literal values |
| Thinking `prevent_destroy` survives deleting the block | It's removed with the block |
| `ignore_changes` and expecting your own code changes to apply | Ignored attributes are ignored both ways |
| `provider` (singular) on a module | Modules use `providers = { aws = aws.us_east }` |
| `provider` blocks inside child modules | Keep them in the root; use `configuration_aliases` |
| Confusing `dynamic` with meta-argument `for_each` | `dynamic` repeats nested blocks, not resources |

---

# Interview Questions

### Q1. What are meta-arguments in Terraform?

> Special arguments built into Terraform that work on any resource, whatever the provider. They control how Terraform creates and manages resources: `count`, `for_each`, `depends_on`, `provider`, and `lifecycle`.

### Q2. What is the difference between `count` and `for_each`?

> `count` creates N copies tracked by position and uses `count.index`. `for_each` creates one copy per item in a map or set, tracked by key, and uses `each.key` and `each.value`. `for_each` is safer when items may be added or removed.

### Q3. Why is `for_each` preferred over `count` for named resources?

> With `count`, removing a middle item shifts positions, so other resources get changed or destroyed. With `for_each`, each item is tracked by its key, so only the removed item is affected.

### Q4. How do you create a resource only under a condition?

> `count = var.condition ? 1 : 0`, and reference it safely with `one(resource[*].attr)`.

### Q5. What does `for_each` accept, and what are its restrictions?

> A map or a set of strings. Keys must be known before apply, values can't be sensitive, and it can't be combined with `count`. Lists are converted with `toset()` or into a map with a `for` expression.

### Q6. How do you loop over a list of objects with `for_each`?

> Convert it to a map with a unique key: `for_each = { for u in var.users : u.name => u }`.

### Q7. How do you create nested combinations, such as every user for every bucket?

> Use `flatten` (or `setproduct`) to build a list of pairs, convert it to a map with a unique composite key, then use `for_each`.

### Q8. When do you need `depends_on`, and what's the downside?

> Only for hidden dependencies that references don't express, such as IAM policy attachments needed before a Lambda runs. Overusing it, especially on data sources and modules, causes more unknown values and slower, noisier plans.

### Q9. How do you deploy to two regions or accounts in one configuration?

> Define extra provider blocks with `alias` (and `assume_role` for other accounts), then set `provider = aws.<alias>` on resources or `providers = { ... }` on modules. Modules needing multiple providers declare `configuration_aliases`.

### Q10. Explain all `lifecycle` options.

> `create_before_destroy` creates the replacement first; `prevent_destroy` blocks deletion; `ignore_changes` ignores drift on listed attributes; `replace_triggered_by` forces replacement when another resource changes; `precondition` and `postcondition` enforce custom rules.

### Q11. Why can `create_before_destroy` fail?

> Old and new resources exist at the same time, so fixed unique names conflict. Use name prefixes or generated names.

### Q12. How do you switch from `count` to `for_each` without recreating resources?

> Add `moved` blocks mapping each `[index]` address to its new `["key"]` address, or use `terraform state mv`.

### Q13. How do you import multiple existing resources into a `for_each` resource?

> Use an `import` block with `for_each` (Terraform 1.7+), mapping each key to its import ID.

### Q14. What is the difference between meta-argument `for_each` and a `dynamic` block?

> Meta-argument `for_each` repeats whole resources or modules. A `dynamic` block repeats nested blocks inside a single resource, such as security group ingress rules.

### Q15. Which meta-arguments work on modules?

> `count`, `for_each`, `depends_on`, and `providers`. `lifecycle` doesn't, and modules with their own provider blocks can't use `count`, `for_each`, or `depends_on`.

---

# Quick Revision

- Meta-arguments = Terraform's **own** arguments; they work on **any** resource.
- `count = N` → `[0]`, `[1]`...; `count.index`; `[*]` for all.
- `count = condition ? 1 : 0` → on/off; read with `one(resource[*].attr)`.
- `for_each` = map or set → `["key"]`; `each.key` / `each.value`.
- Lists → `toset()`; list of objects → `{ for x in list : x.name => x }`.
- Keys must be known before apply and not sensitive.
- Named items → `for_each`; identical copies / switch → `count`; never both.
- Nested combinations → `flatten` or `setproduct` → map → `for_each`.
- Chain resources with `for_each = aws_s3_bucket.this`.
- References create dependencies; `depends_on` only for hidden ones (costly on data/modules).
- `provider = aws.alias`; modules use `providers = {}`; multi-provider modules use `configuration_aliases`.
- `lifecycle`: `create_before_destroy`, `prevent_destroy`, `ignore_changes` (can target map keys), `replace_triggered_by` (+ `terraform_data`), `precondition`/`postcondition`.
- Lifecycle settings must be static; conditions can use expressions.
- `count` → `for_each` migration: `moved` blocks. Bulk import: `import` with `for_each`.
- `dynamic` blocks repeat nested blocks, not resources.
- Quote instance addresses carefully in the CLI.

---

## One-Line Summary

> Meta-arguments are Terraform's built-in controls: `count` and `for_each` create multiple copies (use `for_each` for named items), `depends_on` handles hidden ordering, `provider` targets other regions or accounts, and `lifecycle` controls replacement, protection, drift, and custom checks, with `moved` and `import` blocks letting you refactor safely.

---

## Official References

- https://developer.hashicorp.com/terraform/language/meta-arguments/count
- https://developer.hashicorp.com/terraform/language/meta-arguments/for_each
- https://developer.hashicorp.com/terraform/language/meta-arguments/depends_on
- https://developer.hashicorp.com/terraform/language/meta-arguments/resource-provider
- https://developer.hashicorp.com/terraform/language/meta-arguments/module-providers
- https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle
- https://developer.hashicorp.com/terraform/language/expressions/custom-conditions
- https://developer.hashicorp.com/terraform/language/expressions/dynamic-blocks
- https://developer.hashicorp.com/terraform/language/modules/develop/refactoring
- https://developer.hashicorp.com/terraform/language/import
- https://developer.hashicorp.com/terraform/language/resources/terraform-data
