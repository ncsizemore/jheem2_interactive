// plot_progress.js - Handles plot progress display in UI

$(document).ready(function () {
    const initTimestamp = new Date().toISOString();
    console.log(`[${initTimestamp}] Plot progress module initialized`);

    // Register custom message handlers for Shiny
    Shiny.addCustomMessageHandler("plot_progress_start", function (data) {
        const timestamp = new Date().toISOString();
        console.log(`[${timestamp}] Plot progress START received:`, data);
        try {
            ensureContainer();
            createOrUpdateProgressItem(data);
            // Manually trigger positioning update after adding an item
            if (window.updateProgressPositioning) {
                window.updateProgressPositioning();
            }
        } catch (e) {
            console.error(`[${timestamp}] ERROR in plot_progress_start handler:`, e);
        }
    });

    Shiny.addCustomMessageHandler("plot_progress_complete", function (data) {
        const timestamp = new Date().toISOString();
        console.log(`[${timestamp}] Plot progress COMPLETE received:`, data);
        try {
            ensureContainer(); // Ensure container exists just in case
            completeProgressItem(data);
            // Manually trigger positioning update after removing an item (implicitly via timeout)
            // No immediate trigger needed here, timeout handles removal later
        } catch (e) {
            console.error(`[${timestamp}] ERROR in plot_progress_complete handler:`, e);
        }
    });

    Shiny.addCustomMessageHandler("plot_progress_error", function (data) {
        const timestamp = new Date().toISOString();
        console.log(`[${timestamp}] Plot progress ERROR received:`, data);
        try {
            ensureContainer(); // Ensure container exists just in case
            errorProgressItem(data);
            // Manually trigger positioning update after removing an item (implicitly via timeout)
            // No immediate trigger needed here, timeout handles removal later
        } catch (e) {
            console.error(`[${timestamp}] ERROR in plot_progress_error handler:`, e);
        }
    });

    // Ensure container exists
    function ensureContainer() {
        const container = $('#plot-progress-container');
        if (container.length === 0) {
            // Prepend to ensure it's the first one checked by positioning logic
            $('body').prepend('<div id="plot-progress-container" class="plot-progress-container"></div>');
            console.log("[Plot Progress] Created #plot-progress-container");
        }
    }

    // Create or update a progress item
    function createOrUpdateProgressItem(data) {
        // Use a fixed ID for the plot indicator since we only show one at a time
        const id = "current-plot";
        const progressItem = $(`#plot-${id}`);
        const description = data.description || "Generating Plot"; // Allow custom description

        // Ensure container exists before proceeding
        ensureContainer();
        const container = $('#plot-progress-container');

        if (progressItem.length === 0) {
            // Create new progress item
            const newItem = `
        <div id="plot-${id}" class="plot-progress-item">
          <span class="progress-close">&times;</span>
          <h4>${description}</h4>
          <div class="plot-progress-content">
             <div class="loading-spinner"></div>
             <span class="plot-progress-text">Please wait...</span>
          </div>
        </div>
      `;
            container.append(newItem);

            // Add click handler for close button
            $(`#plot-${id} .progress-close`).on('click', function () {
                removeProgressItem(id, true); // Force remove immediately on click
            });
        } else {
            // Reset existing progress item (in case of rapid clicks)
            progressItem.removeClass('complete error fadeout');
            progressItem.find('h4').text(description); // Update description
            progressItem.find('.plot-progress-text').text('Please wait...');
            progressItem.show(); // Ensure it's visible if previously hidden
        }
    }

    // Mark item as complete
    function completeProgressItem(data) {
        const id = "current-plot"; // Use fixed ID
        const progressItem = $(`#plot-${id}`);

        if (progressItem.length > 0) {
            // Don't add 'complete' class, just remove it
            removeProgressItem(id); // Use standard removal with fadeout
        } else {
            console.warn(`[Plot Progress] Tried to complete non-existent item: plot-${id}`);
        }
    }

    // Mark item as error
    function errorProgressItem(data) {
        const id = "current-plot"; // Use fixed ID
        const progressItem = $(`#plot-${id}`);
        const message = data.message || "An error occurred";

        if (progressItem.length > 0) {
            progressItem.addClass('error'); // Add error class for styling (optional)
            progressItem.find('.plot-progress-text').text(`Error: ${message}`);
            // Remove spinner? Optional.
            // progressItem.find('.loading-spinner').hide();

            // Auto-remove after a delay (e.g., 10 seconds)
            setTimeout(function () {
                removeProgressItem(id);
            }, 10000); // Keep error visible longer
        } else {
            console.warn(`[Plot Progress] Tried to error non-existent item: plot-${id}`);
        }
    }

    // Remove item with fadeout
    function removeProgressItem(id, immediate = false) {
        const progressItem = $(`#plot-${id}`);
        if (progressItem.length > 0) {
            if (immediate) {
                progressItem.remove();
                console.log(`[Plot Progress] Removed item plot-${id} immediately.`);
                // Trigger positioning update immediately after removal
                if (window.updateProgressPositioning) {
                    window.updateProgressPositioning();
                }
            } else {
                progressItem.addClass('fadeout');
                setTimeout(function () {
                    progressItem.remove();
                    console.log(`[Plot Progress] Removed item plot-${id} after fadeout.`);
                    // Trigger positioning update after removal
                    if (window.updateProgressPositioning) {
                        window.updateProgressPositioning();
                    }
                }, 300); // Match fadeout duration in CSS if specified
            }
        }
    }

});