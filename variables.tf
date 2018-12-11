/*
 *	AWS connection variables
 */
# Ensure this keypair is added to your local SSH agent so provisioners can connect
variable "public_key_path" {
  default = "./id_rsa.pub"
}

variable "private_key_path" {
  default = "./id_rsa"
}

variable "aws_access_key" {
}

variable "aws_secret_key" {
}


/*
 *      AWS region variables
 */
# default region
variable "region" {
  description = "AWS region to launch servers"
  default     = "us-west-2"
}

# availabilty zones in selected region
variable "azs" {
  description = "AWS Availability Zones"
  default = {
        "us-west-1" = "us-west-1b,us-west-1c"
        "us-west-2" = "us-west-2a,us-west-2b"
        "us-east-1" = "us-east-1c,us-west-1d"
  }
}

/*
 *      AWS EC2 variables
 */
# AMI Ubuntu Precise 16.04 LTS (x64) - free tier eligible
variable "ubuntu_amis" {
  default = {
    us-east-1 = "ami-cd0f5cb6"
    us-west-1 = "ami-09d2fb69"
    us-west-2 = "ami-6e1a0117"
  }
}

# EC2 instance type
variable "ec2_type" {
  description = "AWS EC2 instance type."
  default = "t2.micro"
}


variable "environment" {
  default = "dev"
}

variable "project_name" {
  default = "tfmod"
}

/*
 *      VPC and Subnets
 */
variable "vpc_cidr_block" {
  description = "CIDR block for the whole VPC"
  default = "192.168.0.0/16"
}

variable "subnet_cidr" {
  description = "subnets CIDR map"
  default = {
    "bastion-subnet" = "192.168.0.0/28"
    "web-subnet" = "192.168.1.0/27"
    "as-subnet" = "192.168.2.0/24"
    "db-subnet" = "192.168.3.0/27"
    "spare-subnet" = "192.168.5.0/27"
  }
}

locals {
	"public_cidrs"  = ["${lookup(var.subnet_cidr, "web-subnet")}", "${lookup(var.subnet_cidr, "bastion-subnet")}"]
  "private_cidrs" = ["${lookup(var.subnet_cidr, "as-subnet")}", "${lookup(var.subnet_cidr, "db-subnet")}"]
  "spare_cidrs" = ["${lookup(var.subnet_cidr, "spare-subnet")}"]
  "spare_names" = ["spare-subnet"]
  "public_names"  = ["web-subnet", "bastion-subnet"]
  "private_names" = ["as-subnet", "db-subnet", "as-subnet"]
}
