import requests
import json
import time
import os

# Azure AD Credentials
TENANT_ID = "_____________________"
CLIENT_ID = "___________________________"
CLIENT_SECRET = "_________________________"

# Microsoft Teams Details
TEAM_ID = "____________________________"
CHANNEL_ID = "19:___________________________________.tacv2"

# AWS Commands
EC2_SCRIPT_PATH = "/root/AWS_ec2/ec2_toggle.sh"

# Get Microsoft Graph API Token
def get_access_token():
    url = "https://login.microsoftonline.com/{}/oauth2/v2.0/token".format(TENANT_ID)
    headers = {"Content-Type": "application/x-www-form-urlencoded"}
    data = {
        "grant_type": "client_credentials",
        "client_id": CLIENT_ID,
        "client_secret": CLIENT_SECRET,
        "scope": "https://graph.microsoft.com/.default"
    }
    response = requests.post(url, headers=headers, data=data)
    
    if response.status_code == 200:
        return response.json().get("access_token")
    else:
        print("❌ Error: Unable to get token. Response: {}".format(response.text))
        return None

# Fetch the latest Teams messages
def fetch_latest_message():
    token = get_access_token()
    if not token:
        return None

    url = "https://graph.microsoft.com/v1.0/teams/{}/channels/{}/messages".format(TEAM_ID, CHANNEL_ID)
    headers = {"Authorization": "Bearer {}".format(token)}
    response = requests.get(url, headers=headers)

    if response.status_code == 200:
        messages = response.json().get("value", [])
        if messages:
            return messages[0]["body"]["content"].strip().lower()  # Get latest message
    else:
        print("❌ Error fetching messages: {}".format(response.text))

    return None

# Check messages for EC2 commands
def check_for_commands():
    last_message = fetch_latest_message()
    
    if last_message:
        print("📩 Latest Message: {}".format(last_message))

        if "start_ec2" in last_message:
            print("🚀 Starting EC2 instances...")
            os.system("{} start_ec2".format(EC2_SCRIPT_PATH))

        elif "stop_ec2" in last_message:
            print("🛑 Stopping EC2 instances...")
            os.system("{} stop_ec2".format(EC2_SCRIPT_PATH))
        
        elif "status_ec2" in last_message:
            print("🔍 Checking status of EC2 instances...")
            os.system("{} status_ec2".format(EC2_SCRIPT_PATH))

# Main Loop
if __name__ == "__main__":
    while True:
        check_for_commands()
        time.sleep(30)  # Check every 30 seconds
