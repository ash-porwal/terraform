# Terraform Configuration Using JSON

This example demonstrates how to define a Terraform output using JSON syntax.

## Supported Terraform Configuration Formats

Terraform configuration files can be written in:

- **HashiCorp Configuration Language (HCL)** using the `.tf` extension
- **JSON** using the `.tf.json` extension

Terraform does not use YAML as its native configuration language. YAML files can be read as data from an HCL configuration, but Terraform configuration files themselves must use HCL or JSON.

## Important Note About JSON Comments

Standard JSON does not support comments. Therefore, do not include `//`, `#`, or `/* ... */` comments inside a `.tf.json` file.

Documentation and explanatory notes should instead be placed in a separate file, such as this `README.md`.

## Project Structure

```text
terraform-json-example/
├── README.md
└── outputs.tf.json
```

## Terraform JSON Configuration

Save the following configuration as `outputs.tf.json`:

```json
{
  "output": {
    "ashish_output": {
      "value": "ashish's first terraform"
    }
  }
}
```

This configuration defines an output named `ashish_output` with the value:

```text
ashish's first terraform
```

## Run the Configuration

Open a terminal in the project directory and initialize Terraform:

```bash
terraform init
```

Validate the configuration:

```bash
terraform validate
```

Preview the changes:

```bash
terraform plan
```

Apply the configuration:

```bash
terraform apply
```

After applying it, Terraform will display an output similar to:

```text
Outputs:

ashish_output = "ashish's first terraform"
```

To display the output again later, run:

```bash
terraform output ashish_output
```

## Equivalent HCL Configuration

The same output can be written in HCL using an `outputs.tf` file:

```hcl
# HCL supports comments.
output "ashish_output" {
  value = "ashish's first terraform"
}
```

HCL is generally easier for people to read and maintain, while JSON can be useful when Terraform configuration is generated programmatically.
