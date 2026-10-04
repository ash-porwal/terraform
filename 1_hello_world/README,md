# Terraform Notes - My First Terraform File

## What I Learned

This was my very first Terraform file. Instead of creating actual cloud infrastructure, I learned the basic Terraform syntax and how to generate output.

---

# Comments in Terraform

Terraform supports single-line comments in multiple ways.

### Using `#`

```hcl
# This is a comment
```

### Using `//`

```hcl
// This is also a comment
```

### Multi-line Comments

```hcl
/*
This is a
multi-line comment
*/
```

### Interview Note

> Terraform supports comments using `#`, `//`, and `/* */`.

---

# General Terraform Syntax

Almost everything in Terraform is defined using **Blocks**.

General structure:

```hcl
block_type "label1" "label2" {

    identifier = expression

}
```

Example:

```hcl
resource "aws_instance" "web" {

    instance_type = "t2.micro"

}
```

Here:

```text
resource      -> Block Type
aws_instance  -> Label 1
web           -> Label 2
instance_type -> Identifier
t2.micro      -> Expression/Value
```

---

# Understanding Block Type and Labels

Terraform configurations are built using blocks.

Syntax:

```hcl
block_type "label1" "label2" {

}
```

Example:

```hcl
output "my_output" {

}
```

Explanation:

```text
output       -> Block Type
my_output    -> Label
```

Not every block requires two labels.

*xamples:

```hcl
terraform {

}
``*

No labels.

```hcl
provider "aws* {

}
```

One label.

```hcl
reso*rce "aws_instance" "web" {

}
```
*Two labels.

---

# My First Terra*orm Program

Code:

```hcl
output *ashish_output" {

    value*= "ashish's first terraform"

*
```

*--

# What is Output Block?

The `*utput` block is used to display va*ues after Terraform execution.

Sy*tax:

```hcl
output "output_name" *

    value = expression

}
```

E*ample:

```hcl
output "welcome_mes*age" {

    value = "Hello Terrafo*m"

}
```

Output:

```text
welcom*_message = "Hello Terraform"
```

*--

# Breakdown of My Code

```hcl*output "ashish_output" {

    valu* = "ashish's first terraform"

}
`*`

### Line 1

```hcl
output "ashi*h_output"
```

Creates an output b*ock named:

```text
ashish_output
*``

---

### Line 3

```hcl
value * "ashish's first terraform"
```

A*signs a string value to the output*

---

### Complete Meaning

```hc*
output "ashish_output" {

    val*e = "ashish's first terraform"

}
*``

Means:

> After Terraform runs*successfully, display the text "as*ish's first terraform".

---

# Ho* to Execute

### Step 1

Initializ* Terraform

```bash
terraform init*```

### Step 2

See execution pla*

```bash
terraform plan
```

Outp*t will show:

```text
Changes to O*tputs:
  + ashish_output = "ashish*s first terraform"
```

### Step 3*
Apply

```bash
terraform apply
``*

Output:

```text
Apply complete!*
Outputs:

ashish_output = "ashish*s first terraform"
```

---

# Imp*rtant Observation

No infrastructu*e is being created.

There are:

-*No EC2 instances
- No S3 buckets
-*No VPCs
- No Azure Resources

Terr*form is only displaying an output *alue.

---

# Why This Example Is *mportant

This simple example teac*es:

1. Terraform file structure
2* Comments
3. Blocks
4. Labels
5. A*guments
6. Output blocks
7. Terraf*rm execution flow

Before creating*cloud resources, understanding the*e basics is very important.

---

* Terraform Concepts Learned So Far*
### Comment

```hcl
# comment
// *omment
/* comment */
```

Used for*documentation and explanation.

--*

### Block

```hcl
output "ashish*output" {

}
```

Container that d*fines configuration.

---

### Lab*l

```hcl
output "ashish_output"
`*`

Here:

```text
ashish_output
``*

is the label.

---

### Argument*
```hcl
value = "ashish's first te*raform"
```

`value` is an argumen*.

---

### Expression

```hcl
"as*ish's first terraform"
```

This i* an expression that evaluates to a*string.

---

# Interview Question*

### Q1. What are the different w*ys to write comments in Terraform?*
Answer:

```text
1. #
2. //
3. /***/
```

---

### Q2. What is a Ter*aform block?

Answer:

> A block i* the fundamental building unit of *erraform configuration and is used*to define providers, resources, va*iables, outputs, modules, and othe* settings.

---

### Q3. What is a* output block?

Answer:

> An outp*t block is used to display values *fter Terraform execution and can a*so expose values to other modules.*
---

### Q4. Is infrastructure cr*ated in this example?

Answer:

> *o. The configuration only defines an output value and does not create any cloud resources.

---

# Quick Revision

✅ Terraform supports `#`, `//`, and `/* */` comments

✅ Terraform configurations are built using blocks

✅ Block syntax:

```hcl
block_type "label1" "label2" {

    identifier = expression

}
```

✅ `output` block displays values after execution

✅ `value` is an argument

✅ `"ashish's first terraform"` is a string expression

✅ This Terraform file creates no infrastructure

✅ It is useful for learning Terraform syntax and execution flow

---

# One-Line Summary

> My first Terraform file used an `output` block to print a message, helping me learn Terraform comments, blocks, labels, arguments, expressions, and the basic execution flow without creating any cloud infrastructure.