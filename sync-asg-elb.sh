#!/bin/bash

#  Copyright 2017 Jeff Nickoloff "jeff@allingeek.com"
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

PERIOD=$1
ELB_NAME=$2
shift 2
ASG_NAMES="$@"
LOG_LINE='{"appName":"sync-asg-elb.sh","date":"%s","asg":"%s","elb":"%s","status":"%s"}\n'

while true; do
  trap '{ echo "Interrupted" ; exit 1; }' INT
  printf "${LOG_LINE}" $(date +%Y-%m-%dT%H:%M:%S%z) "${ASG_NAMES}" "${ELB_NAME}" "$(printf 'polling every %s seconds' "${PERIOD}")"
  sleep "${PERIOD}"

  # get instances in ASG
  INSTANCES=($(aws autoscaling describe-auto-scaling-groups --no-paginate --auto-scaling-group-names $ASG_NAMES 2>/tmp/sae-ierr | jq ".AutoScalingGroups[].Instances[].InstanceId" 2>>/tmp/sae-ierr))
  ERR=$(tr -d "\n" </tmp/sae-ierr | tr '"' '\"')
  if [ ${#ERR} -ne 0 ]; then
    rm /tmp/sae-ierr
    printf "${LOG_LINE}" $(date +%Y-%m-%dT%H:%M:%S%z) "${ASG_NAMES}" "${ELB_NAME}" "${ERR}"
    continue
  fi
  if [ ${#INSTANCES} -eq 0 ]; then
    printf "${LOG_LINE}" $(date +%Y-%m-%dT%H:%M:%S%z) "${ASG_NAMES}" "${ELB_NAME}" "No instances in ASG set"
    continue
  fi

  # get instances in ELB
  REGISTERED=($(aws elb describe-load-balancers --no-paginate --load-balancer-names "${ELB_NAME}" 2>/tmp/sae-rerr | jq ".LoadBalancerDescriptions[0].Instances[].InstanceId" 2>>/tmp/sae-rerr))
  ERR=$(tr -d "\n" </tmp/sae-rerr | tr '"' '\"')
  if [ ${#ERR} -ne 0 ]; then
    rm /tmp/sae-rerr
    printf "${LOG_LINE}" $(date +%Y-%m-%dT%H:%M:%S%z) "${ASG_NAMES}" "${ELB_NAME}" "${ERR}"
    continue
  fi

  # uniq is OR
  # uniq -u is XOR
  # uniq -d is AND
  ACTIONABLE=($(echo ${INSTANCES[@]} ${REGISTERED[@]} | tr ' ' '\n' | sort | uniq -u))
  TO_DEREGISTER=($(echo ${ACTIONABLE[@]} ${REGISTERED[@]} | tr ' ' '\n' | sort | uniq -d))
  TO_REGISTER=($(echo ${ACTIONABLE[@]} ${INSTANCES[@]} | tr ' ' '\n' | sort | uniq -d))

  # deregister old-backend
  if [ ${#TO_DEREGISTER[@]} -eq 0 ]; then
    printf "${LOG_LINE}" $(date +%Y-%m-%dT%H:%M:%S%z) "${ASG_NAMES}" "${ELB_NAME}" "no deregistrations"
  else 
    printf "${LOG_LINE}" $(date +%Y-%m-%dT%H:%M:%S%z) "${ASG_NAMES}" "${ELB_NAME}" "$(printf "deregistering %s" "$(echo ${TO_DEREGISTER[@]} | tr -d '"' | tr -d '\n\r')")"
    if ! aws elb deregister-instances-from-load-balancer --load-balancer-name "${ELB_NAME}" --instances $(echo ${TO_DEREGISTER[@]} | tr -d '"' | tr -d '\n\r') 2>1 1>/dev/null; then
      printf "${LOG_LINE}" $(date +%Y-%m-%dT%H:%M:%S%z) "${ASG_NAMES}" "${ELB_NAME}" "deregistration failed"
    fi
  fi

  # register new-backends
  if [ ${#TO_REGISTER[@]} -eq 0 ]; then
    printf "${LOG_LINE}" $(date +%Y-%m-%dT%H:%M:%S%z) "${ASG_NAMES}" "${ELB_NAME}" "no registrations"
  else 
    printf "${LOG_LINE}" $(date +%Y-%m-%dT%H:%M:%S%z) "${ASG_NAMES}" "${ELB_NAME}" "$(printf "registering %s" "$(echo ${TO_REGISTER[@]} | tr -d '"' | tr -d '\n\r')")"
    if ! aws elb register-instances-with-load-balancer --load-balancer-name "${ELB_NAME}" --instances $(echo ${TO_REGISTER[@]} | tr -d '"' | tr -d '\n\r') 2>1 1>/dev/null; then
      printf "${LOG_LINE}" $(date +%Y-%m-%dT%H:%M:%S%z) "${ASG_NAMES}" "${ELB_NAME}" "registration failed"
    fi
  fi

done
