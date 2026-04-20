terraform {
  required_version = ">= 1.0"
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

variable "test" {
  description = "Test variable"
  type        = string
  default     = "hello"
}

resource "null_resource" "test" {
  triggers = {
    value = var.test
  }

  lifecycle {
    create_before_destroy = true
  }
}
