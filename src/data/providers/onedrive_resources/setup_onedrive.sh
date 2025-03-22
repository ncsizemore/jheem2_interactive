#!/bin/bash

# Interactive script to set up OneDrive sharing links for JHEEM simulations
# This script guides the user through the process of generating sharing links
# for simulation files and configuring the OneDriveProvider.

# Usage: Run this script from any location with:
#   /path/to/setup_onedrive.sh
#   OR
#   cd /path/to/project/root && ./src/data/providers/onedrive_resources/setup_onedrive.sh

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# Find project root by searching upward
find_project_root() {
  local dir="$1"
  # Keep going up until we find the project root
  while [ "$dir" != "/" ]; do
    # Check for key directories that would indicate this is the project root
    if [ -d "$dir/src" ] && [ -d "$dir/src/data" ] && [ -d "$dir/src/data/providers" ]; then
      echo "$dir"
      return 0
    fi
    # Go up one directory
    dir="$(dirname "$dir")"
  done
  # If we get here, we didn't find it
  return 1
}

# Try to find project root from various starting points
PROJECT_ROOT=""
# Try starting from the script directory
PROJECT_ROOT=$(find_project_root "$SCRIPT_DIR")
# If not found, try the current directory
if [ -z "$PROJECT_ROOT" ]; then
  PROJECT_ROOT=$(find_project_root "$(pwd)")
fi

# Check if we found the project root
if [ -z "$PROJECT_ROOT" ]; then
  echo "Error: Could not locate project root."
  echo "Please run this script from the project root, or a directory within the project."
  exit 1
fi

# Change to project root directory
cd "$PROJECT_ROOT"
echo "Working from project root: $PROJECT_ROOT"

# Function to display a colorful header
print_header() {
  echo -e "\033[1;36m===== $1 =====\033[0m"
}

# Function to get user input with a default value
get_input_with_default() {
  local prompt="$1"
  local default="$2"
  local input
  
  echo -n -e "$prompt [\033[1;33m$default\033[0m]: "
  read input
  
  if [ -z "$input" ]; then
    echo "$default"
  else
    echo "$input"
  fi
}

# Function to verify a directory exists
verify_directory() {
  local dir="$1"
  local create_if_missing="$2"
  
  if [ ! -d "$dir" ]; then
    if [ "$create_if_missing" = "true" ]; then
      echo "Directory does not exist. Creating it now..."
      mkdir -p "$dir"
      if [ $? -ne 0 ]; then
        echo "Failed to create directory: $dir"
        return 1
      fi
    else
      echo "Directory does not exist: $dir"
      return 1
    fi
  fi
  return 0
}

# Clear the screen and display welcome message
clear
print_header "JHEEM OneDrive Setup"
echo "This script will help you generate OneDrive sharing links for JHEEM simulation files."
echo "You will need Python with the 'msal' and 'requests' packages installed."
echo ""
echo "Python requirements can be installed with: pip install msal requests"
echo ""

# Check if Python is available
if ! command -v python3 &> /dev/null; then
  echo "Python 3 is not installed or not in your PATH. Please install Python 3 and try again."
  exit 1
fi

# Check if required packages are installed
echo "Checking required Python packages..."
python3 -c "import msal, requests" 2>/dev/null
if [ $? -ne 0 ]; then
  echo "Required Python packages not found. Please install with:"
  echo "pip install msal requests"
  exit 1
fi

echo "Required packages are installed."
echo ""

# Get model version
print_header "Model Version"
echo "Examples: ehe, ryan-white"
echo -n "Enter the model version [ehe]: "
read MODEL_VERSION
MODEL_VERSION=${MODEL_VERSION:-ehe}
echo ""

# Guess the base directory based on model version
DEFAULT_BASE_DIR="$PROJECT_ROOT/simulations/$MODEL_VERSION"
echo -n "Local simulation directory [$DEFAULT_BASE_DIR]: "
read BASE_DIR
BASE_DIR=${BASE_DIR:-$DEFAULT_BASE_DIR}

# Verify the base directory exists
verify_directory "$BASE_DIR" false
if [ $? -ne 0 ]; then
  echo "The specified simulation directory does not exist."
  echo -n "Please enter a valid simulation directory [$PROJECT_ROOT/simulations]: "
  read BASE_DIR
  BASE_DIR=${BASE_DIR:-"$PROJECT_ROOT/simulations"}
  verify_directory "$BASE_DIR" false
  if [ $? -ne 0 ]; then
    echo "Directory still not found. Exiting."
    exit 1
  fi
fi
echo ""

# Get OneDrive directory path
DEFAULT_ONEDRIVE_DIR="jheem/$MODEL_VERSION"
echo -n "OneDrive destination directory [$DEFAULT_ONEDRIVE_DIR]: "
read ONEDRIVE_DIR
ONEDRIVE_DIR=${ONEDRIVE_DIR:-$DEFAULT_ONEDRIVE_DIR}
echo ""

# Get output file path
DEFAULT_OUTPUT="$SCRIPT_DIR/onedrive_sharing_links.json"
echo -n "Output JSON file path [$DEFAULT_OUTPUT]: "
read OUTPUT
OUTPUT=${OUTPUT:-$DEFAULT_OUTPUT}

# Verify the output directory exists or create it
OUTPUT_DIR=$(dirname "$OUTPUT")
verify_directory "$OUTPUT_DIR" true
echo ""

# Ask about locations and scenarios
echo -n "Process specific locations only? (y/n) [n]: "
read PROCESS_SPECIFIC_LOCATIONS
LOCATIONS_ARG=""
if [[ "$PROCESS_SPECIFIC_LOCATIONS" == "y"* || "$PROCESS_SPECIFIC_LOCATIONS" == "Y"* ]]; then
  echo "Enter space-separated location codes (e.g., C.12580 C.37840):"
  read LOCATIONS
  if [ -n "$LOCATIONS" ]; then
    LOCATIONS_ARG="--locations $LOCATIONS"
  fi
fi
echo ""

echo -n "Process specific scenarios only? (y/n) [n]: "
read PROCESS_SPECIFIC_SCENARIOS
SCENARIOS_ARG=""
if [[ "$PROCESS_SPECIFIC_SCENARIOS" == "y"* || "$PROCESS_SPECIFIC_SCENARIOS" == "Y"* ]]; then
  echo "Enter space-separated scenario names (e.g., permanent_loss temporary_loss):"
  read SCENARIOS
  if [ -n "$SCENARIOS" ]; then
    SCENARIOS_ARG="--scenarios $SCENARIOS"
  fi
fi
echo ""

# Ask about dry run
echo -n "Perform a dry run first (no actual uploads)? (y/n) [y]: "
read DRY_RUN
DRY_RUN=${DRY_RUN:-y}
DRY_RUN_ARG=""
if [[ "$DRY_RUN" == "y"* || "$DRY_RUN" == "Y"* ]]; then
  DRY_RUN_ARG="--dry-run"
fi

# Display summary
print_header "Summary"
echo "Model version: $MODEL_VERSION"
echo "Local directory: $BASE_DIR"
echo "OneDrive directory: $ONEDRIVE_DIR"
echo "Output file: $OUTPUT"
if [ -n "$LOCATIONS_ARG" ]; then
  echo "Locations: $LOCATIONS"
else
  echo "Locations: All available"
fi
if [ -n "$SCENARIOS_ARG" ]; then
  echo "Scenarios: $SCENARIOS"
else
  echo "Scenarios: All available"
fi
if [ -n "$DRY_RUN_ARG" ]; then
  echo "Dry run: Yes (no actual uploads)"
else
  echo "Dry run: No (will perform actual uploads)"
fi
echo ""

# Confirm before proceeding
echo -n "Proceed with these settings? (y/n) [y]: "
read CONFIRM
CONFIRM=${CONFIRM:-y}
if [[ "$CONFIRM" != "y"* && "$CONFIRM" != "Y"* ]]; then
  echo "Setup cancelled. No changes made."
  exit 0
fi
echo ""

# Run the Python script with dry run if requested
if [ -n "$DRY_RUN_ARG" ]; then
  print_header "Dry Run"
  python3 "$SCRIPT_DIR/generate_sharing_links.py" \
    --base-dir "$BASE_DIR" \
    --onedrive-dir "$ONEDRIVE_DIR" \
    --model-version "$MODEL_VERSION" \
    --output "$OUTPUT" \
    $LOCATIONS_ARG $SCENARIOS_ARG \
    --dry-run
  
  echo ""
  echo -n "Proceed with actual upload? (y/n) [y]: "
  read PROCEED_AFTER_DRY
  PROCEED_AFTER_DRY=${PROCEED_AFTER_DRY:-y}
  if [[ "$PROCEED_AFTER_DRY" != "y"* && "$PROCEED_AFTER_DRY" != "Y"* ]]; then
    echo "Upload cancelled. No changes made."
    exit 0
  fi
  echo ""
fi

# Run the actual upload
print_header "Generating Sharing Links"
python3 "$SCRIPT_DIR/generate_sharing_links.py" \
  --base-dir "$BASE_DIR" \
  --onedrive-dir "$ONEDRIVE_DIR" \
  --model-version "$MODEL_VERSION" \
  --output "$OUTPUT" \
  $LOCATIONS_ARG $SCENARIOS_ARG

# Check if the JSON file was created
if [ -f "$OUTPUT" ]; then
  print_header "Success"
  echo "Sharing links have been generated and saved to:"
  echo "$OUTPUT"
  echo ""
  echo "To use the OneDrive provider, update the configuration in:"
  echo "  src/ui/config/pages/prerun.yaml"
  echo "  src/ui/config/pages/custom.yaml"
  echo ""
  echo "Change the provider setting in each file to:"
  echo "  provider: \"onedrive\""
  echo "  config_file: \"$OUTPUT\""
else
  print_header "Error"
  echo "Failed to generate sharing links. Check the error messages above."
fi

echo ""
echo "Setup complete. Thank you for using the JHEEM OneDrive Setup tool."
