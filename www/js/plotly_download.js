// www/js/plotly_download.js

console.log("plotly_download.js script loaded.");

$(document).on("shiny:connected", function (event) {
    console.log("Shiny connected. Registering downloadPlotly message handler.");

    Shiny.addCustomMessageHandler("downloadPlotly", function (message) {
        console.log("Received downloadPlotly message:", message);

        if (typeof Plotly === 'undefined' || typeof Plotly.downloadImage !== 'function') {
            console.error("Plotly object or Plotly.downloadImage not available at time of download request.");
            alert("Error: Plotly library not ready for download. Please ensure a plot is visible and fully rendered.");
            return;
        }

        if (message.plotId && message.filename) {
            const plotElement = document.getElementById(message.plotId);

            if (plotElement) {
                console.log("Using plot element for download:", plotElement);
                const downloadOptions = {
                    format: message.format || 'png',
                    width: message.width || null,
                    height: message.height || null,
                    filename: message.filename,
                    scale: message.scale || 1 // Use provided scale or default to 1
                };
                console.log("Calling Plotly.downloadImage with options:", downloadOptions);
                Plotly.downloadImage(plotElement, downloadOptions)
                    .then(function (filename) {
                        console.log("Plot download initiated:", filename);
                    })
                    .catch(function (err) {
                        console.error("Error downloading plot:", err);
                        alert("Error downloading plot: " + err.message);
                    });
            } else {
                console.error("Could not find plot element with ID:", message.plotId);
                alert("Error: Plot container not found for download. This is unexpected.");
            }
        } else {
            console.error("Invalid message received for downloadPlotly (missing plotId or filename):", message);
            alert("Error: Invalid download request from server.");
        }
    });

    console.log("downloadPlotly message handler registered.");
});