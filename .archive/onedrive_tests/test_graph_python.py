#!/usr/bin/env python3
"""
Test script for Microsoft Graph API access to OneDrive using device code authentication.
This script tests finding files and generating sharing links.
"""

import json
import datetime
import sys
import time
import os

# You'll need to install these packages:
# pip install msal requests

try:
    import msal
    import requests
except ImportError:
    print("Required packages not installed. Please run:")
    print("pip install msal requests")
    sys.exit(1)

# Configuration
# This is a generic Microsoft app client ID that can be used for device code flow
# It doesn't need admin approval because it uses delegated permissions with your login
CLIENT_ID = "14d82eec-204b-4c2f-b7e8-296a70dab67e"  # Microsoft's own "Graph Explorer" client ID
AUTHORITY = "https://login.microsoftonline.com/common"  # For multi-tenant apps
SCOPES = ["Files.ReadWrite.All"]
OUTPUT_JSON = "python_sharing_links.json"

# Only test 2 file paths for now
FILE_PATHS = [
    "prerun/C.12580/permanent_loss.Rdata", 
    "prerun/C.12580/current_efforts.Rdata"
]

def get_access_token():
    """Get access token using device code flow (interactive login)"""
    app = msal.PublicClientApplication(CLIENT_ID, authority=AUTHORITY)
    
    # Try to get token from cache first
    accounts = app.get_accounts()
    if accounts:
        result = app.acquire_token_silent(SCOPES, account=accounts[0])
        if result:
            print("Token acquired from cache")
            return result["access_token"]
    
    # If no cached token, do device code flow
    flow = app.initiate_device_flow(scopes=SCOPES)
    print("\n" + flow["message"] + "\n")  # Show the message with the code to the user
    
    # Complete the flow (user needs to go to the URL and enter the code)
    result = app.acquire_token_by_device_flow(flow)
    
    if "access_token" in result:
        print("Token acquired successfully via device code flow")
        return result["access_token"]
    else:
        raise Exception(f"Error acquiring token: {result.get('error_description', 'Unknown error')}")

def get_graph_client(access_token):
    """Create a simple wrapper for making Graph API calls"""
    class GraphClient:
        def __init__(self, token):
            self.token = token
            self.base_url = "https://graph.microsoft.com/v1.0"
            self.headers = {
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json"
            }
        
        def get(self, endpoint):
            url = f"{self.base_url}{endpoint}"
            response = requests.get(url, headers=self.headers)
            return response
        
        def post(self, endpoint, data=None):
            url = f"{self.base_url}{endpoint}"
            response = requests.post(url, headers=self.headers, json=data)
            return response
    
    return GraphClient(access_token)

def get_user_info(client):
    """Get current user info to confirm authentication"""
    response = client.get("/me")
    if response.status_code == 200:
        user_data = response.json()
        print(f"Authenticated as: {user_data['displayName']} <{user_data['userPrincipalName']}>")
        return user_data
    else:
        print(f"Error getting user info: {response.status_code}")
        print(response.text)
        return None

def get_drive_info(client):
    """Get user's OneDrive information"""
    response = client.get("/me/drive")
    if response.status_code == 200:
        drive_data = response.json()
        print(f"OneDrive ID: {drive_data['id']}")
        return drive_data
    else:
        print(f"Error getting drive info: {response.status_code}")
        print(response.text)
        return None

def find_item_by_path(client, file_path):
    """Find an item in OneDrive by its path"""
    # Format the path for the API (needs a leading slash)
    if not file_path.startswith("/"):
        file_path = f"/{file_path}"
    
    print(f"Finding file: {file_path}")
    
    # Use the path API to find the item
    response = client.get(f"/me/drive/root:{file_path}")
    
    if response.status_code == 200:
        item_data = response.json()
        print(f"Found file: {item_data['name']}, ID: {item_data['id']}")
        return item_data
    else:
        print(f"Error finding file: {response.status_code}")
        print(response.text)
        
        # Try an alternative approach - navigate the path
        try:
            parts = file_path.strip("/").split("/")
            current_item = {"id": "root"}  # Start at root
            
            for part in parts:
                if not part:
                    continue
                
                # List children of current folder
                children_response = client.get(f"/me/drive/items/{current_item['id']}/children")
                
                if children_response.status_code != 200:
                    print(f"Error listing children: {children_response.status_code}")
                    return None
                
                # Find the next part in the children
                children = children_response.json()["value"]
                next_item = next((item for item in children if item["name"] == part), None)
                
                if not next_item:
                    print(f"Could not find item: {part}")
                    return None
                
                current_item = next_item
            
            print(f"Found file via navigation: {current_item['name']}, ID: {current_item['id']}")
            return current_item
        except Exception as e:
            print(f"Error navigating path: {str(e)}")
            return None

def create_sharing_link(client, item_id):
    """Create an anonymous sharing link for an item"""
    print(f"Creating sharing link for item: {item_id}")
    
    body = {
        "type": "view",
        "scope": "anonymous"
    }
    
    response = client.post(f"/me/drive/items/{item_id}/createLink", data=body)
    
    if response.status_code == 201:
        link_data = response.json()
        sharing_link = link_data["link"]["webUrl"]
        download_link = f"{sharing_link}&download=1"
        
        print(f"Sharing link: {sharing_link}")
        print(f"Download link: {download_link}")
        
        return download_link
    else:
        print(f"Error creating sharing link: {response.status_code}")
        print(response.text)
        return None

def test_sharing_links_generation():
    """Main function to test generating sharing links"""
    # Initialize results object
    results = {
        "format_version": "1.0",
        "generated_at": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "model_version": "ryan-white",
        "simulations": {}
    }
    
    try:
        # Get access token
        print("Authenticating with Microsoft Graph...")
        access_token = get_access_token()
        
        # Create client
        client = get_graph_client(access_token)
        
        # Test authentication
        user = get_user_info(client)
        if not user:
            print("Authentication failed. Exiting.")
            return
        
        # Get drive info
        drive = get_drive_info(client)
        if not drive:
            print("Could not get drive info. Exiting.")
            return
        
        # Process each file path
        for file_path in FILE_PATHS:
            print(f"\nProcessing: {file_path}")
            
            # Parse the file path to extract location and scenario
            path_parts = file_path.split("/")
            location = path_parts[1]
            scenario = path_parts[2].split(".")[0]
            
            # Find the file
            item = find_item_by_path(client, file_path)
            
            if item:
                # Create sharing link
                sharing_link = create_sharing_link(client, item["id"])
                
                if sharing_link:
                    # Add to results
                    key = f"{location}_{scenario}"
                    results["simulations"][key] = {
                        "location": location,
                        "scenario": scenario,
                        "filename": file_path,
                        "sharing_link": sharing_link
                    }
                    
                    print(f"Successfully added sharing link for: {file_path}")
        
        # Save results to JSON file if we have any sharing links
        if results["simulations"]:
            with open(OUTPUT_JSON, "w") as f:
                json.dump(results, f, indent=2)
            
            print(f"\nSharing links saved to: {OUTPUT_JSON}")
            print(f"Total links generated: {len(results['simulations'])}")
        else:
            print("\nNo sharing links were generated!")
    
    except Exception as e:
        print(f"Error in test_sharing_links_generation: {str(e)}")

if __name__ == "__main__":
    test_sharing_links_generation()
