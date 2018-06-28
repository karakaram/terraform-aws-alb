output "lb_target_group_arn" {
  description = "A target group of alb"
  value       = ["${aws_lb_target_group.rails.arn}"]
}
