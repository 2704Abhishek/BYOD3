resource "aws_instance" "dev_instance" {
  ami           = "ami-0a4408457f9a03be3" # Amazon Linux 2 (example)
  instance_type = var.instance_type

  tags = {
    Name        = "BYOD-${var.environment}"
    Environment = var.environment
  }
}
