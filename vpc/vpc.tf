/*
* Input variables
*/
variable "name" {
  description = "VPC project name"
}

variable "cidr_block" {
  description = "CIDR block for the whole VPC"
}

variable "nat_gw_cidr" {
  description = "Cidr of NAT gateway subnet"
}

variable "private_cidrs" {
  description = "List of private subnet cidrs"
  type = "list"
}

variable "private_names" {
  description = "List of private subnet names (same order of private_cidrs)"
  type = "list"
}

variable "public_cidrs" {
  description = "List of public subnet cidrs"
  type = "list"
}

variable "public_names" {
  description = "List of public subnet names (same order of public_cidrs)"
  type = "list"
}

variable "spare_cidrs" {
  description = "List of spare subnet cidrs"
  type = "list"
}

variable "spare_names" {
  description = "List of sapre subnet names (same order of spare_cidrs)"
  type = "list"
}

variable "environment" {
  description = "Environment tag, e.g prod"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = "list"
}


/*
* Resources
*/

### VPC ###
resource "aws_vpc" "main" {
  cidr_block = "${var.cidr_block}"

  tags {
    Name = "${var.name}-vpc"
    Environment = "${var.environment}"
  }
}

# Create an internet gateway to give our public subnets access to the outside world
resource "aws_internet_gateway" "igw-vpc" {
  vpc_id = "${aws_vpc.main.id}"

  tags {
    Name = "${var.name}-igw"
    Environment = "${var.environment}"
  }
}

# create an Elastic IP for creating a NAT gateway
resource "aws_eip" "eip-nat-gw" {
  vpc = true

  tags {
    Name = "${var.name}-eip-nat-gw"
    Environment = "${var.environment}"
  }
}

# retrieve NAT gateway subnet by cidr_block
data "aws_subnet" "nat_subnet" {
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "${var.nat_gw_cidr}"

  depends_on = ["aws_subnet.public"]
}

# create a NAT gateway to permit egress traffic for private subnets
resource "aws_nat_gateway" "nat-gw" {
  subnet_id     = "${data.aws_subnet.nat_subnet.id}"
  allocation_id = "${aws_eip.eip-nat-gw.id}"

  # NAT Gateway depends on the Internet Gateway for the VPC in which the NAT Gateway's subnet is located
  depends_on = ["aws_internet_gateway.igw-vpc"]

  tags {
    Name = "${var.name}-nat-gw"
    Environment = "${var.environment}"
  }
}

### SUBNETS ###
# Create public subnet
resource "aws_subnet" "public" {
  vpc_id                  = "${aws_vpc.main.id}"
  map_public_ip_on_launch = true
  availability_zone       = "${element(var.availability_zones, 0)}"
  count                   = "${length(var.public_cidrs)}"
  cidr_block              = "${element(var.public_cidrs, count.index)}"

  tags {
    Name = "${var.name}-${element(var.public_names, count.index)}-pub"
    Environment = "${var.environment}"
  }
}

# Create private subnets
resource "aws_subnet" "private" {
  vpc_id                  = "${aws_vpc.main.id}"
  map_public_ip_on_launch = false
  availability_zone       = "${element(var.availability_zones, 0)}"
  count                   = "${length(var.private_cidrs)}"
  cidr_block              = "${element(var.private_cidrs, count.index)}"

  tags {
    Name = "${var.name}-${element(var.private_names, count.index)}-priv"
    Environment = "${var.environment}"
  }
}

# Create spare subnets
resource "aws_subnet" "spare" {
  vpc_id                  = "${aws_vpc.main.id}"
  map_public_ip_on_launch = false
  availability_zone       = "${element(var.availability_zones, 1)}"
  count                   = "${length(var.spare_cidrs)}"
  cidr_block              = "${element(var.spare_cidrs, count.index)}"

  tags {
    Name = "${var.name}-${element(var.spare_names, count.index)}"
    Environment = "${var.environment}"
  }
}


### ROUTING TABLE ###
# public subnets will use VPC internet gateway to go to outside world
resource "aws_route_table" "public" {
    vpc_id = "${aws_vpc.main.id}"

    route {
      cidr_block = "0.0.0.0/0"
      # internet gateway
      gateway_id = "${aws_internet_gateway.igw-vpc.id}"
    }

    tags {
      Name = "${var.name}-internet-rt-public-subnet"
      Environment = "${var.environment}"
    }
}

resource "aws_route_table_association" "internet-public" {
    count = "${length(var.public_cidrs)}"
    subnet_id = "${element(aws_subnet.public.*.id, count.index)}"
    route_table_id = "${aws_route_table.public.id}"
}

# private subnets will use NAT gateway to go over internet
resource "aws_route_table" "private" {
    vpc_id = "${aws_vpc.main.id}"

    route {
      cidr_block = "0.0.0.0/0"
	    # NAT gateway
      gateway_id = "${aws_nat_gateway.nat-gw.id}"
    }

    tags {
      Name = "${var.name}-internet-rt-private-subnet"
      Environment = "${var.environment}"
    }
}

resource "aws_route_table_association" "internet-private" {
    count = "${length(var.private_cidrs)}"
    subnet_id = "${element(aws_subnet.private.*.id, count.index)}"
    route_table_id = "${aws_route_table.private.id}"
}


/*
 * Outputs
 */
output "id" {
  value = "${aws_vpc.main.id}"
}
output "cidr_block" {
  value = "${aws_vpc.main.cidr_block}"
}
output "external_subnets" {
  value = ["${aws_subnet.public.*.id}"]
}
output "internal_subnets" {
  value = ["${aws_subnet.private.*.id}"]
}
output "spare_subnets" {
  value = ["${aws_subnet.spare.*.id}"]
}
// The default VPC security group ID.
output "security_group" {
  value = "${aws_vpc.main.default_security_group_id}"
}
// The list of availability zones of the VPC.
output "availability_zones" {
  value = ["${aws_subnet.public.*.availability_zone}"]
}
// The internal route table ID.
output "internal_rtb_id" {
  value = "${join(",", aws_route_table.private.*.id)}"
}
// The external route table ID.
output "external_rtb_id" {
  value = "${aws_route_table.public.id}"
}
// The list of EIPs associated with the internal subnets.
output "internal_nat_ips" {
  value = ["${aws_eip.eip-nat-gw.*.public_ip}"]
}
