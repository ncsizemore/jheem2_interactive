# GitHub Actions Workflows for JHEEM

This directory contains GitHub Actions workflow files for automating various tasks in the JHEEM project.

## Available Workflows

### deploy-shinyapps.yml

This workflow automates the deployment of the JHEEM interactive app to shinyapps.io.

#### Triggers

- **Tags**: Automatically runs when a tag starting with `deploy-` is pushed
  - Example: `deploy-v1.0.0`
- **Manual**: Can be triggered manually from the GitHub Actions UI

#### Workflow Steps

1. Checks out the main repository (jheem2_interactive)
2. Checks out the deployment fork of jheem_analyses (with Git LFS)
3. Sets up R and installs dependencies
4. Configures shinyapps.io credentials
5. Runs the deployment script
6. Deploys to shinyapps.io

#### Required Secrets

The following secrets must be configured in the GitHub repository settings:

- `GH_PAT`: GitHub Personal Access Token with access to the deployment repository
- `RSCONNECT_USER`: shinyapps.io account name
- `RSCONNECT_TOKEN`: shinyapps.io token
- `RSCONNECT_SECRET`: shinyapps.io secret

#### Multi-Branch Deployments

The workflow supports deploying different versions of the app from different branches:

- Each branch deploys to a different app name on shinyapps.io
- The app name is determined by the branch name

Supported branches and their corresponding app names:

| Branch | App Name | Model Type |
|--------|----------|------------|
| ryan-white | ryan-white | Ryan White |
| ehe | ehe | EHE |
| main (or other) | jheem-dev | Ryan White (default) |

#### Branch-Specific Tags

To deploy from a specific branch using tags, use the format:

```bash
# For ryan-white branch
git tag deploy-ryan-white-v1.0.0
git push origin deploy-ryan-white-v1.0.0

# For ehe branch
git tag deploy-ehe-v1.0.0
git push origin deploy-ehe-v1.0.0
```

The workflow will extract the branch name from the tag and deploy from that branch.
