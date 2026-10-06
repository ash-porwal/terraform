# Terraform Notes - Output Values (`output` block and `terraform output`)

## Quick Answer

An **output** is a value that Terraform **shows or exposes after it runs**. Think of it as the **return value** of your Terraform code.

```hcl
output "repo_url" {
  value = github_repository.learning_repo.html_url
}
```

After `terraform apply`:

```text
Outputs:

repo_url = "https://github.com/ashish/terraform-created-repo"
```

### Python analogy

```python
def create_repo(name):          # variables  = inputs
    url = ...                   # locals     = internal values
    return url                  # outputs    = return values
```

```text
variable  -> goes INTO the module
locals    -> used INSIDE the module
output    -> comes OUT of the module
```

---

# Level 1: Beginner

## Why Do We Need Outputs?

| Use case | Example |
|---|---|
| **Show useful info** after apply | Repo URL, server IP, database endpoint |
| **Pass values between modules** | Network module returns `vpc_id` to the compute module |
| **Share values between projects** | Another Terraform project reads them via remote state |
| **Use in scripts and CI/CD** | Pipeline reads the URL and runs tests against it |
| **Avoid opening the console** | No need to log in to GitHub/AWS to find an ID |

---

## Basic Syntax

```hcl
output "<name>" {
  value = <expression>
}
```

| Part | Meaning |
|---|---|
| `output` | Block type |
| `"<name>"` | Output name (label); must be unique in the module |
| `value` | **Required.** Any Terraform expression |

### Naming rules

- Letters, digits, underscores, and hyphens; must start with a letter or underscore.
- Use clear names: `repo_url`, not `x` or `out1`.
- Convention: lowercase with underscores (`snake_case`).

---

## Your First Output (No Cloud Needed)

```hcl
output "ashish_output" {
  value = "ashish's first terraform"
}
```

```bash
terraform init
terraform apply
```

```text
Changes to Outputs:
  + ashish_output = "ashish's first terraform"

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

ashish_output = "ashish's first terraform"
```

> No resources were created, but the output is still saved in the state file.

---

## What Can Go Inside `value`?

| Source | Example |
|---|---|
| Literal string/number/bool | `"hello"`, `3`, `true` |
| Variable | `var.environment` |
| Local value | `local.common_tags` |
| Resource attribute | `github_repository.learning_repo.html_url` |
| Data source attribute | `data.github_user.me.login` |
| Module output | `module.network.vpc_id` |
| String interpolation | `"Repo ${github_repository.learning_repo.name} is ready"` |
| Function call | `upper(var.environment)` |
| Conditional | `var.environment == "prod" ? "LIVE" : "TEST"` |
| List / map / object | `[a, b]`, `{ url = ..., name = ... }` |
| `for` expression | `[for r in github_repository.multi : r.html_url]` |

---

## Outputs from a Real Resource (GitHub)

```hcl
resource "github_repository" "learning_repo" {
  name       = "terraform-created-repo"
  visibility = "public"
  auto_init  = true
}

output "repo_name" {
  value = github_repository.learning_repo.name
}

output "repo_url" {
  value = github_repository.learning_repo.html_url
}

output "clone_url" {
  value = github_repository.learning_repo.http_clone_url
}
```

### Reading the reference

```text
github_repository . learning_repo . html_url
     type             local name     attribute
```

> Which attributes exist? Check the **Attributes Reference** section of the resource page in the Terraform Registry.

---

## Outputs During `plan`: `(known after apply)`

```bash
terraform plan
```

```text
Changes to Outputs:
  + clone_url = (known after apply)
  + repo_name = "terraform-created-repo"
  + repo_url  = (known after apply)
```

| Value | Why |
|---|---|
| `repo_name` | Known now; you wrote it in code |
| `repo_url` | Only GitHub knows it after the repo is created |

---

## Order of Outputs

Outputs are displayed in **alphabetical order of output name**, not the order in your files.

```hcl
output "zebra" { value = 1 }
output "apple" { value = 2 }
```

```text
Outputs:

apple = 2
zebra = 1
```

---

## Where to Write Outputs

Convention is a separate file:

```text
project/
├── providers.tf
├── variables.tf
├── main.tf
└── outputs.tf     <- all output blocks here
```

> Any `.tf` file works, because Terraform reads all files in the directory together. `outputs.tf` is just a convention.

---

# Level 2: Intermediate

## All Output Block Arguments

```hcl
output "name" {
  value       = <expression>     # required
  description = "..."            # optional, recommended
  sensitive   = true             # optional
  depends_on  = [ ... ]          # optional, rare
  ephemeral   = true             # optional, child modules only (Terraform 1.10+)

  precondition {                 # optional (Terraform 1.2+)
    condition     = <bool expression>
    error_message = "..."
  }
}
```

| Argument | Purpose |
|---|---|
| `value` | The value to return |
| `description` | Documents what the output is for |
| `sensitive` | Hides the value in CLI output |
| `depends_on` | Adds an explicit dependency |
| `precondition` | Checks a condition before saving the output |
| `ephemeral` | Value is passed on but never saved in state or plan |

---

## `description`

```hcl
output "repo_url" {
  description = "Web URL of the learning repository"
  value       = github_repository.learning_repo.html_url
}
```

Not shown in normal CLI output, but very useful for teammates and module users, and documentation tools like `terraform-docs` read it.

---

## `sensitive`

```hcl
variable "db_password" {
  type      = string
  sensitive = true
}

output "db_password" {
  value     = var.db_password
  sensitive = true
}
```

### How sensitive outputs behave

| Where | What you see |
|---|---|
| `terraform plan` / `apply` | `db_password = <sensitive>` |
| `terraform output` (all outputs) | `db_password = <sensitive>` |
| `terraform output db_password` (by name) | ⚠️ **Real value shown** |
| `terraform output -json` | ⚠️ **Real value shown** |
| `terraform output -raw db_password` | ⚠️ **Real value shown** |
| State file | ⚠️ **Stored in plain text** |

> `sensitive = true` hides the value from **casual display**, but anyone with access to the state can read it. Protect the state.

### Error if you forget `sensitive`

If an output uses a sensitive value without `sensitive = true`:

```text
Error: Output refers to sensitive values

To reduce the risk of accidentally exporting sensitive data that was intended
to be only internal, Terraform requires that any root module output containing
sensitive data be explicitly marked as sensitive, to confirm your intent.
```

Fix: add `sensitive = true`.

### `nonsensitive()` function

If you're **sure** a derived value isn't secret, you can remove the mark:

```hcl
output "password_length" {
  value = nonsensitive(length(var.db_password))
}
```

> Use carefully. Never wrap the actual secret in `nonsensitive()`.

---

## Outputs with Complex Types

### List

```hcl
output "branch_names" {
  value = ["main", "dev", "test"]
}
```

```text
branch_names = [
  "main",
  "dev",
  "test",
]
```

### Map / object

```hcl
output "repo_details" {
  value = {
    name       = github_repository.learning_repo.name
    url        = github_repository.learning_repo.html_url
    visibility = github_repository.learning_repo.visibility
  }
}
```

```text
repo_details = {
  "name" = "terraform-created-repo"
  "url" = "https://github.com/ashish/terraform-created-repo"
  "visibility" = "public"
}
```

### Whole resource object

```hcl
output "repo_all" {
  value = github_repository.learning_repo
}
```

Returns **every** attribute. Fine for exploring while learning, but too noisy for real projects, and it may need `sensitive = true` if the resource has sensitive attributes.

---

## Outputs with `count`

```hcl
resource "github_repository" "counted" {
  count = 3
  name  = "tf-counted-${count.index}"
}
```

### All URLs (splat expression `[*]`)

```hcl
output "counted_urls" {
  value = github_repository.counted[*].html_url
}
```

```text
counted_urls = [
  "https://github.com/ashish/tf-counted-0",
  "https://github.com/ashish/tf-counted-1",
  "https://github.com/ashish/tf-counted-2",
]
```

### One instance

```hcl
output "first_url" {
  value = github_repository.counted[0].html_url
}
```

---

## Outputs with `for_each`

```hcl
resource "github_repository" "multi" {
  for_each = toset(["tf-dev", "tf-test", "tf-prod"])
  name     = each.key
}
```

> The splat `[*]` does **not** work directly on `for_each` resources, because they're a map, not a list.

### Map of name → URL ✅ (most useful)

```hcl
output "repo_urls" {
  value = { for name, repo in github_repository.multi : name => repo.html_url }
}
```

```text
repo_urls = {
  "tf-dev" = "https://github.com/ashish/tf-dev"
  "tf-prod" = "https://github.com/ashish/tf-prod"
  "tf-test" = "https://github.com/ashish/tf-test"
}
```

### List of URLs

```hcl
output "repo_url_list" {
  value = [for repo in github_repository.multi : repo.html_url]
}
```

or

```hcl
output "repo_url_list" {
  value = values(github_repository.multi)[*].html_url
}
```

### One instance

```hcl
output "dev_url" {
  value = github_repository.multi["tf-dev"].html_url
}
```

### Filter with `if`

```hcl
output "non_prod_urls" {
  value = [for name, repo in github_repository.multi : repo.html_url if name != "tf-prod"]
}
```

---

## Conditional Outputs

### Different value by condition

```hcl
output "environment_label" {
  value = var.environment == "prod" ? "PRODUCTION" : "NON-PRODUCTION"
}
```

### Output for an optional resource

```hcl
resource "github_repository" "docs" {
  count = var.create_docs ? 1 : 0
  name  = "tf-docs"
}

output "docs_url" {
  value = var.create_docs ? github_repository.docs[0].html_url : null
}
```

Simpler using `one()`:

```hcl
output "docs_url" {
  value = one(github_repository.docs[*].html_url)
}
```

`one()` returns the single element, or `null` if the list is empty.

> An output with a `null` value is **not shown** in CLI output.

---

# Level 3: The `terraform output` Command

Reads outputs from the **state file**. It does **not** run a plan or contact the provider, so it's fast.

### All outputs

```bash
terraform output
```

```text
clone_url = "https://github.com/ashish/terraform-created-repo.git"
db_password = <sensitive>
repo_name = "terraform-created-repo"
repo_url = "https://github.com/ashish/terraform-created-repo"
```

### One output

```bash
terraform output repo_url
```

```text
"https://github.com/ashish/terraform-created-repo"
```

### `-raw`: no quotes (for scripts)

```bash
terraform output -raw repo_url
```

```text
https://github.com/ashish/terraform-created-repo
```

> `-raw` works only for **strings, numbers, and bools**. For lists or maps, use `-json`.

### `-json`: machine-readable

```bash
terraform output -json
```

```json
{
  "repo_url": {
    "sensitive": false,
    "type": "string",
    "value": "https://github.com/ashish/terraform-created-repo"
  },
  "db_password": {
    "sensitive": true,
    "type": "string",
    "value": "SuperSecret123"
  }
}
```

One output as JSON:

```bash
terraform output -json repo_urls
```

```json
{"tf-dev":"https://github.com/ashish/tf-dev","tf-prod":"https://github.com/ashish/tf-prod","tf-test":"https://github.com/ashish/tf-test"}
```

### Options summary

| Option | Purpose |
|---|---|
| *(none)* | All outputs; sensitive ones hidden |
| `NAME` | One output |
| `-raw` | Plain value without quotes (primitive types only) |
| `-json` | JSON format (shows sensitive values!) |
| `-no-color` | No colours |
| `-state=PATH` | Read a specific local state file (legacy) |

### No outputs yet

```text
Warning: No outputs found
```

Cause: no `apply` has been run yet, no output blocks exist, or you're in the wrong folder/workspace.

---

## Using Outputs in Scripts

### Bash

```bash
REPO_URL=$(terraform output -raw repo_url)
echo "Repo created at: $REPO_URL"

# Lists/maps with jq
terraform output -json repo_urls | jq -r '."tf-dev"'
```

### PowerShell

```powershell
$repoUrl = terraform output -raw repo_url
Write-Host "Repo created at: $repoUrl"

# Lists/maps
$urls = terraform output -json repo_urls | ConvertFrom-Json
$urls."tf-dev"
```

### Clone the new repo automatically

```bash
git clone "$(terraform output -raw clone_url)"
```

### CI/CD (GitHub Actions)

```yaml
- name: Terraform Apply
  run: terraform apply -auto-approve

- name: Read output
  id: tf
  run: echo "repo_url=$(terraform output -raw repo_url)" >> "$GITHUB_OUTPUT"

- name: Use output
  run: echo "Deployed to ${{ steps.tf.outputs.repo_url }}"
```

> In GitHub Actions, the `hashicorp/setup-terraform` action wraps commands by default, which can add extra text to output. Set `terraform_wrapper: false` when reading `-raw` values.

---

# Level 4: Advanced

## Outputs in Modules (Most Important Pro Concept)

### Root module vs child module

| | Root module outputs | Child module outputs |
|---|---|---|
| Shown in CLI after apply | ✅ Yes | ❌ No |
| Readable with `terraform output` | ✅ Yes | ❌ No |
| Saved in state | ✅ Yes | Used internally |
| Readable by other projects (remote state) | ✅ Yes | ❌ No |
| How the parent uses it | — | `module.<name>.<output>` |

> A child module's outputs are its **only public interface**. The parent cannot reach inside a module to read its resources directly.

### Example structure

```text
project/
├── main.tf
├── outputs.tf
└── modules/
    └── repo/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

### `modules/repo/main.tf`

```hcl
resource "github_repository" "this" {
  name       = var.name
  visibility = var.visibility
  auto_init  = true
}
```

### `modules/repo/variables.tf`

```hcl
variable "name"       { type = string }
variable "visibility" {
  type    = string
  default = "private"
}
```

### `modules/repo/outputs.tf` (child exposes values)

```hcl
output "url" {
  description = "Repository web URL"
  value       = github_repository.this.html_url
}

output "name" {
  description = "Repository name"
  value       = github_repository.this.name
}
```

### Root `main.tf` (parent calls the module)

```hcl
module "frontend" {
  source = "./modules/repo"
  name   = "tf-frontend"
}

module "backend" {
  source = "./modules/repo"
  name   = "tf-backend"
}
```

### Root `outputs.tf` (re-export to show in CLI)

```hcl
output "frontend_url" {
  value = module.frontend.url
}

output "all_repo_urls" {
  value = {
    frontend = module.frontend.url
    backend  = module.backend.url
  }
}
```

> **Common beginner confusion:** "My module has outputs, but nothing shows after apply." Child outputs must be **re-exported** by a root `output` block.

### Passing one module's output into another module

```hcl
module "repo" {
  source = "./modules/repo"
  name   = "tf-app"
}

module "branch_rules" {
  source    = "./modules/branch-rules"
  repo_name = module.repo.name      # output of one module -> input of another
}
```

Terraform automatically creates a **dependency**: `branch_rules` waits for `repo`.

### Outputs from modules with `for_each`

```hcl
module "repos" {
  source   = "./modules/repo"
  for_each = toset(["tf-dev", "tf-prod"])
  name     = each.key
}

output "repo_urls" {
  value = { for k, m in module.repos : k => m.url }
}
```

---

## Sharing Outputs Between Projects (`terraform_remote_state`)

Project B can read **root outputs** of Project A from A's state.

### Project A (network) outputs

```hcl
output "vpc_id" {
  value = aws_vpc.main.id
}
```

### Project B reads them

```hcl
data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = "ashish-terraform-state"
    key    = "network/terraform.tfstate"
    region = "ap-south-1"
  }
}

resource "aws_subnet" "app" {
  vpc_id     = data.terraform_remote_state.network.outputs.vpc_id
  cidr_block = "10.0.1.0/24"
}
```

| Point | Detail |
|---|---|
| Reads | Only **root module outputs** |
| Needs | Read access to the other project's **whole state file** (which may contain secrets) |
| Alternative | Use **data sources** (e.g. `data "aws_vpc"`) or a parameter store when you don't want to share state access |

---

## `precondition` in Outputs (Terraform 1.2+)

Checks a condition **before** the output is saved. If it fails, Terraform stops with your message.

```hcl
output "repo_url" {
  value = github_repository.learning_repo.html_url

  precondition {
    condition     = github_repository.learning_repo.visibility == "private"
    error_message = "This repository must be private."
  }
}
```

Useful in modules to guarantee that returned values meet expectations.

> Related: **`check` blocks** (Terraform 1.5+) run assertions that show **warnings** instead of stopping the run.

---

## `depends_on` in Outputs (Rare)

Normally dependencies come from references in `value`. Use `depends_on` only when an output must wait for something **not referenced** in its value.

```hcl
output "repo_url" {
  value      = github_repository.learning_repo.html_url
  depends_on = [github_branch_protection.main_rules]
}
```

Here, the URL is only published after branch protection is in place.

> If you need `depends_on`, add a comment explaining why.

---

## Ephemeral Outputs (Terraform 1.10+)

```hcl
output "temp_token" {
  value     = ephemeral.some_provider.token.value
  ephemeral = true
}
```

- Value is passed to the parent module but **never saved** in plan or state files.
- Allowed only in **child modules**, not the root module.
- Used with ephemeral resources and write-only arguments for short-lived secrets.

> Advanced and version-dependent. Check the docs for your Terraform version.

---

## Outputs and State

- Root outputs are **stored in the state file** under `"outputs"`.
- `terraform output` reads from state, so it shows the values from the **last apply**.
- Changing only an output (no resource changes) still needs `apply` to update state:

```text
Changes to Outputs:
  ~ repo_url = "old" -> "new"

You can apply this plan to save these new output values to the Terraform
state, without changing any real infrastructure.
```

- After `terraform destroy`, outputs are removed from state.
- If you remove an output block, the next apply removes it from state.

---

## Best Practices

| Practice | Why |
|---|---|
| Keep outputs in `outputs.tf` | Easy to find |
| Always add `description` | Documents your module's interface |
| Output only what's useful | Fewer values = clearer interface and less risk |
| Use clear names (`repo_url`, not `url1`) | Readability |
| Mark secrets `sensitive = true` | Hides them from casual display |
| Prefer specific attributes over whole objects | Avoids noise and accidental leaks |
| Prefer maps (keyed by name) for `for_each` | Stable and readable |
| Don't use outputs to pass secrets between projects | State access exposes everything |
| Use `-raw` / `-json` in scripts | No quote-stripping hacks |
| Re-export child outputs only when needed | Keeps root outputs focused |

---

## Hands-on Practice

### Exercise 1: No-cloud basics

```hcl
variable "name" {
  default = "Ashish"
}

output "greeting" {
  description = "A friendly greeting"
  value       = "Hello, ${var.name}!"
}

output "skills" {
  value = ["Python", "PySpark", "AWS", "Terraform"]
}

output "profile" {
  value = {
    name       = var.name
    experience = 4
    learning   = true
  }
}

output "secret_note" {
  value     = "my-secret"
  sensitive = true
}
```

```bash
terraform init
terraform apply
terraform output
terraform output greeting
terraform output -raw greeting
terraform output -json skills
terraform output secret_note        # notice: value shown by name
terraform output -json              # notice: sensitive value visible
```

### Exercise 2: GitHub `for_each` outputs

```hcl
resource "github_repository" "multi" {
  for_each  = toset(["tf-out-a", "tf-out-b"])
  name      = each.key
  auto_init = true
}

output "repo_urls" {
  value = { for k, r in github_repository.multi : k => r.html_url }
}
```

```bash
terraform plan            # outputs show (known after apply)
terraform apply
terraform output -json repo_urls
terraform destroy
```

### Exercise 3: Module outputs

Create the `modules/repo` example above, run `apply`, and confirm that child outputs appear **only** after re-exporting them in the root `outputs.tf`.

---

## Common Errors

| Error / Problem | Cause | Fix |
|---|---|---|
| `Output refers to sensitive values` | Sensitive value without `sensitive = true` | Add `sensitive = true` |
| `Unsupported attribute` | Wrong attribute name | Check the registry's Attributes Reference |
| `Reference to undeclared resource` | Resource was deleted/renamed but output still uses it | Update or remove the output |
| `Warning: No outputs found` | No apply yet, wrong folder, or wrong workspace | Run apply; check folder and workspace |
| Splat `[*]` fails on `for_each` resource | `for_each` creates a map | Use a `for` expression or `values(...)[*]` |
| `-raw` fails | Value is a list/map | Use `-json` |
| Child module outputs not shown | Not re-exported | Add a root `output` using `module.x.y` |
| Output shows old value | `terraform output` reads last applied state | Run `terraform apply` |
| Output missing from CLI | Value is `null` | Expected; null outputs are hidden |
| `Missing required argument "value"` | Output block without `value` | Add `value` |

---

## Interview Questions

### Q1. What is an output in Terraform?

> A named value exposed by a module after apply. Root outputs are shown in the CLI and stored in state; child module outputs are passed to the parent module.

### Q2. What is the only required argument in an output block?

> `value`.

### Q3. Difference between variable, local, and output?

> Variables are inputs to a module, locals are internal reusable values, and outputs are values returned from a module.

### Q4. How do you hide a secret in outputs? Is it fully secure?

> Use `sensitive = true`, which hides it in plan, apply, and the all-outputs listing. It is not fully secure, because the value is still in state in plain text and visible via `terraform output NAME` or `-json`.

### Q5. Why does Terraform show `(known after apply)` for outputs?

> The value depends on attributes the platform only creates when the resource is actually created, such as IDs or URLs.

### Q6. How do you use a child module's output?

> Reference it as `module.<module_name>.<output_name>`. To show it in the CLI, re-export it with a root output block.

### Q7. Difference between `terraform output -raw` and `-json`?

> `-raw` prints a plain primitive value without quotes, for scripts. `-json` prints any type as JSON, including sensitive values.

### Q8. How do you output all URLs from a `for_each` resource?

> Use a for expression, for example `{ for k, r in github_repository.multi : k => r.html_url }`, because splat doesn't work directly on `for_each` maps.

### Q9. How can one Terraform project read another project's outputs?

> With the `terraform_remote_state` data source, which reads root module outputs from the other project's state.

### Q10. Does `terraform output` contact the cloud provider?

> No. It reads values from the state file, so it shows the result of the last apply.

### Q11. What is a precondition in an output?

> A check (Terraform 1.2+) that must be true before the output is saved; otherwise Terraform stops with an error message.

### Q12. In what order are outputs displayed?

> Alphabetically by output name, not by file or code order.

---

## Quick Revision

- Output = **return value** of Terraform code.
- `output "name" { value = ... }`; only `value` is required.
- Optional: `description`, `sensitive`, `depends_on`, `precondition`, `ephemeral`.
- Unknown values show as `(known after apply)` in plan.
- Displayed **alphabetically**; `null` outputs are hidden.
- `sensitive = true` hides display only; state, `output NAME`, and `-json` reveal it.
- Forgetting `sensitive` on secret values causes an error.
- `count` → `resource[*].attr`; `for_each` → `{ for k, r in resource : k => r.attr }`.
- `terraform output` reads **state**: `NAME`, `-raw` (primitives), `-json` (any type).
- Child outputs → `module.name.output`; re-export to show in CLI.
- Other projects read root outputs via `terraform_remote_state`.
- Output-only changes still need `apply` to update state.

---

## One-Line Summary

> Outputs are the return values of Terraform code. Root outputs display results after apply and are stored in state, child module outputs pass values to parent modules, `terraform output` reads them for scripts, and `sensitive = true` hides secrets from display but not from the state file.

---

## Official References

- [Output values](https://developer.hashicorp.com/terraform/language/values/outputs)
- [terraform output command](https://developer.hashicorp.com/terraform/cli/commands/output)
- [Module composition](https://developer.hashicorp.com/terraform/language/modules/develop/composition)
- [terraform_remote_state data source](https://developer.hashicorp.com/terraform/language/state/remote-state-data)
- [Custom conditions (precondition, check)](https://developer.hashicorp.com/terraform/language/expressions/custom-conditions)
- [for expressions](https://developer.hashicorp.com/terraform/language/expressions/for)
- [Splat expressions](https://developer.hashicorp.com/terraform/language/expressions/splat)
