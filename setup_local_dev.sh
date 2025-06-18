#!/bin/bash

# Script to update jheem_analyses files for local development after git pull

echo "Setting up local development environment..."

# Update USE.JHEEM2.PACKAGE setting
echo "Updating USE.JHEEM2.PACKAGE to TRUE..."
sed -i '' 's/USE.JHEEM2.PACKAGE = F/USE.JHEEM2.PACKAGE = T/' ../jheem_analyses/use_jheem2_package_setting.R

# Update RW.DATA.MANAGER path
echo "Updating RW.DATA.MANAGER path..."
sed -i '' "s|load.data.manager('../../cached/ryan.white.data.manager.rdata'|load.data.manager('../jheem_analyses/cached/ryan.white.data.manager.rdata'|" ../jheem_analyses/applications/ryan_white/ryan_white_specification.R

echo "Local development setup complete!"
