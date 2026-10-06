# Terraform Notes - `terraform console`

## Quick Answer

`terraform console` opens an **interactive prompt** where you can type Terraform **expressions** and see their results instantly.

```bash
terraform console
```

```text
> upper("ashish")
"ASHISH"

> 2 + 3
5

> exit
```

> Think of it like the **Python REPL** (`python` → `>>>`), but for Terraform expressions. It's a **playground** for testing functions, variables, locals, and resource attributes **without running plan or apply**.

---

## Why Use It?

| Use case | Example |
|---|---|
| **Test functions** before putting them in code | `cidrsubnet()`, `join()`, `format()` |
| **Debug expressions** that give unexpected results | A complex `for` expression |
| **Check variable values** after tfvars and `TF_VAR_` are applied | `var.environment` |
| **Inspect locals** | `local.common_tags` |
| **Read resource attributes** from state | `github_repository.learning_repo.html_url` |
| **Find the type** of a value | `type(var.repos)` |
| **Learn Terraform syntax** safely | Strings, lists, maps, conditionals |
| **Use in scripts** | Pipe an expression in, read the result |

---

## What It Does and Doesn't Do

| Item | Effect |
|---|---|
| Evaluates expressions | ✅ Yes |
| Reads your `.tf` config (variables, locals, outputs) | ✅ Yes |
| Reads the **state** (resource attributes) | ✅ Yes |
| Creates, changes, or destroys resources | ❌ Never |
| Modifies the state file | ❌ Never |
| Changes your `.tf` files | ❌ Never |
| Lets you declare variables or resources | ❌ No; expressions only |

> ⚠️ The console **holds a lock on the state** while it's open. Other commands that need the state lock, like `apply`, will wait or fail until you exit. Always exit when you're done.

---

# Part 1: Basics

## Start and Exit

```bash
terraform console
```

```text
>
```

### Exit

| Method | Works on |
|---|---|
| Type `exit` | All platforms ✅ |
| `Ctrl + C` | All platforms |
| `Ctrl + D` | Linux / macOS |

### Help

```text
> help
```

### History

Use the **↑ / ↓ arrow keys** to reuse previous expressions.

---

## Does It Need `terraform init`?

| Situation | Init needed? |
|---|---|
| Empty folder, testing built-in functions only | ❌ No |
| Folder with variables/locals only (no providers) | Usually no |
| Folder with providers, modules, or a backend | ✅ Yes |
| Using provider-defined functions | ✅ Yes |

> Tip: Create a separate **empty practice folder** just for experimenting with functions.

---

## Arithmetic

```text
> 10 + 5
15

> 10 - 3
7

> 4 * 5
20

> 10 / 3
3.3333333333333335

> floor(10 / 3)
3

> 10 % 3
1

> -5 + 2
-3
```

## Comparison and Logic

```text
> 5 > 3
true

> 5 == 5
true

> "dev" != "prod"
true

> true && false
false

> true || false
true

> !true
false
```

## Strings

```text
> "hello"
"hello"

> "Hello, ${upper("ashish")}"
"Hello, ASHISH"

> lower("TERRAFORM")
"terraform"

> title("ashish porwal")
"Ashish Porwal"

> length("terraform")
9

> substr("terraform", 0, 4)
"terr"

> replace("hello world", " ", "-")
"hello-world"

> trimspace("   padded   ")
"padded"

> format("%s-%03d", "web", 7)
"web-007"

> join("-", ["tf", "dev", "repo"])
"tf-dev-repo"

> split(",", "a,b,c")
tolist([
  "a",
  "b",
  "c",
])
```

## Conditionals

```text
> "dev" == "prod" ? "LIVE" : "TEST"
"TEST"

> length("ab") > 1 ? "long" : "short"
"long"
```

## Null

```text
> null
null

> coalesce("", "default")
"default"
```

---

# Part 2: Collections

## Lists

```text
> ["a", "b", "c"]
[
  "a",
  "b",
  "c",
]

> ["a", "b", "c"][0]
"a"

> length(["a", "b", "c"])
3

> contains(["dev", "prod"], "qa")
false

> concat(["a"], ["b", "c"])
[
  "a",
  "b",
  "c",
]

> reverse([1, 2, 3])
[
  3,
  2,
  1,
]

> distinct(["a", "a", "b"])
tolist([
  "a",
  "b",
])
```

## Sets

```text
> toset(["a", "a", "b"])
toset([
  "a",
  "b",
])
```

## Maps / Objects

```text
> { dev = "t2.micro", prod = "t3.large" }
{
  "dev" = "t2.micro"
  "prod" = "t3.large"
}

> { dev = "t2.micro", prod = "t3.large" }["dev"]
"t2.micro"

> lookup({ dev = "t2.micro" }, "prod", "t3.small")
"t3.small"

> merge({ a = 1 }, { b = 2 })
{
  "a" = 1
  "b" = 2
}
```

## `for` Expressions

### List → list

```text
> [for s in ["a", "b"] : upper(s)]
[
  "A",
  "B",
]
```

### List → map

```text
> { for s in ["dev", "prod"] : s => "${s}-repo" }
{
  "dev" = "dev-repo"
  "prod" = "prod-repo"
}
```

### With a filter

```text
> [for n in [1, 2, 3, 4, 5] : n if n % 2 == 0]
[
  2,
  4,
]
```

### Map → list

```text
> [for k, v in { dev = 1, prod = 3 } : "${k}=${v}"]
[
  "dev=1",
  "prod=3",
]
```

## Splat Expressions

```text
> [{ name = "a" }, { name = "b" }][*].name
[
  "a",
  "b",
]
```

---

# Part 3: Useful Functions to Practise

| Category | Try in console |
|---|---|
| Number | `max(3, 7, 2)`, `min(3, 7, 2)`, `abs(-4)`, `ceil(2.1)` |
| Type conversion | `tonumber("5") + 1`, `tostring(10)`, `tolist(toset(["b","a"]))` |
| Error handling | `try(tonumber("abc"), 0)`, `can(regex("^t3\\.", "t3.micro"))` |
| Encoding | `jsonencode({ name = "ashish" })`, `jsondecode("{\"a\":1}")`, `base64encode("hi")` |
| Network | `cidrsubnet("10.0.0.0/16", 8, 1)`, `cidrhost("10.0.1.0/24", 5)` |
| Date/time | `timestamp()`, `formatdate("YYYY-MM-DD", timestamp())` |
| Files | `file("README.md")`, `fileexists("main.tf")` |
| Collections | `keys(...)`, `values(...)`, `flatten([[1],[2,3]])`, `one([])` |

### Examples

```text
> cidrsubnet("10.0.0.0/16", 8, 1)
"10.0.1.0/24"

> try(tonumber("abc"), 0)
0

> jsonencode({ name = "ashish" })
"{\"name\":\"ashish\"}"

> one([])
null
```

> 💡 **Workflow tip:** When you need a tricky function in your code, test it in the console first. Once the output looks right, paste it into your `.tf` file.

---

## `type()`: Find the Type of Any Value

`type()` is a special function that only works **inside the console**.

```text
> type("hello")
string

> type(5)
number

> type(true)
bool

> type(["a", "b"])
tuple([
    string,
    string,
])

> type(tolist(["a", "b"]))
list(string)

> type({ name = "ashish", exp = 4 })
object({
    exp: number,
    name: string,
})
```

> Notice: a literal `["a", "b"]` is a **tuple**, and `{ ... }` is an **object**. Terraform converts them to `list` or `map` when a variable or argument requires it. `type()` helps you understand type errors.

---

# Part 4: Using Your Project's Config

Run `terraform console` **inside your project folder**, and it loads your variables, locals, resources, data sources, and module outputs.

## Example project

### `variables.tf`

```hcl
variable "environment" {
  type    = string
  default = "dev"
}

variable "repos" {
  type = map(string)
  default = {
    "tf-dev"  = "Dev repo"
    "tf-prod" = "Prod repo"
  }
}

variable "db_password" {
  type      = string
  sensitive = true
  default   = "SuperSecret123"
}
```

### `locals.tf`

```hcl
locals {
  repo_prefix = "ashish-${var.environment}"
  common_tags = {
    owner       = "ashish"
    environment = var.environment
  }
}
```

### `main.tf`

```hcl
resource "github_repository" "learning_repo" {
  name      = "${local.repo_prefix}-learning"
  auto_init = true
}

resource "github_repository" "multi" {
  for_each    = var.repos
  name        = each.key
  description = each.value
}
```

## Variables

```text
> var.environment
"dev"

> var.repos
tomap({
  "tf-dev" = "Dev repo"
  "tf-prod" = "Prod repo"
})

> var.repos["tf-dev"]
"Dev repo"

> keys(var.repos)
tolist([
  "tf-dev",
  "tf-prod",
])
```

## Locals

```text
> local.repo_prefix
"ashish-dev"

> local.common_tags
{
  "environment" = "dev"
  "owner" = "ashish"
}
```

## Variable sources are applied

The console uses the same variable sources as plan: defaults, `terraform.tfvars`, `*.auto.tfvars`, `TF_VAR_`, `-var`, and `-var-file`.

```bash
terraform console -var="environment=prod"
```

```text
> var.environment
"prod"

> local.repo_prefix
"ashish-prod"
```

```bash
terraform console -var-file="envs/prod.tfvars"
```

> Great for checking **which value actually wins** in variable precedence.

### Required variables

If a variable has no default and no value, the console **prompts** for it, just like plan:

```text
var.environment
  Enter a value:
```

## Resource Attributes (from State)

### Before apply

```text
> github_repository.learning_repo.name
"ashish-dev-learning"

> github_repository.learning_repo.html_url
(known after apply)
```

Values from your code are known; values only the platform creates are unknown.

### After apply

```text
> github_repository.learning_repo.html_url
"https://github.com/ashish/ashish-dev-learning"

> github_repository.learning_repo.visibility
"public"
```

### Whole resource

```text
> github_repository.learning_repo
```

Shows **every attribute**. Useful for discovering attribute names you can use in outputs.

### `for_each` resources

```text
> github_repository.multi["tf-dev"].html_url
"https://github.com/ashish/tf-dev"

> { for k, r in github_repository.multi : k => r.html_url }
{
  "tf-dev" = "https://github.com/ashish/tf-dev"
  "tf-prod" = "https://github.com/ashish/tf-prod"
}

> keys(github_repository.multi)
[
  "tf-dev",
  "tf-prod",
]
```

> 💡 Test an output expression here first, then copy it into `outputs.tf`.

### `count` resources

```text
> github_repository.counted[*].html_url
> length(github_repository.counted)
```

## Data Sources and Modules

```text
> data.github_user.me.login
> module.frontend.url
```

## Sensitive Values

```text
> var.db_password
(sensitive value)

> length(var.db_password)
(sensitive value)

> nonsensitive(var.db_password)
"SuperSecret123"
```

> The console protects sensitive values, but `nonsensitive()` reveals them. Be careful when sharing your screen.

---

# Part 5: Options

```bash
terraform console [options]
```

| Option | Purpose |
|---|---|
| `-var 'NAME=VALUE'` | Set a variable value |
| `-var-file=FILE` | Load variables from a `.tfvars` file |
| `-plan` | Evaluate expressions against a **fresh plan** (newer versions) |
| `-state=PATH` | Use a specific local state file (legacy) |

### `-plan`

```bash
terraform console -plan
```

- Normally the console uses the **current state** (last apply).
- With `-plan`, Terraform first builds a plan, so you can inspect **planned values**, for example after changing code but before applying.
- It may contact providers, like a normal plan, so credentials are needed.

> Check `terraform console -help` for the options supported by your Terraform version.

### Different directory

```bash
terraform -chdir=envs/dev console
```

---

# Part 6: Non-Interactive Use (Scripts)

Pipe an expression into the console to get the result **without** an interactive session.

### Bash

```bash
echo 'upper("ashish")' | terraform console
```

```text
"ASHISH"
```

```bash
echo 'var.environment' | terraform console -var="environment=prod"
echo 'github_repository.learning_repo.html_url' | terraform console
```

### PowerShell

```powershell
'upper("ashish")' | terraform console
'cidrsubnet("10.0.0.0/16", 8, 1)' | terraform console
```

### Save to a variable

```bash
URL=$(echo 'github_repository.learning_repo.html_url' | terraform console)
echo $URL     # includes quotes: "https://..."
```

### Multiple expressions

```bash
printf 'var.environment\nlocal.repo_prefix\n' | terraform console
```

> For reading **final output values** in scripts, `terraform output -raw` or `-json` is cleaner. Use console piping for **expressions** that aren't outputs.

---

# Part 7: Limitations

| Limitation | Detail |
|---|---|
| Expressions only | No `variable`, `resource`, `locals`, or `output` blocks |
| No assignments | `x = 5` doesn't work |
| No custom variables in the session | Add them to `.tf` files or use `-var` |
| Locks the state | Exit before running `apply` |
| Unknown values | Not-yet-created attributes show `(known after apply)` |
| Shows last applied state | Use `-plan` to see planned values |
| Multi-line input | Limited in older versions; newer versions support multi-line expressions. Otherwise, write it on one line |
| Can't call external commands | It's not a shell |

---

## Console vs Other Commands

| | `console` | `output` | `plan` | `state show` |
|---|---|---|---|---|
| Purpose | Evaluate **any** expression | Read **output** values | Preview changes | Show one resource from state |
| Interactive | ✅ Yes | ❌ No | ❌ No | ❌ No |
| Functions and math | ✅ Yes | ❌ No | ❌ No | ❌ No |
| Reads variables and locals | ✅ Yes | ❌ No | ✅ Yes | ❌ No |
| Changes anything | ❌ No | ❌ No | ❌ No | ❌ No |
| Typical use | Testing and debugging | Scripts, CI | Before apply | Inspect a resource |

---

## Hands-on Practice

### Exercise 1: Empty folder (functions only)

```bash
mkdir tf-console-practice
cd tf-console-practice
terraform console
```

```text
> upper("terraform")
> join("-", ["ashish", "dev"])
> [for s in ["dev", "test", "prod"] : "${s}-repo"]
> { for s in ["dev", "prod"] : s => length(s) }
> cidrsubnet("10.0.0.0/16", 8, 2)
> type({ name = "ashish", exp = 4 })
> try(tonumber("abc"), -1)
> exit
```

### Exercise 2: Variables and precedence

```bash
terraform console
> var.environment

terraform console -var="environment=prod"
> var.environment
> local.repo_prefix
```

Then add `environment = "test"` to `terraform.tfvars`, set `TF_VAR_environment`, and check which value wins each time.

### Exercise 3: Resources

```bash
terraform apply
terraform console
> github_repository.learning_repo.html_url
> github_repository.learning_repo
> { for k, r in github_repository.multi : k => r.html_url }
> exit
terraform destroy
```

### Exercise 4: Piping

```bash
echo 'upper("piped")' | terraform console
```

---

## Common Mistakes

| Mistake | Fix |
|---|---|
| Forgetting to exit, then `apply` hangs on the state lock | Type `exit` |
| Writing `variable "x" {}` in the console | Expressions only; declare in `.tf` files |
| Expecting `x = 5` to work | No assignments in the console |
| Running from the wrong folder | `var.`/`local.` errors; `cd` into the project |
| Skipping `init` in a project with providers | Run `terraform init` first |
| Expecting real URLs before apply | Shows `(known after apply)`; apply first or use `-plan` |
| Using `type()` in `.tf` code | `type()` only works in the console |
| Using `nonsensitive()` carelessly | It reveals secrets on screen |
| Escaping quotes wrongly in PowerShell pipes | Wrap the whole expression in single quotes |

---

## Interview Questions

### Q1. What is `terraform console`?

> An interactive command-line tool for evaluating Terraform expressions, including functions, variables, locals, and resource attributes from state, without changing anything.

### Q2. Does `terraform console` change state or resources?

> No. It only reads. But it holds a state lock while open.

### Q3. Why use it?

> To test functions and expressions before writing them into code, debug complex expressions, check variable and local values, and inspect resource attributes.

### Q4. Can you access resource attributes in the console?

> Yes, from the state, for example `github_repository.learning_repo.html_url`. Before apply, platform-generated values show as `(known after apply)`.

### Q5. How do you pass variables to the console?

> The same ways as plan: defaults, tfvars, `TF_VAR_` environment variables, `-var`, and `-var-file`.

### Q6. Which function only works in the console?

> `type()`, which shows the type of a value.

### Q7. How are sensitive values shown?

> As `(sensitive value)`, unless revealed with `nonsensitive()`.

### Q8. How do you use the console non-interactively?

> Pipe an expression into it, for example `echo 'upper("a")' | terraform console`.

### Q9. How do you exit the console?

> Type `exit`, or press Ctrl+C (Ctrl+D also works on Linux and macOS).

### Q10. What does `terraform console -plan` do?

> It evaluates expressions in the context of a fresh plan, so planned values can be inspected before apply.

### Q11. Can you declare variables or resources in the console?

> No. It only evaluates expressions. Declarations must go in `.tf` files.

---

## Quick Revision

- `terraform console` = **REPL for Terraform expressions**.
- Start with `terraform console`; exit with `exit` or Ctrl+C.
- Never changes resources, state, or code, but **locks state** while open.
- Empty folder → test built-in functions; project folder → `var.`, `local.`, resources, data, modules.
- Uses defaults, tfvars, `TF_VAR_`, `-var`, `-var-file`.
- Resource values come from **state**; unknown before apply → `(known after apply)`.
- `-plan` evaluates against a fresh plan.
- `type()` works only in the console.
- Sensitive → `(sensitive value)`; `nonsensitive()` reveals.
- Pipe for scripts: `echo 'expr' | terraform console`.
- Expressions only: no blocks, no assignments.
- Best habit: **test in console → paste into code**.

---

## One-Line Summary

> `terraform console` is an interactive, read-only playground for evaluating Terraform expressions. You can use it to test functions, check variables and locals, and inspect resource attributes from state before writing them into your code.

---

## Official References

- [terraform console command](https://developer.hashicorp.com/terraform/cli/commands/console)
- [Built-in functions](https://developer.hashicorp.com/terraform/language/functions)
- [type function](https://developer.hashicorp.com/terraform/language/functions/type)
- [Expressions](https://developer.hashicorp.com/terraform/language/expressions)
- [for expressions](https://developer.hashicorp.com/terraform/language/expressions/for)
