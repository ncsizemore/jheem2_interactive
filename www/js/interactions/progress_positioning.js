// progress_positioning.js - Handles dynamic positioning of multiple progress containers
// Conservative implementation to avoid conflicts with model loading

(function () {
  // Global variables to track state
  let isInitialized = false;
  let updateInterval = null;
  // Track heights for plot, download, and simulation
  let lastHeights = { plot: 0, download: 0, simulation: 0 };
  const spacing = '1rem'; // Use a variable for spacing between containers

  // Config
  const CONFIG = {
    checkIntervalMs: 500,        // How often to check for updates (ms)
    maxUpdateCount: 100,         // Safety limit for consecutive updates
    initialDelayMs: 2000,        // Wait after page load before initializing
    modelLoadCheckIntervalMs: 500 // How often to check if model is loaded
  };

  // Wait for DOM to be fully ready
  $(document).ready(function () {
    console.log("[PROGRESS_POSITIONING] Module loaded, waiting for initialization");

    // Delay initialization to avoid conflicts with model loading
    setTimeout(function () {
      // Check if model is still loading
      const modelOverlay = $('#model-loading-overlay');
      if (modelOverlay.length > 0 && !modelOverlay.hasClass('hidden')) {
        // Model is still loading, set up interval to check when it's done
        console.log("[PROGRESS_POSITIONING] Model still loading, will initialize after load completes");

        const modelLoadCheckInterval = setInterval(function () {
          const overlay = $('#model-loading-overlay');
          if (overlay.length === 0 || overlay.hasClass('hidden')) {
            // Model loaded, we can initialize
            clearInterval(modelLoadCheckInterval);
            console.log("[PROGRESS_POSITIONING] Model loading complete, initializing positioning");
            safeInitialize();
          }
        }, CONFIG.modelLoadCheckIntervalMs);
      } else {
        // Model already loaded or no overlay found, initialize now
        console.log("[PROGRESS_POSITIONING] Initializing immediately");
        safeInitialize();
      }
    }, CONFIG.initialDelayMs);
  });

  // Safe initialization function with error handling
  function safeInitialize() {
    try {
      if (isInitialized) {
        console.log("[PROGRESS_POSITIONING] Already initialized, skipping");
        return;
      }

      // Set up interval for positioning updates
      updateInterval = setInterval(function () {
        try {
          checkAndUpdatePositions();
        } catch (e) {
          console.error("[PROGRESS_POSITIONING] Error in update interval:", e);
        }
      }, CONFIG.checkIntervalMs);

      // Add resize handler
      $(window).on('resize', debounce(function () {
        try {
          checkAndUpdatePositions();
        } catch (e) {
          console.error("[PROGRESS_POSITIONING] Error in resize handler:", e);
        }
      }, 250));

      isInitialized = true;
      console.log("[PROGRESS_POSITIONING] Initialization complete");

      // Run initial check
      checkAndUpdatePositions();

    } catch (e) {
      console.error("[PROGRESS_POSITIONING] Error during initialization:", e);
    }
  }

  // Check and update positions for containers
  function checkAndUpdatePositions() {
    // Get containers (using safe jQuery selectors)
    const plotContainer = $('#plot-progress-container');
    const downloadContainer = $('#download-progress-container');
    const simulationContainer = $('#simulation-progress-container');

    // Safety check - only proceed if all containers exist (they are created on demand)
    if (plotContainer.length === 0 || downloadContainer.length === 0 || simulationContainer.length === 0) {
      // console.log("[PROGRESS_POSITIONING] One or more containers not found, skipping update.");
      return;
    }

    // Get heights and visibility for each container
    const plotHeight = plotContainer.outerHeight(true) || 0; // Include margin
    const plotVisible = plotContainer.children().length > 0 && plotHeight > 5; // Use small threshold

    const downloadHeight = downloadContainer.outerHeight(true) || 0; // Include margin
    const downloadVisible = downloadContainer.children().length > 0 && downloadHeight > 5;

    const simulationHeight = simulationContainer.outerHeight(true) || 0; // Include margin
    const simulationVisible = simulationContainer.children().length > 0 && simulationHeight > 5;

    // Check if any height has changed significantly
    if (Math.abs(plotHeight - lastHeights.plot) > 5 ||
      Math.abs(downloadHeight - lastHeights.download) > 5 ||
      Math.abs(simulationHeight - lastHeights.simulation) > 5) {

      // Update last known heights
      lastHeights.plot = plotHeight;
      lastHeights.download = downloadHeight;
      lastHeights.simulation = simulationHeight; // Track simulation height too, though we don't base others on it

      // --- Calculate bottom offsets ---
      let plotBottom = 'var(--spacing-md)'; // Plot is always at the bottom
      let downloadBottom = plotBottom;
      let simulationBottom = plotBottom;

      if (plotVisible) {
        downloadBottom = `calc(${plotHeight}px + ${spacing})`;
      }

      if (downloadVisible) {
        // If download is visible, simulation goes above download (which is already above plot if plot is visible)
        simulationBottom = `calc(${downloadHeight}px + ${downloadBottom})`;
      } else if (plotVisible) {
        // If download not visible but plot is, simulation goes above plot
        simulationBottom = `calc(${plotHeight}px + ${spacing})`;
      }
      // If neither plot nor download is visible, simulation stays at the default bottom

      // --- Apply CSS ---
      // Plot container position is fixed by its CSS class

      // Download container position
      downloadContainer.css({
        bottom: downloadBottom,
        right: 'var(--spacing-md)' // Keep right alignment fixed
      });

      // Simulation container position
      simulationContainer.css({
        bottom: simulationBottom,
        right: 'var(--spacing-md)' // Keep right alignment fixed
      });

      // console.log(`[PROGRESS_POSITIONING] Updated positions - Plot: ${plotBottom}, Download: ${downloadBottom}, Simulation: ${simulationBottom}`);
    }
  }

  // Utility: Debounce function to prevent too many calls
  function debounce(func, wait) {
    let timeout;
    return function () {
      const context = this;
      const args = arguments;
      clearTimeout(timeout);
      timeout = setTimeout(function () {
        func.apply(context, args);
      }, wait);
    };
  }

  // Expose function for manual updates (called by other progress modules)
  window.updateProgressPositioning = function () {
    if (isInitialized) {
      // console.log("[PROGRESS_POSITIONING] Manual update triggered");
      checkAndUpdatePositions();
    } else {
      // console.log("[PROGRESS_POSITIONING] Manual update skipped, not initialized yet");
    }
  };
})();
