# Terraform Notes - `terraform destroy` (Basics to Advanced)

## Quick Answer

`terraform destroy` **deletes all the real resources that Terraform manages** in the current working directory and workspace, using the **state file** to know what to delete.

```text
terraform.tfstate  ->  "I created these 3 things"  ->  terraform destroy  ->  all 3 deleted
```

To delete **only some** resources, you have several options, covered in detail below:

| Goal | Best way |
|---|---|
| Delete **everything** | `terraform destroy` |
| Delete **one or a few** resources permanently | **Remove the block from code**, then `terraform apply` ✅ |
| Delete one resource **urgently / one-off** | `terraform destroy -target=<address>` |
| Delete **one item** of a `for_each` / `count` | Remove that key/item from the map/list, then `apply` |
| **Stop managing** a resource but **keep it alive** | `removed` block or `terraform state rm` |
| **Protect** a resource from deletion | `lifecycle { prevent_destroy = true }` |

---

# Part 1: Basics

## What Does `terraform destroy` Do?

1. Reads the **state file** to find every resource Terraform manages.
2. Refreshes them against the real platform (GitHub, AWS, Azure).
3. Builds a **destroy plan** in the correct **dependency order**.
4. Shows the plan and asks for confirmation.
5. Calls the provider API to **delete** each resource.
6. Removes the deleted resources from the state.

## Basic Usage

```bash
terraform destroy
```

Sample output:

```text
Terraform will perform the following actions:

  # github_repository.learning_repo will be destroyed
  - resource "github_repository" "learning_repo" {
      - name       = "terraform-created-repo" -> null
      - visibility = "public" -> null
      ...
    }

Plan: 0 to add, 0 to change, 1 to destroy.

Do you really want to destroy all resources?
  Terraform will destroy all your managed infrastructure, as shown above.
  There is no undo. Only 'yes' will be accepted to confirm.

  Enter a value: yes

github_repository.learning_repo: Destroying... [id=terraform-created-repo]
github_repository.learning_repo: Destruction complete after 1s

Destroy complete! Resources: 1 destroyed.
```

> ⚠️ **There is no undo.** Only `yes` is accepted. Typing `y` cancels.

## `terraform destroy` = `terraform apply -destroy`

These two commands are **the same**:

```bash
terraform destroy
terraform apply -destroy
```

`terraform destroy` is just a convenient alias.

## Preview Before Destroying (Dry Run)

```bash
terraform plan -destroy
```

Shows **what would be deleted** without deleting anything. Always do this first on real projects.

### Save a destroy plan and apply it exactly

```bash
terraform plan -destroy -out=destroy.tfplan
terraform apply destroy.tfplan
```

> Applying a saved plan file does **not** ask for confirmation, because you already reviewed it. This is common in CI/CD with a manual approval step in between.

## Skip the Confirmation Prompt

```bash
terraform destroy -auto-approve
```

> ⚠️ Use only in automation or throwaway practice environments. In real projects, one wrong folder or workspace means deleting the wrong infrastructure.

---

# Part 2: What Destroy Does and Doesn't Touch

| Item | Destroyed? |
|---|---|
| Resources in **state** (created by `resource` blocks) | ✅ Yes |
| Resources created **manually** (not in state) | ❌ No; Terraform doesn't know they exist |
| `data` sources | ❌ No; they only **read** existing things |
| Resources in **another workspace** or another state | ❌ No; only the current one |
| Resources managed by **another Terraform project** | ❌ No |
| Your `.tf` code files | ❌ No; code stays as is |
| `terraform.tfstate` file | ❌ Not deleted; it becomes **empty** of resources |
| `.terraform/` folder and lock file | ❌ No |

> After destroy, running `terraform apply` again **recreates everything**, because the code still describes those resources.

### State after destroy

```json
{
  "version": 4,
  "serial": 7,
  "resources": [],
  "outputs": {}
}
```

---

# Part 3: Destroy Order (Dependencies)

Terraform destroys resources in the **reverse order** of creation, based on dependencies.

### Example

```hcl
resource "github_repository" "app" {
  name      = "my-app"
  auto_init = true
}

resource "github_branch" "dev" {
  repository = github_repository.app.name
  branch     = "dev"
}

resource "github_branch_protection" "main_rules" {
  repository_id = github_repository.app.node_id
  pattern       = "main"
}
```

### Creation order

```text
github_repository.app
      ↓
github_branch.dev  and  github_branch_protection.main_rules
```

### Destroy order (reversed)

```text
github_branch.dev  and  github_branch_protection.main_rules
      ↓
github_repository.app
```

> Terraform figures this out automatically from references like `github_repository.app.name`. You don't control the order manually. If a hidden dependency exists, use `depends_on` so Terraform orders creation **and** destruction correctly.

---

# Part 4: Deleting Specific Resources (Main Topic)

Assume this project manages **three repos**:

```hcl
resource "github_repository" "frontend" {
  name = "tf-frontend"
}

resource "github_repository" "backend" {
  name = "tf-backend"
}

resource "github_repository" "docs" {
  name = "tf-docs"
}
```

```bash
terraform state list
```

```text
github_repository.backend
github_repository.docs
github_repository.frontend
```

**Goal:** delete only `docs`, keep `frontend` and `backend`.

---

## Method 1: Remove the Block from Code, Then Apply ✅ (Recommended)

This is the **normal, correct** way.

### Step 1: Delete (or comment out) the block

```hcl
resource "github_repository" "frontend" {
  name = "tf-frontend"
}

resource "github_repository" "backend" {
  name = "tf-backend"
}

# docs repo removed
```

### Step 2: Plan

```bash
terraform plan
```

```text
  # github_repository.docs will be destroyed
  # (because github_repository.docs is not in configuration)
  - resource "github_repository" "docs" {
      - name = "tf-docs" -> null
    }

Plan: 0 to add, 0 to change, 1 to destroy.
```

### Step 3: Apply

```bash
terraform apply
```

### Why this is the best way

- **Code and reality stay in sync.** The code no longer has `docs`, and neither does GitHub.
- The change is **reviewed in Git** (pull request) like any other change.
- Running `apply` again later won't bring it back.

> Also remove any **references** to the deleted resource, like outputs using `github_repository.docs.html_url`, or `plan` will fail with a reference error.

---

## Method 2: `-target` Flag (One-off / Emergency)

Destroy one resource **without touching the code**:

```bash
terraform destroy -target=github_repository.docs
```

Preview first:

```bash
terraform plan -destroy -target=github_repository.docs
```

Output includes a warning:

```text
Warning: Resource targeting is in effect

You are creating a plan with the -target option, which means that the result
of this plan may not represent all of the changes requested by the current
configuration.
```

### Multiple targets

```bash
terraform destroy -target=github_repository.docs -target=github_repository.backend
```

### ⚠️ Very important catch

The `docs` block is **still in your code**. So the next normal run will **recreate it**:

```bash
terraform apply
```

```text
  # github_repository.docs will be created
  + resource "github_repository" "docs" { ... }
```

So after a `-target` destroy, **also remove the block from code**, or it comes back.

### Dependents are destroyed too

If other resources **depend on** the target, Terraform destroys them as well, because they can't exist without it.

```bash
terraform destroy -target=github_repository.app
```

```text
  # github_branch.dev will be destroyed
  # github_branch_protection.main_rules will be destroyed
  # github_repository.app will be destroyed

Plan: 0 to add, 0 to change, 3 to destroy.
```

> **Always read the plan.** Targeting one resource can delete more than one.

### When is `-target` appropriate?

| ✅ OK | ❌ Not OK |
|---|---|
| Recovering from an error or broken state | Day-to-day way of deleting resources |
| Urgent one-time cleanup | Replacing normal code changes |
| Learning and practice | Production routine |

> HashiCorp's guidance: `-target` is for **exceptional situations**, not routine use.

---

## Method 3: Specific Items in `for_each`

```hcl
variable "repos" {
  type = map(string)
  default = {
    "tf-dev"  = "Dev repo"
    "tf-test" = "Test repo"
    "tf-prod" = "Prod repo"
  }
}

resource "github_repository" "multi" {
  for_each    = var.repos
  name        = each.key
  description = each.value
}
```

State addresses:

```text
github_repository.multi["tf-dev"]
github_repository.multi["tf-prod"]
github_repository.multi["tf-test"]
```

### ✅ Recommended: remove the key from the map

```hcl
default = {
  "tf-dev"  = "Dev repo"
  "tf-prod" = "Prod repo"
  # tf-test removed
}
```

```bash
terraform apply
```

```text
  # github_repository.multi["tf-test"] will be destroyed

Plan: 0 to add, 0 to change, 1 to destroy.
```

Only `tf-test` is deleted. The others are untouched, because `for_each` tracks items by **key**.

### One-off: target a single instance

The address contains quotes and brackets, so **quoting matters**.

**Bash:**

```bash
terraform destroy -target='github_repository.multi["tf-test"]'
```

**PowerShell 7.3+:**

```powershell
terraform destroy -target='github_repository.multi["tf-test"]'
```

**Windows PowerShell 5.1 / older (inner quotes get stripped):**

```powershell
terraform destroy -target='github_repository.multi[\"tf-test\"]'
```

**cmd:**

```cmd
terraform destroy -target="github_repository.multi[\"tf-test\"]"
```

> Tip: copy the exact address from `terraform state list`.

---

## Method 4: Specific Items in `count` (and Its Trap)

```hcl
variable "repo_names" {
  default = ["tf-a", "tf-b", "tf-c"]
}

resource "github_repository" "counted" {
  count = length(var.repo_names)
  name  = var.repo_names[count.index]
}
```

State addresses:

```text
github_repository.counted[0]   -> tf-a
github_repository.counted[1]   -> tf-b
github_repository.counted[2]   -> tf-c
```

### Removing the **last** item: fine

```hcl
default = ["tf-a", "tf-b"]
```

```text
  # github_repository.counted[2] will be destroyed
```

### ⚠️ Removing a **middle** item: the trap

```hcl
default = ["tf-a", "tf-c"]   # removed tf-b
```

Indexes **shift**:

```text
counted[0] -> tf-a   (no change)
counted[1] -> was tf-b, now tf-c   -> renamed/replaced!
counted[2] -> was tf-c, now gone   -> destroyed!
```

Terraform changes `counted[1]` and destroys `counted[2]`. You wanted to delete only `tf-b`, but `tf-c` is affected too.

> **Lesson:** For collections where items may be removed, use **`for_each`** (tracked by key), not **`count`** (tracked by position).

### Target one `count` instance

```bash
terraform destroy -target='github_repository.counted[1]'
```

---

## Method 5: Stop Managing Without Deleting (`removed` block / `state rm`)

Sometimes you want Terraform to **forget** a resource but **keep it alive**, for example handing it over to another team or another Terraform project.

### Option A: `removed` block (Terraform 1.7+, recommended)

Delete the resource block and add:

```hcl
removed {
  from = github_repository.docs

  lifecycle {
    destroy = false
  }
}
```

```bash
terraform plan
```

```text
  # github_repository.docs will no longer be managed by Terraform, but will not be destroyed
  # (destroy = false is set in the configuration)
```

```bash
terraform apply
```

The repo stays on GitHub, but disappears from state. Once applied, you can delete the `removed` block.

### Option B: `terraform state rm` (CLI)

```bash
terraform state rm github_repository.docs
```

Same result, done immediately from the command line without a plan.

> Then delete the resource block from code. Otherwise, the next `apply` tries to **create** it again, and fails because a repo with that name already exists.

### Comparison

| | Remove block + apply | `-target` destroy | `removed` (destroy=false) / `state rm` |
|---|---|---|---|
| Real resource | **Deleted** | **Deleted** | **Kept** |
| Removed from state | Yes | Yes | Yes |
| Code updated | Yes | ❌ No (do it yourself) | Yes / do it yourself |
| Reviewed in plan | Yes | Yes | Yes / ❌ No |
| Typical use | Normal deletion | Emergency, one-off | Hand-over, stop managing |

---

# Part 5: Protecting Resources from Deletion

## `prevent_destroy`

```hcl
resource "github_repository" "prod_repo" {
  name = "tf-prod-critical"

  lifecycle {
    prevent_destroy = true
  }
}
```

Now any plan that would delete it **fails**:

```bash
terraform destroy
```

```text
Error: Instance cannot be destroyed

Resource github_repository.prod_repo has lifecycle.prevent_destroy set, but the
plan calls for this resource to be destroyed.
```

> This also blocks `terraform destroy` for **everything**, because Terraform refuses the whole plan. To destroy the rest, use `-target` on the other resources, or remove `prevent_destroy` first.

### ⚠️ Limitation

If you **delete the whole resource block**, the `prevent_destroy` setting is deleted with it, so the protection is gone and the resource gets destroyed. It only protects while the block is in the code.

## Provider-Level Safety Options

Many providers have their own safety arguments. Check the registry docs.

| Provider resource | Argument | Effect |
|---|---|---|
| `github_repository` | `archive_on_destroy = true` | **Archives** the repo instead of deleting it |
| `aws_s3_bucket` | `force_destroy = false` (default) | Refuses to delete a **non-empty** bucket |
| `aws_db_instance` | `deletion_protection = true` | AWS blocks deletion |
| `aws_db_instance` | `skip_final_snapshot = false` | Takes a final snapshot before deleting |
| `aws_instance` | `disable_api_termination = true` | Termination protection |

### GitHub example

```hcl
resource "github_repository" "learning_repo" {
  name               = "terraform-created-repo"
  archive_on_destroy = true
}
```

`terraform destroy` now **archives** the repo (read-only) instead of deleting it. Safer while learning.

---

# Part 6: Destroy vs Replace vs Taint

Sometimes you don't want to delete, you want to **recreate** a broken resource.

| Command | What it does |
|---|---|
| `terraform destroy -target=X` | Deletes X (comes back on next apply if still in code) |
| `terraform apply -replace=X` ✅ | Destroys and **recreates** X in one step |
| `terraform taint X` | Old way to mark X for replacement (deprecated) |

```bash
terraform apply -replace='github_repository.docs'
```

```text
  # github_repository.docs will be replaced, as requested
-/+ resource "github_repository" "docs" { ... }
```

### `create_before_destroy`

By default, replacement is **destroy first, then create**. To avoid downtime:

```hcl
lifecycle {
  create_before_destroy = true
}
```

> Doesn't work when the new resource needs the same unique name as the old one (like a GitHub repo name), because both would exist at the same moment.

---

# Part 7: Useful Destroy Options

| Option | Purpose |
|---|---|
| `-auto-approve` | Skip the `yes` prompt |
| `-target=ADDRESS` | Destroy only this resource (and its dependents); repeatable |
| `-var` / `-var-file` | Pass variables; needed if required variables have no default |
| `-refresh=false` | Skip refreshing real resources first (faster, riskier) |
| `-parallelism=N` | Number of resources deleted in parallel (default 10) |
| `-lock-timeout=60s` | Wait for a state lock instead of failing immediately |
| `-input=false` | No prompts for variables (CI/CD) |

> **Why variables matter for destroy:** Terraform still evaluates your configuration, including provider settings. If a required variable has no value, destroy prompts for it, just like plan. Use the same `-var-file` you used for apply:
>
> ```bash
> terraform destroy -var-file="envs/dev.tfvars"
> ```

---

# Part 8: Multiple Environments - Destroy the Right One!

With one state per environment, **double-check which one you're pointed at** before destroying.

### Workspaces

```bash
terraform workspace show        # check current workspace
terraform workspace select dev
terraform destroy -var-file="envs/dev.tfvars"
```

### Separate backends / folders

```bash
cd envs/dev
terraform destroy
```

### Safety checklist before destroying

- [ ] Correct **folder**?
- [ ] Correct **workspace** (`terraform workspace show`)?
- [ ] Correct **`-var-file`**?
- [ ] Correct **cloud account / GitHub owner**?
- [ ] Ran **`terraform plan -destroy`** and read every line?
- [ ] Any **data** that needs a backup first (databases, buckets, repo contents)?

---

# Part 9: Common Errors During Destroy

| Error | Cause | Fix |
|---|---|---|
| `Instance cannot be destroyed` | `prevent_destroy = true` | Remove it, or `-target` other resources |
| `403 Must have admin rights` (GitHub) | Token can't delete repos | Fine-grained: **Administration: Read and write**; classic: `delete_repo` scope |
| `BucketNotEmpty` (AWS S3) | Bucket has objects | Empty it, or set `force_destroy = true` |
| `DependencyViolation` (AWS) | Something outside Terraform still uses the resource | Remove the external dependency first |
| `Error acquiring the state lock` | Another run is active, or a stale lock | Wait, or `force-unlock` if sure nothing is running |
| `No value for required variable` | Missing `-var-file` | Pass the same variables used for apply |
| `Invalid target address` | Wrong address or quoting | Copy it from `terraform state list`; fix quotes |
| Resource "comes back" after `-target` destroy | Block still in code | Remove the block from code |
| `No changes. No objects need to be destroyed.` | State is empty, or wrong folder/workspace | Check folder, workspace, and backend |

---

# Hands-on Practice (GitHub, No Cloud Account Needed)

### `main.tf`

```hcl
resource "github_repository" "frontend" {
  name      = "tf-practice-frontend"
  auto_init = true
}

resource "github_repository" "backend" {
  name      = "tf-practice-backend"
  auto_init = true
}

resource "github_branch" "backend_dev" {
  repository = github_repository.backend.name
  branch     = "dev"
}

resource "github_repository" "multi" {
  for_each  = toset(["tf-practice-a", "tf-practice-b", "tf-practice-c"])
  name      = each.key
  auto_init = true
}
```

### Exercises

```bash
# 0. Create everything
terraform apply
terraform state list

# 1. Preview a full destroy (nothing deleted)
terraform plan -destroy

# 2. Target a resource that has a dependent
terraform plan -destroy -target=github_repository.backend
#    -> notice github_branch.backend_dev is destroyed too

# 3. Destroy one for_each instance with -target
terraform destroy -target='github_repository.multi["tf-practice-c"]'

# 4. Run a normal apply -> tf-practice-c comes back!
terraform apply

# 5. Now delete it properly: remove "tf-practice-c" from the toset(), then
terraform apply

# 6. Remove the frontend block and add a removed block with destroy = false
terraform apply
#    -> repo stays on GitHub, but is gone from state

# 7. Add prevent_destroy to backend, then
terraform destroy
#    -> error: Instance cannot be destroyed

# 8. Remove prevent_destroy and clean everything up
terraform destroy
```

> After step 6, delete the `tf-practice-frontend` repo manually on GitHub, since Terraform no longer manages it.

---

# Common Mistakes

| Mistake | Correct approach |
|---|---|
| Using `-target` as the normal way to delete | Remove the block from code and `apply` |
| Forgetting to remove code after a `-target` destroy | The resource gets recreated on the next apply |
| Not reading the plan when targeting | Dependents get destroyed too |
| Removing a middle item from a `count` list | Use `for_each` for removable items |
| Running destroy in the wrong workspace/folder | Check `terraform workspace show` and the path |
| Using `-auto-approve` on real environments | Review the plan; approve manually |
| Thinking `prevent_destroy` survives deleting the block | It's removed together with the block |
| Using `state rm` but leaving the block in code | Next apply tries to create it again |
| Expecting destroy to delete manually created resources | Only resources in state are destroyed |
| Forgetting `-var-file` for destroy | Use the same variables as apply |

---

# Interview Questions

### Q1. What does `terraform destroy` do?

> It deletes all resources tracked in the current state, in reverse dependency order, after showing a plan and asking for confirmation.

### Q2. How do you preview what destroy will delete?

> `terraform plan -destroy`.

### Q3. What is the difference between `terraform destroy` and `terraform apply -destroy`?

> None. `terraform destroy` is an alias for `terraform apply -destroy`.

### Q4. How do you delete a single resource when there are many?

> The recommended way is to remove its block from the code and run `terraform apply`. For one-off cases, use `terraform destroy -target=<address>`.

### Q5. What is the risk of `-target`?

> It skips the rest of the configuration, so the plan may not reflect everything. Dependents of the target are destroyed too, and if the block is still in code, the next apply recreates it. It's meant for exceptional cases.

### Q6. How do you delete one instance of a `for_each` resource?

> Remove its key from the map or set and apply. Or, as a one-off, target it with `-target='type.name["key"]'`.

### Q7. Why prefer `for_each` over `count` when removing items?

> `count` tracks items by index, so removing a middle item shifts indexes and changes or destroys other resources. `for_each` tracks items by key, so only the removed item is affected.

### Q8. How do you stop Terraform managing a resource without deleting it?

> Use a `removed` block with `lifecycle { destroy = false }` (Terraform 1.7+), or `terraform state rm`, and remove the resource block from code.

### Q9. How do you protect a resource from being destroyed?

> `lifecycle { prevent_destroy = true }`. It makes any plan that destroys the resource fail, but it stops protecting once the block is deleted. Provider options like `deletion_protection` or `archive_on_destroy` add another layer.

### Q10. In what order are resources destroyed?

> In reverse dependency order: resources that depend on others are destroyed first.

### Q11. Does destroy delete the state file?

> No. The state file remains, with an empty list of resources.

### Q12. How do you recreate a resource without deleting it permanently?

> `terraform apply -replace=<address>`, which replaced the older `terraform taint`.

---

# Quick Revision

- `terraform destroy` deletes **everything in state** for the current folder and workspace.
- `terraform destroy` = `terraform apply -destroy`.
- Preview with `terraform plan -destroy`; only `yes` confirms.
- Destroy order = **reverse** of dependencies.
- Doesn't touch data sources, manual resources, other workspaces, or code.
- **Delete specific resources:** remove the block → `apply` ✅.
- `-target` = one-off; destroys dependents too; block must also leave the code.
- `for_each`: remove the key. `count`: beware index shifting.
- `removed { lifecycle { destroy = false } }` or `state rm` = forget, don't delete.
- `prevent_destroy = true` blocks destruction while the block exists.
- Provider safety: `archive_on_destroy`, `deletion_protection`, `force_destroy`.
- Recreate instead of delete: `terraform apply -replace=<address>`.
- Pass the same `-var-file` to destroy as to apply.
- Always confirm folder, workspace, and plan before destroying.

---

## One-Line Summary

> `terraform destroy` removes every resource in the current state in reverse dependency order. To delete only specific resources, remove them from the code and apply, using `-target` only for one-off cases, `removed` blocks to stop managing without deleting, and `prevent_destroy` to protect critical resources.

---

## Official References

- [terraform destroy command](https://developer.hashicorp.com/terraform/cli/commands/destroy)
- [terraform plan command (-destroy, -target, -replace)](https://developer.hashicorp.com/terraform/cli/commands/plan)
- [Resource lifecycle (prevent_destroy, create_before_destroy)](https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle)
- [Removing resources (removed block)](https://developer.hashicorp.com/terraform/language/resources/syntax#removing-resources)
- [for_each meta-argument](https://developer.hashicorp.com/terraform/language/meta-arguments/for_each)
- [github_repository resource](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository)
