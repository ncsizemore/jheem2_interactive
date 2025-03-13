# JHEEM2 Interactive Deployment

This folder contains files and scripts related to the deployment of the JHEEM2 Interactive application to shinyapps.io or other hosting platforms.

## Deployment Process Overview

The JHEEM2 Interactive application has several complex dependencies and requires a careful deployment process to ensure all components work correctly in the production environment.

### Key Components

1. **deploy_shinyapps.R** - The main deployment script that orchestrates the entire process
2. **prepare_cache_manager.R** - Handles the creation of a deployment-friendly cache manager
3. **templates/cache_manager.R.template** - Template file for generating the deployment cache manager
4. **deployment_dependencies.R** - Lists all required packages for deployment (used solely for dependency detection)

## Deployment Steps

The deployment process follows these key steps:

1. **Prepare jheem2 deployment branch**
   - Creates a special branch of the jheem2 package optimized for deployment
   - Removes compiled objects and sets appropriate compiler flags
   
2. **Install jheem2 from deployment branch**
   - Temporarily installs the deployment version for bundling

3. **Prepare external dependencies**
   - Detects and copies all required source files from jheem_analyses
   - Modifies file paths to work in the deployment environment
   - Detects and copies data files referenced in the code
   - Copies the cached object directory for model functions

4. **Prepare cache_manager.R**
   - Uses a template approach to create a deployment-friendly version
   - Adds stub functions for network-dependent operations
   - Provides more robust error handling

5. **Copy cached directory**
   - Ensures all pre-computed data is available in deployment

6. **Generate deployment command**
   - Outputs the final rsconnect::deployApp() command with all necessary parameters

## Special Files and Their Purpose

- **cache_manager.R.template**: Contains simplified implementations of cache-related functions that work in the deployment environment without requiring network access or writing permissions
- **deployment_dependencies.R**: Lists all package dependencies required for deployment (not used at runtime, only for dependency detection)
- **prepare_cache_manager.R**: Converts the template into a functional cache manager for deployment

## Common Issues and Solutions

### Missing Package Dependencies
If you encounter missing package errors during deployment:
1. Add the package to `deployment_dependencies.R`
2. Redeploy the application

### Missing Data Files
If data files are missing:
1. The deployment script automatically detects and copies data files referenced in the code
2. Additionally, it copies the entire `data_files` directory to ensure all dependencies are included
3. If specific files are still missing, add them manually to the `copy_data_files()` function

### Cache-Related Errors
If you encounter errors related to cached objects:
1. Ensure the `object_for_version_cache` directory is properly copied during deployment
2. Check if the required cached objects exist in your local environment
3. If needed, run the code in `build_rw_priors.R` to generate missing cached objects

### Path-Related Errors
If you encounter path-related errors:
1. Check that file paths have been properly adjusted from `../jheem_analyses/` to `external/jheem_analyses/`
2. Verify that all referenced files are included in the deployment bundle

## Maintenance

When making changes to the application:

1. **Adding new dependencies**: Update `deployment_dependencies.R` with any new package requirements
2. **Modifying cache manager**: Update the `cache_manager.R.template` file rather than directly modifying the generated file
3. **Adding new data files**: The system should automatically detect them, but verify they're included in the deployment bundle

## Deployment Command

The final deployment command will be printed after running `deploy_shinyapps.R`. It typically includes:

```R
rsconnect::deployApp(
  appDir = "/path/to/jheem2_interactive",
  appName = "ryan-white",
  account = "jheem",
  appFiles = c(
    "app.R",
    ".Renviron",
    "deployment/deployment_dependencies.R",
    # Plus all other required files
  ),
  forceUpdate = TRUE,
  lint = FALSE
)
```

Copy and run this command to deploy the application.
