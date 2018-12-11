/*
 * Creates basic security groups to be used by instances and ELBs.
 */
variable "name" {
  description = "The name of the security groups serves as a prefix"
}

variable "vpc_id" {
  description = "The VPC ID"
}

variable "environment" {
  description = "The environment, used for tagging, e.g prod"
}

variable "cidr" {
  description = "The cidr block to use for private security groups"
}


/*
* Resources
*/
resource "aws_security_group" "private_elb" {
  name        = "${format("%s-%s-private-elb", var.name, var.environment)}"
  vpc_id      = "${var.vpc_id}"
  description = "Allows private ELB traffic"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${var.cidr}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags {
    Name        = "${format("%s-private-elb", var.name)}"
    Environment = "${var.environment}"
  }
}

resource "aws_security_group" "public_elb" {
  name        = "${format("%s-%s-public-elb", var.name, var.environment)}"
  vpc_id      = "${var.vpc_id}"
  description = "Allows public ELB traffic"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags {
    Name        = "${format("%s-public-elb", var.name)}"
    Environment = "${var.environment}"
  }
}

resource "aws_security_group" "public_ssh" {
  name        = "${format("%s-%s-public-ssh", var.name, var.environment)}"
  description = "Allows ssh from the world"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags {
    Name        = "${format("%s-public-ssh", var.name)}"
    Environment = "${var.environment}"
  }
}

resource "aws_security_group" "private_ssh" {
  name        = "${format("%s-%s-private-ssh", var.name, var.environment)}"
  description = "Allows ssh from bastion"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = ["${aws_security_group.public_ssh.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "tcp"
    cidr_blocks = ["${var.cidr}"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags {
    Name        = "${format("%s-private-ssh", var.name)}"
    Environment = "${var.environment}"
  }
}


/*
* Outputs
*/
// public SSH allows ssh connections on port 22 from the world.
output "public_ssh" {
  value = "${aws_security_group.public_ssh.id}"
}
// private SSH allows ssh connections from the public ssh security group.
output "private_ssh" {
  value = "${aws_security_group.private_ssh.id}"
}
// private ELB allows private traffic.
output "private_elb" {
  value = "${aws_security_group.private_elb.id}"
}
// public ELB allows traffic from the world.
output "public_elb" {
  value = "${aws_security_group.public_elb.id}"
}
