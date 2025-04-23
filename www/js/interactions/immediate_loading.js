// immediate_loading.js
// Show loading indicator immediately when buttons are clicked

$(document).ready(function() {
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
  
  // Function to show the overlay
  window.showLoadingOverlay = function(pageId) {
    console.log(`[Loading Overlay] Showing for ${pageId}`);
    isLoading = true;
    hasPlotBeenRendered = false;
    
    // Center in the viewport
    $('#global-loading-overlay').css({
      'position': 'fixed',
      'top': '50%',
      'left': '50%',
      'transform': 'translate(-50%, -50%)',
      'width': '150px',
      'height': '150px',
      'display': 'flex',
      'z-index': '100000'
    });
  };
  
  // Function to hide the overlay
  window.hideLoadingOverlay = function() {
    console.log('[Loading Overlay] Hiding requested');
    
    // Only hide if we've seen a plot rendered
    if (hasPlotBeenRendered) {
      console.log('[Loading Overlay] Plot rendered, hiding overlay');
      $('#global-loading-overlay').hide();
      isLoading = false;
    } else {
      console.log('[Loading Overlay] Plot not yet rendered, delaying hide');
      // Set a timeout to check again later
      setTimeout(function() {
        if (isLoading) {
          // If we're still loading after 5 seconds, hide anyway
          console.log('[Loading Overlay] Timeout reached, forcing hide');
          $('#global-loading-overlay').hide();
          isLoading = false;
        }
      }, 5000);
    }
  };
  
  // Track plot rendering
  window.markPlotRendered = function() {
    console.log('[Loading Overlay] Plot rendered signal received');
    hasPlotBeenRendered = true;
    if (isLoading) {
      window.hideLoadingOverlay();
    }
  };
  
  // Target specific buttons that generate plots
  $('#generate_projections_prerun').on('click', function() {
    window.showLoadingOverlay('prerun');
  });
  
  $('#update_visualization_prerun').on('click', function() {
    window.showLoadingOverlay('prerun');
  });
  
  // Registered handlers for server messages
  Shiny.addCustomMessageHandler("hideLoadingOverlay", function(message) {
    console.log('[Loading Overlay] Received hide message from R');
    window.hideLoadingOverlay();
  });
  
  Shiny.addCustomMessageHandler("plotRendered", function(message) {
    console.log('[Loading Overlay] Received plot rendered message from R');
    window.markPlotRendered();
  });
  
  // Monitor plot rendering by watching DOM changes
  const observeDOM = (function(){
    const MutationObserver = window.MutationObserver || window.WebKitMutationObserver;
    
    return function(obj, callback){
      if(!obj || obj.nodeType !== 1) return; 
      
      if(MutationObserver){
        const mutationObserver = new MutationObserver(callback);
        mutationObserver.observe(obj, {childList: true, subtree: true});
        return mutationObserver;
      }
    };
  })();
  
  // Watch for plot panel changes
  observeDOM(document.body, function(mutations) {
    if (isLoading) {
      // Check if plots are rendered
      const plotElements = document.querySelectorAll('.plot-container');
      if (plotElements.length > 0) {
        console.log('[Loading Overlay] Plot detected in DOM');
        window.markPlotRendered();
      }
    }
  });
});

