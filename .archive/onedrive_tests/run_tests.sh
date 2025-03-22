#!/bin/bash

# Script to run the various OneDrive integration tests
# This makes it easier to execute the different test scripts

echo "OneDrive Integration Tests"
echo "=========================="
echo
echo "Choose a test to run:"
echo "1. PowerShell - Test creating and sharing test files"
echo "2. PowerShell - Test sharing existing simulation files"
echo "3. Python - Test Microsoft Graph API with device code flow"
echo "4. Exit"
echo

read -p "Enter your choice (1-4): " choice

case $choice in
    1)
        echo "Running PowerShell test for creating and sharing test files..."
        chmod +x ./test_graph_interactive.ps1
        pwsh -File ./test_graph_interactive.ps1
        ;;
    2)
        echo "Running PowerShell test for sharing existing simulation files..."
        chmod +x ./test_existing_files.ps1
        pwsh -File ./test_existing_files.ps1
        ;;
    3)
        echo "Running Python test with Microsoft Graph API..."
        chmod +x ./test_graph_python.py
        
        # Check if required packages are installed
        python3 -c "import msal, requests" 2>/dev/null
        if [ $? -ne 0 ]; then
            echo "Installing required Python packages..."
            pip3 install msal requests
        fi
        
        python3 ./test_graph_python.py
        ;;
    4)
        echo "Exiting."
        exit 0
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac
