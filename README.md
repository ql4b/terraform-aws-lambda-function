# terraform-aws-lambda-function

> Minimal Lambda function with zip packaging for provided.al2023 runtime

Terraform module that creates a Lambda function with zip packaging, IAM execution role, and CloudWatch logs. Perfect for shell scripts and custom runtimes without container overhead.

## Features

- **Zip packaging** from source directory
- **IAM execution role** with basic Lambda permissions
- **CloudWatch log group** with configurable retention
- **provided.al2023 runtime** optimized for shell scripts
- **CloudPosse labeling** for consistent naming

## Usage

### Basic Usage with Template Generation

```hcl
module "lambda_function" {
  source = "git::https://github.com/ql4b/terraform-aws-lambda-function.git"
  
  source_dir       = "./src"
  create_templates = true
  template_dir     = "./src"
  
  context = {
    namespace = "myorg"
    name      = "myfunction"
  }
}
```

This will automatically create `bootstrap`, `handler.sh`, and `Makefile` in your `./src` directory.

## Advanced Usage

```hcl
module "lambda_function" {
  source = "git::https://github.com/ql4b/terraform-aws-lambda-function.git"
  
  source_dir         = "./src"
  create_templates   = true
  template_dir       = "./src"
  
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

## Template Generation

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
export FUNCTION_NAME=$(terraform output -raw function_name)
```

### 3. Use the Generated Makefile

When `create_templates = true`, a `Makefile` is generated with deployment workflows:

```bash
# Set function name
export FUNCTION_NAME=$(terraform output -raw function_name)

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
- Archive provider >= 2.0

## Outputs

- `function_name` - Lambda function name
- `function_arn` - Lambda function ARN
- `execution_role_arn` - IAM execution role ARN
- `log_group_name` - CloudWatch log group name
- `template_files` - Paths to generated template files (when `create_templates = true`)

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