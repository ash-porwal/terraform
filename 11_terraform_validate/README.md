# Terraform Notes - `terraform validate`

## Quick Answer

`terraform validate` checks whether your Terraform code is **written correctly**. It checks that the syntax is valid and that the code is **internally consistent**, for example that references point to things that exist and arguments are allowed.

It does **not** talk to GitHub, AWS, or Azure. It does not check credentials, state, or whether the resources can really be created.

```bash
terraform validate
```

```text
Success! The configuration is valid.
```

> Think of it like a **spell-check and grammar-check** for Terraform code. It tells you the code is well-formed. It doesn't tell you the deployment will succeed.

---

## Where It Fits in the Workflow

```text
Write code
    ↓
terraform init       -> download providers and modules
    ↓
terraform fmt        -> make the code neat (optional but recommended)
    ↓
terraform validate   -> check the code is correct  <-- this file
    ↓
terraform plan       -> compare with real infrastructure
    ↓
terraform apply      -> make the changes
```

---

## Why Do We Need It?

- **Catches mistakes early**, before `plan` or `apply`.
- **Fast**: no API calls, no cloud login needed.
- **Safe**: never changes anything, so it can run automatically on every save or commit.
- **Great for CI/CD**: the first quality gate in a pipeline.
- **Great for reusable modules**: checks attribute names and value types without needing real input values.

---

## Requirement: Run `terraform init` First

Validate needs the **provider plugins** to know which arguments each resource supports. So the working directory must be initialized.

If you skip init:

```text
Error: Missing required provider

This configuration requires provider registry.terraform.io/integrations/github,
but that provider isn't available. You may be able to install it automatically
by running:
  terraform init
```

### Init without a backend (useful in CI)

If your project uses a remote backend, like S3, but you only want to validate:

```bash
terraform init -backend=false
terraform validate
```

This downloads providers and modules **without connecting to the remote state**, so no cloud credentials are needed for the backend.

---

## What `validate` Checks ✅

| Check | Example of what it catches |
|---|---|
| **Syntax errors** | Missing `}` or `"`, wrong `=` usage |
| **Unsupported arguments** | `visiblity = "public"` (typo) |
| **Missing required arguments** | A `github_repository` without `name` |
| **Wrong value types** | `auto_init = "maybe"` where a `bool` is expected |
| **Undeclared variables** | Using `var.repo_name` with no `variable "repo_name"` block |
| **Undeclared resources** | Referencing `github_repository.docs` when it doesn't exist |
| **Invalid attribute references** | `github_repository.repo.html_link` (attribute doesn't exist) |
| **Duplicate names** | Two `resource "github_repository" "repo"` blocks |
| **Invalid block types** | A misspelled block, like `resorce` |
| **Module input problems** | Passing an argument a module doesn't declare |

## What `validate` Does NOT Check ❌

| Not checked | Why | Caught by |
|---|---|---|
| Invalid or expired credentials / token | No API calls are made | `plan` / `apply` |
| Permission problems (403) | No API calls | `plan` / `apply` |
| Repo name already exists | No API calls | `apply` |
| Remote state / backend access | Backend isn't contacted | `init` / `plan` |
| Real values from `.tfvars` and env vars | Validation runs regardless of variable values | `plan` |
| Drift / differences from real infrastructure | State isn't compared | `plan` |
| Many platform-specific values (e.g. a non-existent AWS instance type) | Often only the platform API knows | `plan`, `apply`, or `tflint` |
| Code style / formatting | Not its job | `terraform fmt -check` |

> **Key point:** `Success! The configuration is valid.` means **the code is well-formed**, not that `apply` will succeed.

---

## Examples with the GitHub Project

### Valid code

```hcl
terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

provider "github" {
  owner = "your-github-username"
}

resource "github_repository" "learning_repo" {
  name       = "terraform-created-repo"
  visibility = "public"
  auto_init  = true
}

output "repo_url" {
  value = github_repository.learning_repo.html_url
}
```

```bash
terraform validate
```

```text
Success! The configuration is valid.
```

---

### Error 1: Syntax error (missing closing brace)

```hcl
resource "github_repository" "learning_repo" {
  name = "terraform-created-repo"
```

```text
Error: Unclosed configuration block

  on main.tf line 1, in resource "github_repository" "learning_repo":
   1: resource "github_repository" "learning_repo" {

There is no closing brace for this block before the end of the file.
```

---

### Error 2: Typo in an argument name

```hcl
resource "github_repository" "learning_repo" {
  name      = "terraform-created-repo"
  visiblity = "public"
}
```

```text
Error: Unsupported argument

  on main.tf line 3, in resource "github_repository" "learning_repo":
   3:   visiblity = "public"

An argument named "visiblity" is not expected here. Did you mean "visibility"?
```

---

### Error 3: Missing required argument

```hcl
resource "github_repository" "learning_repo" {
  visibility = "public"
}
```

```text
Error: Missing required argument

  on main.tf line 1, in resource "github_repository" "learning_repo":
   1: resource "github_repository" "learning_repo" {

The argument "name" is required, but no definition was found.
```

---

### Error 4: Wrong type

```hcl
resource "github_repository" "learning_repo" {
  name      = "terraform-created-repo"
  auto_init = "maybe"
}
```

```text
Error: Incorrect attribute value type

  on main.tf line 3, in resource "github_repository" "learning_repo":
   3:   auto_init = "maybe"

Inappropriate value for attribute "auto_init": a bool is required.
```

---

### Error 5: Undeclared variable

```hcl
resource "github_repository" "learning_repo" {
  name = var.repo_name
}
```

No `variable "repo_name"` block exists:

```text
Error: Reference to undeclared input variable

  on main.tf line 2, in resource "github_repository" "learning_repo":
   2:   name = var.repo_name

An input variable with the name "repo_name" has not been declared.
```

---

### Error 6: Reference to a resource that doesn't exist

```hcl
output "repo_url" {
  value = github_repository.docs.html_url
}
```

```text
Error: Reference to undeclared resource

  on outputs.tf line 2, in output "repo_url":
   2:   value = github_repository.docs.html_url

A managed resource "github_repository" "docs" has not been declared in the root module.
```

> This is a very common error after **deleting a resource block** but forgetting the output or other references that used it.

---

### Error 7: Wrong attribute name

```hcl
output "repo_url" {
  value = github_repository.learning_repo.html_link
}
```

```text
Error: Unsupported attribute

  on outputs.tf line 2, in output "repo_url":
   2:   value = github_repository.learning_repo.html_link

This object has no argument, nested block, or exported attribute named "html_link".
```

---

### Error 8: Duplicate resource name

```hcl
resource "github_repository" "repo" {
  name = "repo-one"
}

resource "github_repository" "repo" {
  name = "repo-two"
}
```

```text
Error: Duplicate resource "github_repository" configuration

A github_repository resource named "repo" was already declared at main.tf:1,1-37.
Resource names must be unique per type in each module.
```

---

### Not an error: wrong token

```powershell
$env:GITHUB_TOKEN = "wrong-token"
terraform validate
```

```text
Success! The configuration is valid.
```

`validate` passes because it never contacts GitHub. The bad token only shows up later:

```bash
terraform plan
```

```text
Error: GET https://api.github.com/user: 401 Bad credentials
```

---

## Validate and Variables

`validate` checks the code **regardless of the variable values** you supply. It confirms that variables are declared and used correctly, but it doesn't use your real `.tfvars` values to decide whether the configuration is valid.

```hcl
variable "repo_visibility" {
  type = string

  validation {
    condition     = contains(["public", "private"], var.repo_visibility)
    error_message = "Visibility must be public or private."
  }
}
```

- `terraform validate` checks that this `validation` block is **written correctly**.
- To check a **real value** against the rule, like `repo_visibility = "secret"` in `terraform.tfvars`, run `terraform plan`. That's where the actual values are evaluated.

> Newer Terraform versions also accept `-var` and `-var-file` on `validate`. Run `terraform validate -help` to see what your version supports. `terraform plan` is still the reliable place to check real variable values, because plan always includes validation.

---

## Command Options

```bash
terraform validate [options]
```

| Option | Purpose |
|---|---|
| `-json` | Output results as machine-readable JSON (for tools and CI) |
| `-no-color` | Plain output without colours (cleaner CI logs) |
| `-var 'NAME=VALUE'` | Set a variable value (newer versions) |
| `-var-file=FILE` | Load variables from a `.tfvars` file (newer versions) |

> Run `terraform validate -help` to see every option for your installed version.

### Validate a different directory

```bash
terraform -chdir=envs/dev validate
```

`-chdir` is a global option, so it goes **before** `validate`.

---

## JSON Output

```bash
terraform validate -json
```

### Valid code

```json
{
  "format_version": "1.0",
  "valid": true,
  "error_count": 0,
  "warning_count": 0,
  "diagnostics": []
}
```

### Invalid code (simplified)

```json
{
  "format_version": "1.0",
  "valid": false,
  "error_count": 1,
  "warning_count": 0,
  "diagnostics": [
    {
      "severity": "error",
      "summary": "Unsupported argument",
      "detail": "An argument named \"visiblity\" is not expected here. Did you mean \"visibility\"?",
      "range": {
        "filename": "main.tf",
        "start": { "line": 3, "column": 3 }
      }
    }
  ]
}
```

| Field | Meaning |
|---|---|
| `valid` | `true` or `false` |
| `error_count` / `warning_count` | Number of problems found |
| `diagnostics` | Details of each problem, including file and line |

> Tools like the VS Code extension and CI systems use this to highlight errors on the exact line.

---

## Exit Codes (Important for CI/CD)

| Exit code | Meaning |
|---|---|
| `0` | Configuration is valid (warnings are allowed) |
| `1` | Configuration has errors |

A pipeline step fails automatically when the exit code is `1`.

---

## `fmt` vs `validate` vs `plan`

| | `terraform fmt` | `terraform validate` | `terraform plan` |
|---|---|---|---|
| Purpose | Format code neatly | Check code is correct | Preview real changes |
| Needs `init` | ❌ No | ✅ Yes | ✅ Yes |
| Needs credentials | ❌ No | ❌ No | ✅ Yes |
| Contacts the provider API | ❌ No | ❌ No | ✅ Yes |
| Reads state | ❌ No | ❌ No | ✅ Yes |
| Uses real variable values | ❌ No | Not needed | ✅ Yes |
| Changes files | ✅ Yes (rewrites formatting) | ❌ No | ❌ No |
| Changes infrastructure | ❌ No | ❌ No | ❌ No |
| Speed | Very fast | Fast | Slower |

> `terraform plan` **includes validation automatically**. So if you always run `plan`, you get validation too. `validate` is still useful because it's fast, needs no credentials, and fits early checks in CI.

---

## Using It in CI/CD

### Typical checks

```bash
terraform init -backend=false -input=false
terraform fmt -check -recursive
terraform validate -no-color
```

| Step | Fails when |
|---|---|
| `fmt -check -recursive` | Any file isn't formatted |
| `validate` | The code has errors |

### GitHub Actions example

```yaml
name: terraform-checks

on: [pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: hashicorp/setup-terraform@v3

      - name: Terraform Init
        run: terraform init -backend=false -input=false

      - name: Terraform Format Check
        run: terraform fmt -check -recursive

      - name: Terraform Validate
        run: terraform validate -no-color
```

> No cloud or GitHub token is needed for these steps, because none of them call a provider API.

---

## Going Beyond `validate`

`validate` checks Terraform rules. It doesn't know platform-specific rules or best practices. Common add-ons:

| Tool | What it adds |
|---|---|
| **VS Code HashiCorp Terraform extension** | Shows validation errors while you type |
| **TFLint** | Linter that can catch provider-specific problems, like invalid AWS instance types, plus best-practice rules |
| **Checkov / Trivy** | Security and compliance scanning (for example, public buckets or missing encryption) |
| **pre-commit hooks** | Run `fmt` and `validate` automatically before each Git commit |

---

## Hands-on Practice

Using your GitHub repo project:

```bash
# 0. Make sure it's initialized
terraform init

# 1. Valid code
terraform validate

# 2. Break it on purpose, one at a time, and run validate after each:
#    - remove a closing }
#    - misspell "visibility" as "visiblity"
#    - delete the "name" argument
#    - set auto_init = "maybe"
#    - use var.repo_name without declaring it
#    - reference github_repository.docs in an output
terraform validate

# 3. See JSON output
terraform validate -json

# 4. Prove validate doesn't check credentials
$env:GITHUB_TOKEN = "wrong-token"
terraform validate   # Success
terraform plan       # 401 Bad credentials

# 5. Delete .terraform/ and try again
#    (PowerShell: Remove-Item -Recurse -Force .terraform)
terraform validate   # error: provider not available -> run terraform init
```

---

## Common Mistakes

| Mistake | Correct understanding |
|---|---|
| Running `validate` before `init` | Run `terraform init` first (or `init -backend=false`) |
| Thinking "valid" means "apply will work" | Credentials, permissions, and API rules are only checked by `plan`/`apply` |
| Expecting `validate` to check `.tfvars` values against rules | Use `terraform plan` to check real values |
| Expecting `validate` to fix formatting | That's `terraform fmt` |
| Putting `-chdir` after `validate` | It's global: `terraform -chdir=DIR validate` |
| Skipping `plan` because validate passed | Always review `plan` before `apply` |
| Forgetting to remove references after deleting a resource | Validate catches this; fix the outputs/references |

---

## Interview Questions

### Q1. What does `terraform validate` do?

> It checks that the configuration files in a directory are syntactically valid and internally consistent, such as correct argument names, types, and references. It does not contact remote services.

### Q2. Does `terraform validate` need `terraform init`?

> Yes. It needs an initialized directory with provider plugins and modules installed. In CI, `terraform init -backend=false` initializes without connecting to the backend.

### Q3. Does `validate` check credentials or access to the cloud?

> No. It doesn't call provider APIs or remote state, so wrong credentials or permissions are only caught by `plan` or `apply`.

### Q4. What's the difference between `validate` and `plan`?

> `validate` only checks the code. `plan` also reads state, uses real variable values, calls provider APIs, and shows the actual changes. `plan` includes validation automatically.

### Q5. What's the difference between `validate` and `fmt`?

> `fmt` rewrites code into the standard style. `validate` checks correctness and never changes files.

### Q6. Why use `validate` if `plan` already validates?

> It's fast, safe, and needs no credentials or state, so it works well as an early check on every commit or pull request.

### Q7. What does `terraform validate -json` do?

> It outputs results in JSON, including `valid`, error and warning counts, and diagnostics with file and line numbers, for use by editors and CI tools.

### Q8. Give examples of errors `validate` catches.

> Syntax errors, unsupported or misspelled arguments, missing required arguments, wrong value types, undeclared variables or resources, invalid attribute references, and duplicate resource names.

### Q9. Give examples of errors `validate` cannot catch.

> Invalid credentials, permission errors, names that already exist, real variable values breaking validation rules, drift, and many platform-specific values.

### Q10. What exit code does validate return?

> `0` when the configuration is valid and `1` when there are errors, which lets CI pipelines fail automatically.

---

## Quick Revision

- `terraform validate` = **check the code is correct**.
- Checks syntax, arguments, types, references, and duplicate names.
- Needs `terraform init` first; in CI use `init -backend=false`.
- **No** API calls, **no** credentials, **no** state, **no** infrastructure changes.
- "Valid" ≠ "apply will succeed".
- Checks code regardless of real variable values; `plan` checks real values.
- `-json` for tools; `-no-color` for clean logs.
- Exit code `0` = valid, `1` = errors.
- `fmt` = formatting, `validate` = correctness, `plan` = real changes.
- `plan` includes validation automatically.
- Add TFLint and security scanners for deeper checks.

---

## One-Line Summary

> `terraform validate` is a fast, safe check that Terraform code is syntactically correct and internally consistent. It needs an initialized directory but no credentials, and it doesn't prove the deployment will succeed, which is what `plan` checks.

---

## Official References

- [terraform validate command](https://developer.hashicorp.com/terraform/cli/commands/validate)
- [Terraform CLI commands overview](https://developer.hashicorp.com/terraform/cli/commands)
- [terraform fmt command](https://developer.hashicorp.com/terraform/cli/commands/fmt)
- [terraform plan command](https://developer.hashicorp.com/terraform/cli/commands/plan)
