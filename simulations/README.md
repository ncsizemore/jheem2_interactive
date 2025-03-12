# JHEEM2 Simulations Directory

## Overview

This directory contains simulation files used by different versions of the JHEEM2 model. Since simulation files are large and not suitable for version control, they are not included in the Git repository. This README explains how to set up and use the simulation directory structure.

## Directory Structure

The simulations are organized by model version, with each version having its own subdirectory:

```
simulations/
├── main/                  # Main branch simulations
│   ├── base/              # Base simulations for custom interventions
│   │   └── C.12580_base.Rdata
│   ├── prerun/            # Pre-run simulation results
│   │   └── C.12580/
│   │       └── various_simsets.Rdata
│   └── test/              # Test simulations (smaller files for testing)
│       ├── base/
│       └── prerun/
└── ryan-white/            # Ryan White model simulations
    ├── base/              # Base simulations for custom interventions
    │   └── C.12580_base.Rdata
    ├── prerun/            # Pre-run simulation results
    │   └── C.12580/
    │       ├── permanent_loss.Rdata
    │       └── temporary_loss.Rdata
    └── test/              # Test simulations for Ryan White model
        ├── base/
        └── prerun/
```

## Configuration

The model specifies which simulation directory to use via the `simulation_root` setting in `src/ui/config/base.yaml`:

```yaml
# Simulation directory configuration
simulation_root: "simulations/ryan-white"  # Root directory for simulation files
```

This allows different branches to use different simulation files without conflicts.

## Setting Up Your Environment

1. **Create the directory structure** for the model version you're working on:

   ```
   mkdir -p simulations/ryan-white/{base,prerun/C.12580,test/{base,prerun/C.12580}}
   ```

2. **Place simulation files** in the appropriate directories:
   - Base simulations: `simulations/<model>/base/C.XXXXX_base.Rdata`
   - Pre-run simulations: `simulations/<model>/prerun/C.XXXXX/<scenario>.Rdata`
   - Test simulations: `simulations/<model>/test/...`

3. **Update the configuration** in `src/ui/config/base.yaml` to point to your model directory:
   ```yaml
   simulation_root: "simulations/<your-model>"
   ```

## Ryan White Model Simsets

The Ryan White model uses the following simsets:

1. **No Intervention** (`noint`): Base simset for running custom interventions
   - Path: `simulations/ryan-white/base/C.12580_base.Rdata`

2. **Permanent Ryan White Loss** (`loseRW`): Pre-run simset for permanent loss of funding
   - Path: `simulations/ryan-white/prerun/C.12580/permanent_loss.Rdata`

3. **Temporary Ryan White Loss** (`temploseRW`): Pre-run simset for temporary loss until 2029
   - Path: `simulations/ryan-white/prerun/C.12580/temporary_loss.Rdata`

## Switching Between Models

When switching between different model branches, be sure to update the `simulation_root` setting in the configuration to point to the appropriate directory.

## Test Mode

Test mode uses smaller simulation files for faster loading during development. To enable test mode, set `testing.enabled: true` in `src/ui/config/defaults.yaml`. The test files should be placed in the `test/` subdirectory of your model's simulation root.
