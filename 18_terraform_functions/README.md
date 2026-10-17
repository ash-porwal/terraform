# Terraform Notes - Built-in Functions (Beginner to Pro)

## Table of Contents

1. [Big Picture](#big-picture)
2. [Part 1: Function Basics](#part-1-function-basics)
3. [Part 2: Numeric Functions](#part-2-numeric-functions)
4. [Part 3: String Functions](#part-3-string-functions)
5. [Part 4: Collection Functions](#part-4-collection-functions)
6. [Part 5: Encoding Functions](#part-5-encoding-functions)
7. [Part 6: Filesystem Functions (and `templatefile`)](#part-6-filesystem-functions)
8. [Part 7: Date and Time Functions](#part-7-date-and-time-functions)
9. [Part 8: Hash and Crypto Functions](#part-8-hash-and-crypto-functions)
10. [Part 9: IP Network Functions](#part-9-ip-network-functions)
11. [Part 10: Type Conversion and Error Handling](#part-10-type-conversion-and-error-handling)
12. [Part 11: Provider-Defined Functions (Terraform 1.8+)](#part-11-provider-defined-functions-terraform-18)
13. [Part 12: Real-World AWS Recipes](#part-12-real-world-aws-recipes)
14. [Part 13: Pro Tips and Pitfalls](#part-13-pro-tips-and-pitfalls)
15. [Part 14: Hands-on Practice (Free, No Cloud Account)](#part-14-hands-on-practice-free-no-cloud-account)
16. [Cheat Sheet: All Functions](#cheat-sheet-all-functions)
17. [Common Errors](#common-errors)
18. [Interview Questions](#interview-questions)
19. [Quick Revision](#quick-revision)

---

# Big Picture

A **function** is a ready-made tool that takes some input, does a job, and gives back a result.

```hcl
upper("ashish")          # -> "ASHISH"
max(5, 12, 3)            # -> 12
join("-", ["a", "b"])    # -> "a-b"
```

### Python comparison

| Python | Terraform |
|---|---|
| `"ashish".upper()` | `upper("ashish")` |
| `max(5, 12, 3)` | `max(5, 12, 3)` |
| `"-".join(["a", "b"])` | `join("-", ["a", "b"])` |
| `len([1, 2, 3])` | `length([1, 2, 3])` |
| `json.dumps(d)` | `jsonencode(d)` |

## Three Facts Every Beginner Must Know

| Fact | Meaning |
|---|---|
| **Built-in only** | Terraform comes with ~100+ functions. You **cannot write your own** functions in HCL. |
| **Lowercase names** | `upper()`, `jsonencode()`, `cidrsubnet()` |
| **Test in the console** | Run `terraform console` and try any function instantly |

> Need "your own function"? Use a **local value** for a reusable expression, or a **module** for reusable resources. Since Terraform 1.8, **providers** can also ship functions (Part 11).

## Function Categories

| Category | What they do | Examples |
|---|---|---|
| **Numeric** | Math | `max`, `min`, `ceil`, `floor`, `abs` |
| **String** | Work with text | `upper`, `lower`, `replace`, `split`, `join`, `format` |
| **Collection** | Work with lists, maps, sets | `length`, `merge`, `concat`, `lookup`, `flatten` |
| **Encoding** | Convert to/from JSON, YAML, Base64, CSV | `jsonencode`, `yamldecode`, `base64encode` |
| **Filesystem** | Read local files | `file`, `templatefile`, `fileset`, `fileexists` |
| **Date and Time** | Timestamps | `timestamp`, `formatdate`, `timeadd` |
| **Hash and Crypto** | Hashes and IDs | `md5`, `sha256`, `filebase64sha256`, `uuid` |
| **IP Network** | CIDR maths for VPCs | `cidrsubnet`, `cidrhost`, `cidrnetmask` |
| **Type Conversion** | Change types, handle errors | `tostring`, `tonumber`, `toset`, `try`, `can` |

---

# Part 1: Function Basics

## 1.1 Syntax

```hcl
function_name(argument1, argument2, ...)
```

```hcl
lower("HELLO")                       # 1 argument
replace("a-b-c", "-", "_")           # 3 arguments
max(1, 2, 3, 4)                      # any number of arguments
timestamp()                          # no arguments
```

## 1.2 Where Can You Use Functions?

**Anywhere a value is expected**: resource arguments, `locals`, `output`, `variable` validation, `count`, `for_each`, module inputs, conditionals, and string templates.

```hcl
locals {
  bucket_name = lower("${var.project}-${var.environment}-data")
}

resource "aws_s3_bucket" "data" {
  bucket = local.bucket_name
  tags   = merge(local.common_tags, { Name = local.bucket_name })
}

output "bucket_name_length" {
  value = length(local.bucket_name)
}
```

> ❌ You **can't** use functions in places that must be static, such as `backend` blocks, `lifecycle` settings (except conditions), or a variable's `default`.

## 1.3 Nesting Functions (Inside-Out)

Functions can be placed inside other functions. Terraform evaluates the **innermost first**.

```hcl
upper(trimspace("  ashish  "))
```

```text
Step 1: trimspace("  ashish  ")  ->  "ashish"
Step 2: upper("ashish")          ->  "ASHISH"
```

A real example: build a safe S3 bucket name.

```hcl
substr(lower(replace(var.name, "/[^a-zA-Z0-9-]/", "-")), 0, 63)
```

```text
replace  -> swap unsafe characters for "-"
lower    -> make lowercase (S3 requires it)
substr   -> cut to max 63 characters (S3 limit)
```

> 💡 If a nested call becomes hard to read, split it into several `locals`.

## 1.4 Argument Expansion (`...`)

Some functions take **separate arguments**, but you have a **list**. Add `...` to "spread" the list:

```hcl
max(5, 12, 3)               # ✅ separate arguments  -> 12
max([5, 12, 3])             # ❌ error: a list is one argument
max([5, 12, 3]...)          # ✅ list expanded       -> 12
```

```hcl
locals {
  sizes   = [20, 50, 100]
  biggest = max(local.sizes...)     # 100
}
```

Works with any function that accepts a variable number of arguments, such as `min`, `max`, `concat`, `merge`, `coalesce`, `setunion`.

```hcl
merge(local.list_of_tag_maps...)
```

## 1.5 When Are Functions Evaluated?

During **`terraform plan`**, before anything is created.

- If all inputs are known → the result is known in the plan.
- If an input is **unknown** (like an ID created during apply) → the result shows `(known after apply)`.

```hcl
output "upper_name" {
  value = upper(aws_s3_bucket.data.id)    # (known after apply) on first plan
}
```

## 1.6 Pure vs Impure Functions

| Type | Meaning | Examples |
|---|---|---|
| **Pure** | Same input → **always** same output | Almost all functions |
| **Impure** | Different output **every run** | `timestamp()`, `uuid()`, `bcrypt()` |

> ⚠️ Impure functions in resource arguments cause a **change on every plan**. See Part 13.

## 1.7 Functions vs Operators vs Expressions

| Tool | Example | Note |
|---|---|---|
| Function | `max(1, 2)` | Called with `()` |
| Operator | `1 + 2`, `a == b`, `!x` | Symbols |
| Conditional | `cond ? a : b` | Not a function |
| `for` expression | `[for x in list : upper(x)]` | Not a function |
| String template | `"${var.a}-${var.b}"` | Not a function, but often replaces `format()` |

## 1.8 Testing Functions in the Console

```bash
terraform console
```

```text
> upper("terraform")
"TERRAFORM"

> type(toset(["a"]))
set(string)

> exit
```

> Every example in these notes can be pasted into `terraform console`.

---

# Part 2: Numeric Functions

| Function | What it does | Example | Result |
|---|---|---|---|
| `abs(n)` | Absolute value | `abs(-7)` | `7` |
| `ceil(n)` | Round **up** | `ceil(4.1)` | `5` |
| `floor(n)` | Round **down** | `floor(4.9)` | `4` |
| `max(n...)` | Largest | `max(3, 9, 2)` | `9` |
| `min(n...)` | Smallest | `min(3, 9, 2)` | `2` |
| `pow(a, b)` | Power | `pow(2, 10)` | `1024` |
| `log(n, base)` | Logarithm | `log(8, 2)` | `3` |
| `signum(n)` | Sign: -1, 0, or 1 | `signum(-3)` | `-1` |
| `parseint(s, base)` | String → number in a base | `parseint("FF", 16)` | `255` |

### Notes

```hcl
floor(-4.1)            # -5 (rounds DOWN, not toward zero)
ceil(10 / 3)           # 4
10 % 3                 # 1   (% is an operator, not a function)
parseint("101", 2)     # 5   (binary)
```

> There's **no `round()`** function. Use `floor(x + 0.5)` for positive numbers.

### Real use: instances per AZ

```hcl
locals {
  total_instances = 7
  az_count        = 3
  per_az          = ceil(local.total_instances / local.az_count)   # 3
}
```

### Real use: minimum size guard

```hcl
volume_size = max(var.requested_size, 20)     # never less than 20 GB
```

---

# Part 3: String Functions

## 3.1 Case and Whitespace

| Function | Example | Result |
|---|---|---|
| `upper(s)` | `upper("dev")` | `"DEV"` |
| `lower(s)` | `lower("Ashish-DEV")` | `"ashish-dev"` |
| `title(s)` | `title("ashish porwal")` | `"Ashish Porwal"` |
| `trimspace(s)` | `trimspace("  hi \n")` | `"hi"` |
| `trim(s, chars)` | `trim("??hi!!", "?!")` | `"hi"` |
| `trimprefix(s, p)` | `trimprefix("ami-123", "ami-")` | `"123"` |
| `trimsuffix(s, x)` | `trimsuffix("app.zip", ".zip")` | `"app"` |
| `chomp(s)` | `chomp("line\n")` | `"line"` |
| `strrev(s)` | `strrev("abc")` | `"cba"` |

> `trim()` removes **any of the listed characters** from both ends, not the whole string. `trimprefix` / `trimsuffix` remove an **exact** text.

## 3.2 Searching

| Function | Version | Example | Result |
|---|---|---|---|
| `strcontains(s, sub)` | 1.5+ | `strcontains("ashish-prod", "prod")` | `true` |
| `startswith(s, p)` | 1.3+ | `startswith("ami-123", "ami-")` | `true` |
| `endswith(s, x)` | 1.3+ | `endswith("config.json", ".json")` | `true` |
| `length(s)` | all | `length("terraform")` | `9` |

## 3.3 Cutting and Replacing

### `substr(string, offset, length)`

```hcl
substr("terraform", 0, 5)     # "terra"
substr("terraform", 5, -1)    # "form"   (-1 = to the end)
substr("abc", 0, 63)          # "abc"    (length beyond end is fine)
```

### `replace(string, search, replacement)`

```hcl
replace("ashish_dev_bucket", "_", "-")          # "ashish-dev-bucket"
```

**Regex mode:** wrap the search in slashes `/.../`

```hcl
replace("Ashish Dev #1", "/[^a-zA-Z0-9]/", "-")   # "Ashish-Dev--1"
replace("a1b22c333", "/[0-9]+/", "")              # "abc"
```

## 3.4 Splitting and Joining

```hcl
split(",", "dev,staging,prod")        # ["dev", "staging", "prod"]
join("-", ["ashish", "dev", "data"])  # "ashish-dev-data"
join(", ", ["a", "b", "c"])           # "a, b, c"
```

### Real use: comma-separated variable → list

```hcl
variable "allowed_ips_csv" {
  default = "10.0.0.1/32, 10.0.0.2/32"
}

locals {
  allowed_ips = [for ip in split(",", var.allowed_ips_csv) : trimspace(ip)]
}
```

## 3.5 Formatting

### `format(spec, values...)`

```hcl
format("%s-%s", "ashish", "dev")          # "ashish-dev"
format("server-%03d", 7)                  # "server-007"
format("%.2f GB", 3.14159)                # "3.14 GB"
format("%q", "hello")                     # "\"hello\""  (quoted)
format("%d%%", 80)                        # "80%"
```

| Verb | Meaning |
|---|---|
| `%s` | String |
| `%d` | Whole number |
| `%03d` | Whole number, padded to 3 digits with zeros |
| `%f` / `%.2f` | Decimal / 2 decimal places |
| `%t` | Boolean |
| `%q` | Quoted string |
| `%v` | Default format for any value |
| `%#v` | JSON format |
| `%%` | A literal `%` |

### `formatlist(spec, lists...)` - format every item

```hcl
formatlist("%s-server", ["web", "api"])
# ["web-server", "api-server"]

formatlist("%s=%s", ["env", "team"], ["dev", "data"])
# ["env=dev", "team=data"]
```

### `indent(spaces, string)` - indent all lines except the first

```hcl
indent(2, "line1\nline2\nline3")
# "line1\n  line2\n  line3"
```

Useful when inserting multi-line text into YAML.

### `format()` vs string template

```hcl
format("%s-%s", var.project, var.environment)   # function
"${var.project}-${var.environment}"             # template (more common)
```

Use `format()` when you need **padding or decimals**, like `%03d` or `%.2f`.

## 3.6 Regular Expressions

### `regex(pattern, string)` - first match (error if no match)

```hcl
regex("[0-9]+", "server-042-prod")       # "042"
```

**Capture groups → list:**

```hcl
regex("^(\\w+)-(\\w+)$", "ashish-dev")   # ["ashish", "dev"]
```

**Named groups → map:**

```hcl
regex("^(?P<project>\\w+)-(?P<env>\\w+)$", "ashish-dev")
# { env = "dev", project = "ashish" }
```

### `regexall(pattern, string)` - all matches (never errors)

```hcl
regexall("[0-9]+", "a1 b22 c333")       # ["1", "22", "333"]
length(regexall("prod", var.name)) > 0  # "does it contain prod?"
```

> In HCL strings, a regex backslash must be written **twice**: `\\w`, `\\d`, `\\.`.

> Safe check without an error: `can(regex("^ami-", var.ami_id))`.

## 3.7 `templatestring` (Terraform 1.9+)

Renders a template **stored in a string** (instead of a file):

```hcl
locals {
  greeting_tpl = "Hello $${name}, welcome to $${team}!"
}

output "greeting" {
  value = templatestring(local.greeting_tpl, { name = "Ashish", team = "Data" })
}
```

> The first argument must be a **reference** (like `local.greeting_tpl`), not a direct literal. `$${` escapes `${` so it isn't evaluated too early.

---

# Part 4: Collection Functions

Collections = **lists**, **sets**, **maps**, and **objects**.

## 4.1 Size and Checking

| Function | Example | Result |
|---|---|---|
| `length(x)` | `length(["a", "b"])` | `2` |
| `length(x)` | `length({ a = 1, b = 2 })` | `2` |
| `contains(list, v)` | `contains(["dev", "prod"], "qa")` | `false` |
| `alltrue(list)` | `alltrue([true, true])` | `true` |
| `anytrue(list)` | `anytrue([false, true])` | `true` |

> `alltrue([])` is `true`, `anytrue([])` is `false`.

## 4.2 Getting Items

| Function | Example | Result |
|---|---|---|
| `element(list, i)` | `element(["a", "b", "c"], 1)` | `"b"` |
| `element(list, i)` | `element(["a", "b", "c"], 4)` | `"b"` (wraps around) |
| `index(list, v)` | `index(["a", "b", "c"], "c")` | `2` |
| `one(list)` | `one(["only"])` | `"only"` |
| `one(list)` | `one([])` | `null` |
| `slice(list, start, end)` | `slice(["a", "b", "c", "d"], 1, 3)` | `["b", "c"]` |

### `element()` vs `[i]`

```hcl
local.azs[4]             # ❌ error if the list has only 3 items
element(local.azs, 4)    # ✅ wraps: index 4 % 3 = 1
```

**Real use:** spread 5 instances across 3 AZs:

```hcl
availability_zone = element(local.azs, count.index)
# 0->az-a, 1->az-b, 2->az-c, 3->az-a, 4->az-b
```

> `slice` end index is **exclusive**: `slice(list, 0, 2)` returns items 0 and 1.

## 4.3 Building and Combining Lists

| Function | Example | Result |
|---|---|---|
| `concat(lists...)` | `concat(["a"], ["b", "c"])` | `["a", "b", "c"]` |
| `flatten(list)` | `flatten([["a"], ["b", ["c"]]])` | `["a", "b", "c"]` |
| `distinct(list)` | `distinct(["a", "b", "a"])` | `["a", "b"]` |
| `compact(list)` | `compact(["a", "", null, "b"])` | `["a", "b"]` |
| `reverse(list)` | `reverse([1, 2, 3])` | `[3, 2, 1]` |
| `sort(list)` | `sort(["c", "a", "b"])` | `["a", "b", "c"]` |
| `range(n)` | `range(3)` | `[0, 1, 2]` |
| `range(a, b, step)` | `range(0, 10, 5)` | `[0, 5]` |
| `chunklist(list, n)` | `chunklist(["a", "b", "c"], 2)` | `[["a", "b"], ["c"]]` |
| `sum(list)` | `sum([1, 2, 3.5])` | `6.5` |

> ⚠️ `sort()` sorts as **text**: `sort([10, 2, 33])` → `["10", "2", "33"]`. See Part 13.

### Real use: optional extra item

```hcl
locals {
  ports = concat([80, 443], var.enable_ssh ? [22] : [])
}
```

## 4.4 Maps

| Function | Example | Result |
|---|---|---|
| `keys(map)` | `keys({ b = 2, a = 1 })` | `["a", "b"]` (sorted) |
| `values(map)` | `values({ b = 2, a = 1 })` | `[1, 2]` (in key order) |
| `lookup(map, key, default)` | `lookup({ dev = "t3.micro" }, "prod", "t3.small")` | `"t3.small"` |
| `merge(maps...)` | `merge({ a = 1 }, { a = 2, b = 3 })` | `{ a = 2, b = 3 }` |
| `zipmap(keys, values)` | `zipmap(["a", "b"], [1, 2])` | `{ a = 1, b = 2 }` |
| `transpose(map)` | `transpose({ a = ["1", "2"], b = ["2"] })` | `{ "1" = ["a"], "2" = ["a", "b"] }` |

### `merge()`: later maps win

```hcl
locals {
  default_tags = {
    ManagedBy   = "Terraform"
    Environment = "dev"
  }

  bucket_tags = merge(local.default_tags, {
    Name        = "ashish-data"
    Environment = "prod"           # overrides "dev"
  })
}
# { Environment = "prod", ManagedBy = "Terraform", Name = "ashish-data" }
```

> `merge()` is **shallow**: a nested map is **replaced**, not merged inside.

### `lookup()` vs `map[key]`

```hcl
local.sizes["prod"]                       # ❌ error if "prod" key is missing
lookup(local.sizes, "prod", "t3.micro")   # ✅ returns default if missing
```

## 4.5 Sets (Math on Groups)

| Function | Example | Result |
|---|---|---|
| `setunion(a, b)` | `setunion(["a", "b"], ["b", "c"])` | `["a", "b", "c"]` |
| `setintersection(a, b)` | `setintersection(["a", "b"], ["b", "c"])` | `["b"]` |
| `setsubtract(a, b)` | `setsubtract(["a", "b", "c"], ["b"])` | `["a", "c"]` |
| `setproduct(a, b)` | `setproduct(["dev", "prod"], ["app", "db"])` | all pairs (below) |

```hcl
setproduct(["dev", "prod"], ["app", "db"])
# [["dev","app"], ["dev","db"], ["prod","app"], ["prod","db"]]
```

### Real use: every environment × every service

```hcl
locals {
  pairs = setproduct(["dev", "prod"], ["app", "db"])
}

resource "aws_s3_bucket" "this" {
  for_each = { for p in local.pairs : "${p[0]}-${p[1]}" => p }
  bucket   = "ashish-${each.key}-2026"
}
# keys: "dev-app", "dev-db", "prod-app", "prod-db"
```

## 4.6 Fallbacks

| Function | Example | Result |
|---|---|---|
| `coalesce(values...)` | `coalesce(null, "", "fallback")` | `"fallback"` |
| `coalescelist(lists...)` | `coalescelist([], ["a"])` | `["a"]` |

`coalesce` returns the **first value that is not null and not an empty string**.

```hcl
locals {
  bucket_name = coalesce(var.custom_bucket_name, "ashish-${var.environment}-default")
}
```

## 4.7 `matchkeys` (Filter One List by Another)

```hcl
matchkeys(
  ["i-111", "i-222", "i-333"],          # values
  ["ap-south-1a", "ap-south-1b", "ap-south-1a"],   # keys (same order)
  ["ap-south-1a"]                       # keys to keep
)
# ["i-111", "i-333"]
```

> A `for` expression with `if` is usually clearer.

---

# Part 5: Encoding Functions

| Function | Converts | Example | Result |
|---|---|---|---|
| `jsonencode(v)` | Value → JSON text | `jsonencode({ a = 1 })` | `"{\"a\":1}"` |
| `jsondecode(s)` | JSON text → value | `jsondecode("{\"a\":1}").a` | `1` |
| `yamlencode(v)` | Value → YAML text | `yamlencode({ a = 1 })` | `"\"a\": 1\n"` |
| `yamldecode(s)` | YAML text → value | `yamldecode("a: 1").a` | `1` |
| `base64encode(s)` | Text → Base64 | `base64encode("hello")` | `"aGVsbG8="` |
| `base64decode(s)` | Base64 → text | `base64decode("aGVsbG8=")` | `"hello"` |
| `base64gzip(s)` | Gzip then Base64 | `base64gzip(local.script)` | compressed text |
| `csvdecode(s)` | CSV text → list of maps | see below | |
| `urlencode(s)` | URL-safe text | `urlencode("a b&c")` | `"a+b%26c"` |
| `textencodebase64(s, enc)` | Text in another encoding → Base64 | `textencodebase64("hi", "UTF-16LE")` | Base64 text |
| `textdecodebase64(s, enc)` | Reverse of above | | |

## 5.1 `jsonencode` - The Most Used Encoding Function

**IAM policies** must be JSON. Writing JSON by hand inside a heredoc is error-prone. Let Terraform build it:

```hcl
resource "aws_iam_policy" "read_data" {
  name = "ashish-read-data"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.data.arn,
          "${aws_s3_bucket.data.arn}/*",
        ]
      }
    ]
  })
}
```

✅ No missing commas, no quote mistakes, and you can use references inside.

> Alternative: the `aws_iam_policy_document` data source. Both are valid; `jsonencode` is simpler to learn.

## 5.2 `jsondecode` - Read JSON

```hcl
locals {
  settings = jsondecode(file("${path.module}/settings.json"))
}

output "app_port" {
  value = local.settings.app.port
}
```

Also common: reading a secret stored as JSON:

```hcl
data "aws_secretsmanager_secret_version" "db" {
  secret_id = "ashish/db"
}

locals {
  db_creds = jsondecode(data.aws_secretsmanager_secret_version.db.secret_string)
  db_user  = local.db_creds.username
}
```

## 5.3 `yamldecode` - Config-Driven Infrastructure

### `config.yaml`

```yaml
project: ashish-learning
environment: dev
buckets:
  - logs
  - data
```

### Terraform

```hcl
locals {
  config = yamldecode(file("${path.module}/config.yaml"))
}

resource "aws_s3_bucket" "this" {
  for_each = toset(local.config.buckets)
  bucket   = "${local.config.project}-${local.config.environment}-${each.key}"
}
```

Non-Terraform users can now add a bucket by editing YAML.

## 5.4 `csvdecode` - Read a CSV

### `users.csv`

```text
name,team,role
ashish,data,engineer
priya,devops,lead
```

```hcl
locals {
  users = csvdecode(file("${path.module}/users.csv"))
}
# [
#   { name = "ashish", role = "engineer", team = "data" },
#   { name = "priya",  role = "lead",     team = "devops" },
# ]

resource "aws_iam_user" "this" {
  for_each = { for u in local.users : u.name => u }
  name     = each.key
  tags     = { Team = each.value.team }
}
```

> The **first row** is the header. All values come back as **strings**.

## 5.5 `base64encode` and `base64gzip`

```hcl
resource "aws_launch_template" "app" {
  # launch templates expect Base64 user data
  user_data = base64encode(templatefile("${path.module}/user_data.sh.tftpl", {
    environment = var.environment
  }))
}
```

> `aws_instance.user_data` accepts plain text (the provider encodes it). `aws_launch_template.user_data` needs Base64.

---

# Part 6: Filesystem Functions

## 6.1 Path References (Use These, Not Plain Relative Paths)

| Reference | Points to |
|---|---|
| `path.module` | Folder of the **current module** ✅ use this |
| `path.root` | Folder of the **root module** |
| `path.cwd` | Folder where you **ran** `terraform` |

```hcl
file("${path.module}/scripts/setup.sh")    # ✅ works inside modules too
file("scripts/setup.sh")                   # ⚠️ relative to where you ran terraform
```

## 6.2 Reading Files

| Function | Example | Result |
|---|---|---|
| `file(path)` | `file("${path.module}/hello.txt")` | File text (UTF-8) |
| `fileexists(path)` | `fileexists("${path.module}/x.txt")` | `true` / `false` |
| `filebase64(path)` | `filebase64("${path.module}/logo.png")` | Base64 of binary file |
| `fileset(dir, pattern)` | `fileset(path.module, "files/*.txt")` | Set of matching paths |

### Optional file

```hcl
locals {
  extra_script = fileexists("${path.module}/extra.sh") ? file("${path.module}/extra.sh") : ""
}
```

### `fileset` patterns

| Pattern | Matches |
|---|---|
| `*` | Any characters except `/` |
| `**` | Any folders (recursive) |
| `?` | One character |
| `{a,b}` | Either `a` or `b` |
| `[abc]` | One of these characters |

```hcl
fileset("${path.module}/website", "**")             # every file, all folders
fileset("${path.module}/website", "*.{html,css}")   # html and css in top folder
```

> `fileset` returns paths **relative** to the folder you give it.

## 6.3 Path Helpers

| Function | Example | Result |
|---|---|---|
| `basename(p)` | `basename("site/css/main.css")` | `"main.css"` |
| `dirname(p)` | `dirname("site/css/main.css")` | `"site/css"` |
| `abspath(p)` | `abspath("files")` | Full absolute path |
| `pathexpand(p)` | `pathexpand("~/.ssh/id_rsa.pub")` | `"/home/ashish/.ssh/id_rsa.pub"` |

```hcl
resource "aws_key_pair" "me" {
  key_name   = "ashish-key"
  public_key = file(pathexpand("~/.ssh/id_rsa.pub"))
}
```

## 6.4 `templatefile` - Files with Variables (Very Important)

`templatefile(path, variables)` reads a file, fills in variables, and supports **loops** and **if/else**.

### `templates/user_data.sh.tftpl`

```bash
#!/bin/bash
echo "Environment: ${environment}"
echo "Owner: ${owner}"

%{ for pkg in packages ~}
yum install -y ${pkg}
%{ endfor ~}

%{ if enable_monitoring ~}
echo "Installing monitoring agent"
%{ else ~}
echo "Monitoring disabled"
%{ endif ~}
```

### Terraform

```hcl
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = "t3.micro"

  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    environment       = var.environment
    owner             = "ashish"
    packages          = ["git", "htop", "docker"]
    enable_monitoring = var.environment == "prod"
  })
}
```

### Template syntax

| Syntax | Meaning |
|---|---|
| `${name}` | Insert a value |
| `%{ for x in list }` ... `%{ endfor }` | Loop |
| `%{ if cond }` ... `%{ else }` ... `%{ endif }` | Condition |
| `~` | Remove whitespace/newline next to the directive |
| `$${` | Literal `${` (escape) |
| `%%{` | Literal `%{` (escape) |

### Rendered result (dev)

```bash
#!/bin/bash
echo "Environment: dev"
echo "Owner: ashish"

yum install -y git
yum install -y htop
yum install -y docker

echo "Monitoring disabled"
```

### The `~` strip marker

```text
%{ for pkg in packages }      -> leaves blank lines around each item
%{ for pkg in packages ~}     -> removes the newline after the directive
```

### Rules

- Recommended extension: **`.tftpl`**.
- **Every** variable used in the template must be passed in the map.
- Templates can use Terraform functions: `${upper(owner)}`.
- For JSON output, use `${jsonencode(...)}` inside the template instead of building JSON by hand.
- `templatefile` can't call itself recursively.

### Shell variables in templates

Bash also uses `${...}`. Escape it with `$$`:

```bash
NAME="ashish"
echo "Hello $${NAME}"     # Terraform outputs: echo "Hello ${NAME}"
echo "Hello $NAME"        # no braces = no escaping needed
```

## 6.5 Heredoc Strings (Inline Templates)

For short templates, use a heredoc directly in the code:

```hcl
locals {
  motd = <<-EOT
    Welcome to ${var.environment}
    %{ for u in var.admins ~}
    Admin: ${u}
    %{ endfor ~}
  EOT
}
```

`<<-EOT` removes leading indentation; `<<EOT` keeps it.

## 6.6 ⚠️ Filesystem Functions Read at Plan Time

`file()`, `fileset()`, `templatefile()`, `filemd5()` and similar read files **when Terraform plans**, from **your disk**.

- The file must **already exist** before `plan`.
- You can't `file()` a file that a resource creates **during the same apply**. Use that resource's attributes instead (e.g. `local_file.x.content` or `data.archive_file.x.output_base64sha256`).

---

# Part 7: Date and Time Functions

| Function | Version | Example | Result |
|---|---|---|---|
| `timestamp()` | all | `timestamp()` | `"2026-10-17T10:00:00Z"` (now, UTC) |
| `plantimestamp()` | 1.5+ | `plantimestamp()` | Time when plan ran |
| `formatdate(fmt, ts)` | all | `formatdate("YYYY-MM-DD", "2026-10-17T10:00:00Z")` | `"2026-10-17"` |
| `timeadd(ts, dur)` | all | `timeadd("2026-10-17T10:00:00Z", "48h")` | `"2026-10-19T10:00:00Z"` |
| `timecmp(a, b)` | 1.3+ | `timecmp("2026-01-01T00:00:00Z", "2026-06-01T00:00:00Z")` | `-1` |

Timestamps use **RFC 3339** format: `YYYY-MM-DDThh:mm:ssZ`.

## 7.1 `formatdate` Tokens

| Token | Meaning | Example |
|---|---|---|
| `YYYY` / `YY` | Year | `2026` / `26` |
| `MMMM` / `MMM` / `MM` | Month | `October` / `Oct` / `10` |
| `DD` / `D` | Day | `07` / `7` |
| `EEEE` / `EEE` | Weekday | `Saturday` / `Sat` |
| `hh` | Hour (24h, 2 digits) | `15` |
| `HH` | Hour (12h, 2 digits) | `03` |
| `mm` | Minutes | `30` |
| `ss` | Seconds | `05` |
| `AA` / `aa` | AM/PM | `PM` / `pm` |
| `ZZZ` | Time zone | `UTC` |
| `'text'` | Literal text | `'at'` |

```hcl
formatdate("DD MMM YYYY 'at' hh:mm ZZZ", "2026-10-17T15:30:00Z")
# "17 Oct 2026 at 15:30 UTC"
```

## 7.2 `timeadd` Durations

Units: `ns`, `us`, `ms`, `s`, `m`, `h`. **No days**, so use hours:

```hcl
timeadd(timestamp(), "720h")     # +30 days
timeadd(timestamp(), "-1h30m")   # 1.5 hours ago
```

## 7.3 ⚠️ `timestamp()` Causes Changes Every Plan

```hcl
tags = {
  CreatedAt = timestamp()      # ❌ new value every run -> resource always "changes"
}
```

### Fixes

**Option 1: ignore after creation**

```hcl
tags = {
  CreatedAt = timestamp()
}

lifecycle {
  ignore_changes = [tags["CreatedAt"]]
}
```

**Option 2: `time_static` resource (stores the time once)**

```hcl
resource "time_static" "created" {}

resource "aws_s3_bucket" "data" {
  bucket = "ashish-data-2026"
  tags = {
    CreatedAt = time_static.created.rfc3339
  }
}
```

> `time_static` comes from the `hashicorp/time` provider.

### `timestamp()` vs `plantimestamp()`

| | `timestamp()` | `plantimestamp()` |
|---|---|---|
| Known during plan | ❌ `(known after apply)` | ✅ Yes |
| Value | Time during apply | Time when plan ran |
| Good for | Rarely needed | Checks in `check`/conditions, e.g. certificate expiry |

---

# Part 8: Hash and Crypto Functions

## 8.1 Hashes of Text

| Function | Example | Result |
|---|---|---|
| `md5(s)` | `md5("hello")` | `"5d41402abc4b2a76b9719d911017c592"` |
| `sha1(s)` | `sha1("hello")` | 40-char hex |
| `sha256(s)` | `sha256("hello")` | `"2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"` |
| `sha512(s)` | `sha512("hello")` | 128-char hex |
| `base64sha256(s)` | `base64sha256("hello")` | Base64 form of SHA-256 |
| `base64sha512(s)` | | Base64 form of SHA-512 |

## 8.2 Hashes of Files (Change Detection)

| Function | Typical use |
|---|---|
| `filemd5(path)` | S3 object `etag`: re-upload when the file changes |
| `filesha1(path)` / `filesha256(path)` / `filesha512(path)` | Detect file changes |
| `filebase64sha256(path)` | Lambda `source_code_hash` |
| `filebase64sha512(path)` | Same idea, SHA-512 |

### S3: upload again only when content changes

```hcl
resource "aws_s3_object" "config" {
  bucket = aws_s3_bucket.data.id
  key    = "app/config.json"
  source = "${path.module}/config.json"
  etag   = filemd5("${path.module}/config.json")
}
```

### Lambda: redeploy when the zip changes

```hcl
resource "aws_lambda_function" "app" {
  function_name    = "ashish-app"
  filename         = "${path.module}/lambda.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda.zip")
  handler          = "app.handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda.arn
}
```

> If the zip is created by `data "archive_file"` in the same config, use `data.archive_file.app.output_base64sha256` instead (Part 6.6).

## 8.3 IDs and Passwords

| Function | Pure? | Meaning |
|---|---|---|
| `uuid()` | ❌ Impure | Random UUID, **new every run** |
| `uuidv5(namespace, name)` | ✅ Pure | Same input → same UUID every time |
| `bcrypt(s)` | ❌ Impure | Password hash with random salt |
| `rsadecrypt(cipher, key)` | ✅ | Decrypt RSA text, e.g. Windows EC2 password |

```hcl
uuidv5("dns", "ashish.example.com")    # always the same UUID for this name
```

> Need random values that **stay stable**? Use the `hashicorp/random` provider: `random_id`, `random_string`, `random_password`, `random_uuid`. They're generated once and stored in state.

```hcl
resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "data" {
  bucket = "ashish-data-${random_id.suffix.hex}"    # e.g. ashish-data-1a2b3c4d
}
```

---

# Part 9: IP Network Functions

Essential for building **VPCs and subnets**.

| Function | Example | Result |
|---|---|---|
| `cidrsubnet(prefix, newbits, netnum)` | `cidrsubnet("10.0.0.0/16", 8, 1)` | `"10.0.1.0/24"` |
| `cidrsubnets(prefix, newbits...)` | `cidrsubnets("10.0.0.0/16", 8, 8, 8)` | `["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]` |
| `cidrhost(prefix, hostnum)` | `cidrhost("10.0.1.0/24", 5)` | `"10.0.1.5"` |
| `cidrhost(prefix, -n)` | `cidrhost("10.0.1.0/24", -2)` | `"10.0.1.254"` |
| `cidrnetmask(prefix)` | `cidrnetmask("10.0.0.0/16")` | `"255.255.0.0"` |

## 9.1 Understanding `cidrsubnet`

```hcl
cidrsubnet("10.0.0.0/16", 8, 3)
```

| Argument | Value | Meaning |
|---|---|---|
| `prefix` | `10.0.0.0/16` | The big network (VPC) |
| `newbits` | `8` | Add 8 bits: /16 + 8 = **/24** subnets |
| `netnum` | `3` | Take the **4th** /24 (counting from 0) |

Result: `"10.0.3.0/24"`

```text
10.0.0.0/16  (VPC, 65,536 addresses)
├── netnum 0 -> 10.0.0.0/24
├── netnum 1 -> 10.0.1.0/24
├── netnum 2 -> 10.0.2.0/24
├── netnum 3 -> 10.0.3.0/24
...
└── netnum 255 -> 10.0.255.0/24
```

## 9.2 Real Use: Public and Private Subnets per AZ

```hcl
variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
}

resource "aws_subnet" "public" {
  count             = length(local.azs)
  vpc_id            = aws_vpc.main.id
  availability_zone = local.azs[count.index]
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)        # 10.0.0-2.0/24
}

resource "aws_subnet" "private" {
  count             = length(local.azs)
  vpc_id            = aws_vpc.main.id
  availability_zone = local.azs[count.index]
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)   # 10.0.10-12.0/24
}
```

> The `+ 10` offset keeps private subnets in a separate range, leaving room for more public subnets later.

---

# Part 10: Type Conversion and Error Handling

## 10.1 Converting Types

| Function | Example | Result |
|---|---|---|
| `tostring(v)` | `tostring(42)` | `"42"` |
| `tonumber(v)` | `tonumber("42")` | `42` |
| `tobool(v)` | `tobool("true")` | `true` |
| `tolist(v)` | `tolist(toset(["b", "a"]))` | `["a", "b"]` |
| `toset(v)` | `toset(["a", "b", "a"])` | `["a", "b"]` (unique) |
| `tomap(v)` | `tomap({ a = "1", b = "2" })` | map of strings |

### Most common: `toset()` for `for_each`

```hcl
resource "aws_iam_user" "team" {
  for_each = toset(var.user_names)     # for_each needs a set or map
  name     = each.key
}
```

### Environment variables are always strings

```hcl
# TF_VAR_port="8080" with type = string
locals {
  port = tonumber(var.port)
}
```

> `tonumber("abc")` and `tobool("yes")` fail. Only `"true"`/`"false"` convert to bool.

## 10.2 `try()` - Use a Fallback If Something Fails

```hcl
try(expression1, expression2, ..., fallback)
```

Returns the **first expression that works** without an error.

```hcl
try(var.config.port, 8080)          # 8080 if config has no "port"
try(tonumber(var.size), 20)         # 20 if size isn't a number
try(local.users[0].name, "nobody")  # "nobody" if the list is empty
```

### Real use: optional attributes in a decoded YAML file

```hcl
locals {
  config     = yamldecode(file("${path.module}/config.yaml"))
  monitoring = try(local.config.features.monitoring, false)
  log_days   = try(local.config.logging.retention_days, 7)
}
```

> ⚠️ `try()` only catches **runtime** errors such as a missing attribute or a failed conversion. It does **not** hide mistakes like a misspelled variable name or invalid syntax. Those still fail.

## 10.3 `can()` - "Would This Work?" (true/false)

```hcl
can(regex("^ami-", "ami-12345"))    # true
can(tonumber("abc"))                # false
```

### Perfect for variable validation

```hcl
variable "ami_id" {
  type = string

  validation {
    condition     = can(regex("^ami-[0-9a-f]{8,17}$", var.ami_id))
    error_message = "ami_id must look like ami-xxxxxxxx."
  }
}

variable "vpc_cidr" {
  type = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR, e.g. 10.0.0.0/16."
  }
}
```

| | `try()` | `can()` |
|---|---|---|
| Returns | A value (or the fallback) | `true` / `false` |
| Use in | Locals, arguments | Validation, conditions |

## 10.4 Sensitive Values

| Function | Version | Meaning |
|---|---|---|
| `sensitive(v)` | 0.15+ | Mark a value as sensitive (hidden in output) |
| `nonsensitive(v)` | 0.15+ | Remove the sensitive mark ⚠️ |
| `issensitive(v)` | 1.8+ | Check whether a value is sensitive |

```hcl
locals {
  db_url = sensitive("postgres://user:${var.db_password}@db:5432/app")
}

output "password_length" {
  value = nonsensitive(length(var.db_password))   # safe: only the length
}
```

> Never wrap the secret itself in `nonsensitive()`.

## 10.5 `type()` (Console Only)

```text
> type(["a", "b"])
tuple([
    string,
    string,
])

> type(tolist(["a", "b"]))
list(string)
```

Helps you understand type errors. It only works in `terraform console`.

## 10.6 Removed Functions

| Old | Use instead |
|---|---|
| `list(a, b)` | `[a, b]` or `tolist([...])` |
| `map(k, v)` | `{ k = v }` or `tomap({...})` |

Removed in Terraform 0.15. You'll still see them in very old tutorials.

---

# Part 11: Provider-Defined Functions (Terraform 1.8+)

Since Terraform 1.8, **providers can ship their own functions**. They use this syntax:

```hcl
provider::<provider_name>::<function_name>(arguments)
```

### AWS provider example (AWS provider 5.40+)

```hcl
terraform {
  required_version = ">= 1.8.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40"
    }
  }
}

locals {
  role_arn = "arn:aws:iam::111122223333:role/ashish-app"
  parsed   = provider::aws::arn_parse(local.role_arn)
}

output "account_id" {
  value = local.parsed.account_id      # "111122223333"
}

output "service" {
  value = local.parsed.service         # "iam"
}
```

| AWS function | Purpose |
|---|---|
| `provider::aws::arn_parse(arn)` | Split an ARN into parts (partition, service, region, account_id, resource) |
| `provider::aws::arn_build(...)` | Build an ARN from parts |
| `provider::aws::trim_iam_role_path(arn)` | Remove the path from an IAM role ARN |

### Rules

- The provider must be in `required_providers`.
- Run `terraform init` so the provider (and its functions) is installed.
- Check the provider's **Functions** section in the Terraform Registry for what's available.

### Terraform's built-in provider functions

Terraform itself also ships a few under `provider::terraform::`, such as `encode_tfvars`, `decode_tfvars`, and `encode_expr`. These are advanced and rarely needed day to day.

---

# Part 12: Real-World AWS Recipes

## 12.1 Standard Naming and Tags

```hcl
locals {
  name_prefix = lower("${var.project}-${var.environment}")

  common_tags = {
    Project     = var.project
    Environment = upper(var.environment)
    Owner       = title(var.owner)
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket" "logs" {
  bucket = "${local.name_prefix}-logs"
  tags   = merge(local.common_tags, { Purpose = "logs" })
}
```

## 12.2 Safe S3 Bucket Name

S3 rules: lowercase, letters/numbers/hyphens, 3–63 characters.

```hcl
locals {
  raw_name    = "${var.project}_${var.environment}_Data Lake"
  bucket_name = substr(trim(lower(replace(local.raw_name, "/[^a-zA-Z0-9-]/", "-")), "-"), 0, 63)
}
# "ashish_dev_Data Lake" style input -> "ashish-dev-data-lake"
```

## 12.3 Instance Size per Environment

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

## 12.4 Upload a Whole Folder to S3

```hcl
locals {
  site_dir = "${path.module}/website"

  mime_types = {
    ".html" = "text/html"
    ".css"  = "text/css"
    ".js"   = "application/javascript"
    ".png"  = "image/png"
    ".json" = "application/json"
  }
}

resource "aws_s3_object" "site" {
  for_each = fileset(local.site_dir, "**")

  bucket       = aws_s3_bucket.site.id
  key          = each.value
  source       = "${local.site_dir}/${each.value}"
  etag         = filemd5("${local.site_dir}/${each.value}")
  content_type = lookup(local.mime_types, try(regex("\\.[^.]+$", each.value), ""), "application/octet-stream")
}
```

Functions used: `fileset`, `filemd5`, `lookup`, `try`, `regex`.

## 12.5 Subnets Across AZs

See Part 9.2 (`cidrsubnet` + `count.index` + `slice`).

## 12.6 IAM Policy for Many Buckets

```hcl
resource "aws_iam_policy" "read_all" {
  name = "${local.name_prefix}-read-all"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["s3:GetObject", "s3:ListBucket"]
      Resource = flatten([
        for b in aws_s3_bucket.this : [b.arn, "${b.arn}/*"]
      ])
    }]
  })
}
```

## 12.7 EC2 User Data from a Template

See Part 6.4 (`templatefile`).

## 12.8 Users from CSV, Settings from YAML

See Parts 5.3 and 5.4 (`csvdecode`, `yamldecode`).

---

# Part 13: Pro Tips and Pitfalls

## 13.1 Impure Functions = Endless Changes

`timestamp()`, `uuid()`, and `bcrypt()` produce a new value every run, so plans never say "No changes".

**Fix:** `lifecycle { ignore_changes = [...] }`, or use stable resources from the `time` and `random` providers.

## 13.2 `sort()` Treats Numbers as Text

```hcl
sort([10, 2, 33])        # ["10", "2", "33"]   ❌ not numeric order
```

For numeric sorting, pad first or avoid relying on sort:

```hcl
[for s in sort(formatlist("%05d", [10, 2, 33])) : tonumber(s)]   # [2, 10, 33]
```

## 13.3 Sets Have No Index

```hcl
toset(["b", "a"])[0]                # ❌ error: sets can't be indexed
tolist(toset(["b", "a"]))[0]        # ✅ "a"
```

## 13.4 `merge()` Is Shallow

```hcl
merge(
  { app = { port = 80, debug = false } },
  { app = { debug = true } }
)
# { app = { debug = true } }   <- "port" is LOST
```

Merge nested parts separately:

```hcl
{ app = merge(local.defaults.app, local.overrides.app) }
```

## 13.5 Many Functions Fail on `null`

```hcl
length(null)        # ❌ error
upper(null)         # ❌ error
```

Guard with `coalesce()`, `try()`, or a conditional:

```hcl
length(coalesce(var.names, []))
try(upper(var.name), "")
```

## 13.6 `regex()` Errors When Nothing Matches

```hcl
regex("prod", "dev-bucket")              # ❌ error
regexall("prod", "dev-bucket")           # ✅ []
can(regex("prod", "dev-bucket"))         # ✅ false
```

## 13.7 `element()` Wraps, `[i]` Doesn't

Use `element()` for round-robin placement. Use `[i]` when going out of range **should** be an error.

## 13.8 `lookup()` Without a Default

```hcl
lookup(local.sizes, "qa")          # ❌ error if the key is missing
lookup(local.sizes, "qa", null)    # ✅ null when missing
```

## 13.9 Files Are Read at Plan Time

Use `path.module`, make sure files exist before planning, and don't `file()` a file that the same apply creates.

## 13.10 `jsonencode` Sorts Keys

`jsonencode({ b = 1, a = 2 })` → `{"a":2,"b":1}`. Output is stable, so you get no false "changes" from key order.

## 13.11 Unknown In → Unknown Out

```hcl
upper(aws_instance.web.id)    # (known after apply) until the instance exists
```

That's normal. It matters when the result feeds `count` or `for_each` keys, which must be known at plan time.

## 13.12 Prefer Readability

```hcl
# ❌ Hard to read
bucket = substr(trim(lower(replace("${var.p}_${var.e}", "/[^a-zA-Z0-9-]/", "-")), "-"), 0, 63)

# ✅ Split into locals
locals {
  raw_name   = "${var.project}_${var.environment}"
  clean_name = trim(lower(replace(local.raw_name, "/[^a-zA-Z0-9-]/", "-")), "-")
  bucket     = substr(local.clean_name, 0, 63)
}
```

---

# Part 14: Hands-on Practice (Free, No Cloud Account)

## 14.1 Console Drills

```bash
terraform console
```

### Numeric and string

```text
> max([4, 19, 7]...)
> ceil(7 / 3)
> parseint("FF", 16)
> format("server-%03d", 7)
> replace("Ashish Dev #1", "/[^a-zA-Z0-9]/", "-")
> regex("^(?P<project>\\w+)-(?P<env>\\w+)$", "ashish-dev")
> regexall("[0-9]+", "a1 b22 c333")
> join("-", split(",", "a,b,c"))
> trimprefix("ami-123", "ami-")
```

### Collections

```text
> length({ a = 1, b = 2 })
> element(["a", "b", "c"], 4)
> flatten([["a"], ["b", ["c"]]])
> compact(["a", "", null, "b"])
> merge({ env = "dev", owner = "x" }, { env = "prod" })
> lookup({ dev = "t3.micro" }, "prod", "t3.small")
> zipmap(["a", "b"], [1, 2])
> setproduct(["dev", "prod"], ["app", "db"])
> sort([10, 2, 33])
> coalesce(null, "", "fallback")
> one([])
```

### Encoding, network, type

```text
> jsonencode({ name = "ashish", skills = ["tf", "aws"] })
> jsondecode("{\"exp\": 4}").exp
> yamlencode({ project = "ashish", buckets = ["logs", "data"] })
> base64encode("hello")
> cidrsubnet("10.0.0.0/16", 8, 3)
> cidrsubnets("10.0.0.0/16", 8, 8, 8)
> cidrhost("10.0.1.0/24", -2)
> try(tonumber("abc"), 0)
> can(regex("^ami-", "ami-123"))
> formatdate("DD MMM YYYY", "2026-10-17T10:00:00Z")
> timeadd("2026-10-17T10:00:00Z", "48h")
> md5("hello")
> type(toset(["a", "b"]))
```

## 14.2 Mini Project with the `local` Provider

### Folder

```text
18_functions_lab/
├── versions.tf
├── main.tf
├── config.yaml
├── data/
│   └── users.csv
└── templates/
    └── welcome.tftpl
```

### `versions.tf`

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}
```

### `config.yaml`

```yaml
project: ashish-learning
environment: dev
buckets:
  - logs
  - data
features:
  monitoring: true
```

### `data/users.csv`

```text
name,team,role
ashish,data,engineer
priya,devops,lead
rahul,data,analyst
```

### `templates/welcome.tftpl`

```text
Hello ${name}!
Team: ${team}
Role: ${role}
%{ if is_lead ~}
You are a team lead.
%{ endif ~}
Skills:
%{ for s in skills ~}
- ${s}
%{ endfor ~}
```

### `main.tf`

```hcl
locals {
  config = yamldecode(file("${path.module}/config.yaml"))
  users  = csvdecode(file("${path.module}/data/users.csv"))

  users_by_name = { for u in local.users : u.name => u }
  data_team     = [for u in local.users : u.name if u.team == "data"]

  name_prefix   = lower("${local.config.project}-${local.config.environment}")
  bucket_names  = formatlist("${local.name_prefix}-%s", local.config.buckets)
  monitoring_on = try(local.config.features.monitoring, false)
  log_days      = try(local.config.logging.retention_days, 7)   # missing -> 7
}

# templatefile + for_each
resource "local_file" "welcome" {
  for_each = local.users_by_name

  filename = "${path.module}/out/welcome-${each.key}.txt"
  content = templatefile("${path.module}/templates/welcome.tftpl", {
    name    = title(each.key)
    team    = upper(each.value.team)
    role    = each.value.role
    is_lead = each.value.role == "lead"
    skills  = ["Terraform", "AWS", "PySpark"]
  })
}

# jsonencode
resource "local_file" "policy" {
  filename = "${path.module}/out/policy.json"
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject"]
      Resource = formatlist("arn:aws:s3:::%s/*", local.bucket_names)
    }]
  })
}

# yamlencode
resource "local_file" "inventory" {
  filename = "${path.module}/out/inventory.yaml"
  content = yamlencode({
    project    = local.config.project
    buckets    = local.bucket_names
    users      = keys(local.users_by_name)
    data_team  = local.data_team
    monitoring = local.monitoring_on
    log_days   = local.log_days
  })
}

output "bucket_names" {
  value = local.bucket_names
}

output "data_team" {
  value = local.data_team
}

output "subnets" {
  value = cidrsubnets("10.0.0.0/16", 8, 8, 8)
}

output "config_md5" {
  value = filemd5("${path.module}/config.yaml")
}

output "input_files" {
  value = fileset(path.module, "**/*.{csv,yaml,tftpl}")
}

output "welcome_files" {
  value = [for f in local_file.welcome : basename(f.filename)]
}
```

### Run

```bash
terraform init
terraform apply
terraform output
```

### What to observe

1. Open `out/welcome-priya.txt`: it includes "You are a team lead."
2. Open `out/policy.json` and `out/inventory.yaml`.
3. Add a user to `users.csv` → `terraform plan` shows **one** new welcome file.
4. Add `logging: { retention_days: 30 }` to `config.yaml` → `log_days` becomes `30`.
5. Edit `config.yaml` → `config_md5` changes.

### Clean up

```bash
terraform destroy
```

---

# Cheat Sheet: All Functions

### Numeric

| Function | Purpose |
|---|---|
| `abs` | Absolute value |
| `ceil` | Round up |
| `floor` | Round down |
| `log` | Logarithm |
| `max` | Largest |
| `min` | Smallest |
| `parseint` | String to number in a base |
| `pow` | Power |
| `signum` | Sign (-1, 0, 1) |

### String

| Function | Purpose |
|---|---|
| `chomp` | Remove trailing newlines |
| `endswith` | Ends with text? (1.3+) |
| `format` | Format with verbs |
| `formatlist` | Format each list item |
| `indent` | Indent lines after the first |
| `join` | List to string |
| `lower` | Lowercase |
| `regex` | First regex match |
| `regexall` | All regex matches |
| `replace` | Replace text or regex |
| `split` | String to list |
| `startswith` | Starts with text? (1.3+) |
| `strcontains` | Contains text? (1.5+) |
| `strrev` | Reverse |
| `substr` | Part of a string |
| `templatestring` | Render a template string (1.9+) |
| `title` | Capitalise each word |
| `trim` | Remove characters from both ends |
| `trimprefix` | Remove exact prefix |
| `trimsuffix` | Remove exact suffix |
| `trimspace` | Remove whitespace |
| `upper` | Uppercase |

### Collection

| Function | Purpose |
|---|---|
| `alltrue` | All true? |
| `anytrue` | Any true? |
| `chunklist` | Split list into chunks |
| `coalesce` | First non-null, non-empty value |
| `coalescelist` | First non-empty list |
| `compact` | Remove empty strings and nulls |
| `concat` | Join lists |
| `contains` | List has value? |
| `distinct` | Remove duplicates |
| `element` | Item by index (wraps) |
| `flatten` | Flatten nested lists |
| `index` | Position of a value |
| `keys` | Map keys |
| `length` | Size |
| `lookup` | Map value with default |
| `matchkeys` | Filter by matching keys |
| `merge` | Combine maps (later wins) |
| `one` | Single item or null |
| `range` | Number sequence |
| `reverse` | Reverse list |
| `setintersection` | Common items |
| `setproduct` | All combinations |
| `setsubtract` | Items in A not in B |
| `setunion` | All unique items |
| `slice` | Part of a list |
| `sort` | Sort strings |
| `sum` | Add numbers |
| `transpose` | Swap map keys and values |
| `values` | Map values |
| `zipmap` | Two lists to a map |

### Encoding

| Function | Purpose |
|---|---|
| `base64decode` / `base64encode` | Base64 |
| `base64gzip` | Gzip + Base64 |
| `csvdecode` | CSV to list of maps |
| `jsondecode` / `jsonencode` | JSON |
| `textdecodebase64` / `textencodebase64` | Base64 with a character encoding |
| `urlencode` | URL encoding |
| `yamldecode` / `yamlencode` | YAML |

### Filesystem

| Function | Purpose |
|---|---|
| `abspath` | Absolute path |
| `basename` | File name from path |
| `dirname` | Folder from path |
| `file` | Read text file |
| `filebase64` | Read file as Base64 |
| `fileexists` | File exists? |
| `fileset` | Find files by pattern |
| `pathexpand` | Expand `~` |
| `templatefile` | Render a template file |

### Date and Time

| Function | Purpose |
|---|---|
| `formatdate` | Format a timestamp |
| `plantimestamp` | Plan time (1.5+) |
| `timeadd` | Add a duration |
| `timecmp` | Compare timestamps (1.3+) |
| `timestamp` | Current time (impure) |

### Hash and Crypto

| Function | Purpose |
|---|---|
| `base64sha256` / `base64sha512` | Base64 hashes of text |
| `bcrypt` | Password hash (impure) |
| `filebase64sha256` / `filebase64sha512` | Base64 hashes of files |
| `filemd5` / `filesha1` / `filesha256` / `filesha512` | Hex hashes of files |
| `md5` / `sha1` / `sha256` / `sha512` | Hex hashes of text |
| `rsadecrypt` | Decrypt RSA |
| `uuid` | Random UUID (impure) |
| `uuidv5` | Name-based UUID (stable) |

### IP Network

| Function | Purpose |
|---|---|
| `cidrhost` | IP of a host in a range |
| `cidrnetmask` | Netmask of a range |
| `cidrsubnet` | One subnet |
| `cidrsubnets` | Several consecutive subnets |

### Type Conversion

| Function | Purpose |
|---|---|
| `can` | Does it work? (true/false) |
| `ephemeralasnull` | Ephemeral value to null (1.10+, advanced) |
| `issensitive` | Is it sensitive? (1.8+) |
| `nonsensitive` | Remove sensitive mark |
| `sensitive` | Add sensitive mark |
| `tobool` / `tolist` / `tomap` / `tonumber` / `toset` / `tostring` | Convert type |
| `try` | First expression that works |
| `type` | Show type (console only) |

> Run `terraform version` and check the official function list for your version; new functions are added over time.

---

# Common Errors

| Error | Cause | Fix |
|---|---|---|
| `Call to unknown function` | Typo, wrong case, or function not in your version | Check spelling (lowercase) and Terraform version |
| `Invalid function argument` | Wrong type, e.g. `max([1,2])` | Use `...` expansion or the right type |
| `Not enough function arguments` / `Too many function arguments` | Wrong argument count | Check the function's syntax |
| `Invalid value for "path" parameter: no file exists` | Wrong path or file missing | Use `path.module`; check the file exists |
| `Error in function call ... no matches found` (`regex`) | No match | Use `regexall` or `can()` |
| `Invalid index` | Index out of range | `element()`, `try()`, or `one()` |
| `Elements of a set are identified only by their value` | Indexing a set | `tolist()` first |
| `Invalid template interpolation value` | Passing a list/map into `${}` in a template | Use `join()` or `jsonencode()` |
| `vars map does not contain key` (`templatefile`) | Variable used in template but not passed | Pass every variable |
| `Inconsistent conditional result types` | Different types in `? :` | Match types or use `null` |
| `Invalid argument: argument must not be null` | `null` passed to a function | `coalesce()` or `try()` |
| Perpetual diff every plan | `timestamp()` / `uuid()` in arguments | `ignore_changes`, `time_static`, or `random_*` |
| `Function calls not allowed` | Function in backend/lifecycle/variable default | Use literals there |

---

# Interview Questions

### Q1. Can you create your own functions in Terraform?

> No. Terraform only has built-in functions. Reusable logic goes in local values or modules. Since Terraform 1.8, providers can also offer functions, called as `provider::name::function()`.

### Q2. How do you test a function quickly?

> With `terraform console`, which evaluates any expression interactively without changing anything.

### Q3. What is the `...` after a list argument?

> Argument expansion. It spreads a list into separate arguments, for example `max(local.sizes...)`.

### Q4. Difference between `lookup()` and `map["key"]`?

> `lookup(map, key, default)` returns a default when the key is missing. `map["key"]` fails if the key doesn't exist.

### Q5. Difference between `element()` and `list[index]`?

> `element()` wraps around when the index exceeds the length, which is useful for round-robin placement. `list[index]` errors when out of range.

### Q6. How do `merge()` conflicts work?

> Later arguments win for duplicate keys. It's a shallow merge, so nested maps are replaced, not merged.

### Q7. Why use `jsonencode()` for IAM policies?

> It produces valid JSON from Terraform values, avoiding manual syntax mistakes and allowing references and expressions inside the policy.

### Q8. What is `templatefile()` used for?

> Rendering a file with variables, loops, and conditionals, for example EC2 user data scripts or config files.

### Q9. How does `cidrsubnet()` work?

> `cidrsubnet(prefix, newbits, netnum)` adds `newbits` to the prefix length and picks subnet number `netnum`. `cidrsubnet("10.0.0.0/16", 8, 1)` returns `10.0.1.0/24`.

### Q10. Difference between `try()` and `can()`?

> `try()` returns the first expression that succeeds or a fallback value. `can()` returns true or false depending on whether an expression succeeds, and is common in validation.

### Q11. Why can `timestamp()` cause problems?

> It returns a new value every run, so any resource using it shows a change on every plan. Use `ignore_changes`, `time_static`, or `plantimestamp()` where appropriate.

### Q12. How do you make Lambda redeploy only when the code changes?

> Set `source_code_hash = filebase64sha256("lambda.zip")`, or use `data.archive_file.x.output_base64sha256` when the zip is built by Terraform.

### Q13. When are filesystem functions evaluated?

> At plan time, reading files from the local disk. The files must exist before planning, and they can't be files created by the same apply.

### Q14. How do you convert a list for use in `for_each`?

> `toset(list)` for strings, or a `for` expression to build a map for lists of objects.

### Q15. Why might `sort([10, 2, 33])` surprise you?

> `sort()` works on strings, so numbers are sorted as text: `["10", "2", "33"]`.

---

# Quick Revision

- Functions = built-in tools: `name(args)`; **no custom functions**; test with `terraform console`.
- Nesting runs inside-out; split long chains into `locals`.
- `list...` expands a list into arguments.
- Impure: `timestamp`, `uuid`, `bcrypt` → changes every run.
- **Numeric:** `max`, `min`, `ceil`, `floor`, `abs`, `pow`, `parseint`.
- **String:** `upper/lower/title`, `trim*`, `replace` (regex with `/.../`), `split/join`, `format` (`%03d`), `substr`, `regex/regexall`, `strcontains/startswith/endswith`.
- **Collection:** `length`, `contains`, `element` (wraps), `concat`, `flatten`, `distinct`, `compact`, `merge` (later wins, shallow), `lookup` (default), `keys/values`, `zipmap`, `setproduct`, `coalesce`, `one`, `sort` (text).
- **Encoding:** `jsonencode` (IAM policies), `yamldecode`/`csvdecode` (config files), `base64encode`.
- **Filesystem:** `path.module`, `file`, `fileexists`, `fileset`, `templatefile` (`${}`, `%{ for }`, `%{ if }`, `~`).
- **Time:** `timestamp`, `plantimestamp`, `formatdate`, `timeadd` (hours, not days), `timecmp`.
- **Hash:** `filemd5` (S3 etag), `filebase64sha256` (Lambda), `uuidv5` (stable); use `random_*` for stable randomness.
- **Network:** `cidrsubnet` (`/16 + 8 = /24`), `cidrsubnets`, `cidrhost`, `cidrnetmask`.
- **Types:** `toset` (for_each), `tonumber`, `tostring`, `try` (fallback), `can` (validation), `sensitive/nonsensitive`.
- **Provider functions (1.8+):** `provider::aws::arn_parse(...)`.

---

## One-Line Summary

> Terraform functions are built-in tools for maths, text, collections, encoding, files, time, hashing, networking, and type handling. You can't write your own, but by nesting them, combining them with locals, and testing them in `terraform console`, you can build clean, dynamic infrastructure code without hardcoding.

---

## Official References

- https://developer.hashicorp.com/terraform/language/functions
- https://developer.hashicorp.com/terraform/language/expressions/function-calls
- https://developer.hashicorp.com/terraform/language/functions/templatefile
- https://developer.hashicorp.com/terraform/language/expressions/strings
- https://developer.hashicorp.com/terraform/language/functions/cidrsubnet
- https://developer.hashicorp.com/terraform/language/functions/try
- https://developer.hashicorp.com/terraform/language/functions/can
- https://developer.hashicorp.com/terraform/language/functions/formatdate
- https://developer.hashicorp.com/terraform/plugin/framework/functions
- https://registry.terraform.io/providers/hashicorp/aws/latest/docs/functions/arn_parse
- https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/static
- https://registry.terraform.io/providers/hashicorp/random/latest/docs
