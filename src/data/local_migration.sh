#!/bin/bash
# Bash script to migrate simulation files from rw-w and rw-ws folders
# For use on macOS in Terminal or VSCode

# Parse command line arguments
DRY_RUN=false
for arg in "$@"; do
  if [ "$arg" == "--dry-run" ] || [ "$arg" == "-d" ]; then
    DRY_RUN=true
  fi
done

# Print header based on mode
if [ "$DRY_RUN" = true ]; then
  echo -e "\033[33mRunning in DRY RUN mode - no files will be copied\033[0m"
  echo -e "\033[33mUse without the --dry-run parameter to perform actual file copying\033[0m"
  echo ""
fi

# Configuration (adjust these values as needed)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source paths - adjust if your paths are different
RW_W_PATH="$PROJECT_ROOT/simulations/rw-w/final.ehe-80"
RW_WS_PATH="$PROJECT_ROOT/simulations/rw-ws/final.ehe-80"

# Destination path
DESTINATION_ROOT_PATH="$PROJECT_ROOT/simulations/ryan-white"

echo "Project root: $PROJECT_ROOT"
echo "Source paths:"
echo "  RW-W path: $RW_W_PATH"
echo "  RW-WS path: $RW_WS_PATH"
echo "Destination path: $DESTINATION_ROOT_PATH"
echo ""

# Ensure source paths exist
if [ ! -d "$RW_W_PATH" ]; then
  echo -e "\033[31mError: Source path does not exist: $RW_W_PATH\033[0m"
  echo "Please check the path and update the script if necessary."
  exit 1
fi

if [ ! -d "$RW_WS_PATH" ]; then
  echo -e "\033[31mError: Source path does not exist: $RW_WS_PATH\033[0m"
  echo "Please check the path and update the script if necessary."
  exit 1
fi

# Ensure destination directories exist
ensure_directory_exists() {
  if [ ! -d "$1" ]; then
    if [ "$DRY_RUN" = true ]; then
      echo -e "\033[36mWould create directory: $1\033[0m"
    else
      mkdir -p "$1"
      echo -e "\033[32mCreated directory: $1\033[0m"
    fi
  fi
}

# Initialize destination structure
ensure_directory_exists "$DESTINATION_ROOT_PATH/base"
ensure_directory_exists "$DESTINATION_ROOT_PATH/prerun"

# Mapping of original file suffix to new scenario name
declare -A SCENARIO_MAPPING
SCENARIO_MAPPING["rw.b.intr"]="brief_interruption"  # Brief interruption scenario
SCENARIO_MAPPING["rw.end"]="cessation"              # Cessation scenario
SCENARIO_MAPPING["rw.p.intr"]="prolonged_interruption"  # Prolonged interruption scenario

# Get all location folders from RW-W path (we'll use this as our main source of locations)
if ! LOCATION_FOLDERS=$(find "$RW_W_PATH" -type d -depth 1 2>/dev/null); then
  # Try with -maxdepth instead of -depth for compatibility
  LOCATION_FOLDERS=$(find "$RW_W_PATH" -type d -maxdepth 1 -mindepth 1)
fi

LOCATION_COUNT=$(echo "$LOCATION_FOLDERS" | wc -l)
LOCATION_COUNT=$(echo "$LOCATION_COUNT" | tr -d ' ')  # Trim whitespace

if [ "$LOCATION_COUNT" -eq 0 ]; then
  echo -e "\033[31mNo location folders found in source directory\033[0m"
  exit 1
fi

echo -e "\033[36mFound $LOCATION_COUNT location folders in source directory\033[0m"

# Initialize counters for reporting
TOTAL_FILES=0
COPIED_FILES=0
ERROR_FILES=0
CURRENT_LOCATION=0

# Process each location folder
for LOCATION_PATH in $LOCATION_FOLDERS; do
  LOCATION_NAME=$(basename "$LOCATION_PATH")
  CURRENT_LOCATION=$((CURRENT_LOCATION + 1))
  
  echo -e "\n\033[33mProcessing location ($CURRENT_LOCATION/$LOCATION_COUNT): $LOCATION_NAME\033[0m"
  
  # Ensure prerun directory exists for this location
  ensure_directory_exists "$DESTINATION_ROOT_PATH/prerun/$LOCATION_NAME"
  
  # STEP 1: Process the baseline file from RW-WS first
  echo -e "  Processing baseline file from RW-WS..."
  BASELINE_PATH="$RW_WS_PATH/$LOCATION_NAME"
  BASELINE_FILE=$(find "$BASELINE_PATH" -name "*_baseline.Rdata" 2>/dev/null)
  
  if [ -z "$BASELINE_FILE" ]; then
    echo -e "  \033[33mWarning: No baseline file found in RW-WS for location $LOCATION_NAME\033[0m"
    # Try to use the noint file from RW-W as fallback
    echo -e "  Looking for noint file as fallback..."
    NOINT_FILE=$(find "$LOCATION_PATH" -name "*_noint.Rdata" 2>/dev/null)
    
    if [ -n "$NOINT_FILE" ]; then
      echo -e "  \033[33mFound fallback noint file: $(basename "$NOINT_FILE")\033[0m"
      BASELINE_FILE="$NOINT_FILE"
    else
      echo -e "  \033[31mNo fallback noint file found either. Skipping base file for $LOCATION_NAME\033[0m"
      ERROR_FILES=$((ERROR_FILES + 1))
    fi
  fi
  
  # Copy the baseline file if found
  if [ -n "$BASELINE_FILE" ]; then
    TOTAL_FILES=$((TOTAL_FILES + 1))
    DESTINATION_PATH="$DESTINATION_ROOT_PATH/base/${LOCATION_NAME}_base.Rdata"
    
    if [ "$DRY_RUN" = true ]; then
      echo -e "  \033[36mWould copy baseline: $(basename "$BASELINE_FILE") -> $DESTINATION_PATH\033[0m"
      COPIED_FILES=$((COPIED_FILES + 1))
    else
      if cp "$BASELINE_FILE" "$DESTINATION_PATH"; then
        echo -e "  \033[32mCopied baseline: $(basename "$BASELINE_FILE") -> $DESTINATION_PATH\033[0m"
        COPIED_FILES=$((COPIED_FILES + 1))
      else
        echo -e "  \033[31mError copying baseline file: $(basename "$BASELINE_FILE")\033[0m"
        ERROR_FILES=$((ERROR_FILES + 1))
      fi
    fi
  fi
  
  # STEP 2: Process the scenario files from RW-W
  echo -e "  Processing scenario files from RW-W..."
  
  # Get all simulation files for this location from RW-W
  SIMULATION_FILES=$(find "$LOCATION_PATH" -name "*.Rdata" 2>/dev/null)
  SIM_FILE_COUNT=$(echo "$SIMULATION_FILES" | grep -c "\.Rdata" || echo 0)
  
  echo -e "  Found $SIM_FILE_COUNT scenario files"
  
  # Process each simulation file
  for FILE_PATH in $SIMULATION_FILES; do
    FILE_NAME=$(basename "$FILE_PATH")
    
    # Skip noint files as we're using baseline files instead
    if [[ "$FILE_NAME" == *"_noint.Rdata" ]]; then
      echo -e "  \033[90mSkipping noint file: $FILE_NAME (using baseline instead)\033[0m"
      continue
    fi
    
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
      echo -e "  \033[31mUnable to determine scenario type for file: $FILE_NAME\033[0m"
      ERROR_FILES=$((ERROR_FILES + 1))
      continue
    fi
    
    # Get the mapped scenario name
    SCENARIO_NAME="${SCENARIO_MAPPING[$SCENARIO_TYPE]}"
    
    # Determine destination path for prerun scenario
    DESTINATION_PATH="$DESTINATION_ROOT_PATH/prerun/$LOCATION_NAME/$SCENARIO_NAME.Rdata"
    
    if [ "$DRY_RUN" = true ]; then
      # In dry run mode, just show what would be copied
      echo -e "  \033[36mWould copy scenario: $FILE_NAME -> $DESTINATION_PATH\033[0m"
      COPIED_FILES=$((COPIED_FILES + 1))
    else
      # Copy file to destination with new name
      if cp "$FILE_PATH" "$DESTINATION_PATH"; then
        echo -e "  \033[32mCopied scenario: $FILE_NAME -> $DESTINATION_PATH\033[0m"
        COPIED_FILES=$((COPIED_FILES + 1))
      else
        echo -e "  \033[31mError copying scenario file: $FILE_NAME\033[0m"
        ERROR_FILES=$((ERROR_FILES + 1))
      fi
    fi
  done
done

# Summary
echo -e "\n\033[36m==================== SUMMARY ====================\033[0m"
echo -e "Total locations processed: $CURRENT_LOCATION"
echo -e "Total files processed: $TOTAL_FILES"
if [ "$DRY_RUN" = true ]; then
  echo -e "\033[36mFiles that would be copied: $COPIED_FILES\033[0m"
else
  echo -e "\033[32mSuccessfully copied files: $COPIED_FILES\033[0m"
fi
if [ $ERROR_FILES -gt 0 ]; then
  echo -e "\033[31mFiles with errors: $ERROR_FILES\033[0m"
fi
echo -e "\033[36m=================================================\033[0m"

# Next steps
echo -e "\n\033[33mNext steps:\033[0m"
if [ "$DRY_RUN" = true ]; then
  echo "1. Run the script without the --dry-run parameter to perform the actual file copying:"
  echo "   ./mac_migration.sh"
else
  echo "1. Review the copied files to ensure they're correct"
fi
echo "2. Update the prerun.yaml configuration to match your scenarios"
echo "3. Run the OneDrive upload script to generate sharing links:"
echo "   cd src/data/providers/onedrive_resources"
echo "   python generate_sharing_links.py --base-dir simulations/ryan-white --onedrive-dir jheem/ryan-white --model-version ryan-white"
echo ""
