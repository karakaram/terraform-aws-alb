provider "aws" {
  region = "${var.region}"
}

terraform {
  backend "s3" {}
}

data "terraform_remote_state" "vpc" {
  backend = "s3"
  config  = "${var.vpc_state_config}"
}

data "aws_caller_identity" "current" {}

locals {
  log_bucket_name = "${var.log_bucket_name}-${data.aws_caller_identity.current.account_id}-${var.region}"
}

data "aws_elb_service_account" "main" {}

data "aws_iam_policy_document" "bucket_policy" {
  statement {
    sid       = "AllowToPutLoadBalancerLogsToS3Bucket"
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${local.log_bucket_name}/${var.log_location_prefix}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_elb_service_account.main.id}:root"]
    }
  }
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    sid = ""

    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    effect = "Allow"
  }
}

data "template_file" "user_data" {
  template = "${file("${path.module}/user_data.tpl")}"

  vars {
    lb_name     = "${var.lb_name}"
    environment = "${var.environment}"
  }
}

data "aws_ami" "amzn2_rails" {
  most_recent = true

  filter {
    name = "name"

    values = [
      "amzn2-rails-*",
    ]
  }

  owners = ["self"]
}

resource "aws_s3_bucket" "log_bucket" {
  bucket        = "${local.log_bucket_name}"
  policy        = "${data.aws_iam_policy_document.bucket_policy.json}"
  force_destroy = true

  lifecycle_rule {
    id      = "log-expiration"
    enabled = "true"

    expiration {
      days = "7"
    }
  }
}

resource "aws_security_group" "alb" {
  name        = "${var.lb_name}"
  description = "Security group for ${var.lb_name}"
  vpc_id      = "${data.terraform_remote_state.vpc.vpc_id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "application" {
  name               = "${var.lb_name}"
  load_balancer_type = "application"
  internal           = false
  security_groups    = ["${aws_security_group.alb.id}"]
  subnets            = ["${data.terraform_remote_state.vpc.public_subnets}"]
  ip_address_type    = "ipv4"

  tags = {
    Name        = "${var.lb_name}"
    Environment = "${var.environment}"
  }

  access_logs {
    enabled = true
    bucket  = "${local.log_bucket_name}"
    prefix  = "${var.log_location_prefix}"
  }
}

resource "aws_lb_target_group" "rails" {
  name_prefix          = "${var.lb_name}"
  port                 = "3000"
  protocol             = "HTTP"
  vpc_id               = "${data.terraform_remote_state.vpc.vpc_id}"
  deregistration_delay = 10

  health_check = [{
    interval            = 10
    path                = "/dashboard/index"
    port                = 3000
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = 200
  }]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = "${aws_lb.application.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_lb_target_group.rails.arn}"
    type             = "forward"
  }
}

resource "aws_security_group" "lc" {
  name        = "${var.lc_name}"
  description = "Security group for ${var.lb_name} Launch Configuration"
  vpc_id      = "${data.terraform_remote_state.vpc.vpc_id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${data.terraform_remote_state.vpc.public_subnets_cidr_blocks}"]
  }

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = ["${aws_security_group.alb.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "lc" {
  name               = "${var.lc_name}_role"
  assume_role_policy = "${data.aws_iam_policy_document.assume_role.json}"
}

resource "aws_iam_role_policy_attachment" "lc_s3" {
  role       = "${aws_iam_role.lc.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "lc_cloudwatch_agent" {
  role       = "${aws_iam_role.lc.name}"
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "lc" {
  name = "${var.lc_name}-profile"
  role = "${aws_iam_role.lc.name}"
}

resource "aws_ssm_parameter" "cloudwatch_agent" {
  name      = "AmazonCloudWatch-Agent-${var.lb_name}"
  type      = "String"
  value     = "${file("${path.module}/cloudwatch_agent.json")}"
  overwrite = true
}

module "autoscaling_group_blue" {
  source = "autoscaling_group"

  lc_name_prefix       = "${var.lc_name}-blue-"
  image_id             = "${data.aws_ami.amzn2_rails.image_id}"
  instance_type        = "${var.instance_type}"
  iam_instance_profile = "${aws_iam_instance_profile.lc.name}"
  key_name             = "${var.key_name}"
  security_groups      = ["${aws_security_group.lc.id}"]
  user_data            = "${data.template_file.user_data.rendered}"
  asg_name             = "${var.asg_name}-blue"
  desired_capacity     = "${var.blue_desired_capacity}"
  vpc_zone_identifier  = ["${data.terraform_remote_state.vpc.private_subnets}"]
  target_group_arns    = ["${aws_lb_target_group.rails.arn}"]
  environment          = "${var.environment}"
}

module "autoscaling_group_green" {
  source = "autoscaling_group"

  lc_name_prefix       = "${var.lc_name}-green-"
  image_id             = "${data.aws_ami.amzn2_rails.image_id}"
  instance_type        = "${var.instance_type}"
  iam_instance_profile = "${aws_iam_instance_profile.lc.name}"
  key_name             = "${var.key_name}"
  security_groups      = ["${aws_security_group.lc.id}"]
  user_data            = "${data.template_file.user_data.rendered}"
  asg_name             = "${var.asg_name}-green"
  desired_capacity     = "${var.green_desired_capacity}"
  vpc_zone_identifier  = ["${data.terraform_remote_state.vpc.private_subnets}"]
  target_group_arns    = ["${aws_lb_target_group.rails.arn}"]
  environment          = "${var.environment}"
}
