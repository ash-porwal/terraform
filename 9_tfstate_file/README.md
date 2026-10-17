# Terraform Notes - State File (`terraform.tfstate`) and Remote Backend (AWS S3)

## Quick Answer

The **state file** is Terraform's **memory**. It records **what Terraform has created** and **links each resource in your code to the real object** in the cloud or platform.

It is the **bridge** between:

```text
Desired configuration (.tf code)  <-->  State file (.tfstate)  <-->  Actual infrastructure (AWS/GitHub)
   "what you want to build"             "what Terraform knows"         "what currently exists"
```

Example:

```text
Your code (.tf)              State file (.tfstate)              Real world (GitHub/AWS)
github_repository     <-->   "learning_repo" = id:          <-->   github.com/ashish/
  .learning_repo             terraform-created-repo                terraform-created-repo
```

Without state, Terraform would not know which real resources belong to which block in your code.

---

## Why Does Terraform Need a State File?

### 1. Mapping code to real resources

Your code says:

```hcl
resource "github_repository" "learning_repo" {
  name = "terraform-created-repo"
}
```

The state records that this block is the **real repo with ID `terraform-created-repo`**. Next time you run `plan`, Terraform knows the repo already exists and **does not create it again**.

### 2. Knowing what to change or delete

If you **remove** a resource block from your code, Terraform checks the state, sees that it created that resource earlier, and plans to **destroy** it. Without state, it wouldn't know the resource ever existed.

### 3. Storing attributes

Values like `html_url`, IDs, and ARNs are stored in state, so outputs and references between resources work.

### 4. Tracking dependencies

State remembers which resources depend on which, so Terraform can **destroy them in the correct order**, even after the code is deleted.

### 5. Performance

Terraform uses state to **track resources and calculate the required changes efficiently**, instead of having to discover everything in your cloud account from scratch.

> **Precision note:** By default, `plan` and `apply` still **refresh** each resource listed in state by calling the provider API. State tells Terraform **exactly which** resources to check (by ID), so it never has to scan the whole account. For very large setups, `-refresh=false` skips the refresh and relies on state alone (faster, but riskier).

---

## When Is the State File Created?

| Command | Effect on state |
|---|---|
| `terraform init` | **No state yet**. Downloads providers and configures the backend. |
| `terraform plan` | **Reads** state; does not save changes to it |
| `terraform apply` | **Creates or updates** state |
| `terraform destroy` | **Updates** state; resources are removed from it |

After the first `apply` with **local state**, your folder looks like this:

```text
project/
├── .terraform/
├── .terraform.lock.hcl
├── main.tf
├── providers.tf
├── outputs.tf
├── terraform.tfstate          <- current state
└── terraform.tfstate.backup   <- previous version of state
```

> `terraform.tfstate.backup` is created when the state is **updated**. It holds the version from **just before** the last change, so you can recover if something goes wrong.

---

## What Does the State File Look Like?

It's a **JSON** file. A simplified example after creating the GitHub repo:

```json
{
  "version": 4,
  "terraform_version": "1.9.0",
  "serial": 3,
  "lineage": "a1b2c3d4-....",
  "outputs": {
    "repo_url": {
      "value": "https://github.com/ashish/terraform-created-repo",
      "type": "string"
    }
  },
  "resources": [
    {
      "mode": "managed",
      "type": "github_repository",
      "name": "learning_repo",
      "provider": "provider[\"registry.terraform.io/integrations/github\"]",
      "instances": [
        {
          "attributes": {
            "id": "terraform-created-repo",
            "name": "terraform-created-repo",
            "visibility": "public",
            "html_url": "https://github.com/ashish/terraform-created-repo"
          }
        }
      ]
    }
  ]
}
```

### Key fields

| Field | Meaning |
|---|---|
| `version` | Format version of the state file itself |
| `terraform_version` | Terraform version that last wrote the state |
| `serial` | Counter that **increases on every change** to state |
| `lineage` | Unique ID assigned when the state was first created; stays the same for its whole life |
| `outputs` | Saved output values |
| `resources` | Every resource Terraform manages |
| `mode` | `managed` = created by a `resource` block; `data` = read by a `data` block |
| `type` + `name` | Same as `resource "type" "name"` in your code |
| `provider` | Which provider manages it |
| `attributes` | All the real values, including IDs and URLs |

> `serial` and `lineage` help Terraform stop an **older** or **unrelated** state file from overwriting a newer one.

---

## How `plan` Uses State

When you run `terraform plan`, Terraform compares three things:

```text
1. Desired state  ->  your .tf code
2. Known state    ->  terraform.tfstate
3. Actual state   ->  real resources, checked through the provider API (refresh)
```

| Situation | Plan result |
|---|---|
| In code, not in state | `+ create` |
| In code and state, values differ | `~ update` or `-/+ replace` |
| In state, removed from code | `- destroy` |
| Code, state, and reality all match | `No changes.` |

---

## Drift: When Reality Changes Outside Terraform

**Drift** happens when someone changes a resource **manually**, for example editing the repo description on github.com instead of in code.

### What happens

1. Code says: `description = "My first repository"`
2. Someone changes it on GitHub to `"Edited manually"`
3. You run `terraform plan`
4. Terraform **refreshes**, detects the difference, and plans to change it **back** to match your code:

```text
  ~ description = "Edited manually" -> "My first repository"
```

> **Your code is the source of truth.** Manual changes get overwritten on the next apply. Make changes through code.

### Only update state, without changing resources

```bash
terraform plan -refresh-only     # preview what state would change
terraform apply -refresh-only    # update state only
```

> The old `terraform refresh` command does the same thing but without a review step. `-refresh-only` is the recommended replacement.

---

## State Contains Secrets ⚠️

State stores **all attribute values in plain text**, including metadata and potential secrets:

- Database passwords
- Tokens and keys
- Values of variables marked `sensitive = true`

> `sensitive = true` hides values on screen, **but they are still saved in the state file**.

That's why state is **highly sensitive** and should **not** live on a laptop or on the server/CI agent where Terraform commands run.

### Rules

- **Never commit** `terraform.tfstate` or `*.tfstate.backup` to Git.
- **Never share** the state file casually.
- Store state in a **remote backend** with **encryption** and **access control**.

### `.gitignore`

```gitignore
*.tfstate
*.tfstate.*
.terraform/
```

---

## Local State vs Remote State

### Local state (default)

State is saved as `terraform.tfstate` in the **project folder** on your machine.

**Good for:** learning and personal practice.

**Problems in a team:**

| Problem | Example |
|---|---|
| No sharing | Your teammate's laptop has no state, so their Terraform tries to create everything again |
| Conflicts | Two people run `apply` at the same time and corrupt the state |
| Loss | Laptop dies or folder is deleted, and Terraform loses track of everything |
| Security | Secrets sit unencrypted on personal machines or build servers |

### Remote state (recommended)

State is stored in a **shared, secure location** called a **backend**.

| Backend | Platform |
|---|---|
| `s3` | AWS S3 bucket |
| `azurerm` | Azure Storage Account |
| `gcs` | Google Cloud Storage |
| HCP Terraform (`cloud` block) | HashiCorp's managed service |

**Benefits:** **centralised** (one copy for the whole team), **secure** (encryption + IAM), **collaborative**, **locked** during runs, **versioned** and backed up.

---

## State Locking

**Locking** stops two people or pipelines from changing the same state at the same time, which would **corrupt** it.

```text
Ashish runs apply   ->  state LOCKED
Teammate runs apply ->  Error: Error acquiring the state lock
Ashish's apply ends ->  state UNLOCKED
```

- Locking happens **automatically** for any command that can write state, on backends that support it.
- Local state also uses a local lock while a command runs.

### S3 locking: DynamoDB (old) vs S3 native (new)

| | DynamoDB table (traditional) | S3 native lock file (modern) |
|---|---|---|
| Setting | `dynamodb_table = "tf-locks"` | `use_lockfile = true` |
| Extra AWS resource | Yes, a DynamoDB table with a `LockID` key | No, only the S3 bucket |
| How it works | Lock entry written to DynamoDB | A `<key>.tflock` file is created next to the state in S3 |
| Terraform version | All versions | **1.10+** |
| Status | **Deprecated** | **Recommended** |

> If you follow an older tutorial that creates a DynamoDB table, it still works, but new projects should use `use_lockfile = true`. Check the S3 backend docs for your Terraform version.

### Stuck lock

If a run crashes or is cancelled, the lock may stay behind:

```bash
terraform force-unlock <LOCK_ID>
```

> ⚠️ Use `force-unlock` **only** when you're sure no other run is active. Unlocking during a real run can corrupt the state.

---

# Hands-on: Move State to an AWS S3 Remote Backend

This is the practical part: start with local state, then move it to S3.

## Big Picture

```text
Before:  terraform.tfstate  ->  on my laptop  (risky)
After:   terraform.tfstate  ->  s3://my-bucket/dev/terraform.tfstate  (central, secure, locked)
```

## Prerequisites

- AWS account and AWS CLI configured (`aws configure` or `AWS_PROFILE`)
- Terraform **1.10+** (for S3 native locking)
- IAM permissions on the state bucket:
  - `s3:ListBucket` on the bucket
  - `s3:GetObject`, `s3:PutObject` on the state file
  - `s3:DeleteObject` on the lock file (`*.tflock`)

---

## Step 1: Create the S3 Bucket Manually

### Why manually? (Chicken-and-egg problem)

The backend bucket must **exist before** `terraform init`, because init needs somewhere to store the state. If the same Terraform project tried to create its own state bucket, it would need state to create the bucket that stores the state.

So the state bucket is usually created:

- Manually (Console or AWS CLI), as in this lab, or
- By a **separate, small "bootstrap" Terraform project** with local state.

### Option A: AWS Console

1. Open **S3** → **Create bucket**
2. **Bucket name:** globally unique, e.g. `ashish-terraform-state-2026`
3. **Region:** e.g. `ap-south-1`
4. **Block all public access:** ✅ keep enabled
5. **Bucket Versioning:** ✅ **Enable** (this is your backup / recovery)
6. **Default encryption:** SSE-S3 (default) or SSE-KMS
7. **Create bucket**

### Option B: AWS CLI

```bash
# Create the bucket (regions other than us-east-1 need LocationConstraint)
aws s3api create-bucket \
  --bucket ashish-terraform-state-2026 \
  --region ap-south-1 \
  --create-bucket-configuration LocationConstraint=ap-south-1

# Enable versioning (backups of every state version)
aws s3api put-bucket-versioning \
  --bucket ashish-terraform-state-2026 \
  --versioning-configuration Status=Enabled

# Block all public access
aws s3api put-public-access-block \
  --bucket ashish-terraform-state-2026 \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

> **PowerShell:** replace the `\` line continuations with a backtick `` ` `` or put each command on one line.

---

## Step 2: Start with a Normal Project (Local State)

### `providers.tf`

```hcl
terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}
```

### `main.tf`

```hcl
resource "aws_s3_bucket" "demo" {
  bucket = "ashish-tf-demo-bucket-2026"

  tags = {
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}
```

```bash
terraform init
terraform apply
```

A local `terraform.tfstate` now exists in the folder.

---

## Step 3: Add the `backend "s3"` Block

The backend goes **inside the `terraform {}` block**:

```hcl
terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "ashish-terraform-state-2026"
    key          = "dev/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

### What each argument means

| Argument | Meaning |
|---|---|
| `bucket` | Name of the existing S3 bucket that stores the state |
| `key` | **Path of the state file inside the bucket** (like a file path) |
| `region` | Region of the **state bucket** (can differ from where resources are created) |
| `encrypt` | Encrypt the state file at rest |
| `use_lockfile` | Enable S3 native state locking (creates `dev/terraform.tfstate.tflock` during runs) |

> **Older equivalent:** `dynamodb_table = "tf-locks"` instead of `use_lockfile = true` (deprecated).

### Backend block rules

- **No variables** allowed: `bucket = var.bucket` will fail. Use literal values, or pass them at init time:

  ```bash
  terraform init -backend-config="bucket=ashish-terraform-state-2026"
  ```

- **No credentials** in the backend block. The backend uses the same AWS credential chain as the provider (`AWS_PROFILE`, environment variables, IAM role).
- Any change to the backend block needs `terraform init` again.

---

## Step 4: Run `terraform init` (Migrate the State)

```bash
terraform init
```

Because a local state already exists, Terraform asks whether to copy it to S3:

```text
Initializing the backend...
Do you want to copy existing state to the new backend?
  Pre-existing state was found while migrating the previous "local" backend to the
  newly configured "s3" backend. No existing state was found in the newly
  configured "s3" backend. Do you want to copy this state to the new "s3"
  backend? Enter "yes" to copy and "no" to start with an empty state.

  Enter a value: yes

Successfully configured the backend "s3"! Terraform will automatically
use this backend unless the backend configuration changes.
```

Type **`yes`** to keep track of the resources you already created.

> ⚠️ Typing `no` starts with an **empty** state in S3. Terraform would then "forget" existing resources and try to create them again.

### Useful init flags

| Command | When to use |
|---|---|
| `terraform init -migrate-state` | Explicitly migrate state to a new or changed backend |
| `terraform init -reconfigure` | Use the new backend config **without** migrating (ignores old state) |
| `terraform init -backend=false` | Skip backend setup (e.g. only to run `validate` in CI) |

---

## Step 5: Verify the Migration

### Local folder

```text
project/
├── .terraform/
│   └── terraform.tfstate     <- NOT your infrastructure state! Only backend settings
├── .terraform.lock.hcl
├── main.tf
├── providers.tf
└── terraform.tfstate         <- no longer used (may be left empty)
```

- Your infrastructure state is **no longer kept locally**.
- `.terraform/terraform.tfstate` only stores **which backend** this folder uses (bucket, key, region). It is not the resource state.
- After confirming the S3 copy, you can delete the old local `terraform.tfstate` and `terraform.tfstate.backup`.

### S3 bucket

**Console:** S3 → `ashish-terraform-state-2026` → `dev/` → `terraform.tfstate` ✅

**CLI:**

```bash
aws s3 ls s3://ashish-terraform-state-2026/dev/
```

```text
2026-09-20 15:10:42       2345 terraform.tfstate
```

### Terraform still sees everything

```bash
terraform plan
```

```text
No changes. Your infrastructure matches the configuration.
```

This confirms Terraform is reading the state from S3.

### See the lock file in action

Run `terraform apply` (don't type `yes` yet) and list the bucket from another terminal:

```bash
aws s3 ls s3://ashish-terraform-state-2026/dev/
```

```text
terraform.tfstate
terraform.tfstate.tflock     <- exists only while a run holds the lock
```

### Check versioning (backups)

```bash
aws s3api list-object-versions \
  --bucket ashish-terraform-state-2026 \
  --prefix dev/terraform.tfstate
```

Every `apply` creates a new version you can roll back to.

---

## Step 6: Isolate State per Environment

Use a **different `key`** (or a different bucket/account) for each environment, so a mistake in dev can never touch prod:

```text
s3://ashish-terraform-state-2026/
├── dev/terraform.tfstate
├── test/terraform.tfstate
└── prod/terraform.tfstate
```

### Partial backend configuration (one codebase, many environments)

`providers.tf`:

```hcl
terraform {
  backend "s3" {}
}
```

`backend/dev.s3.tfbackend`:

```hcl
bucket       = "ashish-terraform-state-2026"
key          = "dev/terraform.tfstate"
region       = "ap-south-1"
encrypt      = true
use_lockfile = true
```

`backend/prod.s3.tfbackend`:

```hcl
bucket       = "ashish-terraform-state-2026"
key          = "prod/terraform.tfstate"
region       = "ap-south-1"
encrypt      = true
use_lockfile = true
```

```bash
terraform init -backend-config="backend/dev.s3.tfbackend"
terraform plan -var-file="envs/dev.tfvars"

terraform init -reconfigure -backend-config="backend/prod.s3.tfbackend"
terraform plan -var-file="envs/prod.tfvars"
```

> In real companies, prod state often lives in a **separate AWS account / bucket** with stricter IAM access.

---

## Step 7: Clean Up the Lab

```bash
terraform destroy                     # deletes the demo resources
```

The **state bucket** was created manually, so delete it manually at the end (empty it first, including all object versions).

> Don't delete the state bucket while any project still uses it.

---

## `terraform state` Commands

Use these instead of **ever editing the JSON by hand**. They work the same with local and remote state.

| Command | Purpose |
|---|---|
| `terraform state list` | List all resources managed by the state |
| `terraform state show <address>` | Detailed attributes of one resource |
| `terraform state mv <old> <new>` | Rename or move a resource in state, without recreating it |
| `terraform state rm <address>` | Make Terraform **forget** a resource, **without deleting** the real object |
| `terraform state pull` | Print the current state (very handy with remote state) |
| `terraform state push` | Upload a local state file to the backend (dangerous; avoid) |
| `terraform show` | Human-readable view of the whole state |

### Examples (AWS lab)

```bash
terraform state list
```

```text
aws_s3_bucket.demo
```

```bash
terraform state show aws_s3_bucket.demo
```

```text
# aws_s3_bucket.demo:
resource "aws_s3_bucket" "demo" {
    arn    = "arn:aws:s3:::ashish-tf-demo-bucket-2026"
    bucket = "ashish-tf-demo-bucket-2026"
    id     = "ashish-tf-demo-bucket-2026"
    region = "ap-south-1"
    tags   = {
        "Environment" = "dev"
        "ManagedBy"   = "Terraform"
    }
    ...
}
```

```bash
# Read the remote state without opening S3
terraform state pull > state-copy.json
```

> Treat `state-copy.json` like the real state: it contains secrets. Delete it after use and never commit it.

### Renaming a resource safely

You rename `demo` to `main` in code. Without telling Terraform, the plan would **destroy the old bucket and create a new one**.

**Option 1: `moved` block (recommended, reviewed in code)**

```hcl
moved {
  from = aws_s3_bucket.demo
  to   = aws_s3_bucket.main
}
```

**Option 2: CLI command**

```bash
terraform state mv aws_s3_bucket.demo aws_s3_bucket.main
```

### Stop managing a resource without deleting it

```bash
terraform state rm aws_s3_bucket.demo
```

The bucket stays in AWS, but Terraform no longer tracks it. Remove the block from code too, or the next `apply` will try to create it again.

> Newer Terraform versions also support a `removed` block for doing this in code.

---

## Importing Existing Resources

What if a resource was created **manually** and you want Terraform to manage it?

### Option 1: `import` block (recommended, Terraform 1.5+)

```hcl
import {
  to = aws_s3_bucket.existing
  id = "my-manual-bucket"
}

resource "aws_s3_bucket" "existing" {
  bucket = "my-manual-bucket"
}
```

```bash
terraform plan
terraform apply
```

Generate the resource code automatically:

```bash
terraform plan -generate-config-out=generated.tf
```

### Option 2: CLI command

```bash
terraform import aws_s3_bucket.existing my-manual-bucket
```

> The **import ID format** differs per resource. Check the **Import** section at the bottom of the resource's registry page.

---

## Golden Rules for State

1. **Never edit `terraform.tfstate` by hand.** Use `terraform state` commands, `moved`, `import`, or `removed` blocks.
2. **Never delete it** unless you've destroyed everything and are done with the project.
3. **Never commit it to Git.** It contains secrets.
4. **Use a remote backend** (e.g. S3) with locking, encryption, versioning, and blocked public access.
5. **One state per environment.** Separate `key`s, buckets, or accounts for dev, test, and prod.
6. **Back up state.** S3 versioning is the easiest way.
7. **Make changes through code**, not manually in the console, to avoid drift.
8. **Read the plan** before every `apply`.

---

## What If the State File Is Lost?

Terraform **forgets** everything it created. The real resources **still exist**, but:

- `plan` will show everything as **new** and try to create it again.
- Creation may fail with conflicts, like "bucket already exists", or create **duplicates**.

### Recovery options

| Option | When |
|---|---|
| Restore from `terraform.tfstate.backup` | Local state, recent loss |
| Restore an older **S3 object version** | Remote backend with versioning ✅ |
| `import` each resource again | No backup available |

---

## Common Mistakes

| Mistake | Fix |
|---|---|
| Committing `terraform.tfstate` to Git | Add `*.tfstate` and `*.tfstate.*` to `.gitignore` |
| Editing state JSON by hand | Use `terraform state` commands or `moved`/`import` blocks |
| Running `init` before the S3 bucket exists | Create the bucket first (manually or via a bootstrap project) |
| Answering `no` to "copy existing state" | Answer `yes`, or Terraform starts with empty state |
| Using `var.` inside the `backend` block | Literal values, or `-backend-config` |
| Putting AWS keys in the backend block | Use `AWS_PROFILE`, environment variables, or IAM roles |
| Bucket without versioning | Enable versioning before storing state |
| Same `key` for dev and prod | Separate key/bucket per environment |
| Confusing `.terraform/terraform.tfstate` with real state | It only stores backend settings |
| Creating a DynamoDB lock table on Terraform 1.10+ | Prefer `use_lockfile = true` |
| Using `force-unlock` while a run is active | Confirm no run is active first |
| Thinking `sensitive = true` keeps secrets out of state | It doesn't; protect the state itself |

---

## Interview Questions

### Q1. What is the Terraform state file?

> A JSON file (`terraform.tfstate`) that records the resources Terraform manages and maps each resource in the code to its real-world object. It is the bridge between desired configuration and actual infrastructure.

### Q2. Why does Terraform need state?

> To map code to real resources, detect what to create, change, or destroy, store attributes for references and outputs, track dependencies for destroy order, and calculate changes efficiently.

### Q3. Why shouldn't state be stored locally?

> It contains metadata and secrets in plain text, it can't be shared or locked across a team, and it's easily lost. Remote backends make it centralised, secure, and collaborative.

### Q4. How do you configure an S3 remote backend?

> Create the S3 bucket first, add a `backend "s3"` block inside the `terraform {}` block with `bucket`, `key`, `region`, `encrypt`, and `use_lockfile`, then run `terraform init` and confirm the state migration.

### Q5. What is the `key` in the S3 backend?

> The path of the state file inside the bucket, for example `dev/terraform.tfstate`. Using different keys isolates state per environment or project.

### Q6. Why must the backend bucket be created before `terraform init`?

> Init needs an existing location to store state. A project can't create its own state bucket because it would need state to do so, so the bucket is created manually or by a separate bootstrap project.

### Q7. What is state locking, and how does S3 support it?

> Locking prevents concurrent runs from writing to the same state and corrupting it. Traditionally S3 used a DynamoDB table; Terraform 1.10+ supports S3 native locking with `use_lockfile = true`, which creates a `.tflock` file. The DynamoDB option is deprecated.

### Q8. Can you use variables in the backend block?

> No. Backend values must be literals or passed with `terraform init -backend-config`.

### Q9. What happens to the local state after migrating to S3?

> Terraform copies it to S3 and uses S3 from then on. The local file is no longer used and can be removed after verifying. `.terraform/terraform.tfstate` only stores backend settings.

### Q10. What do `terraform state list` and `terraform state show` do?

> `state list` lists every resource address in the state. `state show <address>` displays the detailed attributes of one resource.

### Q11. How do you back up remote state?

> Enable versioning on the S3 bucket, so every state change is kept as a recoverable object version.

### Q12. Difference between `terraform state rm` and `terraform destroy`?

> `state rm` only removes the resource from state, so Terraform stops tracking it but the real resource stays. `destroy` deletes the real resource.

### Q13. How do you rename a resource in code without recreating it?

> Use a `moved` block, or run `terraform state mv`.

### Q14. What are `serial` and `lineage`?

> `serial` increases with every state change. `lineage` is a unique ID set when the state is first created. Together they stop old or unrelated state from overwriting the current one.

---

## Quick Revision

- State = Terraform's **memory**: bridge between desired config and actual infrastructure.
- Created by the first `apply`; read by `plan`; updated by `apply` and `destroy`.
- JSON with `resources`, `outputs`, `serial`, and `lineage`.
- `plan` compares **code**, **state**, and **reality** (refresh by default).
- State holds **secrets in plain text**: never commit, never keep on laptops or build servers.
- Remote backend = **centralised, secure, collaborative** state.
- S3 backend: `bucket`, `key` (file path), `region`, `encrypt`, `use_lockfile`.
- Create the bucket **first** (chicken-and-egg), with versioning + encryption + no public access.
- `terraform init` → answer **yes** to copy existing state.
- Locking: DynamoDB = old (deprecated); `use_lockfile = true` = new (Terraform 1.10+).
- Isolate state per environment with different keys/buckets/accounts.
- Verify with `aws s3 ls`, `terraform plan` (no changes), `terraform state list/show`.
- Use `state list/show/mv/rm/pull`, `moved`, `import`; never hand-edit.
- Recover with S3 object versions.

---

## One-Line Summary

> The Terraform state file maps your code to real infrastructure and contains sensitive data, so instead of keeping it locally, store it in a remote backend like an encrypted, versioned S3 bucket with `use_lockfile = true` for locking, isolate it per environment, and inspect it with `terraform state list` and `terraform state show`.

---

## Official References

- [Terraform State](https://developer.hashicorp.com/terraform/language/state)
- [Backend Configuration](https://developer.hashicorp.com/terraform/language/backend)
- [S3 Backend](https://developer.hashicorp.com/terraform/language/backend/s3)
- [State Locking](https://developer.hashicorp.com/terraform/language/state/locking)
- [terraform init (backend migration)](https://developer.hashicorp.com/terraform/cli/commands/init)
- [terraform state commands](https://developer.hashicorp.com/terraform/cli/commands/state)
- [Import](https://developer.hashicorp.com/terraform/language/import)
- [Refactoring with moved blocks](https://developer.hashicorp.com/terraform/language/modules/develop/refactoring)
