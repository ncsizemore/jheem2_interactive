// immediate_loading.js
// Show loading indicator immediately when buttons are clicked

$(document).ready(function () {
  // Create a global loading overlay element
  const overlay = $('<div id="global-loading-overlay" class="global-loading-overlay">' +
    '<div class="loading-content">' +
    '<div class="loading-spinner"></div>' +
    '<span>Generating plot...</span>' +
    '</div></div>');

  // Add it to the body
  $('body').append(overlay);

  // Track if we're actively loading
  let isLoading = false;
  let hasPlotBeenRendered = false;
  let renderCycle = 0; // Track render cycles
  let currentCycle = 0; // Track the specific cycle for the current loading operation

  // Function to show the overlay
  // Added isUpdate and cycleInfo parameters (cycleInfo currently unused but planned)
  window.showLoadingOverlay = function (pageId, isUpdate = false, cycleInfo = null) {
    renderCycle++;
    currentCycle = renderCycle; // Store the cycle number for this specific operation
    console.log(`[Loading Overlay] Starting render cycle ${currentCycle} for ${pageId}. Is update: ${isUpdate}`);

    isLoading = true;
    hasPlotBeenRendered = false; // Reset plot rendered flag for the new cycle

    // Center and show the overlay
    $('#global-loading-overlay').css({
      'position': 'fixed',
      'top': '50%',
      'left': '50%',
      'transform': 'translate(-50%, -50%)',
      'width': '150px',
      'height': '150px',
      'display': 'flex', // Make sure it's visible
      'z-index': '100000'
    }).show(); // Explicitly show it

    // Add a timeout specific to this render cycle
    const timeoutCycle = currentCycle; // Capture cycle number for timeout closure
    setTimeout(function () {
      // Only hide if we are *still* in the same loading cycle and haven't rendered
      if (isLoading && renderCycle === timeoutCycle && !hasPlotBeenRendered) {
        console.log(`[Loading Overlay] Render cycle ${timeoutCycle} timed out after 30s. Forcing hide.`);
        $('#global-loading-overlay').hide();
        isLoading = false;
      } else if (renderCycle !== timeoutCycle) {
        console.log(`[Loading Overlay] Timeout for cycle ${timeoutCycle} ignored, new cycle ${renderCycle} started.`);
      }
    }, 30000); // 30 seconds max loading time
  };

  // Function to hide the overlay
  window.hideLoadingOverlay = function () {
    // Check if we are currently in a loading state AND the plot has been marked as rendered
    if (isLoading && hasPlotBeenRendered) {
      console.log(`[Loading Overlay] Plot rendered for cycle ${currentCycle}, hiding overlay.`);
      $('#global-loading-overlay').hide();
      isLoading = false;
    } else if (isLoading && !hasPlotBeenRendered) {
      console.log(`[Loading Overlay] Hide requested for cycle ${currentCycle}, but plot not yet marked as rendered. Waiting.`);
      // Do nothing, wait for plot rendered signal or timeout
    } else {
      // Not loading or already hidden
      console.log(`[Loading Overlay] Hide requested but not currently loading or already hidden.`);
    }
  };

  // Track plot rendering - called by message handler or DOM observer
  window.markPlotRendered = function () {
    // Only mark if we are actively loading
    if (isLoading) {
      console.log(`[Loading Overlay] Plot rendered signal received/detected for cycle ${currentCycle}.`);
      hasPlotBeenRendered = true;
      // Attempt to hide immediately now that the condition is met
      window.hideLoadingOverlay();
    } else {
      console.log(`[Loading Overlay] Plot rendered signal received/detected but not currently loading (Cycle ${currentCycle}). Ignoring.`);
    }
  };

  // Target specific buttons that generate plots across different pages (excluding #generate_custom)
  $('#generate_projections_prerun, #update_visualization_prerun').on('click', function (event) {
    // Determine page or context if needed, for now using 'prerun' as default
    // We could potentially get the page context from the button's attributes or parent elements if necessary
    const pageId = 'prerun'; // Or determine dynamically
    console.log(`[Loading Overlay] Button clicked: #${event.currentTarget.id}. Triggering overlay for page: ${pageId}`);
    window.showLoadingOverlay(pageId);
  });

  // NOTE: #generate_custom click handler removed - it will be triggered by simulation completion message instead.
  // REMOVED old separate handlers:
  // $('#generate_projections_prerun').on('click', ...);
  // $('#update_visualization_prerun').on('click', ...);

  // Registered handlers for server messages
  // REMOVED: Shiny.addCustomMessageHandler("hideLoadingOverlay", ...);

  Shiny.addCustomMessageHandler("plotRendered", function (message) {
    console.log(`[Loading Overlay] Received 'plotRendered' message from R for cycle ${currentCycle}`);
    window.markPlotRendered(); // Mark as rendered and attempt hide
  });

  // Handler for starting an update cycle explicitly from R
  Shiny.addCustomMessageHandler("startPlotUpdate", function (message) {
    console.log(`[Loading Overlay] Received 'startPlotUpdate' message from R. Cycle info: ${message.cycle}`);
    // Assuming 'prerun' is the relevant page ID for now
    // Pass true for isUpdate, and the cycle info from R (though not used in showLoadingOverlay yet)
    window.showLoadingOverlay('prerun', true, message.cycle);
  });

  // Monitor plot rendering by watching DOM changes
  const observeDOM = (function () {
    const MutationObserver = window.MutationObserver || window.WebKitMutationObserver;

    return function (obj, callback) {
      if (!obj || obj.nodeType !== 1) return;

      if (MutationObserver) {
        const mutationObserver = new MutationObserver(callback);
        mutationObserver.observe(obj, { childList: true, subtree: true });
        return mutationObserver;
      }
    };
  })();

  // Watch for plot panel changes
  // Function to check if a plot is actually rendered in the DOM
  function detectPlotRenderedInDOM() {
    // Check for ggplot2 (SVG inside the output container)
    const ggplotSVG = document.querySelector('.main-panel-plot .plotOutput svg.ggplot');
    if (ggplotSVG) {
      // Basic check: does the SVG have dimensions? Rendered SVGs usually do.
      const rect = ggplotSVG.getBoundingClientRect();
      if (rect.width > 1 && rect.height > 1) {
        console.log('[Loading Overlay] ggplot SVG detected in DOM with dimensions.');
        return true;
      }
    }

    // Check for plotly (specific structure)
    const plotlyDiv = document.querySelector('.main-panel-plot .plotly-container .plot-container');
    if (plotlyDiv && plotlyDiv.children.length > 0) {
      // Basic check: does the plotly container have child elements?
      console.log('[Loading Overlay] Plotly container detected in DOM with children.');
      return true;
    }

    // Add checks for other plot types if necessary

    return false;
  }

  // Watch for plot panel changes using the improved detection
  observeDOM(document.body, function (mutations) {
    // Only check if we are actively loading and haven't marked the plot as rendered yet for this cycle
    if (isLoading && !hasPlotBeenRendered) {
      if (detectPlotRenderedInDOM()) {
        console.log(`[Loading Overlay] Plot detected in DOM for cycle ${currentCycle}.`);
        window.markPlotRendered(); // Mark as rendered and attempt hide
      }
    }
  });
});
