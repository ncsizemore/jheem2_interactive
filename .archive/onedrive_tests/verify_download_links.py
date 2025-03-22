#!/usr/bin/env python3
"""
Test script to verify that OneDrive sharing links download the correct file content.
This script:
1. Creates a test file with unique, identifiable content
2. Uploads it to OneDrive
3. Creates a sharing link
4. Downloads the file through the sharing link
5. Verifies the downloaded content matches the original file
"""

import json
import datetime
import sys
import time
import os
import tempfile
import hashlib
import uuid

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
TEST_FOLDER = "jheem_test/verification"
TEST_FILE_SIZES = [10, 100, 1000, 10000] # File sizes in KB to test

# The download parameter format to use
DOWNLOAD_PARAM = "?download=1"

def get_access_token():
    """Get access token using device code flow"""
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
        
        def delete(self, endpoint):
            url = f"{self.base_url}{endpoint}"
            response = requests.delete(url, headers=self.headers)
            return response
    
    return GraphClient(access_token)

def ensure_folder_path(client, folder_path):
    """Ensure that a folder path exists, creating folders as needed"""
    path_parts = folder_path.strip("/").split("/")
    current_path = ""
    current_id = "root"
    
    for part in path_parts:
        if not part:
            continue
            
        if current_path:
            current_path = f"{current_path}/{part}"
        else:
            current_path = part
            
        print(f"Checking for folder: {current_path}")
        
        check_response = client.get(f"/me/drive/root:/{current_path}")
        
        if check_response.status_code == 200:
            folder_data = check_response.json()
            current_id = folder_data["id"]
            print(f"Folder exists: {part} (ID: {current_id})")
        elif check_response.status_code == 404:
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
    
    return current_id

def create_test_file(size_kb):
    """Create a test file with unique, identifiable content"""
    # Generate a unique ID for this test
    test_id = str(uuid.uuid4())
    
    # Create temporary file
    fd, temp_path = tempfile.mkstemp(suffix=".bin")
    try:
        with os.fdopen(fd, 'wb') as f:
            # Write a header with the test ID and timestamp
            header = f"TEST_ID:{test_id} TIME:{datetime.datetime.now().isoformat()} SIZE:{size_kb}KB\n".encode('utf-8')
            f.write(header)
            
            # Generate random-looking but deterministic content
            remaining_size = size_kb * 1024 - len(header)
            seed = test_id.encode('utf-8')
            
            # Generate content in chunks
            chunk_size = 4096
            while remaining_size > 0:
                # Create deterministic content based on the current position and seed
                h = hashlib.md5(seed + str(remaining_size).encode('utf-8')).digest()
                chunk = h * (chunk_size // len(h) + 1)
                write_size = min(chunk_size, remaining_size)
                f.write(chunk[:write_size])
                remaining_size -= write_size
            
        # Read the file back to compute its hash and size
        with open(temp_path, 'rb') as f:
            content = f.read()
            file_hash = hashlib.md5(content).hexdigest()
            file_size = len(content)
        
        print(f"Created test file: {temp_path}")
        print(f"Size: {file_size} bytes, MD5: {file_hash}")
        print(f"Test ID: {test_id}")
        
        return {
            "path": temp_path,
            "content": content,
            "hash": file_hash,
            "size": file_size,
            "test_id": test_id
        }
    except Exception as e:
        print(f"Error creating test file: {e}")
        os.unlink(temp_path)
        return None

def upload_test_file(client, folder_id, file_info):
    """Upload a test file to OneDrive"""
    file_name = f"test_{file_info['size'] // 1024}KB_{file_info['test_id']}.bin"
    print(f"Uploading test file: {file_name}")
    
    # Upload the file
    upload_url = f"/me/drive/items/{folder_id}:/{file_name}:/content"
    
    upload_response = client.put(
        upload_url,
        content=file_info['content'],
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
    """Create a sharing link for a file"""
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
            download_link = sharing_link + "&download=1"
        else:
            download_link = sharing_link + DOWNLOAD_PARAM
        
        print(f"Sharing link: {sharing_link}")
        print(f"Download link: {download_link}")
        
        return {
            "sharing_link": sharing_link,
            "download_link": download_link
        }
    else:
        print(f"Error creating sharing link: {response.status_code}")
        print(response.text)
        return None

def download_and_verify(link, original_file_info):
    """Download a file through a sharing link and verify its contents"""
    print(f"Downloading and verifying file...")
    
    try:
        # Add a cache buster to avoid caching issues
        download_url = f"{link}{'&' if '?' in link else '?'}_cb={int(time.time())}"
        
        start_time = time.time()
        response = requests.get(download_url, allow_redirects=True)
        end_time = time.time()
        
        print(f"Download status code: {response.status_code}")
        print(f"Download time: {end_time - start_time:.2f} seconds")
        print(f"Downloaded size: {len(response.content)} bytes")
        print(f"Content-Type: {response.headers.get('Content-Type', 'Not specified')}")
        
        # Check if this is HTML content (likely an error page)
        content_type = response.headers.get('Content-Type', '').lower()
        if 'html' in content_type:
            print("ERROR: Downloaded content is HTML, not the file content")
            content_preview = response.content[:200].decode('utf-8', errors='ignore')
            print(f"Content preview: {content_preview}...")
            return False
        
        # Compute hash of downloaded content
        downloaded_hash = hashlib.md5(response.content).hexdigest()
        print(f"Downloaded file hash: {downloaded_hash}")
        print(f"Original file hash: {original_file_info['hash']}")
        
        # Verify file size
        size_match = len(response.content) == original_file_info['size']
        print(f"Size match: {size_match}")
        
        # Verify file hash
        hash_match = downloaded_hash == original_file_info['hash']
        print(f"Hash match: {hash_match}")
        
        # Check if the test ID is in the content (sanity check)
        content_preview = response.content[:200].decode('utf-8', errors='ignore')
        test_id_present = original_file_info['test_id'] in content_preview
        print(f"Test ID present: {test_id_present}")
        
        return size_match and hash_match and test_id_present
    
    except Exception as e:
        print(f"Error downloading/verifying file: {e}")
        return False

def cleanup_test_file(file_info):
    """Clean up the local test file"""
    try:
        os.unlink(file_info['path'])
        print(f"Deleted test file: {file_info['path']}")
    except Exception as e:
        print(f"Error deleting test file: {e}")

def main():
    results = {
        "tests": [],
        "success_count": 0,
        "fail_count": 0,
        "timestamp": datetime.datetime.now().isoformat()
    }
    
    try:
        # Authenticate
        print("Authenticating with Microsoft Graph...")
        access_token = get_access_token()
        client = get_graph_client(access_token)
        
        # Create test folder
        print(f"\nCreating test folder: {TEST_FOLDER}")
        folder_id = ensure_folder_path(client, TEST_FOLDER)
        
        if not folder_id:
            print("Failed to create test folder. Exiting.")
            return
        
        # Test different file sizes
        for size_kb in TEST_FILE_SIZES:
            print(f"\n=== Testing {size_kb} KB file ===")
            
            # Create test file
            file_info = create_test_file(size_kb)
            
            if not file_info:
                print(f"Failed to create {size_kb} KB test file. Skipping.")
                results["fail_count"] += 1
                results["tests"].append({
                    "size_kb": size_kb,
                    "success": False,
                    "error": "Failed to create test file"
                })
                continue
                
            try:
                # Upload the file
                file_data = upload_test_file(client, folder_id, file_info)
                
                if not file_data:
                    print(f"Failed to upload {size_kb} KB test file. Skipping.")
                    results["fail_count"] += 1
                    results["tests"].append({
                        "size_kb": size_kb,
                        "success": False,
                        "error": "Failed to upload file"
                    })
                    continue
                
                # Create sharing link
                links = create_sharing_link(client, file_data["id"])
                
                if not links:
                    print(f"Failed to create sharing link for {size_kb} KB file. Skipping.")
                    results["fail_count"] += 1
                    results["tests"].append({
                        "size_kb": size_kb,
                        "success": False,
                        "error": "Failed to create sharing link"
                    })
                    continue
                
                # Download and verify file
                print("\nTesting direct download link:")
                download_success = download_and_verify(links["download_link"], file_info)
                
                # Record results
                if download_success:
                    print(f"✅ SUCCESS: {size_kb} KB file download verified!")
                    results["success_count"] += 1
                    results["tests"].append({
                        "size_kb": size_kb,
                        "success": True,
                        "sharing_link": links["sharing_link"],
                        "download_link": links["download_link"],
                        "file_hash": file_info["hash"],
                        "file_size": file_info["size"]
                    })
                else:
                    print(f"❌ FAILURE: {size_kb} KB file download verification failed!")
                    
                    # Try the sharing link without download parameter as a fallback
                    print("\nTesting fallback to regular sharing link:")
                    fallback_success = download_and_verify(links["sharing_link"], file_info)
                    
                    if fallback_success:
                        print(f"✅ PARTIAL SUCCESS: Regular sharing link works but download parameter doesn't!")
                        results["success_count"] += 1
                        results["tests"].append({
                            "size_kb": size_kb,
                            "success": True,
                            "partial": True,
                            "sharing_link": links["sharing_link"],
                            "download_link": links["download_link"],
                            "file_hash": file_info["hash"],
                            "file_size": file_info["size"],
                            "note": "Download parameter didn't work but regular sharing link did"
                        })
                    else:
                        print(f"❌ COMPLETE FAILURE: Neither link works correctly!")
                        results["fail_count"] += 1
                        results["tests"].append({
                            "size_kb": size_kb,
                            "success": False,
                            "error": "File verification failed for both links"
                        })
            
            finally:
                # Clean up the test file
                cleanup_test_file(file_info)
        
        # Save results to JSON
        with open("download_verification_results.json", "w") as f:
            json.dump(results, f, indent=2)
        
        print("\n=== VERIFICATION SUMMARY ===")
        print(f"Total tests: {len(results['tests'])}")
        print(f"Successful tests: {results['success_count']}")
        print(f"Failed tests: {results['fail_count']}")
        
        if results["success_count"] > 0:
            print("\n✅ SUCCESS: Some download links worked correctly!")
            print("You can use the format shown in the success cases for your application.")
        else:
            print("\n❌ FAILURE: None of the download links worked correctly.")
            print("You may need to consider an alternative approach.")
        
        print("\nResults saved to: download_verification_results.json")
    
    except Exception as e:
        print(f"Error in main function: {e}")

if __name__ == "__main__":
    main()
