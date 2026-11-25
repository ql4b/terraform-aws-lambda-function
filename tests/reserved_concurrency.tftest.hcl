# Unit tests for reserved_concurrent_executions. No AWS access: the aws provider
# is mocked and every run is a plan.
#
#   terraform init -backend=false && terraform test

mock_provider "aws" {}

variables {
  namespace  = "test"
  name       = "fn"
  source_dir = "./tests/fixture"
}

run "unset_is_accepted_and_unreserved" {
  command = plan

  assert {
    condition     = var.reserved_concurrent_executions == null
    error_message = "reserved_concurrent_executions must default to null (unreserved)."
  }
}

run "value_is_passed_to_the_function" {
  command = plan

  variables {
    reserved_concurrent_executions = 7
  }

  assert {
    condition     = aws_lambda_function.this.reserved_concurrent_executions == 7
    error_message = "The configured reserved concurrency must reach aws_lambda_function.this."
  }
}

run "minus_one_means_unreserved_and_is_accepted" {
  command = plan

  variables {
    reserved_concurrent_executions = -1
  }

  assert {
    condition     = aws_lambda_function.this.reserved_concurrent_executions == -1
    error_message = "-1 must be passed through (unreserved)."
  }
}

run "zero_is_accepted_and_passed_through" {
  command = plan

  variables {
    reserved_concurrent_executions = 0
  }

  assert {
    condition     = aws_lambda_function.this.reserved_concurrent_executions == 0
    error_message = "0 is valid (it throttles every invocation) and must be passed through."
  }
}

run "below_minus_one_is_rejected" {
  command = plan

  variables {
    reserved_concurrent_executions = -2
  }

  expect_failures = [var.reserved_concurrent_executions]
}
