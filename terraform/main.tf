variable "project" {}
variable "env" {}
variable "key_name" {}
variable "vpc_cidr" {}
variable "cidrs" {}
variable "azs" {}

provider "aws" {
  region = "us-east-1"
}

data "aws_ami" "appimage" {
  most_recent = true
  owners = ["505545132866"]
  filter {  
    name   = "name"
    values = ["opseng-challenge-app*"]
  }
}

resource "aws_vpc" "main" {
  cidr_block = "${var.vpc_cidr}"

  lifecycle {
    create_before_destroy = true
  }

  tags {
    Name = "${var.project}-${var.env}-vpc"
  }
}

resource "aws_security_group" "allow_all" {
  name        = "allow_all"
  description = "Allow all inbound traffic"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.main.id}"
}

resource "aws_subnet" "public" {
  vpc_id            = "${aws_vpc.main.id}"
  cidr_block        = "${element(split(",", var.cidrs), count.index)}"
  availability_zone = "${element(split(",", var.azs), count.index)}"
  count             = "${length(split(",", var.cidrs))}"

  tags {
    Name = "public_subnet"
  }

  lifecycle {
    create_before_destroy = true
  }

  map_public_ip_on_launch = true

  tags {
    Name = "${var.project}-${var.env}-subnet"
  }
}

resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw.id}"
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = ["route"]
  }

  tags {
    Name = "${var.project}-${var.env}-${element(split(",", var.azs), count.index)}"
  }
}

resource "aws_route_table_association" "public_assoc" {
  count          = "${length(split(",", var.cidrs))}"
  subnet_id      = "${element(aws_subnet.public.*.id, count.index)}"
  route_table_id = "${aws_route_table.public.id}"
}

resource "aws_instance" "web" {
  count             = 1
  ami               = "${data.aws_ami.appimage.id}"
  instance_type     = "t2.micro"
  key_name          = "dthornton"
  availability_zone = "us-east-1a"
  security_groups   = ["${aws_security_group.allow_all.id}"]
  subnet_id         = "${element(aws_subnet.public.*.id, count.index)}"

  lifecycle {
    create_before_destroy = true
  }

  tags {
    Name = "${var.project}-${var.env}-${count.index}"
  }

}

/*
resource "aws_lb_target_group" "target_group" {
  name     = "${var.project}-${var.env}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.main.id}"
}
*/

/*
resource "aws_placement_group" "placementgroup" {
  name     = "${var.project}-${var.env}-pg"
  strategy = "cluster"
}
*/

/*
resource "aws_launch_configuration" "launchconfig" {
  name          = "${var.project}-${var.env}-launch-config"
  image_id      = "${data.aws_ami.appimage.id}"
  instance_type = "t2.micro"
  key_name = "dthornton"
}
*/

/*
resource "aws_autoscaling_group" "asg" {
  availability_zones        = ["us-east-1a","us-east-1b"]
  name                      = "${var.project}-${var.env}"
  max_size                  = 5
  min_size                  = 2
  health_check_grace_period = 300
  health_check_type         = "ELB"
  desired_capacity          = 4
  force_delete              = true
  placement_group           = "${aws_placement_group.placementgroup.id}"
  launch_configuration      = "${aws_launch_configuration.launchconfig.name}"
}
*/

output "url" {
  value = "http://${aws_instance.web.public_ip}:8000"
}
