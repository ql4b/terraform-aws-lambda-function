# Lambda function outputs
output "function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.this.function_name
}

output "function_arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.this.arn
}

output "function_invoke_arn" {
  description = "Lambda function invoke ARN"
  value       = aws_lambda_function.this.invoke_arn
}

output "function_qualified_arn" {
  description = "Lambda function qualified ARN"
  value       = aws_lambda_function.this.qualified_arn
}

output "function_version" {
  description = "Lambda function version"
  value       = aws_lambda_function.this.version
}

output "function_last_modified" {
  description = "Lambda function last modified date"
  value       = aws_lambda_function.this.last_modified
}

output "function_source_code_hash" {
  description = "Lambda function source code hash"
  value       = aws_lambda_function.this.source_code_hash
}

output "function_source_code_size" {
  description = "Lambda function source code size"
  value       = aws_lambda_function.this.source_code_size
}

# IAM role outputs
output "execution_role_arn" {
  description = "Lambda execution role ARN"
  value       = aws_iam_role.lambda_execution.arn
}

output "execution_role_name" {
  description = "Lambda execution role name"
  value       = aws_iam_role.lambda_execution.name
}

# CloudWatch log group outputs
output "log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}

output "log_group_arn" {
  description = "CloudWatch log group ARN"
  value       = aws_cloudwatch_log_group.lambda_logs.arn
}

# Package outputs
output "package_path" {
  description = "Path to the Lambda deployment package"
  value       = data.archive_file.lambda_zip.output_path
}

output "package_size" {
  description = "Size of the Lambda deployment package"
  value       = data.archive_file.lambda_zip.output_size
}

# Template outputs
output "template_files" {
  description = "Paths to created template files"
  value = var.create_templates ? {
    bootstrap = "${var.template_dir}/bootstrap"
    handler   = "${var.template_dir}/handler.sh"
    makefile  = "${var.template_dir}/Makefile"
  } : {}
}