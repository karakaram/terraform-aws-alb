variable "region" {
  description = "A region for the VPC"
}

variable "vpc_state_config" {
  description = "A config for accessing the vpc state file"
  type        = "map"
}

variable "log_bucket_name" {
  default = "my-alb-logs"
}

variable "log_location_prefix" {
  default = "logs"
}

variable "lb_name" {
  description = "The resource name and Name tag of the load balancer."
}

variable "lc_name" {
  description = "Creates a unique name for launch configuration beginning with the specified prefix"
  default     = ""
}

variable "asg_name" {
  description = "Creates a unique name for autoscaling group beginning with the specified prefix"
  default     = ""
}

variable "blue_desired_capacity" {
  description = "Number of instances to launch for blue autoscaling group"
  default     = 0
}

variable "green_desired_capacity" {
  description = "Number of instances to launch for green autoscaling group"
  default     = 0
}

variable "instance_type" {
  description = "The type of instance to start"
}

variable "key_name" {
  description = "The key name to use for the instance"
  default     = ""
}

variable "environment" {
  description = "The environment to use for the instance"
  default     = ""
}
