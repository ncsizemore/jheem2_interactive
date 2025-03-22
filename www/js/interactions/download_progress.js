// download_progress.js - Handles download progress display in UI with state management

// Wait for document ready
$(document).ready(function() {
  const initTimestamp = new Date().toISOString();
  console.log(`[${initTimestamp}] Download progress module initialized`);
  
  // Register custom message handlers for Shiny with enhanced logging
  Shiny.addCustomMessageHandler("download_progress_start", function(data) {
    const timestamp = new Date().toISOString();
    console.log(`[${timestamp}] Download progress START received:`, data);
    console.log(`[${timestamp}] START data - id type: ${typeof data.id}`);
    console.log(`[${timestamp}] START data - id value: ${data.id}`);
    console.log(`[${timestamp}] START data - filename value: ${data.filename}`);
    if (data.trace_id) console.log(`[${timestamp}] START data - trace_id: ${data.trace_id}`);
    
    // Call the createOrUpdateProgressItem function
    try {
      console.log(`[${timestamp}] Ensuring container exists before creating progress item`);
      ensureContainer();
      console.log(`[${timestamp}] Creating progress item for download ${data.id}`);
      createOrUpdateProgressItem(data);
      
      // Double-check the DOM after a short delay
      setTimeout(function() {
        const container = $('#download-progress-container');
        const progressItem = $(`#download-${data.id}`);
        console.log(`[${timestamp}] Container exists: ${container.length > 0}`);
        console.log(`[${timestamp}] Progress item exists: ${progressItem.length > 0}`);
        console.log(`[${timestamp}] Container HTML: ${container.html()}`);
      }, 100);
    } catch (e) {
      console.error(`[${timestamp}] ERROR in download_progress_start handler:`, e);
    }
  });
  
  // Register custom message handler for download progress updates with enhanced logging
  Shiny.addCustomMessageHandler("download_progress_update", function(data) {
    const timestamp = new Date().toISOString();
    console.log(`[${timestamp}] Download progress UPDATE received:`, data);
    console.log(`[${timestamp}] UPDATE action: ${data.action}`);
    console.log(`[${timestamp}] UPDATE data - id value: ${data.id}`);
    if (data.trace_id) console.log(`[${timestamp}] UPDATE data - trace_id: ${data.trace_id}`);
    
    try {
      // Ensure container exists
      console.log(`[${timestamp}] Ensuring container exists before processing update`);
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
      
      // Verify DOM state after processing
      setTimeout(function() {
        const progressItem = $(`#download-${data.id}`);
        console.log(`[${timestamp}] After ${data.action} - Progress item exists: ${progressItem.length > 0}`);
      }, 50);
    } catch (e) {
      console.error(`[${timestamp}] ERROR in download_progress_update handler:`, e);
    }
  });
  
  // Register message handler for completion with enhanced logging
  Shiny.addCustomMessageHandler("download_progress_complete", function(data) {
    const timestamp = new Date().toISOString();
    console.log(`[${timestamp}] Download progress COMPLETE received:`, data);
    if (data.trace_id) console.log(`[${timestamp}] COMPLETE data - trace_id: ${data.trace_id}`);
    
    try {
      ensureContainer();
      completeProgressItem(data);
      
      // Verify DOM state after processing
      setTimeout(function() {
        const progressItem = $(`#download-${data.id}`);
        console.log(`[${timestamp}] After COMPLETE - Progress item exists: ${progressItem.length > 0}`);
      }, 50);
    } catch (e) {
      console.error(`[${timestamp}] ERROR in download_progress_complete handler:`, e);
    }
  });
  
  // Register message handler for errors with enhanced logging
  Shiny.addCustomMessageHandler("download_progress_error", function(data) {
    const timestamp = new Date().toISOString();
    console.log(`[${timestamp}] Download progress ERROR received:`, data);
    if (data.trace_id) console.log(`[${timestamp}] ERROR data - trace_id: ${data.trace_id}`);
    
    try {
      ensureContainer();
      errorProgressItem(data);
      
      // Verify DOM state after processing
      setTimeout(function() {
        const progressItem = $(`#download-${data.id}`);
        console.log(`[${timestamp}] After ERROR - Progress item exists: ${progressItem.length > 0}`);
      }, 50);
    } catch (e) {
      console.error(`[${timestamp}] ERROR in download_progress_error handler:`, e);
    }
  });
  
  // Ensure container exists with enhanced logging
  function ensureContainer() {
    const timestamp = new Date().toISOString();
    console.log(`[${timestamp}] Ensuring container exists`);
    console.log(`[${timestamp}] Container selector: #download-progress-container`);
    const container = $('#download-progress-container');
    console.log(`[${timestamp}] Container found: ${container.length > 0}`);
    
    if (container.length > 0) {
      console.log(`[${timestamp}] Container already exists`);
      console.log(`[${timestamp}] Container HTML structure: ${container.prop('outerHTML')}`);
      console.log(`[${timestamp}] Container visibility properties:`, {
        'display': container.css('display'),
        'visibility': container.css('visibility'),
        'opacity': container.css('opacity'),
        'position': container.css('position'),
        'z-index': container.css('z-index'),
        'width': container.css('width'),
        'height': container.css('height'),
        'background': container.css('background')
      });
    } else {
      console.log(`[${timestamp}] Container does not exist - creating one`);
      $('body').append('<div id="download-progress-container" class="download-progress-container"></div>');
      console.log(`[${timestamp}] Container created. New container HTML: ${$('#download-progress-container').prop('outerHTML')}`);
    }
  }
  
  // Create or update a progress item with enhanced logging
  function createOrUpdateProgressItem(data) {
    const timestamp = new Date().toISOString();
    console.log(`[${timestamp}] Creating/updating progress item:`, data);
    console.log(`[${timestamp}] Download ID format: ${data.id}`);
    
    // Make sure we have a valid ID
    if (!data.id) {
      console.error(`[${timestamp}] ERROR: Missing ID in download data`);
      return;
    }
    
    // Ensure ID is string format
    const id = String(data.id);
    console.log(`[${timestamp}] Element selector will be: #download-${id}`);
    
    // Verify container exists before proceeding
    const container = $('#download-progress-container');
    if (container.length === 0) {
      console.error(`[${timestamp}] ERROR: Container does not exist when trying to create item!`);
      ensureContainer();
    }
    
    // Check if item exists
    const progressItem = $(`#download-${id}`);
    console.log(`[${timestamp}] Checking for existing item #download-${id}: ${progressItem.length > 0 ? "Found" : "Not found"}`);
    
    if (progressItem.length === 0) {
      // Create new progress item with enhanced debugging info
      console.log(`[${timestamp}] Creating new progress item`);
      const newItem = `
        <div id="download-${id}" class="download-progress-item">
          <span class="progress-close">&times;</span>
          <h4>${data.filename}</h4>
          <div class="download-progress-text">Starting download...</div>
          <div class="download-progress-bar">
            <div class="download-progress-bar-inner" style="width:5%;"></div>
          </div>
        </div>
      `;
      
      // Log container state before appending
      console.log(`[${timestamp}] Container state before append:`, {
        'exists': container.length > 0,
        'childCount': container.children().length,
        'html': container.html()
      });
      
      // Append the new item
      container.append(newItem);
      
      // Check if item was actually added
      const newItemAdded = $(`#download-${data.id}`);
      console.log(`[${timestamp}] New item appended to container. Success: ${newItemAdded.length > 0}`);
      console.log(`[${timestamp}] Container children count after append: ${container.children().length}`);
      
      // Add click handler for close button
      $(`#download-${id} .progress-close`).on('click', function() {
        console.log(`[${new Date().toISOString()}] Close button clicked for download ${id}`);
        $(`#download-${id}`).addClass('fadeout');
        setTimeout(function() {
          $(`#download-${id}`).remove();
          console.log(`[${new Date().toISOString()}] Download ${id} removed from DOM`);
        }, 300);
      });
    } else {
      // Reset existing progress item
      console.log(`[${timestamp}] Resetting existing progress item`);
      progressItem.removeClass('complete error fadeout');
      progressItem.find('.download-progress-text').text('Starting download...');
      progressItem.find('.download-progress-bar-inner').css('width', '5%');}
  }
  
  // Update progress on an existing item with enhanced logging
  function updateProgressItem(data) {
    const timestamp = new Date().toISOString();
    
    // Ensure ID is string format
    const id = String(data.id);
    console.log(`[${timestamp}] Updating progress for download ${id} to ${data.percent}%`);
    
    // Check if element exists first
    const progressItem = $(`#download-${id}`);
    
    // If element doesn't exist, create it first (might have missed start message)
    if (progressItem.length === 0) {
      console.log(`[${timestamp}] Element #download-${id} doesn't exist for update - creating it first`);
      createOrUpdateProgressItem(data);
      
      // Get the newly created element
      const newItem = $(`#download-${id}`);
      if (newItem.length > 0) {
        // Update progress bar
        newItem.find('.download-progress-bar-inner').css('width', `${data.percent}%`);
        newItem.find('.download-progress-text').text(`Downloading: ${data.percent}%`);
      } else {
        console.error(`[${timestamp}] Failed to create element for update!`);
      }
      return;
    }
    
    // Update progress bar
    progressItem.find('.download-progress-bar-inner').css('width', `${data.percent}%`);
    progressItem.find('.download-progress-text').text(`Downloading: ${data.percent}%`);}
  
  // Mark item as complete with enhanced logging
  function completeProgressItem(data) {
    const timestamp = new Date().toISOString();
    
    // Ensure ID is string format
    const id = String(data.id);
    console.log(`[${timestamp}] Marking download ${id} as complete`);
    
    // Check if element exists first
    const progressItem = $(`#download-${id}`);
    
    // If element doesn't exist, create it first (might have missed start message)
    if (progressItem.length === 0) {
      console.log(`[${timestamp}] Element #download-${id} doesn't exist for completion - creating it first`);
      createOrUpdateProgressItem(data);
    }
    
    // Get the element again after ensuring it exists
    const completingItem = $(`#download-${id}`);
    if (completingItem.length > 0) {
      // Mark as complete
      completingItem.addClass('complete');
      completingItem.find('.download-progress-text').text('Download complete');
      completingItem.find('.download-progress-bar-inner').css('width', '100%');
      
      // Auto-remove after 5 seconds
      console.log(`[${timestamp}] Scheduling removal of completed download ${id} in 5 seconds`);
      setTimeout(function() {
        console.log(`[${new Date().toISOString()}] Auto-removing completed download ${id}`);
        completingItem.addClass('fadeout');
        setTimeout(function() {
          completingItem.remove();
          console.log(`[${new Date().toISOString()}] Completed download ${id} removed from DOM`);
        }, 300);
      }, 5000);
    } else {
      console.error(`[${timestamp}] Failed to find element for completion even after creation attempt!`);
    }
  }
  
  // Mark item as error with enhanced logging
  function errorProgressItem(data) {
    const timestamp = new Date().toISOString();
    
    // Ensure ID is string format
    const id = String(data.id);
    console.log(`[${timestamp}] Marking download ${id} as error: ${data.message}`);
    
    // Check if element exists first
    const progressItem = $(`#download-${id}`);
    
    // If element doesn't exist, create it first (might have missed start message)
    if (progressItem.length === 0) {
      console.log(`[${timestamp}] Element #download-${id} doesn't exist for error - creating it first`);
      createOrUpdateProgressItem(data);
    }
    
    // Get the element again after ensuring it exists
    const errorItem = $(`#download-${id}`);
    if (errorItem.length > 0) {
      // Mark as error
      errorItem.addClass('error');
      errorItem.find('.download-progress-text').text(`Error: ${data.message}`);
      
      // Auto-remove after 10 seconds
      console.log(`[${timestamp}] Scheduling removal of error download ${id} in 10 seconds`);
      setTimeout(function() {
        console.log(`[${new Date().toISOString()}] Auto-removing error download ${id}`);
        errorItem.addClass('fadeout');
        setTimeout(function() {
          errorItem.remove();
          console.log(`[${new Date().toISOString()}] Error download ${id} removed from DOM`);
        }, 300);
      }, 10000);
    } else {
      console.error(`[${timestamp}] Failed to find element for error even after creation attempt!`);
    }
  }
});
