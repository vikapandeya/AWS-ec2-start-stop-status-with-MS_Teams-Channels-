#!/bin/bash

##########################
# Author : Vikash Pandey
# Date : 2025-04-28
# Version : v1
# Description: Start, Stop, or Report the status of EC2 instances based on the provided command
#              and sends status updates to Microsoft Teams.
##########################

# AWS CLI Configuration
AWS_CLI_PATH="/usr/local/bin/aws"
AWS_REGION="us-east-1"
AWS_PROFILE="Prifile_Name"

# EC2 Instance IDs (Modify as needed)
INSTANCE_IDS=("i-----------")  # Replace with your instance ID(s)

# Microsoft Teams Webhook URL (Set up in Teams)
TEAMS_WEBHOOK_URL="https://domain.webhook.office.com/webhookb2/-----------------------"

# Function to send messages to Microsoft Teams
send_teams_message() {
    MESSAGE="$1"
    JSON_PAYLOAD="{\"text\": \"$MESSAGE\"}"
    curl -H "Content-Type: application/json" \
         -X POST \
         -d "$JSON_PAYLOAD" \
         "$TEAMS_WEBHOOK_URL"
}

# Function to get the current state of an instance
get_instance_state() {
    instance_id=$1
    state=$(${AWS_CLI_PATH} --region ${AWS_REGION} --profile ${AWS_PROFILE} ec2 describe-instances \
            --instance-ids "$instance_id" --query "Reservations[*].Instances[*].State.Name" --output text)
    echo "$state"
}

# Function to wait until an instance reaches a desired state
wait_for_state() {
    instance_id=$1
    desired_state=$2

    while true; do
        current_state=$(get_instance_state "$instance_id")
        echo "Current State of $instance_id: $current_state"

        if [[ "$current_state" == "$desired_state" ]]; then
            echo "Instance $instance_id is now $desired_state."
            send_teams_message "✅ Instance $instance_id is now **$desired_state**."
            break
        fi
        sleep 10  # Wait before checking again
    done
}

# Check if a command argument is passed: expected "start_ec2", "stop_ec2", or "status_ec2"
if [ -z "$1" ]; then
    echo "No command provided. Please specify 'start_ec2', 'stop_ec2', or 'status_ec2'."
    exit 1
fi

COMMAND=$1

# Main Logic: Process EC2 Instances based on the command
for instance_id in "${INSTANCE_IDS[@]}"; do
    current_state=$(get_instance_state "$instance_id")
    echo "Instance $instance_id current state: $current_state"

    case "$COMMAND" in
        start_ec2)
            if [[ "$current_state" == "running" ]]; then
                echo "Instance $instance_id is already running."
                send_teams_message "ℹ️ Instance $instance_id is already **running**. No action taken."
            elif [[ "$current_state" == "stopped" ]]; then
                echo "Starting EC2 instance: $instance_id"
                send_teams_message "⏳ Starting EC2 instance: **$instance_id**..."
                ${AWS_CLI_PATH} --region ${AWS_REGION} --profile ${AWS_PROFILE} ec2 start-instances --instance-ids "$instance_id"
                wait_for_state "$instance_id" "running"
            else
                echo "Instance $instance_id is in an unknown state: $current_state"
                send_teams_message "⚠️ Instance $instance_id is in an unknown state: **$current_state**."
            fi
            ;;
        stop_ec2)
            if [[ "$current_state" == "stopped" ]]; then
                echo "Instance $instance_id is already stopped."
                send_teams_message "ℹ️ Instance $instance_id is already **stopped**. No action taken."
            elif [[ "$current_state" == "running" ]]; then
                echo "Stopping EC2 instance: $instance_id"
                send_teams_message "⏳ Stopping EC2 instance: **$instance_id**..."
                ${AWS_CLI_PATH} --region ${AWS_REGION} --profile ${AWS_PROFILE} ec2 stop-instances --instance-ids "$instance_id"
                wait_for_state "$instance_id" "stopped"
            else
                echo "Instance $instance_id is in an unknown state: $current_state"
                send_teams_message "⚠️ Instance $instance_id is in an unknown state: **$current_state**."
            fi
            ;;
        status_ec2)
            echo "Status for instance $instance_id: $current_state"
            send_teams_message "ℹ️ Instance $instance_id is currently **$current_state**."
            ;;
        *)
            echo "Unknown command: $COMMAND. Use 'start_ec2', 'stop_ec2', or 'status_ec2'."
            exit 1
            ;;
    esac
done
