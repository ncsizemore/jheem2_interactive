#!/usr/bin/env python3
"""
Test script for Microsoft Graph API with OneDrive:
- Authenticates using device code flow
- Creates a test folder structure
- Uploads a test file
- Generates a sharing link
- Tests downloading using the sharing link
"""

import json
import datetime
import sys
import time
import os
import tempfile
import io

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
CLIENT_ID = "14d82eec-204b-4c2f-b7e8-296a70dab67e"  # Microsoft's "Graph Explorer" client ID
AUTHORITY = "https://login.microsoftonline.com/common"
SCOPES = ["Files.ReadWrite.All"]
OUTPUT_JSON = "python_sharing_links.json"

# Test folder and file structure
TEST_FOLDER_PATH = "jheem_test/prerun/C.12580"  # Create this test path
TEST_FILE_NAME = "test_simulation.Rdata"  # Create this test file

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
            
        def put(self, endpoint, data=None, content=None, headers=None):
            url = f"{self.base_url}{endpoint}"
            req_headers = self.headers.copy()
            if headers:
                req_headers.update(headers)
            
            if content:  # Binary content
                # Remove Content-Type:application/json for binary uploads
                if "Content-Type" in req_headers and req_headers["Content-Type"] == "application/json":
                    del req_headers["Content-Type"]
                
                response = requests.put(url, headers=req_headers, data=content)
            else:  # JSON data
                response = requests.put(url, headers=req_headers, json=data)
                
            return response
        
        def delete(self, endpoint):
            url = f"{self.base_url}{endpoint}"
            response = requests.delete(url, headers=self.headers)
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

def ensure_folder_path(client, folder_path):
    """Ensure that a folder path exists, creating folders as needed"""
    # Split the path into components
    path_parts = folder_path.strip("/").split("/")
    current_path = ""
    current_id = "root"
    
    for part in path_parts:
        if not part:
            continue
            
        # Update current path
        if current_path:
            current_path = f"{current_path}/{part}"
        else:
            current_path = part
            
        print(f"Checking for folder: {current_path}")
        
        # Check if this folder exists
        check_response = client.get(f"/me/drive/root:/{current_path}")
        
        if check_response.status_code == 200:
            # Folder exists
            folder_data = check_response.json()
            current_id = folder_data["id"]
            print(f"Folder exists: {part} (ID: {current_id})")
        elif check_response.status_code == 404:
            # Folder doesn't exist, create it
            print(f"Creating folder: {part}")
            
            create_data = {
                "name": part,
                "folder": {},
                "@microsoft.graph.conflictBehavior": "replace"
            }
            
            create_response = client.post(f"/me/drive/items/{current_id}/children", create_data)
            
            if create_response.status_code == 201:
                folder_data = create_response.json()
                current_id = folder_data["id"]
                print(f"Created folder: {part} (ID: {current_id})")
            else:
                print(f"Error creating folder: {create_response.status_code}")
                print(create_response.text)
                return None
        else:
            print(f"Error checking folder: {check_response.status_code}")
            print(check_response.text)
            return None
    
    # Return the ID of the final folder
    return current_id

def upload_test_file(client, folder_id, file_name):
    """Upload a test file to the specified folder"""
    print(f"Uploading test file: {file_name} to folder ID: {folder_id}")
    
    # Create a small test file content
    test_data = f"""This is a test file for the JHEEM OneDrive integration.
Created at: {datetime.datetime.now().isoformat()}
This simulates an R data file but is actually just a text file.
"""
    
    # For files under 4MB, we can use a simple upload
    upload_url = f"/me/drive/items/{folder_id}:/{file_name}:/content"
    
    # Upload the file
    upload_response = client.put(
        upload_url, 
        content=test_data.encode('utf-8'),
        headers={"Content-Type": "application/octet-stream"}
    )
    
    if upload_response.status_code in (200, 201):
        file_data = upload_response.json()
        print(f"Uploaded file: {file_name} (ID: {file_data['id']})")
        return file_data
    else:
        print(f"Error uploading file: {upload_response.status_code}")
        print(upload_response.text)
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

def test_download_link(download_link):
    """Test if the download link works"""
    print(f"Testing download link...")
    
    try:
        response = requests.get(download_link)
        
        if response.status_code == 200:
            content = response.text
            content_preview = content[:100] + "..." if len(content) > 100 else content
            print(f"Successfully downloaded file. Content preview: {content_preview}")
            return True
        else:
            print(f"Error downloading file: {response.status_code}")
            print(response.text)
            return False
    except Exception as e:
        print(f"Exception while testing download: {str(e)}")
        return False

def main():
    # Initialize results object
    results = {
        "format_version": "1.0",
        "generated_at": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "model_version": "test",
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
        
        # Create folder structure
        print(f"\nCreating folder structure: {TEST_FOLDER_PATH}")
        folder_id = ensure_folder_path(client, TEST_FOLDER_PATH)
        
        if not folder_id:
            print("Failed to create folder structure. Exiting.")
            return
        
        # Upload test file
        print(f"\nUploading test file: {TEST_FILE_NAME}")
        file_data = upload_test_file(client, folder_id, TEST_FILE_NAME)
        
        if not file_data:
            print("Failed to upload test file. Exiting.")
            return
        
        # Create sharing link
        print("\nCreating sharing link...")
        sharing_link = create_sharing_link(client, file_data["id"])
        
        if not sharing_link:
            print("Failed to create sharing link. Exiting.")
            return
        
        # Test the download link
        print("\nTesting download link...")
        link_works = test_download_link(sharing_link)
        
        if not link_works:
            print("Download link test failed.")
        
        # Add to results
        # Parse path to match your expected structure
        path_parts = TEST_FOLDER_PATH.split("/")
        location = path_parts[-1]  # C.12580
        scenario = TEST_FILE_NAME.split(".")[0]  # test_simulation
        
        results["simulations"][f"{location}_{scenario}"] = {
            "location": location,
            "scenario": scenario,
            "filename": f"{TEST_FOLDER_PATH}/{TEST_FILE_NAME}",
            "sharing_link": sharing_link
        }
        
        # Save results to JSON
        with open(OUTPUT_JSON, "w") as f:
            json.dump(results, f, indent=2)
        
        print(f"\nSharing link saved to: {OUTPUT_JSON}")
        
        # Print summary
        print("\n=== TEST SUMMARY ===")
        print(f"Authentication: SUCCESS")
        print(f"Folder creation: SUCCESS")
        print(f"File upload: SUCCESS")
        print(f"Sharing link creation: SUCCESS")
        print(f"Download test: {'SUCCESS' if link_works else 'FAILED'}")
        print(f"Configuration saved to: {OUTPUT_JSON}")
        
        if link_works:
            print("\n✅ SUCCESS: The Microsoft Graph API approach works for your OneDrive integration!")
            print("You can now use this approach to generate sharing links for all your simulation files.")
        else:
            print("\n⚠️ WARNING: Sharing link was created but download test failed.")
            print("You may need to check the sharing permissions on your OneDrive.")
    
    except Exception as e:
        print(f"Error in main function: {str(e)}")

if __name__ == "__main__":
    main()
