# Terraform Notes - Environment Variables

## What is an Environment Variable?

An **environment variable** is a `KEY=VALUE` setting stored in your **terminal session** or **operating system**, not in your Terraform code.

Any program started from that terminal, including Terraform, can read it.

```text
Terminal session
   └── TF_VAR_environment = "dev"
          ↓
      terraform plan reads it
```

---

## Three Kinds of Environment Variables Used with Terraform

| Kind | Example | Purpose |
|---|---|---|
| **1. Input variable values** | `TF_VAR_environment` | Give values to `variable` blocks |
| **2. Terraform CLI behaviour** | `TF_LOG`, `TF_INPUT`, `TF_CLI_ARGS` | Change how Terraform itself behaves |
| **3. Provider credentials/settings** | `AWS_ACCESS_KEY_ID`, `AWS_REGION` | Read by the provider plugin (AWS, Azure, GCP) |

> Kinds 1 and 2 are read by **Terraform**. Kind 3 is read by the **provider plugin**, and the exact names depend on the provider.

---

## How to Set Environment Variables

### Linux / macOS (Bash, Zsh)

```bash
# Set
export TF_VAR_environment="dev"

# Check
echo $TF_VAR_environment

# Remove
unset TF_VAR_environment
```

Set it for **one command only**:

```bash
TF_VAR_environment="prod" terraform plan
```

### Windows PowerShell

```powershell
# Set (current session only)
$env:TF_VAR_environment = "dev"

# Check
echo $env:TF_VAR_environment

# Remove
Remove-Item Env:TF_VAR_environment
```

### Windows Command Prompt (cmd)

```cmd
:: Set
set TF_VAR_environment=dev

:: Check
echo %TF_VAR_environment%
```

### Permanent setting

| OS | How |
|---|---|
| Linux / macOS | Add the `export` line to `~/.bashrc` or `~/.zshrc` |
| Windows | System Properties → Advanced → Environment Variables → New |

> Variables set with `export` or `$env:` last only for **that terminal session**. Close the terminal and they are gone. Open a **new** terminal after setting permanent variables.

---

# Part 1: `TF_VAR_` - Passing Values to Input Variables

## Format

```text
TF_VAR_<variable_name>
```

The part after `TF_VAR_` must **exactly match** the variable name declared in the `variable` block.

## Example

### `variables.tf`

```hcl
variable "environment" {
  type = string
}

variable "instance_count" {
  type = number
}
```

### `outputs.tf`

```hcl
output "summary" {
  value = "Deploying ${var.instance_count} instance(s) to ${var.environment}"
}
```

### Set and run

**Bash:**

```bash
export TF_VAR_environment="dev"
export TF_VAR_instance_count=2
terraform plan
```

**PowerShell:**

```powershell
$env:TF_VAR_environment = "dev"
$env:TF_VAR_instance_count = "2"
terraform plan
```

Output:

```text
summary = "Deploying 2 instance(s) to dev"
```

No prompt appears, because Terraform found both values in the environment.

---

## Case Sensitivity

```text
variable "environment"   ->  TF_VAR_environment   ✅
variable "environment"   ->  TF_VAR_ENVIRONMENT   ❌ (on Linux/macOS)
```

> The `TF_VAR_` prefix is fixed, and the variable-name part must match the declared name. Environment variable names are case-sensitive on Linux and macOS. Windows is case-insensitive, but matching the case exactly everywhere avoids surprises.

---

## Passing Lists and Maps with `TF_VAR_`

Complex types are written in **HCL syntax** inside the string.

### `variables.tf`

```hcl
variable "availability_zones" {
  type = list(string)
}

variable "instance_types" {
  type = map(string)
}
```

### Bash

```bash
export TF_VAR_availability_zones='["ap-south-1a", "ap-south-1b"]'
export TF_VAR_instance_types='{ dev = "t2.micro", prod = "t3.large" }'
```

### PowerShell

```powershell
$env:TF_VAR_availability_zones = '["ap-south-1a", "ap-south-1b"]'
$env:TF_VAR_instance_types = '{ dev = "t2.micro", prod = "t3.large" }'
```

> Use **single quotes** around the whole value so the inner double quotes are kept. Setting `$env:` in PowerShell does not have the quote-stripping problem that `-var` has, so this works as written.

---

## Where `TF_VAR_` Fits in Precedence

From **lowest** to **highest** priority:

```text
1. default value in the variable block        (lowest)
2. Environment variables (TF_VAR_*)           <-- here
3. terraform.tfvars
4. terraform.tfvars.json
5. *.auto.tfvars / *.auto.tfvars.json   (alphabetical order)
6. -var and -var-file on the command line     (highest)
```

> `TF_VAR_` only beats the **default value**. Any `.tfvars` file or command-line flag overrides it.

### Example

```hcl
# variables.tf
variable "instance_type" {
  default = "t2.micro"
}
```

```bash
export TF_VAR_instance_type="t3.small"
```

| Situation | Final value |
|---|---|
| Only the default and `TF_VAR_` exist | `t3.small` |
| `terraform.tfvars` also sets `instance_type = "t3.medium"` | `t3.medium` |
| Run with `-var="instance_type=t3.large"` | `t3.large` |

> **Common confusion:** If you set `TF_VAR_` but Terraform uses a different value, check whether a `terraform.tfvars` or `*.auto.tfvars` file sets the same variable. Those files win.

---

## Why Use `TF_VAR_`? (Best Use Case: Secrets)

`TF_VAR_` is the most common way to pass **secrets** without writing them in any file.

```hcl
variable "db_password" {
  type      = string
  sensitive = true
}
```

```bash
export TF_VAR_db_password="SuperSecret123"
terraform apply
```

Benefits:

- The secret is **not in any `.tf` or `.tfvars` file**, so it can't be committed to Git by mistake.
- CI/CD tools (GitHub Actions, Azure DevOps, Jenkins, GitLab) can inject it as a **secret pipeline variable**.
- `sensitive = true` hides it in plan and apply output.

> **Remember:** The value still ends up in the **state file**. Protect the state with an encrypted remote backend and access control. Also note that the secret can show up in shell history if you type it directly, so in CI/CD prefer the tool's secret store.

---

## Undeclared `TF_VAR_` Variables

If you set `TF_VAR_region` but there is no `variable "region"` block, Terraform **silently ignores** it. No error, no warning.

> This is different from `-var`, which errors for undeclared variables. A typo like `TF_VAR_enviroment` will simply be ignored, and Terraform will prompt or use the default. Double-check spelling when a value doesn't seem to apply.

---

# Part 2: Terraform CLI Environment Variables

These change how the **Terraform CLI** behaves. They are all optional.

## Summary Table

| Variable | Purpose | Example |
|---|---|---|
| `TF_LOG` | Turn on detailed logs | `TRACE`, `DEBUG`, `INFO`, `WARN`, `ERROR`, `JSON`, `off` |
| `TF_LOG_PATH` | Save logs to a file | `./terraform.log` |
| `TF_LOG_CORE` | Logs from Terraform core only | `DEBUG` |
| `TF_LOG_PROVIDER` | Logs from provider plugins only | `DEBUG` |
| `TF_INPUT` | Disable interactive prompts | `false` or `0` |
| `TF_CLI_ARGS` | Extra flags for **all** commands | `-no-color` |
| `TF_CLI_ARGS_<command>` | Extra flags for **one** command | `TF_CLI_ARGS_plan="-refresh=false"` |
| `TF_DATA_DIR` | Change location of the `.terraform` folder | `./.terraform-dev` |
| `TF_WORKSPACE` | Select a workspace | `dev` |
| `TF_IN_AUTOMATION` | Shorter output for CI/CD | `true` |
| `TF_PLUGIN_CACHE_DIR` | Shared cache for provider downloads | `$HOME/.terraform.d/plugin-cache` |

---

## `TF_LOG` - Debug Logging

Turns on detailed logs, which help when something fails and the normal error isn't clear.

```bash
export TF_LOG=DEBUG
terraform plan
```

Log levels, from **most** to **least** detailed:

```text
TRACE  >  DEBUG  >  INFO  >  WARN  >  ERROR
```

- `JSON` writes TRACE-level logs in JSON format.
- To turn logging off, use `unset TF_LOG` or `export TF_LOG=off`.

### PowerShell

```powershell
$env:TF_LOG = "DEBUG"
terraform plan
Remove-Item Env:TF_LOG
```

> `TRACE` logs are very large. Start with `DEBUG` or `INFO`.

---

## `TF_LOG_PATH` - Save Logs to a File

```bash
export TF_LOG=DEBUG
export TF_LOG_PATH=./terraform.log
terraform plan
```

> `TF_LOG_PATH` does **nothing on its own**. `TF_LOG` must also be set, or no logs are written.

Add the log file to `.gitignore`, because logs can contain sensitive details:

```gitignore
*.log
```

---

## `TF_LOG_CORE` and `TF_LOG_PROVIDER`

Split logging between Terraform itself and the provider plugins:

```bash
# Only provider logs, e.g. to debug AWS API calls
export TF_LOG_PROVIDER=DEBUG
terraform plan
```

---

## `TF_INPUT` - Disable Prompts

Same as passing `-input=false` to every command.

```bash
export TF_INPUT=0
terraform plan
```

If a required variable has no value, Terraform **fails with an error** instead of waiting for input. This matters in CI/CD, where nobody can type a value and the pipeline would otherwise hang.

---

## `TF_CLI_ARGS` and `TF_CLI_ARGS_<command>`

Add flags automatically without typing them every time.

### All commands

```bash
export TF_CLI_ARGS="-no-color"
terraform plan     # behaves like: terraform plan -no-color
```

### One command only

```bash
export TF_CLI_ARGS_plan="-refresh=false"
export TF_CLI_ARGS_apply="-parallelism=5"
```

### Using it with `.tfvars`

```bash
export TF_CLI_ARGS_plan='-var-file="prod.tfvars"'
terraform plan     # behaves like: terraform plan -var-file="prod.tfvars"
```

> These flags are inserted **right after the command name** and **before** any flags you type yourself. So flags typed on the command line come later and win.

> **Be careful:** Flags in `TF_CLI_ARGS` apply to every command. A flag that a command doesn't support causes an error. For example, `-var-file` works with `plan` and `apply` but not `init`. Prefer the command-specific `TF_CLI_ARGS_<command>` form.

---

## `TF_DATA_DIR`

Changes where Terraform keeps its per-directory working data, which is normally the `.terraform` folder.

```bash
export TF_DATA_DIR=./.terraform-dev
terraform init
```

> Set it consistently for every command in that directory, including `init`, `plan`, and `apply`. Otherwise Terraform won't find the initialized providers and modules.

---

## `TF_WORKSPACE`

Selects a Terraform workspace without running `terraform workspace select`.

```bash
export TF_WORKSPACE=dev
terraform plan
```

Mostly used in CI/CD pipelines.

---

## `TF_IN_AUTOMATION`

When set to any non-empty value, Terraform adjusts its output for automated runs. For example, it skips suggestions about which command to run next.

```bash
export TF_IN_AUTOMATION=true
```

---

## `TF_PLUGIN_CACHE_DIR`

Without a cache, `terraform init` downloads providers separately in **every project**. A plugin cache lets projects reuse downloaded providers.

```bash
mkdir -p $HOME/.terraform.d/plugin-cache
export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"
terraform init
```

Saves time and disk space when you have many Terraform projects.

---

# Part 3: Provider Environment Variables

These are read by the **provider plugin**, not Terraform core. Each provider has its own names.

## AWS Provider

| Variable | Purpose |
|---|---|
| `AWS_ACCESS_KEY_ID` | Access key |
| `AWS_SECRET_ACCESS_KEY` | Secret key |
| `AWS_SESSION_TOKEN` | Temporary session token |
| `AWS_REGION` | Default region |
| `AWS_PROFILE` | Named profile from `~/.aws/credentials` |

```bash
export AWS_PROFILE="dev"
export AWS_REGION="ap-south-1"
terraform plan
```

The provider block can then stay free of credentials:

```hcl
provider "aws" {
  # region and credentials are read from environment variables
}
```

## Azure Provider (`azurerm`)

| Variable | Purpose |
|---|---|
| `ARM_CLIENT_ID` | Service principal / app ID |
| `ARM_CLIENT_SECRET` | Client secret |
| `ARM_TENANT_ID` | Tenant ID |
| `ARM_SUBSCRIPTION_ID` | Subscription ID |

## Google Cloud Provider

| Variable | Purpose |
|---|---|
| `GOOGLE_APPLICATION_CREDENTIALS` | Path to a service account key file |
| `GOOGLE_PROJECT` | Default project |
| `GOOGLE_REGION` | Default region |

> Always check the provider's documentation on the Terraform Registry for the exact names and supported authentication methods.

> **Best practice:** Never hardcode credentials in `provider` blocks. Use environment variables, CLI profiles, or identity-based authentication such as IAM roles, managed identities, or OIDC in CI/CD.

---

# CI/CD Example (GitHub Actions)

```yaml
env:
  TF_IN_AUTOMATION: "true"
  TF_INPUT: "0"
  TF_VAR_environment: "prod"
  TF_VAR_db_password: ${{ secrets.DB_PASSWORD }}
  AWS_REGION: "ap-south-1"

steps:
  - run: terraform init
  - run: terraform plan -var-file="envs/prod.tfvars"
  - run: terraform apply -auto-approve -var-file="envs/prod.tfvars"
```

What each part does:

- `TF_IN_AUTOMATION` and `TF_INPUT` make Terraform pipeline-friendly.
- `TF_VAR_db_password` takes the secret from GitHub Secrets, so it never appears in code.
- `TF_VAR_environment` sets a normal input variable.
- `AWS_REGION` is read by the AWS provider.

> In this example, if `envs/prod.tfvars` also sets `environment`, the `.tfvars` value wins over `TF_VAR_environment`.

---

# Hands-on Practice (No Cloud Account Needed)

### `variables.tf`

```hcl
variable "my_name" {
  type    = string
  default = "Ashish"
}

variable "environment" {
  type = string
}

variable "skills" {
  type = list(string)
}
```

### `outputs.tf`

```hcl
output "intro" {
  value = "Hi, I am ${var.my_name}, working in ${var.environment}."
}

output "skills" {
  value = var.skills
}
```

### Try these in PowerShell

```powershell
terraform init

# 1. Set values through environment variables
$env:TF_VAR_environment = "dev"
$env:TF_VAR_skills = '["Python", "PySpark", "Terraform"]'
terraform plan

# 2. Override the default
$env:TF_VAR_my_name = "Ashish Porwal"
terraform plan

# 3. -var beats TF_VAR_
terraform plan -var="environment=prod"

# 4. Disable prompts and see the error
Remove-Item Env:TF_VAR_environment
$env:TF_INPUT = "0"
terraform plan

# 5. Turn on debug logs saved to a file
$env:TF_INPUT = "1"
$env:TF_VAR_environment = "dev"
$env:TF_LOG = "DEBUG"
$env:TF_LOG_PATH = "./terraform.log"
terraform plan

# Clean up
Remove-Item Env:TF_LOG, Env:TF_LOG_PATH, Env:TF_INPUT
Remove-Item Env:TF_VAR_environment, Env:TF_VAR_skills, Env:TF_VAR_my_name
```

### What to observe

| Run | Result |
|---|---|
| 1 | No prompts; `environment = dev`, `my_name = Ashish` |
| 2 | `my_name = Ashish Porwal` (`TF_VAR_` beats the default) |
| 3 | `environment = prod` (`-var` beats `TF_VAR_`) |
| 4 | Error: no value for required variable `environment`, and no prompt |
| 5 | Normal plan, plus a `terraform.log` file with debug logs |

> If a `terraform.tfvars` file exists in the same folder, it overrides `TF_VAR_` values. Use a clean folder for this practice.

---

# Common Mistakes

| Mistake | Fix |
|---|---|
| `TF_VAR_` name doesn't match the variable name | Match it exactly, e.g. `variable "env"` → `TF_VAR_env` |
| Typo in `TF_VAR_` name and expecting an error | Terraform ignores undeclared `TF_VAR_`s silently; check spelling |
| Expecting `TF_VAR_` to beat `terraform.tfvars` | `.tfvars` files have higher precedence |
| Setting `TF_LOG_PATH` without `TF_LOG` | Set both |
| Setting a variable in one terminal and running Terraform in another | Environment variables are per session |
| Lists/maps losing quotes | Wrap the whole value in single quotes |
| `-var-file` in `TF_CLI_ARGS` breaking `terraform init` | Use `TF_CLI_ARGS_plan` / `TF_CLI_ARGS_apply` instead |
| Hardcoding cloud keys in `provider` blocks | Use provider environment variables or identity-based auth |
| Forgetting to unset `TF_LOG` | Logs keep printing; run `unset TF_LOG` or `Remove-Item Env:TF_LOG` |

---

# Interview Questions

### Q1. How do you pass a value to a Terraform variable using an environment variable?

> Set an environment variable named `TF_VAR_<variable_name>`. For example, `export TF_VAR_region="ap-south-1"` sets `var.region`.

### Q2. Where does `TF_VAR_` sit in variable precedence?

> Just above the default value. `terraform.tfvars`, `*.auto.tfvars`, and command-line flags all override it.

### Q3. Why are environment variables preferred for secrets?

> The secret never gets written into `.tf` or `.tfvars` files, so it can't be committed to Git. CI/CD tools can inject it from their secret stores.

### Q4. What happens if `TF_VAR_` is set for a variable that isn't declared?

> Terraform ignores it silently. There is no error.

### Q5. How do you enable debug logs in Terraform?

> Set `TF_LOG` to a level such as `DEBUG` or `TRACE`. To save the logs to a file, also set `TF_LOG_PATH`.

### Q6. What does `TF_INPUT=0` do?

> It disables interactive prompts, like `-input=false`. If a required variable is missing, Terraform fails instead of waiting for input. This is useful in CI/CD.

### Q7. What is `TF_CLI_ARGS`?

> It adds extra command-line flags to every Terraform command. `TF_CLI_ARGS_<command>` adds them to one specific command, such as `TF_CLI_ARGS_plan`.

### Q8. How does Terraform authenticate to AWS without credentials in code?

> The AWS provider reads environment variables such as `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_PROFILE`, and `AWS_REGION`. It can also use shared credential files or IAM roles.

### Q9. How do you pass a list using `TF_VAR_`?

> Write it in HCL list syntax inside single quotes: `export TF_VAR_zones='["ap-south-1a", "ap-south-1b"]'`.

### Q10. Difference between `TF_VAR_` variables and Terraform CLI environment variables?

> `TF_VAR_` variables supply values for `variable` blocks. CLI environment variables like `TF_LOG` or `TF_INPUT` control how Terraform itself behaves.

---

# Quick Revision

- Environment variables live in the **terminal session**, not in code.
- `TF_VAR_<name>` sets the value of `variable "<name>"`.
- Bash: `export TF_VAR_x="value"`. PowerShell: `$env:TF_VAR_x = "value"`.
- Lists and maps: HCL syntax wrapped in single quotes.
- Precedence: default < **`TF_VAR_`** < `terraform.tfvars` < `.tfvars.json` < `*.auto.tfvars` < CLI flags.
- Undeclared `TF_VAR_` variables are ignored silently.
- Best use case for `TF_VAR_`: **secrets**, especially in CI/CD.
- `TF_LOG` + `TF_LOG_PATH` = debugging with logs saved to a file.
- `TF_INPUT=0` = no prompts; fail fast in pipelines.
- `TF_CLI_ARGS_<command>` = default flags for a command.
- Provider credentials use the provider's own variables, like `AWS_*`, `ARM_*`, and `GOOGLE_*`.
- Variables set in a terminal last only for that session.

---

## One-Line Summary

> Terraform reads environment variables in three ways: `TF_VAR_<name>` supplies input variable values (just above defaults in precedence), `TF_*` settings like `TF_LOG` and `TF_INPUT` control CLI behaviour, and provider variables like `AWS_*` handle authentication, so secrets and settings stay out of code.

---

## Official References

- [Terraform CLI Environment Variables](https://developer.hashicorp.com/terraform/cli/config/environment-variables)
- [Debugging Terraform (TF_LOG)](https://developer.hashicorp.com/terraform/internals/debugging)
- [Terraform Input Variables](https://developer.hashicorp.com/terraform/language/values/variables)
- [Protect Sensitive Input Variables](https://developer.hashicorp.com/terraform/tutorials/configuration-language/sensitive-variables)
