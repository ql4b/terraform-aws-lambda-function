# terraform-aws-lambda-function

> Minimal Lambda function with zip packaging and container image support for provided.al2023 runtime

Terraform module that creates a Lambda function with zip packaging or container images, IAM execution role, and CloudWatch logs. Perfect for shell scripts and custom runtimes.

## Features

- **Zip packaging** from source directory
- **Container image** deployment from ECR
- **IAM execution role** with basic Lambda permissions
- **CloudWatch log group** with configurable retention
- **provided.al2023 runtime** optimized for shell scripts
- **CloudPosse labeling** for consistent naming

## Usage

### Basic Usage with Zip Packaging

```hcl
module "lambda" {
  source = "git::https://github.com/ql4b/terraform-aws-lambda-function.git"
  
  source_dir       = "../app/src"
  template_dir     = "../app/src"
  create_templates = true
  
  context    = module.label.context
  attributes = ["lambda"]
}
```

This will automatically create `bootstrap`, `handler.sh`, and `Makefile` in your `../app/src` directory.

### Container Image Usage

```hcl
module "lambda_function" {
  source = "git::https://github.com/ql4b/terraform-aws-lambda-function.git"
  
  package_type = "Image"
  image_uri    = "${aws_ecr_repository.example.repository_url}:latest"
  
  image_config = {
    entry_point = ["/lambda-entrypoint.sh"]
    command     = ["app.handler"]
  }
  
  memory_size = 512
  timeout     = 30
  
  environment_variables = {
    THUMBNAILS_BUCKET = module.thumbnails_bucket.bucket_id
  }
  
  context    = module.label.context
  attributes = ["lambda"]
}
```

**Note:** This module integrates seamlessly with any existing Terraform setup. The examples above show integration with CloudPosse labeling, but you can use it standalone or with any naming convention.

## Advanced Zip Configuration

```hcl
module "lambda_function" {
  source = "git::https://github.com/ql4b/terraform-aws-lambda-function.git"
  
  package_type = "Zip"
  source_dir   = "./src"
  
  handler            = "bootstrap"
  runtime            = "provided.al2023"
  architecture       = "arm64"
  memory_size        = 256
  timeout            = 30
  
  environment_variables = {
    HANDLER = "/var/task/handler.sh"
    PATH    = "/opt/bin:/usr/local/bin:/usr/bin:/bin"
  }
  
  log_retention_days = 30
  
  context = {
    namespace = "myorg"
    name      = "myfunction"
    stage     = "prod"
  }
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| package_type | Lambda deployment package type | `string` | `"Zip"` | no |
| image_uri | ECR image URI for container image deployment | `string` | `null` | no |
| image_config | Container image configuration | `object` | `null` | no |
| source_dir | Path to source directory (Zip only) | `string` | n/a | yes |
| handler | Lambda function handler (Zip only) | `string` | `"bootstrap"` | no |
| runtime | Lambda runtime (Zip only) | `string` | `"provided.al2023"` | no |
| architecture | Lambda function architecture | `string` | `"arm64"` | no |
| memory_size | Memory in MB | `number` | `128` | no |
| timeout | Timeout in seconds | `number` | `3` | no |
| environment_variables | Environment variables | `map(string)` | `{}` | no |

## Container Image Configuration

The `image_config` object supports:

```hcl
image_config = {
  entry_point       = ["/lambda-entrypoint.sh"]  # Optional
  command          = ["app.handler"]              # Optional  
  working_directory = "/var/task"                 # Optional
}
```

## Template Generation (Zip Only)

Set `create_templates = true` to automatically generate starter files:

- `bootstrap` - Lambda runtime bootstrap (executable)
- `handler.sh` - Example function handler
- `Makefile` - Deployment and testing commands

### Generated Directory Structure

```
src/
├── bootstrap      # Lambda runtime bootstrap (executable)
├── handler.sh     # Your function code
└── Makefile       # Deployment commands
```

## Example Bootstrap

```bash
#!/bin/bash
# bootstrap
set -euo pipefail

while true; do
  HEADERS="$(mktemp)"
  EVENT_DATA=$(curl -sS -LD "$HEADERS" -X GET "http://${AWS_LAMBDA_RUNTIME_API}/2018-06-01/runtime/invocation/next")
  REQUEST_ID=$(grep -Fi Lambda-Runtime-Aws-Request-Id "$HEADERS" | tr -d '[:space:]' | cut -d: -f2)
  
  # Execute your handler
  RESPONSE=$(bash "${HANDLER:-/var/task/handler.sh}" "$EVENT_DATA")
  
  # Send response
  curl -X POST "http://${AWS_LAMBDA_RUNTIME_API}/2018-06-01/runtime/invocation/$REQUEST_ID/response" -d "$RESPONSE"
done
```

## Example Handler

```bash
#!/bin/bash
# handler.sh
api_handler() {
    local event="$1"
    local name=$(echo "$event" | jq -r '.name // "World"')
    
    echo '{
        "statusCode": 200,
        "body": "Hello, '"$name"'!"
    }'
}

# Call handler with event data
api_handler "$1"
```

## Deployment Workflow

### 1. Deploy Infrastructure

```bash
terraform init
terraform apply
```

### 2. Set Function Name

```bash
# If using the module directly
export FUNCTION_NAME=$(terraform output -raw function_name)

# If using as a nested module (like in cloudless-minimal)
export FUNCTION_NAME=$(tf output --json lambda | jq -r .function_name)
```

### 3. Use the Generated Makefile (Zip Only)

When `create_templates = true`, a `Makefile` is generated with deployment workflows:

```bash
# Set function name (adjust based on your output structure)
export FUNCTION_NAME=$(tf output --json lambda | jq -r .function_name)

# Navigate to your source directory
cd app/src

# Deploy function code
make deploy

# Test function
make invoke

# View logs
make logs

# Clean artifacts
make clean

# See all targets
make help
```

### 4. Manual Deployment (Alternative)

```bash
# Package and deploy manually
FUNCTION_NAME=$(terraform output -raw function_name)
cd src && zip -r ../function.zip .
aws lambda update-function-code \
  --function-name $FUNCTION_NAME \
  --zip-file fileb://function.zip

# Test function
aws lambda invoke --function-name $FUNCTION_NAME /tmp/response.json
cat /tmp/response.json
```

## Requirements

- Terraform >= 1.0
- AWS provider >= 5.0
- Archive provider >= 2.0 (Zip packaging only)

## Outputs

- `function_name` - Lambda function name
- `function_arn` - Lambda function ARN
- `execution_role_arn` - IAM execution role ARN
- `execution_role_name` - IAM execution role name
- `log_group_name` - CloudWatch log group name

## Integration with Lambda Layers

```hcl
# Add layers for additional tools
resource "aws_lambda_layer_version" "jq" {
  layer_name = "jq"
  filename   = "jq-layer.zip"
  
  compatible_runtimes      = ["provided.al2023"]
  compatible_architectures = ["arm64"]
}

module "lambda_function" {
  source = "git::https://github.com/ql4b/terraform-aws-lambda-function.git"
  
  source_dir = "./src"
  
  environment_variables = {
    PATH = "/opt/bin:/usr/local/bin:/usr/bin:/bin"
  }
  
  context = {
    namespace = "myorg"
    name      = "myfunction"
  }
}

# Attach layer to function
resource "aws_lambda_function" "with_layers" {
  # ... other configuration
  layers = [aws_lambda_layer_version.jq.arn]
}
```

---

*Part of the [cloudless](https://github.com/ql4b/cloudless-api) ecosystem.*