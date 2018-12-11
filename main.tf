# Specify the provider and access details
provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "${var.region}"
}

resource "aws_key_pair" "auth" {
  public_key = "${file(var.public_key_path)}"
}

# create VPC
module "vpc" {
  source             = "./vpc"
  name               = "${var.project_name}"
  availability_zones = "${split(",", lookup(var.azs, var.region))}"
  cidr_block         = "${var.vpc_cidr_block}"
  nat_gw_cidr        = "${lookup(var.subnet_cidr, "web-subnet")}"
  private_cidrs      = "${local.private_cidrs}"
  public_cidrs       = "${local.public_cidrs}"
  spare_cidrs        = "${local.spare_cidrs}"
  private_names      = "${local.private_names}"
  public_names       = "${local.public_names}"
  spare_names        = "${local.spare_names}"
  environment        = "${var.environment}"
}

# create default security groups
module "security_groups" {
  source      = "./security-groups"
  name        = "${var.project_name}"
  vpc_id      = "${module.vpc.id}"  // ${module.vpc.id}" is an output of vpc module
  environment = "${var.environment}"
  cidr        = "${var.vpc_cidr_block}"
}


# retrieve web subnet subnet.id by cidr_block
data "aws_subnet" "web-net" {
  vpc_id = "${module.vpc.id}"
  cidr_block = "${lookup(var.subnet_cidr, "web-subnet")}"

  depends_on = ["module.vpc"]
}

# retrieve bastion subnet subnet.id by cidr_block
data "aws_subnet" "bastion-net" {
  vpc_id = "${module.vpc.id}"
  cidr_block = "${lookup(var.subnet_cidr, "bastion-subnet")}"

  depends_on = ["module.vpc"]
}

# retrieve as subnet.id by cidr_block
data "aws_subnet" "as-net" {
  vpc_id = "${module.vpc.id}"
  cidr_block = "${lookup(var.subnet_cidr, "as-subnet")}"

  depends_on = ["module.vpc"]
}

# retrieve db subnet.id by cidr_block
data "aws_subnet" "db-net" {
  vpc_id = "${module.vpc.id}"
  cidr_block = "${lookup(var.subnet_cidr, "db-subnet")}"

  depends_on = ["module.vpc"]
}


# create a bastion host for accessing the infrastructure
/**
 * The bastion host acts as the "jump point" for the rest of the infrastructure.
 * Since most of our instances aren't exposed to the external internet, the bastion acts as the gatekeeper
 * for any direct SSH access.
 */
module "ec2-bastion" {
  source          = "./ec2"
  name            = "bastion"
  region          = "${var.region}"
  ami_id          = "${lookup(var.ubuntu_amis, var.region)}"
  instance_type   = "${var.ec2_type}"
  eip             = true // true is converted in 1 and false in 0
  security_groups = "${module.security_groups.public_ssh},${module.security_groups.private_ssh}"
  vpc_id          = "${module.vpc.id}"
  subnet_id       = "${data.aws_subnet.bastion-net.id}"
  key_name        = "${aws_key_pair.auth.id}"
  environment     = "${var.environment}"
}

# create 2 web servers
module "ec2-webserver" {
  source          = "./ec2"
  name            = "web"
  region          = "${var.region}"
  ami_id          = "${lookup(var.ubuntu_amis, var.region)}"
  instance_type   = "${var.ec2_type}"
  eip             = true // true is converted in 1 and false in 0
  security_groups = "${module.security_groups.public_ssh},${module.security_groups.private_ssh}" ################# creare security group
  vpc_id          = "${module.vpc.id}"
  subnet_id       = "${data.aws_subnet.web-net.id}"
  key_name        = "${aws_key_pair.auth.id}"
  environment     = "${var.environment}"
  instances       = 2
}

# create 2 application servers
module "ec2-asserver" {
  source          = "./ec2"
  name            = "as"
  region          = "${var.region}"
  ami_id          = "${lookup(var.ubuntu_amis, var.region)}"
  instance_type   = "${var.ec2_type}"
  eip             = false // true is converted in 1 and false in 0
  security_groups = "${module.security_groups.private_ssh}" ################# creare security group
  vpc_id          = "${module.vpc.id}"
  subnet_id       = "${data.aws_subnet.as-net.id}"
  key_name        = "${aws_key_pair.auth.id}"
  environment     = "${var.environment}"
  instances       = 2
}

# create 2 db servers
module "ec2-dbserver" {
  source          = "./ec2"
  name            = "db"
  region          = "${var.region}"
  ami_id          = "${lookup(var.ubuntu_amis, var.region)}"
  instance_type   = "${var.ec2_type}"
  eip             = false // true is converted in 1 and false in 0
  security_groups = "${module.security_groups.private_ssh}" ################# creare security group
  vpc_id          = "${module.vpc.id}"
  subnet_id       = "${data.aws_subnet.db-net.id}"
  key_name        = "${aws_key_pair.auth.id}"
  environment     = "${var.environment}"
  instances       = 2
}


/*
module "elb" {
  source = "./elb"
  name            = "web-elb"
  port            = "[80, 443]"
  environment     = "${var.environment}"
  subnet_ids      = "${data.aws_subnet.web-net.id}"
  security_groups = "${var.security_groups}"
  dns_name        = "${coalesce(var.dns_name, module.task.name)}"
  healthcheck     = "${var.healthcheck}"
  protocol        = "${var.protocol}"
  zone_id         = "${var.zone_id}"
  log_bucket      = "${var.log_bucket}"
}
*/
