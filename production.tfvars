region = "ap-northeast-1"

vpc_state_config = {
  bucket = "karakaram-tfstate"
  key    = "env:/production/my-vpc.tfstate"
  region = "ap-northeast-1"
}

log_bucket_name = "my-alb-logs"

log_location_prefix = "log"

lb_name = "my-alb"

lc_name = "my-alb-lc"

asg_name = "my-alb-asg"

instance_type = "t2.micro"

key_name = "my-key"

environment = "production"
