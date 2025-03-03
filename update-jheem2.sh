#!/bin/bash
# Script to update jheem2 source files

SOURCE_DIR=~/Documents/jheem/code/jheem2
TARGET_DIR=./vendor/jheem2

# Make sure target directories exist
mkdir -p ${TARGET_DIR}/R
mkdir -p ${TARGET_DIR}/src

# Copy R files
cp -r ${SOURCE_DIR}/R/* ${TARGET_DIR}/R/

# Copy C++ source files
cp -r ${SOURCE_DIR}/src/*.cpp ${TARGET_DIR}/src/
cp -r ${SOURCE_DIR}/src/*.h ${TARGET_DIR}/src/ 2>/dev/null || true  # Headers might not exist

echo "jheem2 source files updated successfully."