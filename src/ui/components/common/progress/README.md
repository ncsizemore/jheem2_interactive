# Simulation Progress Tracking

## Overview

The simulation progress tracking system provides real-time feedback on the progress of running custom interventions. It uses the jheem2 package's listener functionality to receive progress updates directly from the simulation engine and displays them to the user in a consistent UI.

## Architecture

### Components

1. **State Management Extensions (`src/ui/state/types.R`)**:
   - Added `progress` field to simulation state structure
   - Created helper functions for progress state creation and validation

2. **UI Messenger Communication (`src/ui/messaging/ui_messenger.R`)**:
   - Added methods for direct simulation progress communication
   - Bypasses Shiny's reactive system when the main thread is blocked

3. **Simulation Runner Modifications (`src/core/simulation/runner.R`)**:
   - Updated to accept progress callback functions
   - Passes callback to intervention run method

4. **Simulation Adapter Integration (`src/adapters/simulation_adapter.R`)**:
   - Creates and manages progress callbacks
   - Updates simulation state with progress information
   - Sends direct UI updates through the UI messenger

5. **Progress UI Components (`src/ui/components/common/progress/`)**:
   - Shiny module for progress display
   - Consistent styling with download progress

### Dual Update Approach

The system follows a dual approach for updating the UI:

1. **State Store Updates**: 
   - Maintains the standard architectural pattern
   - Keeps simulation progress data in the central state
   - Will support future transition to more modern UI frameworks

2. **Direct UI Messaging**:
   - Bypasses Shiny's reactive system limitations
   - Provides real-time updates when the main R thread is blocked
   - Works around a fundamental limitation in Shiny's reactivity model

This approach ensures users get real-time feedback while maintaining architectural consistency.

## Implementation Details

### Progress State Structure

The progress state is stored in the simulation state and includes:
- `current`: Current simulation index
- `total`: Total number of simulations
- `percentage`: Calculated progress percentage (0-100)
- `done`: Whether the simulation is complete
- `last_updated`: Timestamp of the last update

### Listener Function

The listener function conforms to jheem2's required interface:
```r
function(index, total, done) {
  # Update progress state
  # index: Current simulation index
  # total: Total number of simulations
  # done: Whether the current simulation is complete
}
```

### Session Management

The SimulationAdapter stores sessions by page ID when they're registered, which allows it to access the UI messenger later during simulation runs. This approach avoids direct dependencies on the global session object.

## Usage

The progress tracking is automatically enabled for all custom interventions. No additional configuration is required to use it.

## Future Improvements

1. **Transition to Pure State Management**:
   - Once the application adopts a more modern framework that doesn't block the main thread
   - The direct UI messaging can be removed in favor of pure state-based updates

2. **Progress Visualization Enhancements**:
   - Add estimated time remaining
   - Show more detailed progress information for complex simulations

3. **Cancellation Support**:
   - Add ability to cancel running simulations
