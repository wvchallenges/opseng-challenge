variable "ami" {}

variable "project" {}
variable "env" {}
variable "key_name" {}


provider "aws" {
  region = "us-east-1"
}


resource "aws_vpc" "main" {
 cidr_block = "10.0.0.0/16"
}

/*
resource "aws_lb_target_group" "target_group" {
  name     = "${var.project}-${var.env}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.main.id}"
}
*/

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
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    prefix_list_ids = ["pl-12c4e678"]
  }
}

resource "aws_instance" "web" {
  ami           = "${var.ami}"
  instance_type = "t2.micro"
  key_name = "dthornton"
  security_groups = ["allow_all"]

  tags {
    Name = "${var.project}-${var.env}"
  }
}

/*
resource "aws_placement_group" "placementgroup" {
  name     = "${var.project}-${var.env}-pg"
  strategy = "cluster"
}
*/

/*
resource "aws_launch_configuration" "launchconfig" {
  name          = "${var.project}-${var.env}-launch-config"
  image_id      = "${var.ami}"
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


