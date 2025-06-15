#!/bin/bash

userid=$(id -u)
AMI_ID="ami-09c813fb71547fc4f"
SECURITY_GROUP="sg-066d322d0b8ea9c8f"
INSTANCE=("mongodb" "redis" "mysql" "rabbitmq" "frontend" "payment" "shipping" "catalogue" "user" "dispatch" "cart" "payment")
ZONE_ID="Z05167558BEIFU213OL8"
DOMAIN_NAME="venaws.site"

# Corrected loop to iterate over the INSTANCE array
for instance in "${INSTANCE[@]}"
do
    echo "Processing instance: $instance" # Added for better debugging output

    INSTANCE_ID=$(aws ec2 run-instances --image-id ami-09c813fb71547fc4f --instance-type t3.micro --security-group-ids sg-01bc7ebe005fb1cb2 --tag-specifications "ResourceType=instance,Tags=[{Key=Name, Value=$instance}]" --query "Instances[0].InstanceId" --output text)

    # Check if instance ID was retrieved successfully
    if [ -z "$INSTANCE_ID" ]; then
        echo "Error: Could not create EC2 instance for $instance. Exiting."
        exit 1
    fi

    if [ "$instance" != "frontend" ]
    then
        # It's good practice to wait for the instance to be running to get an IP
        aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
        IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query "Reservations[0].Instances[0].PrivateIpAddress" --output text)
        RECORD_NAME="$instance.$DOMAIN_NAME"
    else
        aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
        IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query "Reservations[0].Instances[0].PublicIpAddress" --output text)
        RECORD_NAME="$DOMAIN_NAME"
    fi
    echo "$instance IP address: $IP"

    # Check if IP was retrieved successfully
    if [ -z "$IP" ]; then
        echo "Error: Could not retrieve IP address for $instance. Skipping Route53 update."
        continue # Skip to the next instance if IP is not found
    fi

    aws route53 change-resource-record-sets \
    --hosted-zone-id "$ZONE_ID" \
    --change-batch '{
        "Comment": "Creating or Updating a record set for '$instance'"
        ,"Changes": [{
        "Action"           : "UPSERT"
        ,"ResourceRecordSet" : {
            "Name"             : "'"$RECORD_NAME"'"
            ,"Type"             : "A"
            ,"TTL"              : 1
            ,"ResourceRecords"  : [{
                "Value"         : "'"$IP"'"
            }]
        }
        }]
    }'
done