#!/bin/bash

# Interactive script to set up OneDrive sharing links for JHEEM simulations
# This script guides the user through the process of generating sharing links
# for simulation files and configuring the OneDriveProvider.

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
  echo "${input:-$default}"
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
MODEL_VERSION=$(get_input_with_default "Enter the model version" "ehe")
echo ""

# Guess the base directory based on model version
DEFAULT_BASE_DIR="simulations/$MODEL_VERSION"
BASE_DIR=$(get_input_with_default "Local simulation directory" "$DEFAULT_BASE_DIR")

# Verify the base directory exists
verify_directory "$BASE_DIR" false
if [ $? -ne 0 ]; then
  echo "The specified simulation directory does not exist."
  BASE_DIR=$(get_input_with_default "Please enter a valid simulation directory" "simulations")
  verify_directory "$BASE_DIR" false
  if [ $? -ne 0 ]; then
    echo "Directory still not found. Exiting."
    exit 1
  fi
fi
echo ""

# Get OneDrive directory path
DEFAULT_ONEDRIVE_DIR="jheem/$MODEL_VERSION"
ONEDRIVE_DIR=$(get_input_with_default "OneDrive destination directory" "$DEFAULT_ONEDRIVE_DIR")
echo ""

# Get output file path
DEFAULT_OUTPUT="src/data/providers/onedrive_resources/onedrive_sharing_links.json"
OUTPUT=$(get_input_with_default "Output JSON file path" "$DEFAULT_OUTPUT")

# Verify the output directory exists or create it
OUTPUT_DIR=$(dirname "$OUTPUT")
verify_directory "$OUTPUT_DIR" true
echo ""

# Ask about locations and scenarios
PROCESS_SPECIFIC_LOCATIONS=$(get_input_with_default "Process specific locations only? (y/n)" "n")
LOCATIONS_ARG=""
if [[ "$PROCESS_SPECIFIC_LOCATIONS" == "y"* || "$PROCESS_SPECIFIC_LOCATIONS" == "Y"* ]]; then
  echo "Enter space-separated location codes (e.g., C.12580 C.37840):"
  read LOCATIONS
  if [ -n "$LOCATIONS" ]; then
    LOCATIONS_ARG="--locations $LOCATIONS"
  fi
fi
echo ""

PROCESS_SPECIFIC_SCENARIOS=$(get_input_with_default "Process specific scenarios only? (y/n)" "n")
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
DRY_RUN=$(get_input_with_default "Perform a dry run first (no actual uploads)? (y/n)" "y")
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
CONFIRM=$(get_input_with_default "Proceed with these settings? (y/n)" "y")
if [[ "$CONFIRM" != "y"* && "$CONFIRM" != "Y"* ]]; then
  echo "Setup cancelled. No changes made."
  exit 0
fi
echo ""

# Run the Python script with dry run if requested
if [ -n "$DRY_RUN_ARG" ]; then
  print_header "Dry Run"
  python3 $(dirname "$0")/generate_sharing_links.py \
    --base-dir "$BASE_DIR" \
    --onedrive-dir "$ONEDRIVE_DIR" \
    --model-version "$MODEL_VERSION" \
    --output "$OUTPUT" \
    $LOCATIONS_ARG $SCENARIOS_ARG \
    --dry-run
  
  echo ""
  PROCEED_AFTER_DRY=$(get_input_with_default "Proceed with actual upload? (y/n)" "y")
  if [[ "$PROCEED_AFTER_DRY" != "y"* && "$PROCEED_AFTER_DRY" != "Y"* ]]; then
    echo "Upload cancelled. No changes made."
    exit 0
  fi
  echo ""
fi

# Run the actual upload
print_header "Generating Sharing Links"
python3 $(dirname "$0")/generate_sharing_links.py \
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
