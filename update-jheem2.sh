#!/bin/bash
# Script to update jheem2 source files and EHE specification

SOURCE_DIR=~/Documents/jheem/code/jheem2
EHE_SPEC_SOURCE=~/Documents/jheem/code/jheem_analyses/applications/EHE/ehe_specification.R
TARGET_DIR=./vendor/jheem2
EHE_TARGET_DIR=./vendor/jheem_analyses/applications/EHE

# Make sure target directories exist
mkdir -p ${TARGET_DIR}/R
mkdir -p ${TARGET_DIR}/src
mkdir -p ${EHE_TARGET_DIR}

# Copy R files
cp -r ${SOURCE_DIR}/R/* ${TARGET_DIR}/R/

# Copy C++ source files
cp -r ${SOURCE_DIR}/src/*.cpp ${TARGET_DIR}/src/
cp -r ${SOURCE_DIR}/src/*.h ${TARGET_DIR}/src/ 2>/dev/null || true  # Headers might not exist

# Copy EHE specification file
cp ${EHE_SPEC_SOURCE} ${EHE_TARGET_DIR}/

echo "jheem2 source files and EHE specification updated successfully."