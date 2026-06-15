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
  source  = "ql4b/lambda-function/aws"
  version = "~> 1.0"
  
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
  source  = "ql4b/lambda-function/aws"
  version = "~> 1.0"
  
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
  source  = "ql4b/lambda-function/aws"
  version = "~> 1.0"
  
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
  source  = "ql4b/lambda-function/aws"
  version = "~> 1.0"
  
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

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | >= 2.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_archive"></a> [archive](#provider\_archive) | >= 2.0 |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |
| <a name="provider_null"></a> [null](#provider\_null) | n/a |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_this"></a> [this](#module\_this) | cloudposse/label/null | 0.25.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_log_group.lambda_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_role.lambda_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.lambda_basic_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_function.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_ssm_parameter.function_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.function_name](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.invoke_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [null_resource.bootstrap_template](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.handler_template](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.makefile_template](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [archive_file.lambda_zip](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_additional_tag_map"></a> [additional\_tag\_map](#input\_additional\_tag\_map) | Additional key-value pairs to add to each map in `tags_as_list_of_maps`. Not added to `tags` or `id`.<br/>This is for some rare cases where resources want additional configuration of tags<br/>and therefore take a list of maps with tag key, value, and additional configuration. | `map(string)` | `{}` | no |
| <a name="input_architecture"></a> [architecture](#input\_architecture) | Lambda function architecture | `string` | `"arm64"` | no |
| <a name="input_attributes"></a> [attributes](#input\_attributes) | ID element. Additional attributes (e.g. `workers` or `cluster`) to add to `id`,<br/>in the order they appear in the list. New attributes are appended to the<br/>end of the list. The elements of the list are joined by the `delimiter`<br/>and treated as a single ID element. | `list(string)` | `[]` | no |
| <a name="input_context"></a> [context](#input\_context) | Single object for setting entire context at once.<br/>See description of individual variables for details.<br/>Leave string and numeric variables as `null` to use default value.<br/>Individual variable settings (non-null) override settings in context object,<br/>except for attributes, tags, and additional\_tag\_map, which are merged. | `any` | <pre>{<br/>  "additional_tag_map": {},<br/>  "attributes": [],<br/>  "delimiter": null,<br/>  "descriptor_formats": {},<br/>  "enabled": true,<br/>  "environment": null,<br/>  "id_length_limit": null,<br/>  "label_key_case": null,<br/>  "label_order": [],<br/>  "label_value_case": null,<br/>  "labels_as_tags": [<br/>    "unset"<br/>  ],<br/>  "name": null,<br/>  "namespace": null,<br/>  "regex_replace_chars": null,<br/>  "stage": null,<br/>  "tags": {},<br/>  "tenant": null<br/>}</pre> | no |
| <a name="input_create_templates"></a> [create\_templates](#input\_create\_templates) | Create template files (bootstrap, handler, Makefile) in template\_dir | `bool` | `false` | no |
| <a name="input_delimiter"></a> [delimiter](#input\_delimiter) | Delimiter to be used between ID elements.<br/>Defaults to `-` (hyphen). Set to `""` to use no delimiter at all. | `string` | `null` | no |
| <a name="input_descriptor_formats"></a> [descriptor\_formats](#input\_descriptor\_formats) | Describe additional descriptors to be output in the `descriptors` output map.<br/>Map of maps. Keys are names of descriptors. Values are maps of the form<br/>`{<br/>   format = string<br/>   labels = list(string)<br/>}`<br/>(Type is `any` so the map values can later be enhanced to provide additional options.)<br/>`format` is a Terraform format string to be passed to the `format()` function.<br/>`labels` is a list of labels, in order, to pass to `format()` function.<br/>Label values will be normalized before being passed to `format()` so they will be<br/>identical to how they appear in `id`.<br/>Default is `{}` (`descriptors` output will be empty). | `any` | `{}` | no |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | Set to false to prevent the module from creating any resources | `bool` | `null` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | ID element. Usually used for region e.g. 'uw2', 'us-west-2', OR role 'prod', 'staging', 'dev', 'UAT' | `string` | `null` | no |
| <a name="input_environment_variables"></a> [environment\_variables](#input\_environment\_variables) | Map of environment variables for the Lambda function | `map(string)` | `{}` | no |
| <a name="input_filename"></a> [filename](#input\_filename) | Path to pre-built zip file (alternative to source\_dir) | `string` | `null` | no |
| <a name="input_handler"></a> [handler](#input\_handler) | Lambda function handler | `string` | `"bootstrap"` | no |
| <a name="input_id_length_limit"></a> [id\_length\_limit](#input\_id\_length\_limit) | Limit `id` to this many characters (minimum 6).<br/>Set to `0` for unlimited length.<br/>Set to `null` for keep the existing setting, which defaults to `0`.<br/>Does not affect `id_full`. | `number` | `null` | no |
| <a name="input_image_config"></a> [image\_config](#input\_image\_config) | Container image configuration | <pre>object({<br/>    entry_point = optional(list(string))<br/>    command     = optional(list(string))<br/>    working_directory = optional(string)<br/>  })</pre> | `null` | no |
| <a name="input_image_uri"></a> [image\_uri](#input\_image\_uri) | ECR image URI for container image deployment | `string` | `null` | no |
| <a name="input_label_key_case"></a> [label\_key\_case](#input\_label\_key\_case) | Controls the letter case of the `tags` keys (label names) for tags generated by this module.<br/>Does not affect keys of tags passed in via the `tags` input.<br/>Possible values: `lower`, `title`, `upper`.<br/>Default value: `title`. | `string` | `null` | no |
| <a name="input_label_order"></a> [label\_order](#input\_label\_order) | The order in which the labels (ID elements) appear in the `id`.<br/>Defaults to ["namespace", "environment", "stage", "name", "attributes"].<br/>You can omit any of the 6 labels ("tenant" is the 6th), but at least one must be present. | `list(string)` | `null` | no |
| <a name="input_label_value_case"></a> [label\_value\_case](#input\_label\_value\_case) | Controls the letter case of ID elements (labels) as included in `id`,<br/>set as tag values, and output by this module individually.<br/>Does not affect values of tags passed in via the `tags` input.<br/>Possible values: `lower`, `title`, `upper` and `none` (no transformation).<br/>Set this to `title` and set `delimiter` to `""` to yield Pascal Case IDs.<br/>Default value: `lower`. | `string` | `null` | no |
| <a name="input_labels_as_tags"></a> [labels\_as\_tags](#input\_labels\_as\_tags) | Set of labels (ID elements) to include as tags in the `tags` output.<br/>Default is to include all labels.<br/>Tags with empty values will not be included in the `tags` output.<br/>Set to `[]` to suppress all generated tags.<br/>**Notes:**<br/>  The value of the `name` tag, if included, will be the `id`, not the `name`.<br/>  Unlike other `null-label` inputs, the initial setting of `labels_as_tags` cannot be<br/>  changed in later chained modules. Attempts to change it will be silently ignored. | `set(string)` | <pre>[<br/>  "default"<br/>]</pre> | no |
| <a name="input_layers"></a> [layers](#input\_layers) | List of Lambda layer ARNs to attach to the function | `list(string)` | `[]` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | CloudWatch log retention in days | `number` | `14` | no |
| <a name="input_memory_size"></a> [memory\_size](#input\_memory\_size) | Amount of memory in MB your Lambda Function can use at runtime | `number` | `128` | no |
| <a name="input_name"></a> [name](#input\_name) | ID element. Usually the component or solution name, e.g. 'app' or 'jenkins'.<br/>This is the only ID element not also included as a `tag`.<br/>The "name" tag is set to the full `id` string. There is no tag with the value of the `name` input. | `string` | `null` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | ID element. Usually an abbreviation of your organization name, e.g. 'eg' or 'cp', to help ensure generated IDs are globally unique | `string` | `null` | no |
| <a name="input_package_type"></a> [package\_type](#input\_package\_type) | Lambda deployment package type | `string` | `"Zip"` | no |
| <a name="input_regex_replace_chars"></a> [regex\_replace\_chars](#input\_regex\_replace\_chars) | Terraform regular expression (regex) string.<br/>Characters matching the regex will be removed from the ID elements.<br/>If not set, `"/[^a-zA-Z0-9-]/"` is used to remove all characters other than hyphens, letters and digits. | `string` | `null` | no |
| <a name="input_runtime"></a> [runtime](#input\_runtime) | Lambda runtime | `string` | `"provided.al2023"` | no |
| <a name="input_source_dir"></a> [source\_dir](#input\_source\_dir) | Path to the source directory containing Lambda function code | `string` | `null` | no |
| <a name="input_stage"></a> [stage](#input\_stage) | ID element. Usually used to indicate role, e.g. 'prod', 'staging', 'source', 'build', 'test', 'deploy', 'release' | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags (e.g. `{'BusinessUnit': 'XYZ'}`).<br/>Neither the tag keys nor the tag values will be modified by this module. | `map(string)` | `{}` | no |
| <a name="input_template_dir"></a> [template\_dir](#input\_template\_dir) | Directory to create template files in | `string` | `"./src"` | no |
| <a name="input_tenant"></a> [tenant](#input\_tenant) | ID element \_(Rarely used, not included by default)\_. A customer identifier, indicating who this instance of a resource is for | `string` | `null` | no |
| <a name="input_timeout"></a> [timeout](#input\_timeout) | Amount of time your Lambda Function has to run in seconds | `number` | `3` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_execution_role_arn"></a> [execution\_role\_arn](#output\_execution\_role\_arn) | Lambda execution role ARN |
| <a name="output_execution_role_name"></a> [execution\_role\_name](#output\_execution\_role\_name) | Lambda execution role name |
| <a name="output_function_arn"></a> [function\_arn](#output\_function\_arn) | Lambda function ARN |
| <a name="output_function_invoke_arn"></a> [function\_invoke\_arn](#output\_function\_invoke\_arn) | Lambda function invoke ARN |
| <a name="output_function_last_modified"></a> [function\_last\_modified](#output\_function\_last\_modified) | Lambda function last modified date |
| <a name="output_function_name"></a> [function\_name](#output\_function\_name) | Lambda function name |
| <a name="output_function_qualified_arn"></a> [function\_qualified\_arn](#output\_function\_qualified\_arn) | Lambda function qualified ARN |
| <a name="output_function_source_code_hash"></a> [function\_source\_code\_hash](#output\_function\_source\_code\_hash) | Lambda function source code hash |
| <a name="output_function_source_code_size"></a> [function\_source\_code\_size](#output\_function\_source\_code\_size) | Lambda function source code size |
| <a name="output_function_version"></a> [function\_version](#output\_function\_version) | Lambda function version |
| <a name="output_log_group_arn"></a> [log\_group\_arn](#output\_log\_group\_arn) | CloudWatch log group ARN |
| <a name="output_log_group_name"></a> [log\_group\_name](#output\_log\_group\_name) | CloudWatch log group name |
| <a name="output_package_path"></a> [package\_path](#output\_package\_path) | Path to the Lambda deployment package |
| <a name="output_package_size"></a> [package\_size](#output\_package\_size) | Size of the Lambda deployment package |
| <a name="output_ssm_parameters"></a> [ssm\_parameters](#output\_ssm\_parameters) | SSM parameter names for Serverless integration |
| <a name="output_template_files"></a> [template\_files](#output\_template\_files) | Paths to created template files |
<!-- END_TF_DOCS -->

---

*Part of the [cloudless](https://github.com/ql4b/cloudless-api) ecosystem.*