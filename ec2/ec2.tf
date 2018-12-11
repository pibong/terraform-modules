/*
* Input variables
*/
 variable "name" {
   description = "Name of instance used also in Name tags"
 }

variable "ami_id" {
  description = "AMI id"
}

variable "region" {
  description = "AWS Region, e.g us-west-2"
}

variable "eip" {
  default     = false
  description = "Associate EIP to ecs instance"
}

variable "instance_type" {
  default     = "t2.micro"
  description = "Instance type"
}

variable "security_groups" {
  description = "a comma separated lists of security group IDs"
}

variable "vpc_id" {
  description = "VPC ID"
}

variable "subnet_id" {
  description = "Subnet ID"
}

variable "key_name" {
  description = "The ID of our SSH keypair"
}

variable "environment" {
  description = "Environment tag, e.g prod"
}

variable "instances" {
  default = 1
  description = "Number of ec2 instances to create"
}

/*
* Resources
*/
### EC2 ###
resource "aws_instance" "ec2" {
  ami                    = "${var.ami_id}"
  instance_type          = "${var.instance_type}"
  subnet_id              = "${var.subnet_id}"
  key_name               = "${var.key_name}"
  vpc_security_group_ids = ["${split(",",var.security_groups)}"]
  monitoring             = false

  count = "${var.instances}"

  tags {
    Name        = "${var.name}-${var.environment}-${count.index}"
    Environment = "${var.environment}"
  }
}

### EIP ###
# created only if var.eip = true
resource "aws_eip" "eip" {
  /* var.eip could be 1 (true) or 0 (false):
  if var.ip == 0 then no_eip
  if var.ip == 1 then create_eip_foreach_ec2
  */
  count = "${var.eip * var.instances}"
  instance = "${element(aws_instance.ec2.*.id, count.index)}"
  vpc      = true

  tags {
    Name = "${var.name}-eip-${element(aws_instance.ec2.*.tags.Name, count.index)}"
    Environment = "${var.environment}"
  }
}

/**
 * Outputs
 */
output "external_ip" {
  value = "${aws_eip.eip.public_ip}"
}
