locals {
  source_dir = var.source_dir
}

# Create zip package from source directory
data "archive_file" "lambda_zip" {
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
  
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  
  handler        = var.handler
  runtime        = var.runtime
  architectures  = [var.architecture]
  memory_size    = var.memory_size
  timeout        = var.timeout
  
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