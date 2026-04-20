variable "test" {
  description = "Test variable"
  type        = string
  default     = "hello"
}

resource "null_resource" "test" {
  lifecycle {
    create_before_destroy = true
  }
}
