locals {
  source_dir = var.source_dir
  use_prebuilt_zip = var.filename != null
}

# Template files for user reference - only created if they don't exist
resource "null_resource" "bootstrap_template" {
  count = var.create_templates ? 1 : 0
  
  triggers = {
    template_dir = var.template_dir
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      if [ ! -f "${var.template_dir}/bootstrap" ]; then
        mkdir -p "${var.template_dir}"
        cat > "${var.template_dir}/bootstrap" << 'EOF'
${file("${path.module}/src/bootstrap")}
EOF
        chmod 0755 "${var.template_dir}/bootstrap"
      fi
    EOT
  }
}

resource "null_resource" "handler_template" {
  count = var.create_templates ? 1 : 0
  
  triggers = {
    template_dir = var.template_dir
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      if [ ! -f "${var.template_dir}/handler.sh" ]; then
        mkdir -p "${var.template_dir}"
        cat > "${var.template_dir}/handler.sh" << 'EOF'
${file("${path.module}/src/handler.sh")}
EOF
        chmod 0755 "${var.template_dir}/handler.sh"
      fi
    EOT
  }
}

resource "null_resource" "makefile_template" {
  count = var.create_templates ? 1 : 0
  
  triggers = {
    template_dir = var.template_dir
    function_name = module.this.id
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      if [ ! -f "${var.template_dir}/Makefile" ]; then
        mkdir -p "${var.template_dir}"
        cat > "${var.template_dir}/Makefile" << 'EOF'
${templatefile("${path.module}/Makefile", { function_name = module.this.id })}
EOF
      fi
    EOT
  }
}

# Create zip package from source directory (only for Zip package type and when not using prebuilt)
data "archive_file" "lambda_zip" {
  count = var.package_type == "Zip" && !local.use_prebuilt_zip ? 1 : 0
  
  type        = "zip"
  source_dir  = local.source_dir
  output_path = "${path.module}/.terraform/tmp/${module.this.id}.zip"
}


# IAM role for Lambda execution
resource "aws_iam_role" "lambda_execution" {
  name = "${module.this.id}-execution"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  
  tags = module.this.tags
}

# Attach basic execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_execution.name
}

# CloudWatch log group
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${module.this.id}"
  retention_in_days = var.log_retention_days
  
  tags = module.this.tags
}

# Lambda function
resource "aws_lambda_function" "this" {
  function_name = module.this.id
  role         = aws_iam_role.lambda_execution.arn
  
  package_type = var.package_type
  
  # Zip package configuration
  filename         = var.package_type == "Zip" ? (local.use_prebuilt_zip ? var.filename : data.archive_file.lambda_zip[0].output_path) : null
  source_code_hash = var.package_type == "Zip" ? (local.use_prebuilt_zip ? null : data.archive_file.lambda_zip[0].output_base64sha256) : null
  handler          = var.package_type == "Zip" ? var.handler : null
  runtime          = var.package_type == "Zip" ? var.runtime : null
  
  # Container image configuration
  image_uri = var.package_type == "Image" ? var.image_uri : null
  
  dynamic "image_config" {
    for_each = var.package_type == "Image" && var.image_config != null ? [var.image_config] : []
    content {
      entry_point       = image_config.value.entry_point
      command          = image_config.value.command
      working_directory = image_config.value.working_directory
    }
  }
  
  architectures = [var.architecture]
  memory_size   = var.memory_size
  timeout       = var.timeout
  
  dynamic "environment" {
    for_each = length(var.environment_variables) > 0 ? [1] : []
    content {
      variables = var.environment_variables
    }
  }
  
  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_cloudwatch_log_group.lambda_logs,
  ]
  
  tags = module.this.tags
}

# SSM parameters for Serverless integration
resource "aws_ssm_parameter" "function_name" {
  name  = "/${module.this.id}/function_name"
  type  = "String"
  value = aws_lambda_function.this.function_name
  
  tags = module.this.tags
}

resource "aws_ssm_parameter" "function_arn" {
  name  = "/${module.this.id}/function_arn"
  type  = "String"
  value = aws_lambda_function.this.arn
  
  tags = module.this.tags
}

resource "aws_ssm_parameter" "invoke_arn" {
  name  = "/${module.this.id}/invoke_arn"
  type  = "String"
  value = aws_lambda_function.this.invoke_arn
  
  tags = module.this.tags
}