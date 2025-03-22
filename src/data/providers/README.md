# JHEEM Data Providers

This directory contains data provider implementations for accessing simulation files.

## Available Providers

### LocalProvider
- Uses local filesystem to access simulation files
- Default provider for development and testing
- Files are accessed from the directory specified in `simulation_root` in `base.yaml`

### OneDriveProvider
- Uses OneDrive sharing links to access simulation files
- Requires a sharing links file (JSON format)
- Downloads files to a temporary directory before loading

## Setting Up the OneDrive Provider

You can set up the OneDrive provider using the interactive setup script:

```bash
cd src/data/providers/onedrive_resources
./setup_onedrive.sh
```

This script will guide you through the process of:
1. Specifying the model version
2. Locating your simulation files
3. Setting up the OneDrive directory structure
4. Generating sharing links
5. Creating the sharing links file

The script will also help you configure the application to use the OneDrive provider.

If you prefer to do this manually, follow these steps:

1. **Generate sharing links** for simulation files using the Python script:
   ```bash
   cd src/data/providers/onedrive_resources
   python generate_sharing_links.py \
     --base-dir simulations/your-model \
     --onedrive-dir jheem/your-model \
     --model-version your-model
   ```

2. **Enable the OneDrive provider** by changing the provider setting in the configuration files:
   
   For prerun simulations in `src/ui/config/pages/prerun.yaml`:
   ```yaml
   prerun_simulations:
     provider: "onedrive"
     file_pattern: "prerun/{location}/{aspect}_{population}_{timeframe}_{intensity}.Rdata"
     config_file: "src/data/providers/onedrive_resources/onedrive_sharing_links.json"
   ```
   
   For custom simulations in `src/ui/config/pages/custom.yaml`:
   ```yaml
   custom_simulations:
     provider: "onedrive"
     file_pattern: "base/{location}_base.Rdata"
     config_file: "src/data/providers/onedrive_resources/onedrive_sharing_links.json"
   ```

## Generating Sharing Links

The `generate_sharing_links.py` script automates the process of creating OneDrive sharing links for all simulation files. Here's how it works:

1. **Authentication**: Uses Microsoft Graph API with device code authentication, which doesn't require admin approval. You'll be prompted to go to a Microsoft website and enter a code.

2. **Folder Creation**: Creates the necessary folder structure in OneDrive if it doesn't exist.

3. **File Upload**: Uploads all simulation files from your local machine to OneDrive.

4. **Link Generation**: Creates anonymous sharing links for each uploaded file.

5. **Output**: Saves all the sharing links in a JSON file that can be used by the OneDriveProvider.

### Using the Script

```bash
python generate_sharing_links.py --base-dir <local-simulation-path> --onedrive-dir <onedrive-path> --output <output-json-path>
```

**Parameters**:
- `--base-dir`: Local directory containing simulation files
- `--onedrive-dir`: OneDrive directory to store files
- `--model-version`: Model version (e.g. "ehe", "ryan-white")
- `--output`: Output JSON file for sharing links
- `--locations`: Specific locations to process (optional)
- `--scenarios`: Specific scenarios to process (optional)
- `--dry-run`: Print actions without performing them

### Requirements

The script requires Python 3 and the following packages:
```bash
pip install msal requests
```

## Sharing Links File Format

The JSON file used by the OneDriveProvider follows this format:

```json
{
  "format_version": "1.0",
  "generated_at": "2025-03-15 15:30:00",
  "model_version": "ehe",
  "simulations": {
    "C.12580_permanent_loss": {
      "location": "C.12580",
      "scenario": "permanent_loss",
      "filename": "prerun/C.12580/permanent_loss.Rdata",
      "sharing_link": "https://livejohnshopkins-my.sharepoint.com/..."
    },
    "C.12580_temporary_loss": {
      "location": "C.12580",
      "scenario": "temporary_loss",
      "filename": "prerun/C.12580/temporary_loss.Rdata",
      "sharing_link": "https://livejohnshopkins-my.sharepoint.com/..."
    },
    "C.12580_base": {
      "location": "C.12580",
      "scenario": "base",
      "filename": "base/C.12580_base.Rdata",
      "sharing_link": "https://livejohnshopkins-my.sharepoint.com/..."
    }
  }
}
```

Each entry in the `simulations` object has:
- A key that combines location and scenario (e.g., `C.12580_permanent_loss`)
- `location`: The location code (e.g., `C.12580`)
- `scenario`: The scenario name (e.g., `permanent_loss`)
- `filename`: The relative path to the simulation file
- `sharing_link`: The OneDrive sharing link with `?download=1` parameter

## How It Works

The OneDriveProvider:
1. Loads the sharing links file on initialization
2. When a simulation is requested, constructs a key based on the settings
3. Looks up the corresponding sharing link
4. Downloads the file to a temporary directory
5. Loads the simulation from the downloaded file

Downloaded files are cached temporarily to improve performance for repeated requests.

## Testing

To test the OneDrive provider:

1. Ensure the sharing links in the JSON file are valid
2. Set `provider: "onedrive"` in the configuration files
3. Run the application and try loading a simulation

If issues occur, check the R console for error messages from the provider.

## Independent Provider Configuration

The prerun and custom pages can use different providers if needed:

- **Prerun** can use OneDrive while **Custom** uses Local (or vice versa)
- Each page's configuration is loaded independently
- The provider is initialized based on the type of simulation being loaded
