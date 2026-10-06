# Terraform Notes - Create a GitHub Repository with Terraform

## What We Will Build

We will write a small Terraform configuration that **creates a GitHub repository**.

Why GitHub? It's a great first real project:

- **Free**, so no cloud bill to worry about
- **No AWS/Azure account needed**, only a GitHub account
- You can **see the result immediately** on github.com
- It teaches the same workflow used for AWS, Azure, and GCP

```text
Write .tf code  ->  terraform init  ->  terraform plan  ->  terraform apply  ->  Repo appears on GitHub
```

---

# Step 1: Understand the Terraform Registry

## What is the Terraform Registry?

The **Terraform Registry** is the official online catalogue of Terraform **providers** and **modules**.

🔗 https://registry.terraform.io

Think of it like:

| Ecosystem | Package store |
|---|---|
| Python | PyPI (`pip install`) |
| Node.js | npm |
| Docker | Docker Hub |
| **Terraform** | **Terraform Registry** |

## What's Inside the Registry?

| Item | Meaning | Example |
|---|---|---|
| **Providers** | Plugins that let Terraform talk to a platform's API | AWS, Azure, Google, **GitHub**, Kubernetes |
| **Modules** | Reusable, ready-made Terraform code | A module that creates a full VPC |

## Provider Tiers (Who Maintains It)

| Tier | Maintained by | Example |
|---|---|---|
| **Official** | HashiCorp | `hashicorp/aws`, `hashicorp/azurerm` |
| **Partner** | A technology company, verified by HashiCorp | `integrations/github` |
| **Community** | Individual contributors | Various |

> Prefer **Official** or **Partner** providers. They are better maintained and more trustworthy.

## Provider Source Address

Every provider has an address in this format:

```text
<namespace>/<type>
```

| Provider | Namespace | Type | Source address |
|---|---|---|---|
| AWS | `hashicorp` | `aws` | `hashicorp/aws` |
| Azure | `hashicorp` | `azurerm` | `hashicorp/azurerm` |
| **GitHub** | `integrations` | `github` | **`integrations/github`** |

The full address actually includes the registry hostname, which Terraform fills in by default:

```text
registry.terraform.io/integrations/github
```

---

# Step 2: Find the GitHub Provider in the Registry

1. Open **https://registry.terraform.io**
2. Select **Browse Providers**
3. Search for **`github`**
4. Open the result **`integrations/github`** (it has a **Partner** badge)

> ⚠️ You may also see an old **`hashicorp/github`** provider. It is **deprecated**. Always use **`integrations/github`**.

## What You'll See on the Provider Page

| Section | What it shows |
|---|---|
| **Overview** | Short description, latest version, download count |
| **USE PROVIDER** button (top right) | Ready-to-copy code for `required_providers` |
| **Documentation** | Every **resource** and **data source** the provider supports |
| **Versions** dropdown | Older versions of the provider |

## Copy the Provider Code

Click **USE PROVIDER**. You get code like this:

```hcl
terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "6.13.0"
    }
  }
}

provider "github" {
  # Configuration options
}
```

## Find the Resource We Need

1. Click **Documentation**
2. In the left menu, open **Resources**
3. Search for **`github_repository`**
4. The page shows an **Example Usage** and a list of **Argument Reference** (inputs) and **Attributes Reference** (outputs)

> 💡 **Golden rule for learners:** You don't memorise Terraform resources. You **read the registry docs** for the resource you need, copy the example, and adjust it. Everyone does this, including experienced engineers.

---

# Step 3: Create a GitHub Personal Access Token (PAT)

Terraform needs permission to create a repo **on your behalf**. We give it a **token**.

## Steps (Fine-grained token, recommended)

1. GitHub → click your **profile photo** → **Settings**
2. Bottom of the left menu → **Developer settings**
3. **Personal access tokens** → **Fine-grained tokens** → **Generate new token**
4. Fill in:
   - **Token name:** `terraform-learning`
   - **Expiration:** 7 or 30 days (short is safer)
   - **Repository access:** **All repositories**
     (needed because the repo we create doesn't exist yet)
5. Under **Permissions → Repository permissions**, set **Administration** to **Read and write**. This is the permission that allows creating and deleting repos.
6. Click **Generate token** and **copy it immediately**. GitHub shows it only once.

> **Alternative, classic token:** **Tokens (classic)** → tick the **`repo`** scope. Add **`delete_repo`** if you also want `terraform destroy` to delete the repo.

> 🔒 **Never** paste the token into a `.tf` file or commit it to Git. Treat it like a password.

## Give the Token to Terraform (Environment Variable)

The GitHub provider automatically reads the **`GITHUB_TOKEN`** environment variable.

**Windows PowerShell:**

```powershell
$env:GITHUB_TOKEN = "github_pat_xxxxxxxxxxxxxxxx"
```

**Linux / macOS:**

```bash
export GITHUB_TOKEN="github_pat_xxxxxxxxxxxxxxxx"
```

> This is the same environment variable idea from the previous notes. The token stays in your terminal session, never in your code. Close the terminal and it's gone.

---

# Step 4: Project Structure

```text
github-repo-demo/
├── providers.tf    # terraform block + provider block
├── main.tf         # the github_repository resource
├── outputs.tf      # values printed after apply
└── .gitignore
```

> As we learned earlier, Terraform reads **all** `.tf` files in the folder as one configuration. Splitting them is just for readability.

---

# Step 5: Write the Code

## `providers.tf`

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

provider "github" {
  owner = "your-github-username"
  # token is read automatically from the GITHUB_TOKEN environment variable
}
```

## `main.tf`

```hcl
resource "github_repository" "learning_repo" {
  name        = "terraform-created-repo"
  description = "My first repository created using Terraform"
  visibility  = "public"

  auto_init = true
}
```

## `outputs.tf`

```hcl
output "repo_url" {
  description = "Web URL of the new repository"
  value       = github_repository.learning_repo.html_url
}

output "clone_url" {
  description = "HTTPS clone URL"
  value       = github_repository.learning_repo.http_clone_url
}
```

## `.gitignore`

```gitignore
.terraform/
*.tfstate
*.tfstate.*
*.tfvars
crash.log
```

> Keep `.terraform.lock.hcl` **committed**. Only the `.terraform/` folder is ignored.

---

# Step 6: Understand Every Line of the Code

## Part A: `terraform` Block

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}
```

| Line | Meaning |
|---|---|
| `terraform { }` | Settings block for **Terraform itself**. Has no label. Creates nothing. |
| `required_version = ">= 1.6.0"` | Terraform CLI must be version 1.6.0 or newer, otherwise it stops with an error |
| `required_providers { }` | List of providers this project needs. `terraform init` reads this to know what to download. |
| `github = { ... }` | `github` is the **local name**. It's how the rest of the code refers to this provider, e.g. `provider "github"`. |
| `source = "integrations/github"` | **Where** to download it from: registry namespace `integrations`, type `github` |
| `version = "~> 6.0"` | **Which versions** are allowed (explained below) |

### Version Constraint Operators

| Constraint | Meaning |
|---|---|
| `= 6.13.0` or `6.13.0` | Exactly this version |
| `>= 6.0` | 6.0 or anything newer, including 7.x |
| `<= 6.5` | 6.5 or older |
| `~> 6.0` | **6.x only**: `>= 6.0` and `< 7.0` |
| `~> 6.13.0` | **6.13.x only**: `>= 6.13.0` and `< 6.14.0` |
| `>= 6.0, < 6.10` | Combine constraints with commas |

> `~>` is called the **pessimistic constraint operator**. It allows only the **rightmost** number to increase. `~> 6.0` gets new features and fixes in 6.x but blocks 7.0, which may contain breaking changes. That's why it's the most common choice.

## Part B: `provider` Block

```hcl
provider "github" {
  owner = "your-github-username"
}
```

| Line | Meaning |
|---|---|
| `provider "github"` | **Configures** the provider. The label `github` must match the local name in `required_providers`. |
| `owner = "..."` | The GitHub **user or organisation** where repos will be created |
| token (not written) | Read automatically from `GITHUB_TOKEN`, so no secret in code |

> **Common confusion:**
> - `required_providers` = **"Which plugin to download"** (used by `terraform init`)
> - `provider` block = **"How to configure it"** (used by `plan` and `apply`)

> **Owner tip:** You can also set the owner with the `GITHUB_OWNER` environment variable instead of `owner` in code. Set **only one** of them to avoid confusion.

## Part C: `resource` Block

```hcl
resource "github_repository" "learning_repo" {
  name        = "terraform-created-repo"
  description = "My first repository created using Terraform"
  visibility  = "public"

  auto_init = true
}
```

### The Header

```text
resource  "github_repository"  "learning_repo"
   │              │                    │
   │              │                    └── Local name: YOUR nickname for this resource
   │              │                        (used only inside Terraform code)
   │              └── Resource type: what to create
   │                  (prefix "github_" tells Terraform which provider handles it)
   └── Block type: "create and manage something"
```

> **Important:** `learning_repo` is **not** the repo's name on GitHub. The real name is the `name` argument. `learning_repo` is just how Terraform refers to it internally.

### The Arguments

| Argument | Required? | Meaning |
|---|---|---|
| `name` | **Yes** | Repo name on GitHub, e.g. `github.com/<owner>/terraform-created-repo` |
| `description` | No | Short text shown on the repo page |
| `visibility` | No | `public` or `private` (or `internal` for enterprise orgs) |
| `auto_init` | No | `true` creates an initial commit with an empty README, so the repo isn't blank |

> 📖 There are many more optional arguments, like `has_issues`, `has_wiki`, `gitignore_template`, `license_template`, and `topics`. Check the **Argument Reference** on the registry page for `github_repository`.

### Example with More Arguments

```hcl
resource "github_repository" "learning_repo" {
  name               = "terraform-created-repo"
  description        = "My first repository created using Terraform"
  visibility         = "public"
  auto_init          = true
  gitignore_template = "Terraform"
  license_template   = "mit"
  has_issues         = true
  topics             = ["terraform", "learning", "iac"]
}
```

## Part D: `output` Block and Resource References

```hcl
output "repo_url" {
  value = github_repository.learning_repo.html_url
}
```

### How to Read a Resource Reference

```text
github_repository . learning_repo . html_url
        │                 │             │
   resource type     local name     attribute
```

- **Arguments** are values **you give** (`name`, `visibility`).
- **Attributes** are values the resource **gives back** after creation (`html_url`, `http_clone_url`, `full_name`).

Many attributes show as `(known after apply)` during `plan`, because GitHub creates them only when the repo actually exists.

---

# Step 7: Run the Terraform Workflow

Open a terminal in the `github-repo-demo` folder.

## 7.1 Set the Token

```powershell
$env:GITHUB_TOKEN = "github_pat_xxxxxxxxxxxxxxxx"
```

## 7.2 `terraform init` - Download the GitHub Provider

```bash
terraform init
```

### What happens

1. Terraform reads `required_providers`.
2. It sees `github = { source = "integrations/github", version = "~> 6.0" }`.
3. It contacts the **Terraform Registry**, finds the newest **6.x** version, and downloads the **GitHub provider plugin** for your OS.
4. It saves the plugin in the **`.terraform/`** folder.
5. It creates **`.terraform.lock.hcl`** with the exact version and checksums.

### Sample output

```text
Initializing the backend...
Initializing provider plugins...
- Finding integrations/github versions matching "~> 6.0"...
- Installing integrations/github v6.x.x...
- Installed integrations/github v6.x.x (signed by a HashiCorp partner)

Terraform has created a lock file .terraform.lock.hcl ...

Terraform has been successfully initialized!
```

### After init, the folder looks like this

```text
github-repo-demo/
├── .terraform/              <- downloaded GitHub provider plugin lives here
│   └── providers/
│       └── registry.terraform.io/
│           └── integrations/
│               └── github/
├── .terraform.lock.hcl      <- exact provider version + checksums
├── providers.tf
├── main.tf
├── outputs.tf
└── .gitignore
```

> **Why is init needed?** Terraform core doesn't know how to talk to GitHub. The **GitHub provider plugin** does. `init` downloads that plugin. Without it, `plan` and `apply` fail with an error asking you to run `terraform init`.

## 7.3 `terraform providers` - See Which Providers Are Used

```bash
terraform providers
```

### Sample output

```text
Providers required by configuration:
.
└── provider[registry.terraform.io/integrations/github] ~> 6.0
```

### What it tells you

- Every provider the configuration needs
- Its full source address
- The version constraint
- Which module requires it (here `.` means the root module)

### Useful related commands

| Command | Purpose |
|---|---|
| `terraform providers` | Tree of providers required by the code (and by state, if any) |
| `terraform version` | Terraform version **plus** installed provider versions |
| `terraform providers lock` | Add checksums for other platforms to the lock file |
| `terraform providers schema -json` | Every resource and argument the provider supports, as JSON (advanced) |

> 💡 `terraform providers` works even **before** `terraform init`, because it reads the code. `terraform version` shows provider versions only **after** init.

## 7.4 `terraform fmt` and `terraform validate`

```bash
terraform fmt        # auto-format the code neatly
terraform validate   # check syntax and references
```

Expected:

```text
Success! The configuration is valid.
```

## 7.5 `terraform plan` - Preview

```bash
terraform plan
```

### Sample output

```text
Terraform will perform the following actions:

  # github_repository.learning_repo will be created
  + resource "github_repository" "learning_repo" {
      + auto_init      = true
      + description    = "My first repository created using Terraform"
      + html_url       = (known after apply)
      + name           = "terraform-created-repo"
      + visibility     = "public"
      ...
    }

Plan: 1 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + clone_url = (known after apply)
  + repo_url  = (known after apply)
```

### How to read it

| Symbol | Meaning |
|---|---|
| `+` | Will be created |
| `~` | Will be updated in place |
| `-` | Will be destroyed |
| `-/+` | Will be destroyed and recreated |
| `(known after apply)` | Value is only available after creation |

**Nothing is created yet.** `plan` is only a preview.

## 7.6 `terraform apply` - Create the Repo

```bash
terraform apply
```

Terraform shows the plan again and asks:

```text
Do you want to perform these actions?
  Enter a value: yes
```

Type **`yes`** (exactly).

### Sample output

```text
github_repository.learning_repo: Creating...
github_repository.learning_repo: Creation complete after 3s [id=terraform-created-repo]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

Outputs:

clone_url = "https://github.com/<owner>/terraform-created-repo.git"
repo_url  = "https://github.com/<owner>/terraform-created-repo"
```

🎉 Open the `repo_url`. Your repo exists on GitHub.

### New file after apply

```text
terraform.tfstate   <- Terraform's record of what it created
```

> The **state file** maps `github_repository.learning_repo` in your code to the real repo on GitHub. Don't edit or delete it by hand, and don't commit it to Git. It can contain sensitive data.

## 7.7 Run `plan` Again (Idempotency)

```bash
terraform plan
```

```text
No changes. Your infrastructure matches the configuration.
```

> Terraform compares code with state and reality. Since the repo already matches, it does nothing. This is called **idempotency**: running the same code again doesn't create duplicates.

## 7.8 Make a Change (Update)

Change the description in `main.tf`:

```hcl
description = "Updated description via Terraform"
```

```bash
terraform plan
```

```text
  # github_repository.learning_repo will be updated in-place
  ~ resource "github_repository" "learning_repo" {
      ~ description = "My first repository created using Terraform" -> "Updated description via Terraform"
    }

Plan: 0 to add, 1 to change, 0 to destroy.
```

Then `terraform apply`. The **same repo** is updated, not recreated.

> ⚠️ Changing some arguments, like `name`, may rename the repo. Always **read the plan** before typing `yes`.

## 7.9 See Outputs Anytime

```bash
terraform output
terraform output repo_url
```

## 7.10 `terraform destroy` - Clean Up

```bash
terraform destroy
```

```text
  # github_repository.learning_repo will be destroyed
  - resource "github_repository" "learning_repo" { ... }

Plan: 0 to add, 0 to change, 1 to destroy.

  Enter a value: yes

Destroy complete! Resources: 1 destroyed.
```

> ⚠️ This **permanently deletes the repo and everything in it**. Your token needs delete permission: **Administration: Read and write** (fine-grained) or **`delete_repo`** (classic).

---

# Bonus: Use Variables Instead of Hardcoding

Applying what we learned in the variables notes:

## `variables.tf`

```hcl
variable "github_owner" {
  description = "GitHub username or organisation"
  type        = string
}

variable "repo_name" {
  description = "Name of the repository"
  type        = string
}

variable "repo_visibility" {
  description = "public or private"
  type        = string
  default     = "private"

  validation {
    condition     = contains(["public", "private"], var.repo_visibility)
    error_message = "Visibility must be public or private."
  }
}
```

## `providers.tf` (provider block)

```hcl
provider "github" {
  owner = var.github_owner
}
```

## `main.tf`

```hcl
resource "github_repository" "learning_repo" {
  name        = var.repo_name
  description = "Created by Terraform"
  visibility  = var.repo_visibility
  auto_init   = true
}
```

## `terraform.tfvars`

```hcl
github_owner    = "your-github-username"
repo_name       = "terraform-created-repo"
repo_visibility = "public"
```

> The token is still **not** in tfvars. It stays in the `GITHUB_TOKEN` environment variable.

---

# Bonus: Create Multiple Repos with `for_each`

```hcl
variable "repos" {
  type = map(string)
  default = {
    "tf-learning-dev"  = "Dev practice repo"
    "tf-learning-test" = "Test practice repo"
  }
}

resource "github_repository" "multi" {
  for_each = var.repos

  name        = each.key
  description = each.value
  visibility  = "private"
  auto_init   = true
}
```

- `for_each` loops over the map.
- `each.key` is the repo name, and `each.value` is the description.
- One resource block creates **two repos**.

---

# Troubleshooting

| Error / Problem | Likely cause | Fix |
|---|---|---|
| `Error: Inconsistent dependency lock file` / `run terraform init` | Provider not downloaded, or code changed | Run `terraform init` |
| `401 Bad credentials` | Token missing, wrong, or expired | Check `$env:GITHUB_TOKEN` and generate a new token if needed |
| `403 Resource not accessible by personal access token` | Token lacks permission | Fine-grained: **Administration: Read and write** + **All repositories**. Classic: `repo` scope |
| `422 name already exists on this account` | Repo with that name already exists | Use a different `name` or delete the existing repo |
| Repo created under the wrong account | Wrong `owner` / `GITHUB_OWNER` | Set only one of them, correctly |
| `destroy` fails with `403` | Token can't delete repos | Classic: add `delete_repo` scope |
| Token worked yesterday, fails today | Session closed or token expired | Set `GITHUB_TOKEN` again in the new terminal |
| `Failed to query available provider packages` | Wrong `source` (e.g. typo) or network/proxy issue | Use `integrations/github` and check internet/proxy |

---

# Common Beginner Mistakes

| Mistake | Correct approach |
|---|---|
| Using `hashicorp/github` | Use `integrations/github`. The old one is deprecated. |
| Hardcoding `token = "ghp_..."` in code | Use the `GITHUB_TOKEN` environment variable |
| Thinking `learning_repo` is the GitHub repo name | The `name` argument is the real repo name |
| Skipping `terraform init` | Always run init first and after changing providers |
| Typing `y` instead of `yes` | Terraform accepts only `yes` |
| Committing `terraform.tfstate` | Add it to `.gitignore` |
| Deleting `.terraform.lock.hcl` | Commit it; it keeps provider versions consistent |
| Not reading the plan | Always check what will be created, changed, or destroyed |

---

# Interview Questions

### Q1. What is the Terraform Registry?

> The public catalogue of Terraform providers and modules at registry.terraform.io. `terraform init` downloads providers from it by default.

### Q2. What is the difference between a provider and a module?

> A provider is a plugin that lets Terraform talk to a platform's API, like GitHub or AWS. A module is reusable Terraform code that groups resources together.

### Q3. Which provider do you use for GitHub, and how do you authenticate?

> The `integrations/github` provider. Authentication is usually a personal access token in the `GITHUB_TOKEN` environment variable. It also supports GitHub App credentials and the GitHub CLI login.

### Q4. What does `terraform init` do in this project?

> It reads `required_providers`, downloads the matching GitHub provider plugin from the registry into `.terraform/`, and records the exact version and checksums in `.terraform.lock.hcl`.

### Q5. What does `terraform providers` show?

> The providers the configuration requires, with their source addresses, version constraints, and which module requires them.

### Q6. What does `~> 6.0` mean?

> Any version from 6.0 up to, but not including, 7.0. Only the rightmost number can increase.

### Q7. In `resource "github_repository" "learning_repo"`, what are the two labels?

> `github_repository` is the resource type, defined by the provider. `learning_repo` is the local name used to refer to it in Terraform code.

### Q8. What is the difference between an argument and an attribute?

> Arguments are inputs you set, like `name` and `visibility`. Attributes are values available after creation, like `html_url`, and are referenced as `type.name.attribute`.

### Q9. What happens if you run `terraform apply` twice with no code change?

> Nothing changes. Terraform sees that the real repo already matches the code. This is idempotency.

### Q10. Why shouldn't the token be stored in a `.tf` file?

> `.tf` files are committed to Git, so the token would leak. It should come from an environment variable or a secrets manager.

---

# Quick Revision

- **Terraform Registry** = catalogue of providers and modules (registry.terraform.io).
- GitHub provider: **`integrations/github`** (Partner tier). Avoid `hashicorp/github`.
- Use **USE PROVIDER** to copy setup code and **Documentation** to find resources.
- Auth: **`GITHUB_TOKEN`** environment variable, never in code.
- `required_providers` = what to download. `provider` block = how to configure.
- `~> 6.0` = any 6.x version.
- `resource "type" "local_name"`: the real repo name comes from the `name` argument.
- Reference attributes as `github_repository.learning_repo.html_url`.
- `terraform init` downloads the plugin into `.terraform/` and creates the lock file.
- `terraform providers` lists the providers the code uses.
- Workflow: `init` → `fmt` → `validate` → `plan` → `apply` → `destroy`.
- `terraform.tfstate` tracks what Terraform created. Don't edit or commit it.
- Running apply again with no changes does nothing (idempotency).

---

## One-Line Summary

> We find the `integrations/github` provider on the Terraform Registry, declare it in `required_providers`, authenticate with `GITHUB_TOKEN`, define a `github_repository` resource, and use `init`, `plan`, `apply`, and `destroy` to create and manage a real GitHub repo from code.

---

## Official References

- [Terraform Registry](https://registry.terraform.io)
- [GitHub Provider (integrations/github)](https://registry.terraform.io/providers/integrations/github/latest/docs)
- [github_repository resource](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository)
- [terraform providers command](https://developer.hashicorp.com/terraform/cli/commands/providers)
- [Provider version constraints](https://developer.hashicorp.com/terraform/language/expressions/version-constraints)
