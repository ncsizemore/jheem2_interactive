#!/bin/bash
# Bash script to migrate simulation files from network drive to local project structure
# Renames files to match expected patterns for the JHEEM2 interactive application

# Parse command line arguments
DRY_RUN=false
for arg in "$@"; do
  if [ "$arg" == "--dry-run" ] || [ "$arg" == "-d" ]; then
    DRY_RUN=true
  fi
done

# Print header based on mode
if [ "$DRY_RUN" = true ]; then
  echo -e "\e[33mRunning in DRY RUN mode - no files will be copied\e[0m"
  echo -e "\e[33mUse without the --dry-run parameter to perform actual file copying\e[0m"
  echo ""
fi

# Configuration (adjust these values as needed)
SOURCE_ROOT_PATH="/q/simulations/rw-w/final.ehe-80"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DESTINATION_ROOT_PATH="$SCRIPT_DIR/../../simulations/ryan-white"

# Ensure destination directories exist
ensure_directory_exists() {
  if [ ! -d "$1" ]; then
    if [ "$DRY_RUN" = true ]; then
      echo -e "\e[36mWould create directory: $1\e[0m"
    else
      mkdir -p "$1"
      echo -e "\e[32mCreated directory: $1\e[0m"
    fi
  fi
}

# Initialize destination structure
ensure_directory_exists "$DESTINATION_ROOT_PATH/base"
ensure_directory_exists "$DESTINATION_ROOT_PATH/prerun"

# Mapping of original file suffix to new scenario name (associative array)
declare -A SCENARIO_MAPPING
SCENARIO_MAPPING["noint"]="base"             # Base scenario for custom page
SCENARIO_MAPPING["rw.b.intr"]="brief_interruption"  # Brief interruption scenario
SCENARIO_MAPPING["rw.end"]="cessation"        # Cessation scenario
SCENARIO_MAPPING["rw.p.intr"]="prolonged_interruption"  # Prolonged interruption scenario

# Check if source path exists
if [ ! -d "$SOURCE_ROOT_PATH" ]; then
  echo -e "\e[31mError: Source path does not exist: $SOURCE_ROOT_PATH\e[0m"
  echo "Please check the path and update the script if necessary."
  exit 1
fi

# Get all location folders
LOCATION_FOLDERS=$(find "$SOURCE_ROOT_PATH" -type d -maxdepth 1 -mindepth 1)
LOCATION_COUNT=$(echo "$LOCATION_FOLDERS" | wc -l)
LOCATION_COUNT=$(echo "$LOCATION_COUNT" | tr -d ' ')  # Trim whitespace

if [ "$LOCATION_COUNT" -eq 0 ]; then
  echo -e "\e[31mNo location folders found in source directory\e[0m"
  exit 1
fi

echo -e "\e[36mFound $LOCATION_COUNT location folders in source directory\e[0m"

# Initialize counters for reporting
TOTAL_FILES=0
COPIED_FILES=0
ERROR_FILES=0
CURRENT_LOCATION=0

# Process each location folder
for LOCATION_PATH in $LOCATION_FOLDERS; do
  LOCATION_NAME=$(basename "$LOCATION_PATH")
  CURRENT_LOCATION=$((CURRENT_LOCATION + 1))
  
  echo -e "\n\e[33mProcessing location ($CURRENT_LOCATION/$LOCATION_COUNT): $LOCATION_NAME\e[0m"
  
  # Ensure prerun directory exists for this location
  ensure_directory_exists "$DESTINATION_ROOT_PATH/prerun/$LOCATION_NAME"
  
  # Get all simulation files for this location
  SIMULATION_FILES=$(find "$LOCATION_PATH" -name "*.Rdata")
  SIM_FILE_COUNT=$(echo "$SIMULATION_FILES" | grep -c ".Rdata" || echo 0)
  
  echo -e "  Found $SIM_FILE_COUNT simulation files"
  
  # Process each simulation file
  for FILE_PATH in $SIMULATION_FILES; do
    FILE_NAME=$(basename "$FILE_PATH")
    TOTAL_FILES=$((TOTAL_FILES + 1))
    
    # Extract the scenario type from filename
    SCENARIO_TYPE=""
    
    for SUFFIX in "${!SCENARIO_MAPPING[@]}"; do
      if [[ "$FILE_NAME" =~ _${SUFFIX}\.Rdata$ ]]; then
        SCENARIO_TYPE="$SUFFIX"
        break
      fi
    done
    
    if [ -z "$SCENARIO_TYPE" ]; then
      echo -e "  \e[31mUnable to determine scenario type for file: $FILE_NAME\e[0m"
      ERROR_FILES=$((ERROR_FILES + 1))
      continue
    fi
    
    # Get the mapped scenario name
    SCENARIO_NAME="${SCENARIO_MAPPING[$SCENARIO_TYPE]}"
    
    # Determine destination path based on scenario
    DESTINATION_PATH=""
    if [ "$SCENARIO_NAME" = "base" ]; then
      # Base scenario goes to base folder with _base suffix
      DESTINATION_PATH="$DESTINATION_ROOT_PATH/base/${LOCATION_NAME}_base.Rdata"
    else
      # Pre-run scenarios go to prerun/location folders
      DESTINATION_PATH="$DESTINATION_ROOT_PATH/prerun/$LOCATION_NAME/$SCENARIO_NAME.Rdata"
    fi
    
    if [ "$DRY_RUN" = true ]; then
      # In dry run mode, just show what would be copied
      echo -e "  \e[36mWould copy: $FILE_NAME -> $DESTINATION_PATH\e[0m"
      COPIED_FILES=$((COPIED_FILES + 1))
    else
      # Copy file to destination with new name
      if cp "$FILE_PATH" "$DESTINATION_PATH"; then
        echo -e "  \e[32mCopied: $FILE_NAME -> $DESTINATION_PATH\e[0m"
        COPIED_FILES=$((COPIED_FILES + 1))
      else
        echo -e "  \e[31mError copying file $FILE_NAME\e[0m"
        ERROR_FILES=$((ERROR_FILES + 1))
      fi
    fi
  done
done

# Summary
echo -e "\n\e[36m==================== SUMMARY ====================\e[0m"
echo -e "Total locations processed: $CURRENT_LOCATION"
echo -e "Total files processed: $TOTAL_FILES"
if [ "$DRY_RUN" = true ]; then
  echo -e "\e[36mFiles that would be copied: $COPIED_FILES\e[0m"
else
  echo -e "\e[32mSuccessfully copied files: $COPIED_FILES\e[0m"
fi
if [ $ERROR_FILES -gt 0 ]; then
  echo -e "\e[31mFiles with errors: $ERROR_FILES\e[0m"
fi
echo -e "\e[36m=================================================\e[0m"

# Next steps
echo -e "\n\e[33mNext steps:\e[0m"
if [ "$DRY_RUN" = true ]; then
  echo "1. Run the script without the --dry-run parameter to perform the actual file copying:"
  echo "   ./migration_script.sh"
else
  echo "1. Review the copied files to ensure they're correct"
fi
echo "2. Update the prerun.yaml configuration to match your scenarios"
echo "3. Run the OneDrive upload script to generate sharing links:"
echo "   cd src/data/providers/onedrive_resources"
echo "   python generate_sharing_links.py --base-dir simulations/ryan-white --onedrive-dir jheem/ryan-white --model-version ryan-white"
echo ""
