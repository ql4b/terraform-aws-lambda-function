variable "source_dir" {
  type        = string
  description = "Path to the source directory containing Lambda function code"
  default     = null
}

variable "handler" {
  type        = string
  description = "Lambda function handler"
  default     = "bootstrap"
}

variable "runtime" {
  type        = string
  description = "Lambda runtime"
  default     = "provided.al2023"
}

variable "architecture" {
  type        = string
  description = "Lambda function architecture"
  default     = "arm64"
  
  validation {
    condition     = contains(["x86_64", "arm64"], var.architecture)
    error_message = "Architecture must be either x86_64 or arm64."
  }
}

variable "memory_size" {
  type        = number
  description = "Amount of memory in MB your Lambda Function can use at runtime"
  default     = 128
  
  validation {
    condition     = var.memory_size >= 128 && var.memory_size <= 10240
    error_message = "Memory size must be between 128 MB and 10,240 MB."
  }
}

variable "timeout" {
  type        = number
  description = "Amount of time your Lambda Function has to run in seconds"
  default     = 3
  
  validation {
    condition     = var.timeout >= 1 && var.timeout <= 900
    error_message = "Timeout must be between 1 and 900 seconds."
  }
}

variable "environment_variables" {
  type        = map(string)
  description = "Map of environment variables for the Lambda function"
  default     = {}
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch log retention in days"
  default     = 14
  
  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch retention period."
  }
}

variable "create_templates" {
  type        = bool
  description = "Create template files (bootstrap, handler, Makefile) in template_dir"
  default     = false
}

variable "template_dir" {
  type        = string
  description = "Directory to create template files in"
  default     = "./src"
}

variable "package_type" {
  type        = string
  description = "Lambda deployment package type"
  default     = "Zip"
  
  validation {
    condition     = contains(["Zip", "Image"], var.package_type)
    error_message = "Package type must be either Zip or Image."
  }
}

variable "image_uri" {
  type        = string
  description = "ECR image URI for container image deployment"
  default     = null
}

variable "image_config" {
  type = object({
    entry_point = optional(list(string))
    command     = optional(list(string))
    working_directory = optional(string)
  })
  description = "Container image configuration"
  default     = null
}

variable "filename" {
  type        = string
  description = "Path to pre-built zip file (alternative to source_dir)"
  default     = null
}