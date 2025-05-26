#!/bin/bash

userid=$(id -u)
AMI_ID="ami-09c813fb71547fc4f"
SECURITY_GROUP="sg-066d322d0b8ea9c8f"
INSTANCE=("mongodb" "redis" "mysql" "rabbitmq" "frontend" "payment" "shipping" "catalogue" "user" "dispatch" "cart" "payment")
ZONE_ID="Z05167558BEIFU213OL8"
DOMAIN_NAME="venaws.site"

if [ $userid -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi
# Check if AWS CLI is installed


for i in "${INSTANCE[@]}"; do
  INSTANCE_ID=$(aws ec2 run-instances --image-id ami-09c813fb71547fc4f --instance-type t2.micro --security-group-ids sg-066d322d0b8ea9c8f --tag-specifications "ResourceType=instance,Tags=[{Key=Name, Value=$i}]" --query "Instances[0].InstanceId" --output text)

    if [ "$i" != "frontend" ]; then
        IP=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$i" --query "Reservations[0].Instances[0].PrivateIpAddress" --output text)
        RECORD_NAME="$i.$DOMAIN_NAME"
    else
        IP=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$i" --query "Reservations[0].Instances[0].PublicIpAddress" --output text)
         RECORD_NAME="$DOMAIN_NAME"
    fi
    echo "IP address for $i is $IP"

done

aws route53 change-resource-record-sets --hosted-zone-id $ZONE_ID --change-batch '{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "'"$RECORD_NAME"'",
        "Type": "A",
        "TTL": 1,
        "ResourceRecords": [
          {
            "Value": "'"$IP"'"
          }
        ]
      }
    }
  ]
}'

  if [ $? -eq 0 ]; then
    echo "DNS record for $RECORD_NAME updated successfully."
  else
    echo "Failed to update DNS record for $RECORD_NAME."
  fi