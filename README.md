# JHEEM2 Interactive

Interactive Shiny application for the JHEEM (Johns Hopkins Epidemiologic and Economic Model) HIV transmission model.

## Development Setup

### After Pulling Updates from jheem_analyses

When pulling updates from the `jheem_analyses` repository, the following local changes need to be made for the interactive app to work properly:

1. **In `../jheem_analyses/use_jheem2_package_setting.R`:**
   - Change: `USE.JHEEM2.PACKAGE = F`
   - To: `USE.JHEEM2.PACKAGE = T`
   - **Why:** The interactive app requires the jheem2 package version, not the source code version

2. **In `../jheem_analyses/applications/ryan_white/ryan_white_specification.R`:**
   - Change: `load.data.manager('../../cached/ryan.white.data.manager.rdata'`
   - To: `load.data.manager('../jheem_analyses/cached/ryan.white.data.manager.rdata'`
   - **Why:** Path difference between development environments

### Quick Setup Script

A script is provided to make these changes automatically:
```bash
./setup_local_dev.sh
```

Run this script after pulling updates to `jheem_analyses`.

## Running the Application

```R
# From the jheem2_interactive directory
shiny::runApp()
```
