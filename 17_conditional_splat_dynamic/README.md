# Terraform Notes - Conditional Expressions, Splat Expressions and Dynamic Blocks (Beginner to Pro)

## Table of Contents

1. [Big Picture](#big-picture)
2. [Part 1: Conditional Expressions](#part-1-conditional-expressions)
3. [Part 2: Splat Expressions](#part-2-splat-expressions)
4. [Part 3: Dynamic Blocks](#part-3-dynamic-blocks)
5. [Part 4: Using All Three Together (Pro)](#part-4-using-all-three-together-pro)
6. [Part 5: Hands-on Practice (Free, No Cloud Account)](#part-5-hands-on-practice-free-no-cloud-account)
7. [Common Errors](#common-errors)
8. [Common Mistakes](#common-mistakes)
9. [Interview Questions](#interview-questions)
10. [Quick Revision](#quick-revision)

---

# Big Picture

These three features make Terraform code **smart and short** instead of long and copy-pasted.

| Feature | Simple meaning | Python equivalent | Example |
|---|---|---|---|
| **Conditional expression** | "If this, use A, otherwise B" | `a if cond else b` | `var.env == "prod" ? "t3.large" : "t3.micro"` |
| **Splat expression** | "Give me this attribute from **every** item in a list" | `[x.id for x in items]` | `aws_instance.web[*].id` |
| **Dynamic block** | "Repeat this **nested block** once per item" | a loop that writes config | `dynamic "ingress" { ... }` |

```text
Conditional  ->  choose ONE value
Splat        ->  collect values from MANY items
Dynamic      ->  generate MANY nested blocks
```

---

# Part 1: Conditional Expressions

## 1.1 Syntax

```hcl
condition ? true_value : false_value
```

| Part | Meaning |
|---|---|
| `condition` | Any expression that gives `true` or `false` |
| `?` | "then" |
| `true_value` | Used when the condition is `true` |
| `:` | "else" |
| `false_value` | Used when the condition is `false` |

> This is called the **ternary operator**. Terraform has **no `if/else` statement**. The conditional expression is how you make decisions.

### Python comparison

```python
instance_type = "t3.large" if environment == "prod" else "t3.micro"
```

```hcl
instance_type = var.environment == "prod" ? "t3.large" : "t3.micro"
```

---

## 1.2 Your First Conditional (AWS)

```hcl
variable "environment" {
  type    = string
  default = "dev"
}

resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = var.environment == "prod" ? "t3.large" : "t3.micro"

  tags = {
    Name = "web-${var.environment}"
  }
}
```

| `environment` | `instance_type` |
|---|---|
| `dev` | `t3.micro` |
| `staging` | `t3.micro` |
| `prod` | `t3.large` |

---

## 1.3 Operators You Can Use in Conditions

### Comparison operators

| Operator | Meaning | Example |
|---|---|---|
| `==` | Equal | `var.env == "prod"` |
| `!=` | Not equal | `var.env != "dev"` |
| `>` `<` | Greater / less than | `var.count > 2` |
| `>=` `<=` | Greater/less or equal | `var.size >= 20` |

### Logical operators

| Operator | Meaning | Example |
|---|---|---|
| `&&` | AND (both true) | `var.env == "prod" && var.ha_enabled` |
| `\|\|` | OR (at least one true) | `var.env == "prod" \|\| var.env == "staging"` |
| `!` | NOT (flip) | `!var.is_public` |

### Bool variables don't need `== true`

```hcl
# ❌ Works, but unnecessary
count = var.create_bucket == true ? 1 : 0

# ✅ Cleaner
count = var.create_bucket ? 1 : 0
```

### Functions that return true/false (great for conditions)

| Function | Example | Returns `true` when |
|---|---|---|
| `contains()` | `contains(["dev", "test"], var.env)` | The list has the value |
| `length()` | `length(var.subnets) > 0` | The list isn't empty |
| `can()` | `can(regex("^t3\\.", var.type))` | The expression works without error |
| `startswith()` | `startswith(var.name, "ashish-")` | String starts with text (Terraform 1.3+) |
| `endswith()` | `endswith(var.file, ".json")` | String ends with text (Terraform 1.3+) |
| `anytrue()` / `alltrue()` | `alltrue([var.a, var.b])` | Any / all items are true |

---

## 1.4 Where Can You Use Conditionals?

**Anywhere a value is expected**: resource arguments, locals, outputs, `count`, `for_each`, module inputs, and dynamic blocks.

### In `locals` (cleanest place)

```hcl
locals {
  is_prod        = var.environment == "prod"
  instance_type  = local.is_prod ? "t3.large" : "t3.micro"
  instance_count = local.is_prod ? 3 : 1
  log_retention  = local.is_prod ? 90 : 7
}
```

> 💡 **Pro habit:** compute `is_prod` once in `locals`, then reuse it. Your resources stay short and readable.

### In outputs

```hcl
output "environment_label" {
  value = local.is_prod ? "PRODUCTION" : "NON-PRODUCTION"
}
```

### Inside strings

```hcl
bucket = "ashish-${var.environment}-${local.is_prod ? "critical" : "temp"}-2026"
```

---

## 1.5 Conditional + `count` = Create a Resource Only Sometimes

The most famous Terraform pattern:

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

- `true` → `count = 1` → created
- `false` → `count = 0` → not created

### Read it safely

```hcl
output "optional_bucket_arn" {
  value = one(aws_s3_bucket.optional[*].arn)   # ARN, or null when not created
}
```

> ❌ `aws_s3_bucket.optional[0].arn` fails with **Invalid index** when `count = 0`.

### Same idea on modules

```hcl
module "monitoring" {
  source = "./modules/monitoring"
  count  = var.enable_monitoring ? 1 : 0
}
```

---

## 1.6 Conditional + `for_each`

```hcl
resource "aws_s3_bucket" "extra" {
  for_each = var.create_extra_buckets ? toset(["logs", "backup"]) : toset([])
  bucket   = "ashish-${each.key}-2026"
}
```

> Both sides must be the **same type**. `toset([...])` and `toset([])` match. Writing `[]` on one side and a map on the other causes a type error.

### Pick a different map per environment

```hcl
locals {
  buckets = local.is_prod ? {
    logs   = "ashish-prod-logs-2026"
    data   = "ashish-prod-data-2026"
    backup = "ashish-prod-backup-2026"
  } : {
    logs = "ashish-dev-logs-2026"
  }
}
```

---

## 1.7 Using `null` to Skip an Argument

If an argument is set to `null`, Terraform behaves **as if you never wrote it**, so the provider's default is used.

```hcl
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = "t3.micro"

  # Only prod gets a key pair; elsewhere the argument is omitted
  key_name = local.is_prod ? "ashish-prod-key" : null
}
```

```hcl
resource "aws_db_instance" "db" {
  # ...
  # Only take a final snapshot in prod
  skip_final_snapshot       = !local.is_prod
  final_snapshot_identifier = local.is_prod ? "ashish-db-final-snapshot" : null
}
```

> `null` is one of the most useful tools for **optional arguments**.

---

## 1.8 Nested Conditionals (Multiple Choices)

```hcl
locals {
  instance_type = (
    var.environment == "prod"    ? "t3.large" :
    var.environment == "staging" ? "t3.small" :
                                   "t3.micro"
  )
}
```

Reads like:

```text
if prod -> t3.large
else if staging -> t3.small
else -> t3.micro
```

### ✅ Better for many choices: a map lookup

```hcl
locals {
  instance_types = {
    dev     = "t3.micro"
    staging = "t3.small"
    prod    = "t3.large"
  }

  instance_type = lookup(local.instance_types, var.environment, "t3.micro")
}
```

| Approach | Use when |
|---|---|
| Single `? :` | Two choices |
| Nested `? :` | Three choices, maybe four |
| Map + `lookup()` or `[key]` | Many choices; easiest to read and extend |

> `local.instance_types[var.environment]` also works, but **fails** for unknown keys. `lookup()` with a default never fails.

---

## 1.9 Type Rules (Important)

Both results must be **convertible to one common type**.

```hcl
# ✅ Both strings
var.enabled ? "yes" : "no"

# ✅ Number and string -> Terraform converts 5 to "5" (string)
var.enabled ? 5 : "none"

# ❌ Object vs string -> error
var.enabled ? { name = "a" } : "none"
```

Error:

```text
Error: Inconsistent conditional result types

The true and false result expressions must have consistent types.
```

### Fixes

```hcl
# Use null instead of a different type
var.enabled ? { name = "a" } : null

# Convert explicitly
var.enabled ? tostring(var.port) : "none"

# Make both sides lists of the same element type
var.enabled ? ["a", "b"] : []
```

### Pro: object type mismatches

```hcl
# ❌ Objects with different attributes are different types
local.is_prod ? { size = 100, iops = 3000 } : { size = 20 }

# ✅ Give both sides the same attributes
local.is_prod ? { size = 100, iops = 3000 } : { size = 20, iops = null }
```

> Only the **selected** branch's value is used, but Terraform still checks that **both** branches have compatible types.

---

## 1.10 Safer Alternatives to Conditionals

| Problem | Instead of a conditional | Use |
|---|---|---|
| "Use A, but if it's empty/null use B" | `var.name != null && var.name != "" ? var.name : "default"` | `coalesce(var.name, "default")` |
| "Try this; if it errors, use a fallback" | complex checks | `try(var.config.port, 8080)` |
| "Get a map value with a fallback" | `contains(keys(m), k) ? m[k] : d` | `lookup(m, k, d)` |
| "First item of a 0/1 list or null" | `length(x) > 0 ? x[0] : null` | `one(x)` |
| "Validate a value" | runtime conditional | `validation` block |

### Pro caution: `&&` and `||` evaluation

In older Terraform versions, **both sides** of `&&` / `||` are evaluated, even when the result is already decided:

```hcl
# ❌ Can fail in older versions when var.config is null
var.config != null && var.config.enabled
```

Newer Terraform versions short-circuit logical operators, but safe patterns work everywhere:

```hcl
# ✅ Works in all versions
try(var.config.enabled, false)

# ✅ or a nested conditional
var.config == null ? false : var.config.enabled
```

---

## 1.11 Conditionals in Validation and Preconditions

```hcl
variable "environment" {
  type = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

resource "aws_instance" "web" {
  # ...
  lifecycle {
    precondition {
      condition     = var.environment != "prod" || var.instance_type != "t2.micro"
      error_message = "Production must not use t2.micro."
    }
  }
}
```

---

# Part 2: Splat Expressions

## 2.1 What is a Splat?

A **splat expression** takes a **list of objects** and returns a **list of one attribute** from every object.

```hcl
aws_instance.web[*].id
```

Means: "Give me the `id` of **every** `aws_instance.web`."

### Python comparison

```python
ids = [instance.id for instance in instances]
```

```hcl
ids = aws_instance.web[*].id
```

### The splat is a shortcut for a `for` expression

```hcl
aws_instance.web[*].id
# is the same as
[for i in aws_instance.web : i.id]
```

---

## 2.2 Splat with `count` Resources

```hcl
resource "aws_instance" "web" {
  count         = 3
  ami           = var.ami_id
  instance_type = "t3.micro"
}

output "instance_ids" {
  value = aws_instance.web[*].id
}

output "private_ips" {
  value = aws_instance.web[*].private_ip
}
```

```text
instance_ids = [
  "i-0abc111...",
  "i-0abc222...",
  "i-0abc333...",
]
```

### Common uses

```hcl
length(aws_instance.web)                       # how many
aws_instance.web[*].id                         # all IDs
join(",", aws_instance.web[*].private_ip)      # "10.0.1.5,10.0.1.6,10.0.1.7"
aws_instance.web[*].tags["Name"]               # one tag from each
```

### Pass all IDs to another resource

```hcl
resource "aws_lb_target_group_attachment" "web" {
  count            = length(aws_instance.web)
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web[count.index].id
}
```

---

## 2.3 Splat on Variables and Lists of Objects

```hcl
variable "users" {
  default = [
    { name = "ashish", team = "data" },
    { name = "priya",  team = "devops" },
    { name = "rahul",  team = "data" },
  ]
}

locals {
  user_names = var.users[*].name   # ["ashish", "priya", "rahul"]
  user_teams = var.users[*].team   # ["data", "devops", "data"]
}
```

---

## 2.4 ⚠️ Splat Does NOT Work on `for_each` Resources

`for_each` resources are a **map**, not a list:

```hcl
resource "aws_s3_bucket" "this" {
  for_each = toset(["logs", "data"])
  bucket   = "ashish-${each.key}-2026"
}
```

```hcl
# ❌ Error
aws_s3_bucket.this[*].arn
```

### Fixes

```hcl
values(aws_s3_bucket.this)[*].arn                        # list of ARNs
[for b in aws_s3_bucket.this : b.arn]                    # list of ARNs
{ for k, b in aws_s3_bucket.this : k => b.arn }          # map: name => ARN ✅ best
```

| Resource uses | Get all values with |
|---|---|
| `count` | `resource[*].attr` |
| `for_each` | `values(resource)[*].attr` or a `for` expression |
| Neither (single) | `resource.attr` (or `resource[*].attr` → 1-item list) |

---

## 2.5 Splat on a Single Value (Pro Trick)

If you use `[*]` on something that is **not a list**:

| Value | Result of `value[*]` |
|---|---|
| An object | A list with **1** item: `[object]` |
| `null` | An **empty** list: `[]` |

### Why that's useful: optional objects → dynamic blocks

```hcl
variable "logging" {
  type = object({
    bucket = string
    prefix = string
  })
  default = null
}

resource "aws_s3_bucket_logging" "this" {
  # ...
}

# Inside a resource that has an optional nested "logging" block:
dynamic "logging" {
  for_each = var.logging[*]      # null -> [] (no block), object -> [object] (1 block)
  content {
    target_bucket = logging.value.bucket
    target_prefix = logging.value.prefix
  }
}
```

> `var.logging[*]` is a neat replacement for `var.logging == null ? [] : [var.logging]`.

---

## 2.6 Nested Splats and `flatten`

Each instance can have **several** network interfaces, so a splat gives a **list of lists**:

```hcl
aws_instance.web[*].network_interface[*].network_interface_id
```

```text
[
  ["eni-111", "eni-112"],
  ["eni-221"],
]
```

Use `flatten()` to make one flat list:

```hcl
flatten(aws_instance.web[*].network_interface[*].network_interface_id)
# ["eni-111", "eni-112", "eni-221"]
```

---

## 2.7 Full Splat `[*]` vs Legacy Splat `.*` (Pro)

Older code (Terraform 0.11 era) uses `.*`:

```hcl
aws_instance.web.*.id      # legacy "attribute-only" splat
aws_instance.web[*].id     # modern "full" splat ✅
```

For simple attributes, they give the **same** result. The difference appears with an **index** after the splat:

| Expression | Meaning |
|---|---|
| `var.list[*].tags[0]` | Take `tags[0]` from **each** item → list |
| `var.list.*.tags[0]` | Collect all `tags` lists, then take the **first** of that list |

```hcl
var.list[*].tags[0]   ==   [for v in var.list : v.tags[0]]
var.list.*.tags[0]    ==   [for v in var.list : v.tags][0]
```

> ✅ Always use `[*]` in new code. Treat `.*` as legacy.

---

## 2.8 Splat vs `for` Expression

| Need | Splat | `for` expression |
|---|---|---|
| One attribute from every item | ✅ `list[*].id` | `[for x in list : x.id]` |
| Filter items (`if`) | ❌ | ✅ `[for x in list : x.id if x.public]` |
| Change values | ❌ | ✅ `[for x in list : upper(x.name)]` |
| Build a map | ❌ | ✅ `{ for x in list : x.name => x.id }` |
| `for_each` resources | ❌ (directly) | ✅ |
| Optional object → 0/1 list | ✅ `obj[*]` | Longer |

> **Rule:** Splat for "grab one attribute from all". `for` for anything more.

---

# Part 3: Dynamic Blocks

## 3.1 The Problem: Repeated Nested Blocks

Some resources have **nested blocks** that repeat, like `ingress` rules in a security group:

```hcl
resource "aws_security_group" "web" {
  name   = "ashish-web-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

Copy-paste for every port. Adding a port means editing code.

> `count` and `for_each` repeat **whole resources**. They **can't** repeat a nested block inside one resource. That's what **dynamic blocks** are for.

---

## 3.2 Dynamic Block Syntax

```hcl
dynamic "<block_name>" {
  for_each = <collection>
  content {
    <arguments using <block_name>.value>
  }
}
```

| Part | Meaning |
|---|---|
| `dynamic "ingress"` | The **name of the nested block** to generate |
| `for_each` | Collection to loop over: list, set, map, or object |
| `content { }` | The body of **each** generated block |
| `ingress.value` | Current item (the iterator is named after the block) |
| `ingress.key` | Current index (list), key (map), or value (set) |

---

## 3.3 Your First Dynamic Block

### Simple list of ports

```hcl
variable "ingress_ports" {
  type    = list(number)
  default = [22, 80, 443]
}

resource "aws_security_group" "web" {
  name   = "ashish-web-sg"
  vpc_id = var.vpc_id

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

Terraform generates **3 `ingress` blocks**. Add `8080` to the list → a 4th block appears. No code change.

### List of objects (each rule has its own settings) ✅

```hcl
variable "ingress_rules" {
  type = list(object({
    port        = number
    description = string
    cidr_blocks = list(string)
  }))

  default = [
    { port = 22,  description = "SSH from VPC", cidr_blocks = ["10.0.0.0/16"] },
    { port = 80,  description = "HTTP",         cidr_blocks = ["0.0.0.0/0"] },
    { port = 443, description = "HTTPS",        cidr_blocks = ["0.0.0.0/0"] },
  ]
}

resource "aws_security_group" "web" {
  name   = "ashish-web-sg"
  vpc_id = var.vpc_id

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      description = ingress.value.description
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = "tcp"
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

> Static blocks (like `egress` here) and dynamic blocks can be **mixed** in the same resource.

---

## 3.4 `.key` and `.value` for Each Collection Type

| `for_each` is a | `.key` | `.value` |
|---|---|---|
| List `["a", "b"]` | Index: `0`, `1` | `"a"`, `"b"` |
| Set `toset(["a", "b"])` | Same as value | `"a"`, `"b"` |
| Map `{ ssh = 22 }` | `"ssh"` | `22` |

### Map example

```hcl
variable "ingress_map" {
  default = {
    ssh   = 22
    http  = 80
    https = 443
  }
}

dynamic "ingress" {
  for_each = var.ingress_map
  content {
    description = ingress.key        # "ssh", "http", "https"
    from_port   = ingress.value      # 22, 80, 443
    to_port     = ingress.value
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

> Unlike meta-argument `for_each`, a dynamic block's `for_each` **accepts lists** directly.

---

## 3.5 Custom Iterator Name (`iterator`)

By default the iterator is named after the block (`ingress.value`). Rename it with `iterator`:

```hcl
dynamic "ingress" {
  for_each = var.ingress_rules
  iterator = rule

  content {
    from_port   = rule.value.port
    to_port     = rule.value.port
    protocol    = "tcp"
    cidr_blocks = rule.value.cidr_blocks
  }
}
```

Useful for **readability** and **required** for nested dynamic blocks that would otherwise have confusing names.

---

## 3.6 Optional Nested Blocks (0 or 1 Block)

A very common pro pattern: include a nested block **only when enabled**.

### With a bool

```hcl
dynamic "ebs_block_device" {
  for_each = var.add_data_disk ? [1] : []
  content {
    device_name = "/dev/sdf"
    volume_size = 50
    volume_type = "gp3"
  }
}
```

- `true` → `[1]` → **1** block
- `false` → `[]` → **0** blocks

> The `1` is just a placeholder. Any single-item list works; the value isn't used.

### With an optional object (no separate bool needed)

```hcl
variable "data_disk" {
  type = object({
    size = number
    type = string
  })
  default = null
}

dynamic "ebs_block_device" {
  for_each = var.data_disk == null ? [] : [var.data_disk]
  # or simply: for_each = var.data_disk[*]
  content {
    device_name = "/dev/sdf"
    volume_size = ebs_block_device.value.size
    volume_type = ebs_block_device.value.type
  }
}
```

---

## 3.7 Nested Dynamic Blocks

Dynamic blocks can be placed **inside** other dynamic blocks.

### Example: S3 lifecycle rules, each with several transitions

```hcl
variable "lifecycle_rules" {
  default = [
    {
      id          = "logs"
      prefix      = "logs/"
      expire_days = 365
      transitions = [
        { days = 30, storage_class = "STANDARD_IA" },
        { days = 90, storage_class = "GLACIER" },
      ]
    },
    {
      id          = "tmp"
      prefix      = "tmp/"
      expire_days = 7
      transitions = []
    },
  ]
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.data.id

  dynamic "rule" {
    for_each = var.lifecycle_rules
    iterator = r

    content {
      id     = r.value.id
      status = "Enabled"

      filter {
        prefix = r.value.prefix
      }

      expiration {
        days = r.value.expire_days
      }

      dynamic "transition" {
        for_each = r.value.transitions
        iterator = t

        content {
          days          = t.value.days
          storage_class = t.value.storage_class
        }
      }
    }
  }
}
```

Result:

```text
rule "logs" -> 2 transition blocks + expiration
rule "tmp"  -> 0 transition blocks + expiration
```

> The inner dynamic block can read the outer iterator (`r.value.transitions`). Custom iterator names (`r`, `t`) keep it readable.

---

## 3.8 Filtering and Transforming Inside `for_each`

Use a `for` expression to filter which blocks are generated:

```hcl
dynamic "ingress" {
  # Only public rules in non-prod; all rules in prod
  for_each = [
    for r in var.ingress_rules : r
    if local.is_prod || r.port != 22
  ]
  content {
    from_port   = ingress.value.port
    to_port     = ingress.value.port
    protocol    = "tcp"
    cidr_blocks = ingress.value.cidr_blocks
  }
}
```

---

## 3.9 `labels` (Rare)

A few nested block types have **labels**. `labels` sets them for each generated block:

```hcl
dynamic "setting" {
  for_each = var.settings
  labels   = [setting.key]
  content {
    value = setting.value
  }
}
```

> Most AWS resource nested blocks have **no labels**, so you'll rarely need this.

---

## 3.10 Where Dynamic Blocks Work (and Don't)

| ✅ Can generate | ❌ Cannot generate |
|---|---|
| Nested blocks inside `resource` | Top-level blocks (`resource`, `module`, `variable`) |
| Nested blocks inside `data` | `lifecycle` blocks |
| Nested blocks inside `provider` | `provisioner` blocks |
| Nested blocks inside `provisioner` | Normal **arguments** (only blocks) |

### Block vs argument: why it matters

```hcl
tags = {               # ← argument (has "="), use a map, NOT a dynamic block
  Name = "web"
}

ingress {              # ← nested block (no "="), can be dynamic
  from_port = 80
}
```

> Check the provider docs. If it's written `name = { }`, it's an argument. If it's `name { }`, it's a block.

---

## 3.11 Dynamic Block vs Meta-Argument `for_each`

| | Meta-argument `for_each` | `dynamic` block |
|---|---|---|
| Repeats | Whole **resources/modules** | **Nested blocks** inside one resource |
| Result | Many resources in state | One resource with many blocks |
| Accepts lists | ❌ (map or set of strings) | ✅ |
| Iterator | `each.key`, `each.value` | `<block>.key`, `<block>.value` |
| Address | `aws_x.name["key"]` | Still one `aws_x.name` |

### Example: separate rules vs inline rules

```hcl
# Option A: one SG with dynamic inline rules
resource "aws_security_group" "web" {
  dynamic "ingress" { ... }
}

# Option B: separate rule resources with for_each
resource "aws_vpc_security_group_ingress_rule" "web" {
  for_each          = { for r in var.ingress_rules : tostring(r.port) => r }
  security_group_id = aws_security_group.web.id
  from_port         = each.value.port
  to_port           = each.value.port
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value.cidr_blocks[0]
}
```

> AWS now recommends **separate rule resources** (Option B) for security groups. Dynamic blocks are still perfect for resources that only support nested blocks, like lifecycle rules, EBS devices, or `setting` blocks.

---

## 3.12 When NOT to Use Dynamic Blocks

- **Fixed, small, known blocks** → write them normally. Static is easier to read.
- **Deeply nested dynamic-in-dynamic-in-dynamic** → hard to debug. Consider a module or simpler variables.
- **Hiding everything behind variables** → a resource that is 100% dynamic can be hard for teammates to understand.

> HashiCorp's own advice: use dynamic blocks **only when needed** to hide details for a clean module interface. Overuse makes code harder to read.

---

# Part 4: Using All Three Together (Pro)

A reusable web-server setup that uses a **conditional**, a **splat**, and **dynamic blocks**.

### `variables.tf`

```hcl
variable "environment" {
  type    = string
  default = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "ingress_rules" {
  type = list(object({
    port        = number
    cidr_blocks = list(string)
  }))
  default = [
    { port = 80,  cidr_blocks = ["0.0.0.0/0"] },
    { port = 443, cidr_blocks = ["0.0.0.0/0"] },
  ]
}

variable "enable_ssh" {
  type    = bool
  default = false
}

variable "data_disk" {
  type = object({
    size = number
  })
  default = null
}
```

### `locals.tf`

```hcl
locals {
  is_prod        = var.environment == "prod"
  instance_type  = local.is_prod ? "t3.large" : "t3.micro"     # conditional
  instance_count = local.is_prod ? 3 : 1                       # conditional

  # conditional list: add SSH only when enabled
  all_ingress_rules = concat(
    var.ingress_rules,
    var.enable_ssh ? [{ port = 22, cidr_blocks = ["10.0.0.0/16"] }] : []
  )
}
```

### `main.tf`

```hcl
resource "aws_security_group" "web" {
  name   = "ashish-${var.environment}-web-sg"
  vpc_id = var.vpc_id

  dynamic "ingress" {                                          # dynamic block
    for_each = local.all_ingress_rules
    content {
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = "tcp"
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "web" {
  count                  = local.instance_count
  ami                    = var.ami_id
  instance_type          = local.instance_type
  vpc_security_group_ids = [aws_security_group.web.id]
  monitoring             = local.is_prod                       # bool from conditional
  key_name               = local.is_prod ? "ashish-prod-key" : null

  dynamic "ebs_block_device" {                                 # optional block
    for_each = var.data_disk[*]
    content {
      device_name = "/dev/sdf"
      volume_size = ebs_block_device.value.size
      volume_type = "gp3"
    }
  }

  tags = {
    Name = "ashish-${var.environment}-web-${count.index}"
  }
}
```

### `outputs.tf`

```hcl
output "instance_ids" {
  value = aws_instance.web[*].id                               # splat
}

output "private_ips" {
  value = aws_instance.web[*].private_ip                       # splat
}

output "first_instance_id" {
  value = one(slice(aws_instance.web[*].id, 0, 1))             # safe first item
}
```

| Setting | dev | prod |
|---|---|---|
| Instance type | `t3.micro` | `t3.large` |
| Instance count | 1 | 3 |
| Detailed monitoring | off | on |
| Key pair | none (`null`) | `ashish-prod-key` |
| SSH rule | only if `enable_ssh = true` | only if `enable_ssh = true` |
| Data disk | only if `data_disk` is set | only if `data_disk` is set |

---

# Part 5: Hands-on Practice (Free, No Cloud Account)

## 5.1 Practise Conditionals and Splats in `terraform console`

Open an empty folder:

```bash
terraform console
```

```text
> "prod" == "prod" ? "t3.large" : "t3.micro"
"t3.large"

> 5 > 3 && "a" != "b"
true

> contains(["dev", "test"], "qa") ? "known" : "unknown"
"unknown"

> lookup({ dev = "t3.micro", prod = "t3.large" }, "staging", "t3.small")
"t3.small"

> coalesce("", "fallback")
"fallback"

> [{ name = "ashish" }, { name = "priya" }][*].name
[
  "ashish",
  "priya",
]

> { name = "single" }[*]
[
  {
    "name" = "single"
  },
]

> flatten([["a", "b"], ["c"]])
[
  "a",
  "b",
  "c",
]

> [for n in [1, 2, 3, 4] : n if n % 2 == 0]
[
  2,
  4,
]

> true ? { a = 1 } : "x"
```

The last one shows the **Inconsistent conditional result types** error.

> `null[*]` can't be typed directly in the console, but a variable that is `null` gives `[]` with `[*]`. Try it in Exercise 5.3.

---

## 5.2 Conditional + Splat with `local_file`

### `versions.tf`

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}
```

### `main.tf`

```hcl
variable "environment" {
  default = "dev"
}

variable "create_notes" {
  type    = bool
  default = true
}

locals {
  is_prod    = var.environment == "prod"
  file_count = local.is_prod ? 3 : 1
}

resource "local_file" "env" {
  count    = local.file_count
  filename = "${path.module}/${var.environment}-file-${count.index}.txt"
  content  = local.is_prod ? "PRODUCTION file ${count.index}" : "dev file ${count.index}"
}

resource "local_file" "notes" {
  count    = var.create_notes ? 1 : 0
  filename = "${path.module}/notes.txt"
  content  = "Optional notes file"
}

output "env_files" {
  value = local_file.env[*].filename          # splat
}

output "notes_file" {
  value = one(local_file.notes[*].filename)   # null when not created
}
```

```bash
terraform init
terraform apply                                   # 1 dev file + notes
terraform apply -var="environment=prod"           # 3 prod files
terraform apply -var="create_notes=false"         # notes removed, output null
terraform output
```

---

## 5.3 Dynamic Blocks with `archive_file` (Free)

The `archive_file` data source has repeatable nested `source { }` blocks, which makes it perfect for practising dynamic blocks locally.

### Add to `main.tf`

```hcl
variable "zip_files" {
  default = {
    "readme.txt" = "Terraform dynamic block practice"
    "config.txt" = "environment=dev"
    "notes.txt"  = "Splat, conditionals and dynamic blocks"
  }
}

variable "extra_file" {
  type = object({
    name    = string
    content = string
  })
  default = null
}

data "archive_file" "bundle" {
  type        = "zip"
  output_path = "${path.module}/bundle.zip"

  # One source block per map entry
  dynamic "source" {
    for_each = var.zip_files
    content {
      filename = source.key
      content  = source.value
    }
  }

  # Optional block: 0 when null, 1 when set (splat on a single value)
  dynamic "source" {
    for_each = var.extra_file[*]
    iterator = extra
    content {
      filename = extra.value.name
      content  = extra.value.content
    }
  }
}

output "zip_path" {
  value = data.archive_file.bundle.output_path
}

output "zip_size_bytes" {
  value = data.archive_file.bundle.output_size
}
```

```bash
terraform init -upgrade
terraform apply
```

Open `bundle.zip`: it contains **3 files**.

### Exercises

1. Add a 4th entry to `zip_files` → apply → the zip has 4 files. **No block code changed.**
2. Apply with the optional block:

   ```bash
   terraform apply -var='extra_file={name="extra.txt",content="I am optional"}'
   ```

   **PowerShell 5.1:**

   ```powershell
   terraform apply -var='extra_file={name=\"extra.txt\",content=\"I am optional\"}'
   ```

3. Apply again without the variable → `extra.txt` disappears.
4. Change `for_each = var.zip_files` to a filtered map:

   ```hcl
   for_each = { for k, v in var.zip_files : k => v if k != "config.txt" }
   ```

   → `config.txt` is excluded.

### Clean up

```bash
terraform destroy
```

> `bundle.zip` is created by a data source, so delete it manually if it remains.

---

# Common Errors

| Error | Cause | Fix |
|---|---|---|
| `Inconsistent conditional result types` | True/false values have different types | Use `null`, `tostring()`, or matching object attributes |
| `Invalid index` | `resource[0]` when `count = 0` | `one(resource[*].attr)` |
| `Unsupported attribute` / splat error on `for_each` resource | `[*]` on a map | `values(resource)[*].attr` or a `for` expression |
| `Missing resource instance key` | `resource.attr` on a `count`/`for_each` resource | Use `[0]`, `["key"]`, or `[*]` |
| `Unsupported block type` in dynamic | Block name doesn't exist in that resource | Check provider docs for the nested block name |
| `Unsupported argument` inside `content` | Wrong attribute name | Check provider docs |
| `Reference to undeclared resource` with iterator | Using `each.value` inside a dynamic block | Use `<block_name>.value` or the `iterator` name |
| `Invalid dynamic for_each value` | `for_each` is null or a string | Use a list/map/set; `[]` for none |
| `Blocks of type "tags" are not expected here` | Treating an argument as a block | Use `tags = { }` (map), not `dynamic "tags"` |
| Error accessing attribute of `null` in `&&` | Both sides evaluated (older versions) | `try()` or a nested conditional |

---

# Common Mistakes

| Mistake | Fix |
|---|---|
| Writing `if/else` statements | Use `condition ? a : b` |
| `var.flag == true ? ...` | Just `var.flag ? ...` |
| Long nested conditionals | Use a map with `lookup()` |
| Repeating `var.environment == "prod"` everywhere | Compute `local.is_prod` once |
| `resource[0].attr` for optional resources | `one(resource[*].attr)` |
| Splat on `for_each` resources | `values()` or `for` expressions |
| Using legacy `.*` in new code | Use `[*]` |
| Using `each.value` inside a dynamic block | Use `<block_name>.value` |
| Using dynamic blocks for `tags` | `tags` is an argument; use a map |
| Trying to make `lifecycle` dynamic | Not supported; lifecycle must be static |
| Dynamic blocks for 1–2 fixed blocks | Write them statically |
| Deeply nested dynamic blocks without iterator names | Use `iterator` for readability |

---

# Interview Questions

### Q1. What is a conditional expression in Terraform?

> A ternary expression, `condition ? true_value : false_value`, that chooses between two values. Terraform has no if/else statements, so this is how decisions are made.

### Q2. How do you create a resource only in some environments?

> Use `count = var.condition ? 1 : 0`, and read it with `one(resource[*].attr)` so it returns `null` when not created.

### Q3. What happens if the two results of a conditional have different types?

> Terraform tries to convert them to a common type. If it can't, such as an object and a string, it fails with "Inconsistent conditional result types". Use `null` or explicit conversion.

### Q4. How do you omit an argument conditionally?

> Set it to `null` in the false case, for example `key_name = local.is_prod ? "prod-key" : null`. Terraform treats `null` as if the argument wasn't set.

### Q5. What is a splat expression?

> A shortcut that collects one attribute from every element of a list, such as `aws_instance.web[*].id`. It's equivalent to `[for i in aws_instance.web : i.id]`.

### Q6. Does splat work on `for_each` resources?

> No, because they're maps. Use `values(resource)[*].attr` or a `for` expression.

### Q7. What does `[*]` do on a single value or `null`?

> A single object becomes a one-element list, and `null` becomes an empty list. This is useful for optional dynamic blocks.

### Q8. Difference between `[*]` and `.*`?

> `[*]` is the full splat and applies any following attributes and indexes to each element. `.*` is the legacy attribute-only splat; an index after it applies to the resulting list, not each element.

### Q9. What is a dynamic block?

> A construct that generates repeated nested blocks inside a resource, data source, provider, or provisioner from a collection, using `for_each` and a `content` block.

### Q10. Difference between meta-argument `for_each` and a dynamic block's `for_each`?

> Meta-argument `for_each` creates multiple resources and accepts only maps or sets of strings. A dynamic block's `for_each` creates multiple nested blocks in one resource and also accepts lists.

### Q11. How do you include a nested block only when a condition is true?

> `dynamic "block" { for_each = var.enabled ? [1] : [] ... }`, or for an optional object, `for_each = var.obj[*]`.

### Q12. What is the `iterator` argument used for?

> To rename the loop variable instead of using the block name, which improves readability and helps with nested dynamic blocks.

### Q13. What can't dynamic blocks generate?

> Top-level blocks, arguments like `tags`, and meta-argument blocks such as `lifecycle` and `provisioner`.

### Q14. When should you avoid dynamic blocks?

> When the blocks are few and fixed. Static blocks are easier to read, and overusing dynamic blocks makes code hard to understand.

---

# Quick Revision

### Conditionals

- Syntax: `condition ? true_value : false_value`; no if/else statements.
- Operators: `== != > < >= <=`, `&& || !`.
- Bool variables: `var.flag ? a : b` (no `== true`).
- Compute `local.is_prod` once and reuse.
- `count = cond ? 1 : 0` → optional resource; read with `one(x[*].attr)`.
- `null` skips an argument.
- Many choices → map + `lookup()`.
- Both branches need compatible types.
- Safer helpers: `coalesce`, `try`, `can`, `lookup`, `one`.

### Splat

- `list[*].attr` = `[for x in list : x.attr]`.
- Works on `count` resources and lists; **not** on `for_each` maps (use `values()` or `for`).
- `object[*]` → `[object]`; `null[*]` → `[]`.
- Nested splats → `flatten()`.
- Use `[*]`, not legacy `.*`.
- Need filtering or maps → `for` expression.

### Dynamic blocks

- Repeat **nested blocks**, not resources.
- `dynamic "name" { for_each = ...; content { name.value } }`.
- `.key` = index (list), key (map), value (set).
- `iterator` renames the loop variable.
- Optional block: `for_each = cond ? [1] : []` or `var.obj[*]`.
- Can nest; can mix with static blocks.
- Can't generate `lifecycle`, `provisioner`, top-level blocks, or arguments like `tags`.
- Use only when it improves the code.

---

## One-Line Summary

> Conditional expressions choose between values (`cond ? a : b`), splat expressions collect an attribute from every item (`list[*].attr`), and dynamic blocks generate repeated nested blocks inside a resource. Together they let one piece of Terraform code adapt to any environment without copy-paste.

---

## Official References

- https://developer.hashicorp.com/terraform/language/expressions/conditionals
- https://developer.hashicorp.com/terraform/language/expressions/operators
- https://developer.hashicorp.com/terraform/language/expressions/splat
- https://developer.hashicorp.com/terraform/language/expressions/dynamic-blocks
- https://developer.hashicorp.com/terraform/language/expressions/for
- https://developer.hashicorp.com/terraform/language/functions/one
- https://developer.hashicorp.com/terraform/language/functions/try
- https://developer.hashicorp.com/terraform/language/functions/coalesce
- https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file
