# sync-asg-elb

`sync-asg-elb.sh` synchronizes the instances of a list of named autoscaling groups with the instance list of a named ElasticLoadBalancer. 

## Usage

### Shell Usage

Where your shell has been configured with the AWSCLI environment variables or shared credentials file:

    sync-asg-elb.sh <PERIOD> <ELB_NAME> <ASG_NAME...>
    
    Where:
     - PERIOD is the number of seconds to wait between sync actions
     - ELB_NAME is the name of the ElasticLoadBalancer resource
     - ASG_NAMES is a space delimited list of AutoScalingGroup names

### Docker Usage Examples

Use the default AWS profile in your default shared credentials file and sync the instances in `MyFirstASG` and `MySecondASG` with the membership list of `MyELBName` every 30 seconds:

    docker run -d \
      -v ~/.aws/credentials:/run/secrets/aws \
      -e AWS_SHARED_CREDENTIALS_FILE=/run/secrets/aws \
      buildertools/asg-elb:v0.1 \
      '30 MyELBName MyFirstASG MySecondASG'

## COPYRIGHT and LICENSE

Copyright 2017 Jeff Nickoloff "jeff@allingeek.com" see [LICENSE](./LICENSE)
