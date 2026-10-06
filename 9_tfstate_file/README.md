# Terraform Notes - State File (`terraform.tfstate`)

## Quick Answer

The **state file** is Terraform's **memory**. It records **what Terraform has created** and **links each resource in your code to the real object** in the cloud or platform.

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

Values like `html_url`, IDs, and ARNs are stored in state, so outputs and references between resources work without asking the API every time.

### 4. Tracking dependencies

State remembers which resources depend on which, so Terraform can **destroy them in the correct order**, even after the code is deleted.

### 5. Performance

For large setups, state acts as a cache so Terraform doesn't have to rediscover everything from scratch.

---

## When Is the State File Created?

| Command | Effect on state |
|---|---|
| `terraform init` | **No state yet**. Only downloads providers. |
| `terraform plan` | **Reads** state; does not save changes to it |
| `terraform apply` | **Creates or updates** `terraform.tfstate` |
| `terraform destroy` | **Updates** state; resources are removed from it |

After the first `apply`, your folder looks like this:

```text
github-repo-demo/
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

If you want state to **accept** what's in reality, without modifying any resources:

```bash
terraform plan -refresh-only     # preview what state would change
terraform apply -refresh-only    # update state only
```

> The old `terraform refresh` command does the same thing but without a review step. `-refresh-only` is the recommended replacement.

---

## State Contains Secrets ⚠️

State stores **all attribute values in plain text**, including:

- Database passwords
- Tokens and keys
- Values of variables marked `sensitive = true`

> `sensitive = true` hides values on screen, **but they are still saved in the state file**.

### Rules

- **Never commit** `terraform.tfstate` or `*.tfstate.backup` to Git.
- **Never share** the state file casually.
- In teams, store state in a **remote backend** with **encryption** and **access control**.

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
| Security | Secrets sit unencrypted on personal machines |

### Remote state (recommended for teams)

State is stored in a **shared, secure location** called a **backend**.

| Backend | Platform |
|---|---|
| `s3` | AWS S3 bucket |
| `azurerm` | Azure Storage Account |
| `gcs` | Google Cloud Storage |
| HCP Terraform (`cloud` block) | HashiCorp's managed service |

**Benefits:** shared by the team, locked during runs, encrypted, versioned, and backed up.

---

## Configuring a Remote Backend

The backend is set inside the `terraform` block.

### AWS S3 example

```hcl
terraform {
  backend "s3" {
    bucket       = "ashish-terraform-state"
    key          = "github-repo-demo/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

| Argument | Meaning |
|---|---|
| `bucket` | S3 bucket that stores the state; must already exist |
| `key` | Path of the state file **inside** the bucket |
| `region` | AWS region of the bucket |
| `encrypt` | Encrypt the state at rest |
| `use_lockfile` | Use S3 itself for state locking |

> **Locking note:** Older setups used a **DynamoDB table** (`dynamodb_table`) for locking. Newer Terraform versions support S3-native locking with `use_lockfile = true`, and the DynamoDB option is deprecated. Check the S3 backend documentation for your Terraform version.

> **Turn on S3 bucket versioning** so you can recover older state versions if something breaks.

### Azure example

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "ashishtfstate"
    container_name       = "tfstate"
    key                  = "github-repo-demo.terraform.tfstate"
  }
}
```

### Backend rules to remember

- Backend blocks **cannot use variables** like `var.bucket`. Values must be literal, or passed with `terraform init -backend-config=...`.
- After adding or changing a backend, you **must run `terraform init`** again.
- To move existing local state to the new backend:

```bash
terraform init -migrate-state
```

- Never store backend **credentials** in the backend block. Use environment variables or identity-based auth.

---

## State Locking

**Locking** stops two people or pipelines from changing the same state at the same time.

```text
Ashish runs apply  ->  state LOCKED
Teammate runs apply ->  Error: Error acquiring the state lock
Ashish's apply ends ->  state UNLOCKED
```

- Locking happens **automatically** for any command that can write state, on backends that support it.
- Local state also uses a local lock file while a command runs.

### Stuck lock

If a run crashes or is cancelled, the lock may stay behind:

```bash
terraform force-unlock <LOCK_ID>
```

> ⚠️ Use `force-unlock` **only** when you're sure no other run is active. Unlocking during a real run can corrupt the state.

---

## `terraform state` Commands

Use these instead of **ever editing the JSON by hand**.

| Command | Purpose |
|---|---|
| `terraform state list` | List all resources in state |
| `terraform state show <address>` | Show details of one resource |
| `terraform state mv <old> <new>` | Rename or move a resource in state, without recreating it |
| `terraform state rm <address>` | Make Terraform **forget** a resource, **without deleting** the real object |
| `terraform state pull` | Print the current state, useful for remote state |
| `terraform state push` | Upload a local state file to the backend (dangerous; avoid) |
| `terraform show` | Human-readable view of the whole state |

### Examples with the GitHub repo

```bash
terraform state list
```

```text
github_repository.learning_repo
```

```bash
terraform state show github_repository.learning_repo
```

```text
# github_repository.learning_repo:
resource "github_repository" "learning_repo" {
    html_url   = "https://github.com/ashish/terraform-created-repo"
    id         = "terraform-created-repo"
    name       = "terraform-created-repo"
    visibility = "public"
    ...
}
```

### Renaming a resource safely

You rename `learning_repo` to `main_repo` in code. Without telling Terraform, the plan would **destroy the old repo and create a new one**.

**Option 1: `moved` block (recommended, reviewed in code)**

```hcl
moved {
  from = github_repository.learning_repo
  to   = github_repository.main_repo
}
```

**Option 2: CLI command**

```bash
terraform state mv github_repository.learning_repo github_repository.main_repo
```

Either way, the real repo stays untouched. Only Terraform's name for it changes.

### Stop managing a resource without deleting it

```bash
terraform state rm github_repository.learning_repo
```

The repo stays on GitHub, but Terraform no longer tracks it. Remove the block from code too, or the next `apply` will try to create it again.

> Newer Terraform versions also support a `removed` block for doing this in code.

---

## Importing Existing Resources

What if the repo was created **manually** and you want Terraform to manage it?

### Option 1: `import` block (recommended, Terraform 1.5+)

```hcl
import {
  to = github_repository.existing_repo
  id = "my-manual-repo"
}

resource "github_repository" "existing_repo" {
  name = "my-manual-repo"
}
```

```bash
terraform plan     # shows the import
terraform apply    # adds it to state
```

Generate the resource code automatically:

```bash
terraform plan -generate-config-out=generated.tf
```

### Option 2: CLI command

```bash
terraform import github_repository.existing_repo my-manual-repo
```

> The **import ID format** differs per resource. Check the **Import** section at the bottom of the resource's registry page.

---

## Golden Rules for State

1. **Never edit `terraform.tfstate` by hand.** Use `terraform state` commands, `moved`, `import`, or `removed` blocks.
2. **Never delete it** unless you've destroyed everything and are done with the project.
3. **Never commit it to Git.** It contains secrets.
4. **Use a remote backend** with locking, encryption, and versioning for team or real projects.
5. **One state per environment.** Keep separate state for dev, test, and prod, using different backend `key`s or workspaces.
6. **Make changes through code**, not manually in the console, to avoid drift.
7. **Back up state.** Versioning on S3 or Azure storage is the easiest way.
8. **Read the plan** before every `apply`.

---

## What If the State File Is Lost?

Terraform **forgets** everything it created. The real resources **still exist**, but:

- `plan` will show everything as **new** and try to create it again.
- Creation may fail with conflicts, like "repo already exists", or create **duplicates**.

### Recovery options

| Option | When |
|---|---|
| Restore from `terraform.tfstate.backup` | Local state, recent loss |
| Restore an older version from the bucket | Remote backend with versioning |
| `import` each resource again | No backup available |

> That's why remote state **with versioning** matters so much.

---

## Hands-on Practice (Using the GitHub Repo Project)

```bash
# 1. Create the repo
terraform apply

# 2. Look at state
terraform state list
terraform state show github_repository.learning_repo
terraform show

# 3. Open terraform.tfstate in VS Code (read only - don't edit!)
#    Find: type, name, attributes, serial

# 4. Create drift: change the repo description manually on github.com
terraform plan                 # Terraform wants to change it back

# 5. Rename safely with a moved block, then:
terraform plan                 # shows a move, not destroy + create

# 6. Forget the repo without deleting it
terraform state rm github_repository.main_repo
terraform state list           # empty; repo still on GitHub

# 7. Bring it back with an import block, then:
terraform apply

# 8. Clean up
terraform destroy
```

> Watch the `serial` number in `terraform.tfstate` after each apply. It goes up every time state changes.

---

## Common Mistakes

| Mistake | Fix |
|---|---|
| Committing `terraform.tfstate` to Git | Add `*.tfstate` and `*.tfstate.*` to `.gitignore` |
| Editing state JSON by hand | Use `terraform state` commands or `moved`/`import` blocks |
| Renaming a resource label without `moved` | Add a `moved` block, or Terraform will recreate the resource |
| Using local state in a team | Use a remote backend with locking |
| Same state for dev and prod | Separate state for each environment |
| Using `force-unlock` while a run is active | Confirm no run is active first |
| Thinking `sensitive = true` keeps secrets out of state | It doesn't; protect the state itself |
| Deleting state to "start fresh" | Resources still exist; you'll get duplicates or conflicts |
| Using variables inside the `backend` block | Use literal values or `-backend-config` |

---

## Interview Questions

### Q1. What is the Terraform state file?

> A JSON file (`terraform.tfstate`) that records the resources Terraform manages and maps each resource in the code to its real-world object, along with its attributes and dependencies.

### Q2. Why does Terraform need state?

> To map code to real resources, detect what needs to be created, changed, or destroyed, store attributes for references and outputs, track dependencies for destroy order, and improve performance.

### Q3. Where is state stored by default?

> Locally, as `terraform.tfstate` in the working directory.

### Q4. Why is local state a problem for teams?

> It isn't shared, has no team-wide locking, can be lost easily, and keeps secrets on personal machines. Teams should use a remote backend.

### Q5. What is state locking?

> A mechanism that prevents multiple runs from writing to the same state at the same time, avoiding corruption. It happens automatically on backends that support it.

### Q6. What is drift?

> A difference between the real infrastructure and what Terraform's code and state expect, usually caused by manual changes. `terraform plan` detects it and proposes changes to match the code.

### Q7. Does the state file contain secrets?

> Yes. All attribute values, including sensitive ones, are stored in plain text. State must be encrypted and access-controlled, and never committed to Git.

### Q8. Difference between `terraform state rm` and `terraform destroy`?

> `state rm` only removes the resource from state, so Terraform stops tracking it but the real resource stays. `destroy` deletes the real resource.

### Q9. How do you bring an existing manually-created resource under Terraform?

> Use an `import` block (Terraform 1.5+) or the `terraform import` command, then match the resource configuration in code.

### Q10. How do you rename a resource in code without recreating it?

> Use a `moved` block, or run `terraform state mv`.

### Q11. What is `terraform.tfstate.backup`?

> A copy of the previous state, written when Terraform updates the state. It can be used for recovery.

### Q12. What are `serial` and `lineage`?

> `serial` increases with every state change. `lineage` is a unique ID set when the state is first created. Together they stop old or unrelated state from overwriting the current one.

---

## Quick Revision

- State = Terraform's **memory**: maps code ↔ real resources.
- Created by the first `apply`; read by `plan`; updated by `apply` and `destroy`.
- Default: local `terraform.tfstate` + `terraform.tfstate.backup`.
- JSON format with `resources`, `outputs`, `serial`, and `lineage`.
- `plan` compares **code**, **state**, and **reality**.
- Drift = manual changes; code wins on the next apply.
- `-refresh-only` updates state without changing resources.
- State holds **secrets in plain text**: never commit, always protect.
- Teams use **remote backends** (S3, Azure Storage, GCS, HCP Terraform).
- **Locking** prevents concurrent writes; `force-unlock` only when safe.
- Use `terraform state list/show/mv/rm`, never hand edits.
- `moved` = rename safely, `import` = adopt existing, `state rm` = forget without deleting.
- One state per environment; enable versioning for recovery.

---

## One-Line Summary

> The Terraform state file is Terraform's record of what it manages. It maps code to real resources so plans are accurate, it contains sensitive data, and in team projects it should be stored in a locked, encrypted, versioned remote backend and changed only through Terraform commands.

---

## Official References

- [Terraform State](https://developer.hashicorp.com/terraform/language/state)
- [Backend Configuration](https://developer.hashicorp.com/terraform/language/backend)
- [S3 Backend](https://developer.hashicorp.com/terraform/language/backend/s3)
- [State Locking](https://developer.hashicorp.com/terraform/language/state/locking)
- [terraform state commands](https://developer.hashicorp.com/terraform/cli/commands/state)
- [Import](https://developer.hashicorp.com/terraform/language/import)
- [Refactoring with moved blocks](https://developer.hashicorp.com/terraform/language/modules/develop/refactoring)
