// progress_positioning.js - Handles dynamic positioning of multiple progress containers
// Conservative implementation to avoid conflicts with model loading

(function() {
  // Global variables to track state
  let isInitialized = false;
  let updateInterval = null;
  let lastHeights = { download: 0, simulation: 0 };
  
  // Config
  const CONFIG = {
    checkIntervalMs: 500,        // How often to check for updates (ms)
    maxUpdateCount: 100,         // Safety limit for consecutive updates 
    initialDelayMs: 2000,        // Wait after page load before initializing
    modelLoadCheckIntervalMs: 500 // How often to check if model is loaded
  };
  
  // Wait for DOM to be fully ready
  $(document).ready(function() {
    console.log("[PROGRESS_POSITIONING] Module loaded, waiting for initialization");
    
    // Delay initialization to avoid conflicts with model loading
    setTimeout(function() {
      // Check if model is still loading
      const modelOverlay = $('#model-loading-overlay');
      if (modelOverlay.length > 0 && !modelOverlay.hasClass('hidden')) {
        // Model is still loading, set up interval to check when it's done
        console.log("[PROGRESS_POSITIONING] Model still loading, will initialize after load completes");
        
        const modelLoadCheckInterval = setInterval(function() {
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
      updateInterval = setInterval(function() {
        try {
          checkAndUpdatePositions();
        } catch (e) {
          console.error("[PROGRESS_POSITIONING] Error in update interval:", e);
        }
      }, CONFIG.checkIntervalMs);
      
      // Add resize handler
      $(window).on('resize', debounce(function() {
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
    const downloadContainer = $('#download-progress-container');
    const simulationContainer = $('#simulation-progress-container');
    
    // Safety check - only proceed if both containers exist
    if (downloadContainer.length === 0 || simulationContainer.length === 0) {
      return;
    }
    
    // Get heights and visibility
    const downloadHeight = downloadContainer.outerHeight() || 0;
    const downloadVisible = downloadContainer.children().length > 0 && downloadHeight > 0;
    
    // Only update if heights have changed significantly
    if (Math.abs(downloadHeight - lastHeights.download) > 5) {
      lastHeights.download = downloadHeight;
      
      // Reset to default position
      simulationContainer.css({
        bottom: 'var(--spacing-md)',
        right: 'var(--spacing-md)'
      });
      
      // Update position if download container is visible
      if (downloadVisible) {
        simulationContainer.css({
          bottom: `calc(${downloadHeight}px + 1rem)`
        });
      }
    }
  }
  
  // Utility: Debounce function to prevent too many calls
  function debounce(func, wait) {
    let timeout;
    return function() {
      const context = this;
      const args = arguments;
      clearTimeout(timeout);
      timeout = setTimeout(function() {
        func.apply(context, args);
      }, wait);
    };
  }
  
  // Expose function for manual updates
  window.updateProgressPositioning = function() {
    if (isInitialized) {
      checkAndUpdatePositions();
    }
  };
})();
