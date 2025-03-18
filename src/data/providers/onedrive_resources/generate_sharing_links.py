#!/usr/bin/env python3
"""
Script to generate sharing links for all simulation files.
Uses the Microsoft Graph API with interactive authentication.

This script:
1. Authenticates with Microsoft Graph API
2. Creates necessary folder structure in OneDrive
3. Uploads all simulation files
4. Generates sharing links for each file
5. Creates a configuration file for the OneDriveProvider
"""

import json
import datetime
import sys
import time
import os
import argparse

try:
    import msal
    import requests
except ImportError:
    print("Required packages not installed. Please run:")
    print("pip install msal requests")
    sys.exit(1)

# Configuration
CLIENT_ID = "14d82eec-204b-4c2f-b7e8-296a70dab67e"
AUTHORITY = "https://login.microsoftonline.com/common"
SCOPES = ["Files.ReadWrite.All"]
OUTPUT_JSON = "src/data/providers/onedrive_resources/onedrive_sharing_links.json"

# The correct download parameter format (based on our testing)
DOWNLOAD_PARAM = "?download=1"

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
    print("\n" + flow["message"] + "\n")
    
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
                if "Content-Type" in req_headers and req_headers["Content-Type"] == "application/json":
                    del req_headers["Content-Type"]
                
                response = requests.put(url, headers=req_headers, data=content)
            else:  # JSON data
                response = requests.put(url, headers=req_headers, json=data)
                
            return response
    
    return GraphClient(access_token)

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

def upload_file(client, local_file_path, onedrive_folder_id, file_name):
    """Upload a file to the specified OneDrive folder"""
    print(f"Uploading file: {local_file_path} -> {file_name}")
    
    try:
        # Read the local file
        with open(local_file_path, "rb") as file:
            file_content = file.read()
        
        file_size = len(file_content)
        print(f"File size: {file_size} bytes")
        
        # For small files (< 4MB), use simple upload
        if file_size < 4 * 1024 * 1024:
            upload_url = f"/me/drive/items/{onedrive_folder_id}:/{file_name}:/content"
            
            # Upload the file
            upload_response = client.put(
                upload_url,
                content=file_content,
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
        else:
            # For larger files, use upload session (chunked upload)
            print(f"Large file detected ({file_size} bytes). Using chunked upload session.")
            
            # Step 1: Create an upload session
            session_url = f"/me/drive/items/{onedrive_folder_id}:/{file_name}:/createUploadSession"
            session_response = client.post(session_url)
            
            if session_response.status_code != 200:
                print(f"Error creating upload session: {session_response.status_code}")
                print(session_response.text)
                return None
            
            upload_url = session_response.json().get('uploadUrl')
            if not upload_url:
                print("No upload URL in session response")
                return None
            
            # Step 2: Upload the file in chunks
            CHUNK_SIZE = 3276800  # 3.125 MB, which is recommended by Microsoft
            total_chunks = (file_size + CHUNK_SIZE - 1) // CHUNK_SIZE  # Ceiling division
            
            print(f"Uploading in {total_chunks} chunks of {CHUNK_SIZE/1024/1024:.2f} MB each")
            
            # Re-open the file for chunked reading
            with open(local_file_path, "rb") as file:
                for chunk_num in range(total_chunks):
                    # Calculate chunk range
                    start_byte = chunk_num * CHUNK_SIZE
                    end_byte = min(start_byte + CHUNK_SIZE - 1, file_size - 1)
                    content_length = end_byte - start_byte + 1
                    
                    # Read chunk
                    file.seek(start_byte)
                    chunk_content = file.read(content_length)
                    
                    # Upload chunk
                    headers = {
                        "Content-Length": str(content_length),
                        "Content-Range": f"bytes {start_byte}-{end_byte}/{file_size}"
                    }
                    
                    print(f"Uploading chunk {chunk_num+1}/{total_chunks}: bytes {start_byte}-{end_byte}/{file_size}")
                    
                    # For the upload URL, we need to use the full URL, not just the endpoint
                    # So we make a direct request instead of using our client helper
                    response = requests.put(upload_url, headers=headers, data=chunk_content)
                    
                    # Check response
                    if response.status_code in (200, 201, 202):
                        if response.status_code == 202:
                            # More chunks to upload
                            print(f"Chunk {chunk_num+1} uploaded successfully")
                        else:
                            # Final chunk, upload complete
                            print(f"Upload complete! Response status: {response.status_code}")
                            file_data = response.json()
                            print(f"Uploaded file: {file_name} (ID: {file_data.get('id')})")
                            return file_data
                    else:
                        print(f"Error uploading chunk {chunk_num+1}: {response.status_code}")
                        print(response.text)
                        return None
            
            # If we get here, something went wrong
            print("Error: Upload process did not complete properly")
            return None
            
    except Exception as e:
        print(f"Error uploading file: {str(e)}")
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
        
        # Use the correct download parameter format
        if "?" in sharing_link:
            # If the URL already has a query parameter, append with &
            download_link = sharing_link + "&download=1"
        else:
            # Otherwise, start the query string with ?
            download_link = sharing_link + DOWNLOAD_PARAM
        
        print(f"Sharing link: {sharing_link}")
        print(f"Download link: {download_link}")
        
        return download_link
    else:
        print(f"Error creating sharing link: {response.status_code}")
        print(response.text)
        return None

def parse_args():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(description="Generate OneDrive sharing links for simulation files")
    
    parser.add_argument(
        "--base-dir",
        type=str,
        help="Base directory containing simulation files"
    )
    parser.add_argument(
        "--onedrive-dir",
        type=str,
        help="OneDrive directory to store files"
    )
    parser.add_argument(
        "--model-version",
        type=str,
        help="Model version"
    )
    parser.add_argument(
        "--output",
        type=str,
        default=OUTPUT_JSON,
        help="Output JSON file for sharing links"
    )
    parser.add_argument(
        "--locations",
        type=str,
        nargs="+",
        help="Specific locations to process (e.g., C.12580)"
    )
    parser.add_argument(
        "--scenarios",
        type=str,
        nargs="+",
        help="Specific scenarios to process (e.g., permanent_loss)"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print actions without performing them"
    )
    
    return parser.parse_args()

def discover_simulation_files(base_dir, locations=None, scenarios=None):
    """Discover simulation files in the specified directory"""
    print(f"Discovering simulation files in: {base_dir}")
    
    simulation_files = []
    
    # Check if base_dir exists
    if not os.path.exists(base_dir):
        print(f"Base directory does not exist: {base_dir}")
        return simulation_files
    
    # Process the base directory for files like "base/C.12580_base.Rdata"
    base_dir_path = os.path.join(base_dir, "base")
    if os.path.exists(base_dir_path):
        for item in os.listdir(base_dir_path):
            if item.endswith(".Rdata"):
                file_path = os.path.join(base_dir_path, item)
                # Extract location from filename (e.g., "C.12580_base.Rdata" -> "C.12580")
                location = item.split("_")[0]
                scenario = "base"
                
                simulation_files.append({
                    "location": location,
                    "scenario": scenario,
                    "local_path": file_path,
                    "relative_path": f"base/{item}",
                    "onedrive_path": f"base"
                })
    
    # Process the prerun directory structure
    prerun_dir_path = os.path.join(base_dir, "prerun")
    if os.path.exists(prerun_dir_path):
        # Get all location directories
        for location in os.listdir(prerun_dir_path):
            location_path = os.path.join(prerun_dir_path, location)
            if os.path.isdir(location_path) and (locations is None or location in locations):
                # Check each file in the location directory
                for item in os.listdir(location_path):
                    if item.endswith(".Rdata") and (scenarios is None or os.path.splitext(item)[0] in scenarios):
                        file_path = os.path.join(location_path, item)
                        scenario = os.path.splitext(item)[0]
                        
                        simulation_files.append({
                            "location": location,
                            "scenario": scenario,
                            "local_path": file_path,
                            "relative_path": f"prerun/{location}/{item}",
                            "onedrive_path": f"prerun/{location}"
                        })
    
    # Process the test directory structure (similar to prerun)
    test_dir_path = os.path.join(base_dir, "test")
    if os.path.exists(test_dir_path):
        # First check if there's a base directory in test
        test_base_path = os.path.join(test_dir_path, "base")
        if os.path.exists(test_base_path):
            for item in os.listdir(test_base_path):
                if item.endswith(".Rdata"):
                    file_path = os.path.join(test_base_path, item)
                    location = item.split("_")[0]
                    scenario = "base_test"  # Marking as a test file
                    
                    simulation_files.append({
                        "location": location,
                        "scenario": scenario,
                        "local_path": file_path,
                        "relative_path": f"test/base/{item}",
                        "onedrive_path": f"test/base"
                    })
        
        # Then check for prerun tests - direct in prerun dir or in location subdirs
        test_prerun_path = os.path.join(test_dir_path, "prerun")
        if os.path.exists(test_prerun_path):
            # First check if there are direct files in the prerun directory
            for item in os.listdir(test_prerun_path):
                item_path = os.path.join(test_prerun_path, item)
                if os.path.isfile(item_path) and item.endswith(".Rdata"):
                    file_path = item_path
                    # Try to extract location from filename (e.g., "C.12580_test_all.Rdata")
                    location = item.split("_")[0]
                    scenario = os.path.splitext(item)[0]  # Use the full filename as scenario
                    
                    simulation_files.append({
                        "location": location,
                        "scenario": scenario,
                        "local_path": file_path,
                        "relative_path": f"test/prerun/{item}",
                        "onedrive_path": f"test/prerun"
                    })
                # Also check subdirectories
                elif os.path.isdir(item_path) and (locations is None or item in locations):
                    location = item
                    for subitem in os.listdir(item_path):
                        if subitem.endswith(".Rdata"):
                            file_path = os.path.join(item_path, subitem)
                            scenario = os.path.splitext(subitem)[0] + "_test"
                            
                            simulation_files.append({
                                "location": location,
                                "scenario": scenario,
                                "local_path": file_path,
                                "relative_path": f"test/prerun/{location}/{subitem}",
                                "onedrive_path": f"test/prerun/{location}"
                            })
    
    print(f"Found {len(simulation_files)} simulation files")
    return simulation_files

def main():
    """Main function to generate sharing links"""
    args = parse_args()
    
    # Initialize results object
    results = {
        "format_version": "1.0",
        "generated_at": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "model_version": args.model_version,
        "simulations": {}
    }
    
    # Discover simulation files
    simulation_files = discover_simulation_files(
        args.base_dir,
        args.locations,
        args.scenarios
    )
    
    if not simulation_files:
        print("No simulation files found. Exiting.")
        return
    
    if args.dry_run:
        print("\nDRY RUN MODE - No actual uploads or link generation")
        for sim in simulation_files:
            print(f"Would process: {sim['relative_path']}")
        return
    
    try:
        # Get access token
        print("Authenticating with Microsoft Graph...")
        access_token = get_access_token()
        
        # Create client
        client = get_graph_client(access_token)
        
        # Process each location
        for sim in simulation_files:
            # Create folder structure for this simulation
            folder_path = f"{args.onedrive_dir}/{sim['onedrive_path']}"
            folder_id = ensure_folder_path(client, folder_path)
            
            if not folder_id:
                print(f"Failed to create folder for path: {folder_path}")
                continue
            
            # Upload the file
            file_name = os.path.basename(sim['local_path'])
            file_data = upload_file(client, sim["local_path"], folder_id, file_name)
            
            if not file_data:
                print(f"Failed to upload file: {sim['relative_path']}")
                continue
            
            # Create sharing link
            sharing_link = create_sharing_link(client, file_data["id"])
                
            if not sharing_link:
                print(f"Failed to create sharing link for: {sim['relative_path']}")
                continue
            
            # Add to results
            key = f"{sim['location']}_{sim['scenario']}"
            
            results["simulations"][key] = {
                "location": sim["location"],
                "scenario": sim["scenario"],
                "filename": sim["relative_path"],  # Use the full relative path
                "sharing_link": sharing_link
            }
            
            print(f"Successfully processed: {sim['relative_path']}")
        
        # Create output directory if it doesn't exist
        os.makedirs(os.path.dirname(args.output), exist_ok=True)
        
        # Save results to JSON
        with open(args.output, "w") as f:
            json.dump(results, f, indent=2)
        
        print(f"\nSharing links saved to: {args.output}")
        print(f"Total links generated: {len(results['simulations'])}")
        
    except Exception as e:
        print(f"Error in main function: {str(e)}")

if __name__ == "__main__":
    main()
