variable "lc_name_prefix" {
  description = "Creates a unique name for launch configuration beginning with the specified prefix"
  default     = ""
}

variable "image_id" {
  description = ""
  default     = ""
}

variable "instance_type" {
  description = "The type of instance to start"
}

variable "iam_instance_profile" {
  description = ""
  default     = ""
}

variable "key_name" {
  description = "The key name to use for the instance"
  default     = ""
}

variable "security_groups" {
  description = ""
  type        = "list"
  default     = []
}

variable "user_data" {
  description = ""
  default     = ""
}

variable "asg_name" {
  description = "Creates a unique name for autoscaling group beginning with the specified prefix"
  default     = ""
}

variable "desired_capacity" {
  description = "Number of instances to launch for autoscaling group"
  default     = 0
}

variable "vpc_zone_identifier" {
  description = ""
  type        = "list"
  default     = []
}

variable "target_group_arns" {
  description = ""
  type        = "list"
  default     = []
}

variable "environment" {
  description = "The environment to use for the instance"
  default     = ""
}
