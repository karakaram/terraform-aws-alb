#!/usr/bin/env bash

set -e

ENVIRONMENT=${1:-production}
BLUE_ASG_NAME="my-alb-asg-blue"
GREEN_ASG_NAME="my-alb-asg-green"
DEFAULT_DESIRED_CAPACITY=1

function get_instance {
  instance_type=$1
  aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=${ENVIRONMENT}-hrp2-ghq-${instance_type}" \
            "Name=instance-state-name,Values=running" \
  --region ${AWS_REGION} | \
  jq -r .Reservations[].Instances[].InstanceId
}

function set_tags {
  resources=$1
  tags=$2
  aws ec2 create-tags \
  --resources $1 \
  --tags $2 \
  --region ${AWS_REGION}
}

# get auto scaling group desired_capacity
function desired_capacity {
  asg_name=$1
  dc=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names ${asg_name} \
  --region ${AWS_REGION} | jq -r .AutoScalingGroups[0].DesiredCapacity)
  [ ${dc} = "null" ] && echo 0 || echo ${dc}
}

# get target group state list
function get_lb_target_group_state_list {
  target_group_arn=$1
  aws elbv2 describe-target-health \
  --target-group-arn ${target_group_arn} \
  --region ${AWS_REGION} | jq -r .TargetHealthDescriptions[].TargetHealth.State
}

function set_asg_action_schedule {
  target_asg_name=$1
  action_name=$2
  recurrence=$3
  skd_desired_capacity=$4
  aws autoscaling put-scheduled-update-group-action \
    --auto-scaling-group-name $target_asg_name \
    --scheduled-action-name $action_name \
    --recurrence "$recurrence" \
    --desired-capacity $skd_desired_capacity \
    --region ${AWS_REGION}
}

# primary_asg
blue_desired_capacity=$(desired_capacity ${BLUE_ASG_NAME})
green_desired_capacity=$(desired_capacity ${GREEN_ASG_NAME})
if [ ${blue_desired_capacity} -ne 0 ]; then
  primary_asg_name=${BLUE_ASG_NAME}
  desired_capacity=${blue_desired_capacity}
  next_color="green"
elif [ ${green_desired_capacity} -ne 0 ]; then
  primary_asg_name=${GREEN_ASG_NAME}
  desired_capacity=${green_desired_capacity}
  next_color="blue"
else
  primary_asg_name=${GREEN_ASG_NAME}
  desired_capacity=${DEFAULT_DESIRED_CAPACITY}
  next_color="blue"
fi

echo "primary_asg_name=${primary_asg_name} desired_capacity=${desired_capacity}"

# terraform apply
make apply env=${ENVIRONMENT} \
blue_desired_capacity=${desired_capacity} \
green_desired_capacity=${desired_capacity}
if [ $? -ne 0 ]; then
  exit 1
fi

lb_target_group_arn=$(terraform output lb_target_group_arn)
if [ "${lb_target_group_arn}" == "" ]; then
  exit 1
fi

loop=true
while ${loop}; do
  target_group_state_list=($(get_lb_target_group_state_list ${lb_target_group_arn}))
  # wait for all instance is added to the target group
  if [ ${#target_group_state_list[@]} -ne $(($desired_capacity * 2)) ]; then
    echo "wait for target group's instance count to be $(($desired_capacity * 2)) ..."
    sleep 5
  else
    # wait for all status to be healthy
    loop=false
    for state in ${target_group_state_list[@]}; do
      if [ "${state}" != "healthy" ]; then
        echo "wait for target group's instance to be healthy ..."
        sleep 5
        loop=true
      fi
    done
  fi
done
echo "target group is healthy"

echo "stop ${primary_asg_name}"
aws autoscaling update-auto-scaling-group \
--auto-scaling-group-name ${primary_asg_name} \
--desired-capacity 0 \
--region ${AWS_REGION}

exit 0
