# Terraform Notes - `terraform refresh` and Refresh-Only Mode

## Quick Answer

**Refreshing** means Terraform **reads the current real values** of the resources it manages (from GitHub, AWS, Azure) and **updates the state file** to match them.

```text
Real world (GitHub)   --read-->   terraform.tfstate updated
Your .tf code         -> NOT changed
Real resources        -> NOT changed
```

> ⚠️ The `terraform refresh` command is **deprecated** (since Terraform v0.15.4). Use these instead:
>
> ```bash
> terraform plan  -refresh-only    # preview what state would change
> terraform apply -refresh-only    # review, then update state
> ```

---

## Why Do We Need Refresh?

The state file is Terraform's **memory** of your resources. But someone can change a resource **outside Terraform**, for example by editing the repo description directly on github.com. Now the state is **out of date**.

This difference is called **drift**:

```text
Code says:     description = "My first repository"
State says:    description = "My first repository"
GitHub has:    description = "Edited manually"      <-- drift
```

Refreshing brings the **state** up to date with **reality**, so Terraform knows what actually exists.

---

## What Refresh Changes and What It Doesn't

| Item | Changed by refresh? |
|---|---|
| `terraform.tfstate` | ✅ Yes, updated to match real resources |
| Output values stored in state | ✅ Yes, re-evaluated |
| Data sources | ✅ Re-read |
| Real resources (GitHub, AWS) | ❌ No, never modified |
| Your `.tf` code | ❌ No |
| Resources not in state (manually created) | ❌ Not added; use `import` for that |

---

## 1. The Old Command: `terraform refresh` (Deprecated)

```bash
terraform refresh
```

It is now just an alias for:

```bash
terraform apply -refresh-only -auto-approve
```

### Why it was deprecated

It **updates state immediately, with no preview and no confirmation**.

That's risky. If your credentials point to the **wrong account, owner, or region**, Terraform can't find your resources, assumes they were deleted, and **removes them all from state**. Terraform then "forgets" your infrastructure, and the next plan tries to create everything again.

> It still works for backward compatibility, but don't use it in new work.

---

## 2. The Modern Way: Refresh-Only Mode ✅

### Step 1: Preview

```bash
terraform plan -refresh-only
```

Sample output when drift exists:

```text
Note: Objects have changed outside of Terraform

Terraform detected the following changes made outside of Terraform since the
last "terraform apply":

  # github_repository.learning_repo has changed
  ~ resource "github_repository" "learning_repo" {
      ~ description = "My first repository" -> "Edited manually"
        id          = "terraform-created-repo"
        name        = "terraform-created-repo"
    }

This is a refresh-only plan, so Terraform will not take any actions to undo
these. If you were expecting these changes then you can apply this plan to
record the updated values in the Terraform state without changing any remote
objects.
```

Nothing is changed yet. This is only a preview.

### Step 2: Accept into state

```bash
terraform apply -refresh-only
```

Terraform shows the same changes and asks for `yes`. After confirming, **only the state is updated**.

### No drift

```text
No changes. Your infrastructure still matches the configuration.
```

### Comparison

| | `terraform refresh` | `terraform apply -refresh-only` |
|---|---|---|
| Shows changes first | ❌ No | ✅ Yes |
| Asks for confirmation | ❌ No | ✅ Yes |
| Can save a plan file | ❌ No | ✅ Yes (`plan -refresh-only -out=...`) |
| Status | Deprecated | Recommended |

---

## 3. Refresh Happens Automatically

You rarely need to refresh on its own, because **`plan` and `apply` refresh by default** before comparing state with your code.

```text
terraform plan
   1. Refresh: read real values           <-- automatic
   2. Compare: code vs refreshed state
   3. Show:    what needs to change
```

### Skip the automatic refresh

```bash
terraform plan  -refresh=false
terraform apply -refresh=false
```

Faster on very large projects, but the plan may be based on **stale** state. Use with care.

### `-refresh=false` vs `-refresh-only`

| Option | Meaning |
|---|---|
| `-refresh=false` | **Don't** read real values; use state as it is |
| `-refresh-only` | **Only** read real values and update state; propose no resource changes |

---

## 4. Normal Plan vs Refresh-Only Plan

Same drift: the description was edited manually on GitHub.

| | `terraform plan` | `terraform plan -refresh-only` |
|---|---|---|
| Detects drift | ✅ Yes | ✅ Yes |
| Proposes | Change GitHub **back** to match the code | Update **state** to match GitHub |
| Who wins | **Code** wins | **Reality** is recorded |

Normal plan output for the same drift:

```text
  # github_repository.learning_repo will be updated in-place
  ~ resource "github_repository" "learning_repo" {
      ~ description = "Edited manually" -> "My first repository"
    }

Plan: 0 to add, 1 to change, 0 to destroy.
```

---

## 5. Handling Drift: Revert or Accept?

When someone changes a resource manually, decide which is correct.

### Option A: Revert (code is right)

```bash
terraform apply
```

Terraform changes GitHub back to match the code.

### Option B: Accept (the manual change is right)

1. **Update the code** to match:

   ```hcl
   description = "Edited manually"
   ```

2. Run:

   ```bash
   terraform plan
   ```

   ```text
   No changes. Your infrastructure matches the configuration.
   ```

3. Optionally record it in state with `terraform apply -refresh-only`.

> ⚠️ **Important:** `apply -refresh-only` alone does **not** make drift permanent. The code still says the old value, so the **next normal `apply` reverts it**. To keep a manual change, you must **update the code**.

---

## 6. Special Case: Resource Deleted Manually

Someone deletes the repo directly on GitHub.

```bash
terraform plan -refresh-only
```

```text
Note: Objects have changed outside of Terraform

  # github_repository.learning_repo has been deleted
  - resource "github_repository" "learning_repo" {
      - name = "terraform-created-repo" -> null
    }
```

```bash
terraform apply -refresh-only
```

The resource is **removed from state**. Since the block is still in your code, the next `terraform plan` shows:

```text
  # github_repository.learning_repo will be created
```

- Want it back? Run `terraform apply`.
- Don't want it? Remove the block from code.

---

## 7. The Wrong-Credentials Danger

```text
Correct owner:  ashish        -> repos found         -> state OK
Wrong owner:    someone-else  -> repos "not found"   -> refresh marks them deleted
```

With `terraform refresh` (no review), those resources are **removed from state immediately**.

With `terraform plan -refresh-only`, you'd **see** "has been deleted" for everything and know something is wrong **before** accepting.

### Safety checklist

- [ ] Correct folder and workspace (`terraform workspace show`)?
- [ ] Correct credentials / token / `owner` / region?
- [ ] Reviewed `plan -refresh-only` output?
- [ ] Remote state has versioning enabled, so you can roll back?

---

## Command Options

`plan -refresh-only` and `apply -refresh-only` support the usual plan and apply options:

| Option | Purpose |
|---|---|
| `-var` / `-var-file` | Pass variables (needed if required variables have no default) |
| `-target=ADDRESS` | Refresh only specific resources |
| `-out=FILE` | Save a refresh-only plan (with `plan`) |
| `-auto-approve` | Skip confirmation (with `apply`; use carefully) |
| `-lock-timeout=60s` | Wait for a state lock |
| `-input=false` | No prompts (CI/CD) |

### Refresh a single resource

```bash
terraform plan -refresh-only -target=github_repository.learning_repo
```

### Save and apply exactly what you reviewed

```bash
terraform plan -refresh-only -out=refresh.tfplan
terraform apply refresh.tfplan
```

---

## Drift Detection in CI/CD

A scheduled pipeline can detect drift without changing anything:

```bash
terraform plan -refresh-only -detailed-exitcode
```

| Exit code | Meaning |
|---|---|
| `0` | No drift |
| `1` | Error |
| `2` | Drift detected → alert the team |

> Don't auto-apply refresh-only plans in pipelines. A human should decide whether to revert or accept drift.

---

## Hands-on Practice (GitHub Project)

```bash
# 0. Create the repo
terraform apply

# 1. No drift yet
terraform plan -refresh-only

# 2. On github.com, edit the repo description manually

# 3. See drift both ways
terraform plan -refresh-only   # proposes updating state
terraform plan                 # proposes changing GitHub back

# 4. Accept into state only
terraform apply -refresh-only
terraform state show github_repository.learning_repo   # new description

# 5. Normal plan -> still wants to revert (code wasn't updated!)
terraform plan

# 6. Update the description in main.tf to match, then
terraform plan                 # No changes

# 7. Delete the repo manually on github.com, then
terraform plan -refresh-only   # "has been deleted"
terraform apply -refresh-only
terraform plan                 # "will be created"

# 8. Bring it back or clean up
terraform apply
terraform destroy
```

---

## Common Mistakes

| Mistake | Correct approach |
|---|---|
| Using `terraform refresh` in new work | Use `plan -refresh-only` / `apply -refresh-only` |
| Thinking refresh changes real resources | It only updates state |
| Thinking refresh updates `.tf` code | Code never changes; update it yourself |
| Expecting `apply -refresh-only` to keep a manual change | The next normal apply reverts it unless code is updated |
| Expecting refresh to add manually created resources | Use `import` |
| Refreshing with wrong credentials or owner | Check credentials, workspace, and review the plan first |
| Using `-refresh=false` all the time | Plans may use stale data |
| Auto-applying refresh-only plans in CI | Detect with `-detailed-exitcode`; let a human decide |

---

## Interview Questions

### Q1. What does refreshing do in Terraform?

> It reads the current real values of managed resources and updates the state file to match. It doesn't change real resources or code.

### Q2. Is `terraform refresh` still recommended?

> No. It's deprecated and is an alias for `terraform apply -refresh-only -auto-approve`. Use `terraform plan -refresh-only` to review and `terraform apply -refresh-only` to accept.

### Q3. Why was `terraform refresh` deprecated?

> It updates state without showing changes or asking for confirmation. With wrong credentials or region, it can mark all resources as deleted and remove them from state.

### Q4. What is drift?

> A difference between real infrastructure and what Terraform's state and code expect, usually caused by manual changes.

### Q5. Difference between `plan` and `plan -refresh-only` when drift exists?

> A normal plan proposes changing real resources back to match the code. A refresh-only plan proposes updating state to match the real resources, with no resource changes.

### Q6. Difference between `-refresh=false` and `-refresh-only`?

> `-refresh=false` skips reading real values and uses state as is. `-refresh-only` only reads real values and updates state, proposing no resource changes.

### Q7. Do `plan` and `apply` refresh automatically?

> Yes, by default, unless `-refresh=false` is used.

### Q8. What happens when a managed resource is deleted manually and you refresh?

> It's removed from state. Since it's still in code, the next plan proposes creating it again.

### Q9. How do you permanently accept a manual change?

> Update the code to match the manual change. Refresh-only alone isn't enough, because the next apply would revert it.

### Q10. Can refresh bring a manually created resource under Terraform?

> No. Refresh only updates resources already in state. Use an `import` block or `terraform import`.

---

## Quick Revision

- Refresh = read real values → **update state only**.
- Never changes real resources or code.
- `terraform refresh` is **deprecated** = `apply -refresh-only -auto-approve`.
- Use `terraform plan -refresh-only` (preview) and `terraform apply -refresh-only` (accept).
- `plan` and `apply` refresh automatically; `-refresh=false` skips it.
- Drift: normal plan = **revert** to code; refresh-only = **record** reality in state.
- To keep a manual change permanently, **update the code**.
- Manually deleted resources are removed from state, then planned for creation.
- Wrong credentials can make everything look deleted, so review first.
- CI drift detection: `plan -refresh-only -detailed-exitcode` (exit code 2 = drift).
- Refresh doesn't adopt new resources; use `import`.

---

## One-Line Summary

> Refreshing updates Terraform's state to match real infrastructure without changing resources or code. The old `terraform refresh` command is deprecated because it skips review, so use `terraform plan -refresh-only` to preview drift and `terraform apply -refresh-only` to accept it, and update your code to keep manual changes permanently.

---

## Official References

- [terraform refresh command](https://developer.hashicorp.com/terraform/cli/commands/refresh)
- [terraform plan command (-refresh-only, -refresh=false)](https://developer.hashicorp.com/terraform/cli/commands/plan)
- [Use refresh-only mode to sync Terraform state (tutorial)](https://developer.hashicorp.com/terraform/tutorials/state/refresh)
- [Terraform state](https://developer.hashicorp.com/terraform/language/state)
