// simulation_progress.js - Handles simulation progress display in UI

// Wait for document ready
$(document).ready(function() {
  const initTimestamp = new Date().toISOString();
  console.log(`[${initTimestamp}] Simulation progress module initialized`);
  
  // Register custom message handlers for Shiny
  Shiny.addCustomMessageHandler("simulation_progress_start", function(data) {
    const timestamp = new Date().toISOString();
    console.log(`[${timestamp}] Simulation progress START received:`, data);
    
    // Call the createOrUpdateProgressItem function
    try {
      console.log(`[${timestamp}] Ensuring container exists before creating progress item`);
      ensureContainer();
      console.log(`[${timestamp}] Creating progress item for simulation ${data.id}`);
      createOrUpdateProgressItem(data);
    } catch (e) {
      console.error(`[${timestamp}] ERROR in simulation_progress_start handler:`, e);
    }
  });
  
  // Register custom message handler for simulation progress updates
  Shiny.addCustomMessageHandler("simulation_progress_update", function(data) {
    const timestamp = new Date().toISOString();
    console.log(`[${timestamp}] Simulation progress UPDATE received:`, data);
    
    try {
      // Ensure container exists
      ensureContainer();
      
      // Process based on action type
      switch(data.action) {
        case "start":
          console.log(`[${timestamp}] Processing START action`);
          createOrUpdateProgressItem(data);
          break;
        case "update":
          console.log(`[${timestamp}] Processing UPDATE action: ${data.percent}%`);
          updateProgressItem(data);
          break;
        case "complete":
          console.log(`[${timestamp}] Processing COMPLETE action`);
          completeProgressItem(data);
          break;
        case "error":
          console.log(`[${timestamp}] Processing ERROR action`);
          errorProgressItem(data);
          break;
        default:
          console.warn(`[${timestamp}] Unknown action type: ${data.action}`);
      }
    } catch (e) {
      console.error(`[${timestamp}] ERROR in simulation_progress_update handler:`, e);
    }
  });
  
  // Register message handler for completion
  Shiny.addCustomMessageHandler("simulation_progress_complete", function(data) {
    const timestamp = new Date().toISOString();
    console.log(`[${timestamp}] Simulation progress COMPLETE received:`, data);
    
    try {
      ensureContainer();
      completeProgressItem(data);
    } catch (e) {
      console.error(`[${timestamp}] ERROR in simulation_progress_complete handler:`, e);
    }
  });
  
  // Register message handler for errors
  Shiny.addCustomMessageHandler("simulation_progress_error", function(data) {
    const timestamp = new Date().toISOString();
    console.log(`[${timestamp}] Simulation progress ERROR received:`, data);
    
    try {
      ensureContainer();
      errorProgressItem(data);
    } catch (e) {
      console.error(`[${timestamp}] ERROR in simulation_progress_error handler:`, e);
    }
  });
  
  // Ensure container exists
  function ensureContainer() {
    const container = $('#simulation-progress-container');
    if (container.length === 0) {
      $('body').append('<div id="simulation-progress-container" class="simulation-progress-container"></div>');
    }
  }
  
  // Create or update a progress item
  function createOrUpdateProgressItem(data) {
    // Make sure we have a valid ID
    if (!data.id) {
      console.error("ERROR: Missing ID in simulation data");
      return;
    }
    
    // Ensure ID is string format
    const id = String(data.id);
    
    // Check if item exists
    const progressItem = $(`#simulation-${id}`);
    
    // Description default if not provided
    const description = data.description || "Running Intervention";
    
    if (progressItem.length === 0) {
      // Create new progress item
      const newItem = `
        <div id="simulation-${id}" class="simulation-progress-item">
          <span class="progress-close">&times;</span>
          <h4>${description}</h4>
          <div class="simulation-progress-text">Starting simulation...</div>
          <div class="simulation-progress-bar">
            <div class="simulation-progress-bar-inner" style="width:5%;"></div>
          </div>
        </div>
      `;
      
      // Append the new item
      $('#simulation-progress-container').append(newItem);
      
      // Add click handler for close button
      $(`#simulation-${id} .progress-close`).on('click', function() {
        $(`#simulation-${id}`).addClass('fadeout');
        setTimeout(function() {
          $(`#simulation-${id}`).remove();
        }, 300);
      });
    } else {
      // Reset existing progress item
      progressItem.removeClass('complete error fadeout');
      progressItem.find('.simulation-progress-text').text('Starting simulation...');
      progressItem.find('.simulation-progress-bar-inner').css('width', '5%');
    }
  }
  
  // Update progress on an existing item
  function updateProgressItem(data) {
    // Ensure ID is string format
    const id = String(data.id);
    
    // Check if element exists first
    const progressItem = $(`#simulation-${id}`);
    
    // If element doesn't exist, create it first (might have missed start message)
    if (progressItem.length === 0) {
      createOrUpdateProgressItem(data);
      
      // Get the newly created element
      const newItem = $(`#simulation-${id}`);
      if (newItem.length > 0) {
        // Update progress bar
        newItem.find('.simulation-progress-bar-inner').css('width', `${data.percent}%`);
        
        // Display current/total if available
        if (data.current && data.total) {
          newItem.find('.simulation-progress-text').text(`Running simulation: ${data.current} of ${data.total} (${data.percent}%)`);
        } else {
          newItem.find('.simulation-progress-text').text(`Running: ${data.percent}%`);
        }
      }
      return;
    }
    
    // Update progress bar
    progressItem.find('.simulation-progress-bar-inner').css('width', `${data.percent}%`);
    
    // Display current/total if available
    if (data.current && data.total) {
      progressItem.find('.simulation-progress-text').text(`Running simulation: ${data.current} of ${data.total} (${data.percent}%)`);
    } else {
      progressItem.find('.simulation-progress-text').text(`Running: ${data.percent}%`);
    }
  }
  
  // Mark item as complete
  function completeProgressItem(data) {
    // Ensure ID is string format
    const id = String(data.id);
    
    // Check if element exists first
    const progressItem = $(`#simulation-${id}`);
    
    // If element doesn't exist, create it first (might have missed start message)
    if (progressItem.length === 0) {
      createOrUpdateProgressItem(data);
    }
    
    // Get the element again after ensuring it exists
    const completingItem = $(`#simulation-${id}`);
    if (completingItem.length > 0) {
      // Mark as complete
      completingItem.addClass('complete');
      completingItem.find('.simulation-progress-text').text('Simulation complete');
      completingItem.find('.simulation-progress-bar-inner').css('width', '100%');
      
      // Auto-remove after 5 seconds
      setTimeout(function() {
        completingItem.addClass('fadeout');
        setTimeout(function() {
          completingItem.remove();
        }, 300);
      }, 5000);
    }
  }
  
  // Mark item as error
  function errorProgressItem(data) {
    // Ensure ID is string format
    const id = String(data.id);
    
    // Check if element exists first
    const progressItem = $(`#simulation-${id}`);
    
    // If element doesn't exist, create it first (might have missed start message)
    if (progressItem.length === 0) {
      createOrUpdateProgressItem(data);
    }
    
    // Get the element again after ensuring it exists
    const errorItem = $(`#simulation-${id}`);
    if (errorItem.length > 0) {
      // Mark as error
      errorItem.addClass('error');
      errorItem.find('.simulation-progress-text').text(`Error: ${data.message}`);
      
      // Auto-remove after 10 seconds
      setTimeout(function() {
        errorItem.addClass('fadeout');
        setTimeout(function() {
          errorItem.remove();
        }, 300);
      }, 10000);
    }
  }
});
