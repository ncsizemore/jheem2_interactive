#!/usr/bin/env python3
"""
Test script that tests different download parameter formats for OneDrive sharing links.
This will help determine which format works for direct downloads without opening the browser.
"""

import json
import requests
import sys
import time
import os

# Configuration
# This is the sharing link we got from the previous test
BASE_SHARING_LINK = "https://livejohnshopkins-my.sharepoint.com/:u:/g/personal/nsizemo1_jh_edu/EYaY5e7MKDhJiHDeVu0lnn0Bwu61mLSra5KvK33JxZa78A"

# Different download parameter formats to test
DOWNLOAD_PARAMS = [
    "&download=1",
    "?download=1",
    "&download=true",
    "?download=true",
    "&Download=1",
    "?Download=1",
    "&d=1",
    "?d=1",
    "/download",
    "",  # Original link with no parameters
]

def test_download_link(link, description):
    """Test if a download link works by trying to download the file"""
    print(f"\nTesting: {description}")
    print(f"URL: {link}")
    
    try:
        # Add a unique query parameter to avoid caching
        cache_buster = int(time.time())
        test_link = f"{link}{'&' if '?' in link else '?'}_cb={cache_buster}"
        
        # Send the request
        start_time = time.time()
        response = requests.get(test_link, allow_redirects=True)
        end_time = time.time()
        
        print(f"Status code: {response.status_code}")
        print(f"Response time: {end_time - start_time:.2f} seconds")
        print(f"Content-Type: {response.headers.get('Content-Type', 'Not specified')}")
        print(f"Content length: {len(response.content)} bytes")
        
        # Check if the response is HTML (likely an error or sharing page)
        is_html = "html" in response.headers.get("Content-Type", "").lower()
        content_preview = response.content[:200].decode('utf-8', errors='ignore')
        
        # Check for indication that this is the file content vs. an HTML page
        if is_html:
            print("Response appears to be HTML (sharing page or error)")
            if "Sorry, access to this document has been removed" in content_preview:
                print("❌ ERROR: Access denied message detected")
            elif "This file will download automatically" in content_preview:
                print("✅ SUCCESS: Download page detected, but not direct download")
            print(f"Content preview: {content_preview[:100]}...")
            return False
        else:
            print("Response appears to be binary/file content")
            print(f"✅ SUCCESS: This format works for direct download!")
            
            # Save the working download link to a file
            with open("working_download_format.txt", "w") as f:
                f.write(f"Working download format: {description}\n")
                f.write(f"Example URL: {link}\n")
                f.write(f"Base URL + parameter: {BASE_SHARING_LINK + description}\n")
            
            return True
    
    except Exception as e:
        print(f"❌ ERROR: Exception while testing download: {str(e)}")
        return False

def main():
    print("Testing different download parameter formats for OneDrive sharing links")
    print("=================================================================")
    print(f"Base sharing link: {BASE_SHARING_LINK}")
    
    successful_formats = []
    
    # Test each format
    for param in DOWNLOAD_PARAMS:
        # Construct the full URL
        if param == "":
            download_link = BASE_SHARING_LINK
            description = "Original sharing link (no parameters)"
        elif param.startswith("/"):
            # For path-based parameters like "/download"
            download_link = BASE_SHARING_LINK + param
            description = f"Path-based format: {param}"
        else:
            # For query parameters
            download_link = BASE_SHARING_LINK + param
            description = f"Query parameter: {param}"
        
        # Test the link
        success = test_download_link(download_link, description)
        if success:
            successful_formats.append({
                "description": description,
                "parameter": param,
                "full_url": download_link
            })
    
    # Print summary
    print("\n=== SUMMARY OF RESULTS ===")
    if successful_formats:
        print(f"Found {len(successful_formats)} working download format(s):")
        for i, format_info in enumerate(successful_formats, 1):
            print(f"{i}. {format_info['description']}")
            print(f"   Parameter: '{format_info['parameter']}'")
            print(f"   Example URL: {format_info['full_url']}")
        
        print("\nRecommendation:")
        print(f"Use this format for direct downloads in your application: {successful_formats[0]['parameter']}")
    else:
        print("No direct download formats were found to work.")
        print("Recommendation: Use the sharing link without parameters and implement a solution to handle the download page.")

if __name__ == "__main__":
    main()
