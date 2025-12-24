data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["amazon"]
}

resource "aws_instance" "dev_instance" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  key_name = "terraform_key"

  tags = {
    Name        = "BYOD-${var.environment}"
    Environment = var.environment
  }
}
