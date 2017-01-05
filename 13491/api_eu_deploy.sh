#!/usr/bin/env bash

#set -xe

###################################################
### See comments in main() block at the bottom. ###
###################################################

# $1 - for getopts() option
AWS_ACCESS_KEY_ID=$2
AWS_SECRET_ACCESS_KEY=$3
AWS_REGION=$4
ENVIRONMENT=$5

# for tests
#export AWS_DEFAULT_PROFILE=PROJECTNAME
#export AWS_DEFAULT_REGION=eu-west-1

#AWS_ACCESS_KEY_ID=
#AWS_SECRET_ACCESS_KEY=
#AWS_REGION=eu-west-1

BLUE_ASG="$ENVIRONMENT-api-blue-asg"
GREEN_ASG="$ENVIRONMENT-api-green-asg"
ELB="$ENVIRONMENT-api-elb"
SCALE_UP_RULE="$ENVIRONMENT-api-scale-up"
SCALE_DOWN_RULE="$ENVIRONMENT-api-scale-down"

export PATH=$PATH:"/home/aws/aws/env/bin/"
export AWS_DEFAULT_REGION=$AWS_REGION

HELP="Specify one of the following options: -d - simple deploy, -b - Production Blue deploy, -g - Production Green deploy"

get_params () {

    if [[ -z $* ]];then
        echo -e "\n$HELP\n"
        exit 1
    fi

    deploy=
    deploy_blue=
    deploy_green=

    while getopts "dbgh" opt; do
        case $opt in
            d) 
                deploy=1
                ;;
            b) 
                deploy_blue=1
                ;;
            g) 
                deploy_green=1
                ;;
            h) 
                echo "$HELP"
                ;;
        esac
    done
}

instance_terminate () {

    local instances_running=$1

    echo -e "Terminating instances $instances_running..."
    for instance in $instances_running; do
        echo -e "\nStopping instance $instance...\n"
        aws ec2 terminate-instances --instance-ids $instance || exit 1
    done

}


asg_scale_up () {

    local asg_name=$1
    aws autoscaling execute-policy --auto-scaling-group-name $asg_name --policy-name $SCALE_UP_RULE
}


asg_scale_down () {

    local asg_name=$1
    aws autoscaling execute-policy --auto-scaling-group-name $asg_name --policy-name $SCALE_DOWN_RULE
}


asg_set_protect () {

    local asg_name=$1
    local instance_to_protect=$(get_instances_running $asg_name)

    aws autoscaling set-instance-protection --instance-ids $instance_to_protect --protected-from-scale-in --auto-scaling-group-name $asg_name 
}


asg_remove_protect () {

    local asg_name=$1
    local instance_to_protect=$(get_instances_running $asg_name)

    aws autoscaling set-instance-protection --instance-ids $instance_to_protect --no-protected-from-scale-in --auto-scaling-group-name $asg_name 
}


asg_set_max_size () {

    local asg_name=$1
    local max_size=$2
    aws autoscaling update-auto-scaling-group --auto-scaling-group-name $asg_name --max-size $max_size
}


asg_set_min_size () {

    local asg_name=$1
    local min_size=$2
    aws autoscaling update-auto-scaling-group --auto-scaling-group-name $asg_name --min-size $min_size
}

get_instances_running () {

    local asg_name=$1
    local instances_running=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $asg_name --query '[AutoScalingGroups[*].Instances[*].InstanceId]' --output text) 
    echo $instances_running
}


blue_asg_status () {

    local asg_name=$1
    local instances_running=$(get_instances_running $asg_name)

    if [[ ! -z $instances_running ]]; then
        echo -e "\nThere is running instances in the Blue ASG: $instances_running\n"
        return 1
    fi
}


asg_health () {

    local at=0
    local max=10
    local timeout=10
    local asg_name=$1

    while [ $at -lt $max ]; do
        local health=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $asg_name --query [AutoScalingGroups[*].Instances[*].LifecycleState] --output text)
        if [[ $health == "InService" ]]; then
            echo -e "\n\n$asg_name instance(s) OK, ready to attach to ELB: $health\n"
            break
        else
            echo "($at/$max $timeout sec) $asg_name instance(s) not ready yet: $health"
        fi
        ((at++))
        sleep $timeout
    done
}


instance_state () {

    local at=0
    local max=10
    local timeout=20
    local instances_running=$1

    for instance in $instances_running; do
        while [ $at -lt $max ]; do
            local state=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $GREEN_ASG --query [AutoScalingGroups[*].Instances[*].InstanceId] | grep $instance)
    
            # $state will be empty if can't get its InstanceState
            # thus - it's terminated
            if [ -z $state ]; then
                echo ""
                echo -e "\nInstance $instance stopped."
                break
            else
                echo -e "($at/$max $timeout sec) Instance $instance still running..."
            fi

            ((at++))
            sleep $timeout
            if [ $at == $max ]; then
                echo "ERROR: max attempts reached."
                exit 1
            fi
        done
    done
}


green_asg_terminate () {

    local asg_name=$1
    local instances_running=$(get_instances_running $asg_name)

    instance_terminate "$instances_running"
    echo -e "\nChecking $instances_running state...\n"
    # be sure instance already terminated before proceed
    instance_state "$instances_running"
}


asg_detach () {

    local asg_name=$1
    aws autoscaling detach-load-balancers --auto-scaling-group-name $asg_name --load-balancer-names $ELB
}


asg_attach () {

    local asg_name=$1
    aws autoscaling attach-load-balancers --auto-scaling-group-name $asg_name --load-balancer-names $ELB
}


elb_health () {

    local out_state="OutOfService"
    local at=0
    local max=30
    local timeout=30

    while [ $at -lt $max ]; do
        local elb_health=$(aws elb describe-instance-health --load-balancer-name $ELB --query '[InstanceStates[*].State]' --output text)
        if [[ $elb_health =~ $out_state ]]; then
            echo "($at/$max $timeout sec) Some intances still $elb_health"
        else
            echo -e "\n\nIntance up and running: $elb_health"
            break
        fi
        ((at++))
        sleep $timeout
        if [ $at == $max ]; then
            echo "\nERROR: max attempts reached.\n"
            exit 1
        fi
    done
    
}


deploy_blue () {

    if blue_asg_status $BLUE_ASG; then

        # add 1 instance in Blue group wich will start with latest builded AMI
        echo -e "\n[BLUE] Blue ASG is empty, executing ScaleUp policy...\n"
        asg_scale_up $BLUE_ASG && echo -e "Scaled up to 1 instance.\n" || exit 1

        # to prevent new instances creation during deployment
        echo -e "[BLUE] Blue ASG updating MAX value to 1...\n"
        asg_set_max_size $BLUE_ASG 1 && echo -e "Done.\n" || exit 1

        # wait when Blue EC2 will start
        echo -e "[BLUE] Checking Blue ASG health...\n"
        asg_health $BLUE_ASG || exit 1

        # to prevent new instances creation during deployment
        echo -e "[GREEN] Green ASG updating MIN value to 1...\n"
        asg_set_min_size $GREEN_ASG 1 && echo -e "Done.\n" || exit 1

        # to prevent new instances creation during deployment
        echo -e "[GREEN] Green ASG updating MAX value to 1...\n"
        asg_set_max_size $GREEN_ASG 1 && echo -e "Done.\n" || exit 1

        # add Blue EC2 under ELB's traffic control
        echo -e "[BLUE] Attaching Blue to ELB...\n"
        asg_attach $BLUE_ASG && echo -e "Blue ASG attached.\n" || exit 1

        # to avoid instance termitation during it's "Green" role
        echo -e "[BLUE] Setting ScaleIn protection...\n"
        asg_set_protect $BLUE_ASG && echo -e "Done\n" || exit 1

        # sleep before check ELB - intanse will be added not immediately
        echo -e "[BLUE] Checking ELB intastances health for Blue instance Up...\n"
        sleep 30
        # ELB health checks :8080/health
        # Thus - it will check untill Gateway service will not start
        elb_health $BLUE_ASG || exit 1

        echo -e "\n[GREEN] Detaching Green from ELB.\n"
        asg_detach $GREEN_ASG && echo -e "Done.\n" || exit 1
        
        # sleep before check ELB - Green intanse will be removed from ELB not immediately
        # ask Verify after
##        sleep 30
    
        echo "Blue ASG deploy finished successfully.\n"

    else
        echo -e "ERROR - all instances in Blue ASG must be terminated and Desired value == 0. Exit.\n"
        exit 1
    fi

}

deploy_green () {

    # terminate Gren's instance
    echo -e "[GREEN] Updating Green ASG instances.\n"
    green_asg_terminate $GREEN_ASG

    echo -e "\n[GREEN] Waiting for Green ASG instance termination...\n"
    sleep 30

    # new instances must be started here by ASG
    echo -e "[GREEN] Checking Green ASG health.\n"
    asg_health $GREEN_ASG || exit 1

    # add Green to ELB
    echo -e "[GREEN] Attaching Green to ELB.\n"
    asg_attach $GREEN_ASG && echo -e "Green ASG attached\n" || exit 1

    # wait for the Gateway service UP state (/health)
    echo -e "[GREEN] Checking ELB intastances health for Green instance Up...\n"
    sleep 30
    elb_health $GREEN_ASG || exit 1

    # detach Blue - Green now is Green
    echo -e "\n[BLUE] Detaching Blue...\n"
    asg_detach $BLUE_ASG && echo -e "Done.\n" || exit 1

    # remove protection before ScaleIn rule will be executed
    echo -e "[BLUE] Removing ScaleIn protection...\n"
    asg_remove_protect $BLUE_ASG && echo -e "Done\n" || exit 1

    # ScaleIn rule will be executed :-)
    echo -e "[BLUE] Scaling Blue in...\n"
    asg_scale_down $BLUE_ASG && echo -e "Scale in to 0 instance - done.\n" || { echo "ERROR: can't execute ScaleDown policy. Exit."; exit 1; }

    # set Green ASG Max instances back to 8
    echo -e "[GREEN] Green ASG restoring MAX value to 8...\n"
    asg_set_max_size $GREEN_ASG 8 && echo -e "Done.\n" || exit 1

    # set Green ASG Min instances back to 2
    echo -e "[GREEN] Green ASG restoring MIN value to 2...\n"
    asg_set_min_size $GREEN_ASG 2 && echo -e "Done.\n" || exit 1

    echo "Green ASG deploy finished successfully.\n"

}


main () {

    # Build and deploy workflow
    #
    # 1 Maven
    #   1.1 Maven build jar archives with an application.
    #   1.2 Maven builds Docker images 1 per service with those jar-files included.
    #   1.3 Maven push those images to the Artifactory Private Docker registry.
    # 2 Packer
    #   2.1 Packer takes $base_ami ID and creates new EC2 instance.
    #   2.2 Installs Docker there and pulls Docker images with the latest code built by Maven.
    #   2.3 Builds new AMI with those images included.
    # 3 Terraform
    #   3.1 Terraform checks all its configs and current infrastructure state plus TF's state-files.
    #   3.2 Regarding to "most_recent = true" in api.tf - TF will see differences between current EC2 instances AMI ID 
    #       and ones found as "latest" in AWS account's AMIs list, as there are new AMIs created by Packer.
    #   3.4 Terraform updates Launch Configs (LC) for AutoScaling groups (ASG) with new AMI IDs.
    # 4 Deploy
    #   4.1 Add new EC2 instance to Blue AutoScale group.
    #   4.2 Attach Blue ASG to the Elastic Load Balancer (ELB).
    #   4.3 Detach Green ASG - traffic will be served by the Blue Group's EC2 instance, started with latest AMI ID.
    #   4.4 Terminate Green ASG instances.
    #   4.5 AutoScale will create an appropriate number of new instances.
    #   4.6 Attach Green ASG to the ELB.
    #   4.7 Detach Blue ASG.
    #   4.8 Terminate Blue ASG instances.

    [[ $deploy ]] && { deploy_blue  && deploy_green; echo -e "Result code: $?\n"; exit 0; }
    [[ $deploy_blue ]] && { deploy_blue; echo -e "Result code: $?\n"; exit 0; }
    [[ $deploy_green ]] && { deploy_green; echo -e "Result code: $?\n"; exit 0; }

}

# check for -d (simple deploy), -b (deploy_blue()) or -g (deploy_green()) option first
get_params $@

# execute main() which will call appropriate function depending on variables specified by get_params()
main && echo -e "\nDeployment finished successfully.\n"



