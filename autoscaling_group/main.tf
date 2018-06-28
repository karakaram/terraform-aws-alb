resource "aws_launch_configuration" "configuration" {
  name_prefix          = "${var.lc_name_prefix}"
  image_id             = "${var.image_id}"
  instance_type        = "${var.instance_type}"
  iam_instance_profile = "${var.iam_instance_profile}"
  key_name             = "${var.key_name}"
  security_groups      = ["${var.security_groups}"]
  user_data            = "${var.user_data}"
  enable_monitoring    = true

  root_block_device = {
    volume_type = "gp2"
    volume_size = "20"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "group" {
  name                      = "${var.asg_name}"
  max_size                  = "4"
  min_size                  = "0"
  health_check_grace_period = 300
  health_check_type         = "ELB"
  launch_configuration      = "${aws_launch_configuration.configuration.name}"
  desired_capacity          = "${var.desired_capacity}"
  vpc_zone_identifier       = ["${var.vpc_zone_identifier}"]
  target_group_arns         = ["${var.target_group_arns}"]

  tag {
    key                 = "Name"
    value               = "${var.asg_name}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = "${var.environment}"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_policy" "policy" {
  name        = "${var.asg_name}-scaling-policy"
  policy_type = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 50
  }

  autoscaling_group_name    = "${aws_autoscaling_group.group.name}"
  estimated_instance_warmup = 30
}
