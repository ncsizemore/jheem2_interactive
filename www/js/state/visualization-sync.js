// visualization-sync.js
// Handles synchronization between state and visualization UI elements

// Custom message handler to update visualization display based on state
Shiny.addCustomMessageHandler('updateVisualizationDisplay', function(message) {
  // Extract information from message
  const pageId = message.page_id;
  const displayType = message.display_type;
  const visibility = message.visibility;
  const plotStatus = message.plot_status;
  
  console.log(`[Visualization Sync][${pageId}] Updating display: type=${displayType}, visibility=${visibility}`);
  
  // Also find the toggle buttons for this page
  const togglePlotButton = document.getElementById(`${pageId}-toggle_plot`);
  const toggleTableButton = document.getElementById(`${pageId}-toggle_table`);
  
  // Log button state
  console.log(`[Visualization Sync][${pageId}] Toggle buttons found:`, {
    plot: togglePlotButton ? true : false,
    table: toggleTableButton ? true : false
  });
  
  // Make sure toggle buttons are enabled
  if (togglePlotButton) {
    togglePlotButton.disabled = false;
    // Check if it has the 'disabled' class and remove it
    togglePlotButton.classList.remove('disabled');
    console.log(`[Visualization Sync][${pageId}] Enabled plot toggle button`);
  }
  
  if (toggleTableButton) {
    toggleTableButton.disabled = false;
    // Check if it has the 'disabled' class and remove it
    toggleTableButton.classList.remove('disabled');
    console.log(`[Visualization Sync][${pageId}] Enabled table toggle button`);
  }
  
  // Update toggle button active state based on display type
  if (togglePlotButton && toggleTableButton) {
    // Log the current classes on the buttons
    console.log(`[Visualization Sync][${pageId}] Button classes:`, {
      plot: togglePlotButton.className,
      table: toggleTableButton.className
    });
    
    if (displayType === 'plot') {
      // Make plot button active
      togglePlotButton.classList.add('active');
      toggleTableButton.classList.remove('active');
      console.log(`[Visualization Sync][${pageId}] Set plot button to active`);
    } else {
      // Make table button active
      togglePlotButton.classList.remove('active');
      toggleTableButton.classList.add('active');
      console.log(`[Visualization Sync][${pageId}] Set table button to active`);
    }
  }
  
  // Find panel containers using the specific panel classes we added
  // These selectors target the specific panels for each page
  let plotPanel = document.querySelector(`.${pageId}-plot-panel`);
  let tablePanel = document.querySelector(`.${pageId}-table-panel`);
  
  if (!plotPanel || !tablePanel) {
    console.warn(`[Visualization Sync][${pageId}] Could not find panel elements`);
    console.warn(`Plot panel found: ${!!plotPanel}, Table panel found: ${!!tablePanel}`);
    console.warn(`Tried selectors: .${pageId}-plot-panel and .${pageId}-table-panel`);
    
    // Fall back to container-based selectors as backup
    const altPlotPanel = document.querySelector(`.${pageId}-container .main-panel-plot`);
    const altTablePanel = document.querySelector(`.${pageId}-container .main-panel-table`);
    console.warn(`Alternative selectors found: Plot: ${!!altPlotPanel}, Table: ${!!altTablePanel}`);
    
    // If we found alternates, use them
    if (altPlotPanel && altTablePanel) {
      console.warn(`Using alternative selectors as fallback`);
      plotPanel = altPlotPanel;
      tablePanel = altTablePanel;
    } else {
      // Log all panel-related elements for debugging
      console.warn('All available panel elements:');
      document.querySelectorAll('.main-panel-plot, .main-panel-table').forEach(el => {
        console.warn(`- ${el.className}`);
      });
      return;
    }
  }
  
  // Update panel visibility based on state
  if (visibility === 'visible') {
    // Show the appropriate panel based on display type
    if (displayType === 'plot') {
      plotPanel.style.display = 'block';
      tablePanel.style.display = 'none';
    } else {
      plotPanel.style.display = 'none';
      tablePanel.style.display = 'block';
    }
  } else {
    // Hide both panels if not visible
    plotPanel.style.display = 'none';
    tablePanel.style.display = 'none';
  }
  
  // Update loading state if needed
  // First try page-specific panel indicators
  let loadingIndicators = [];
  
  if (plotPanel) {
    const panelIndicators = plotPanel.querySelectorAll('.loading-indicator');
    if (panelIndicators.length > 0) {
      loadingIndicators = Array.from(panelIndicators);
    }
  }
  
  if (tablePanel) {
    const tableIndicators = tablePanel.querySelectorAll('.loading-indicator');
    if (tableIndicators.length > 0) {
      loadingIndicators = loadingIndicators.concat(Array.from(tableIndicators));
    }
  }
  
  // If we couldn't find specific indicators, try a broader selector
  if (loadingIndicators.length === 0) {
    loadingIndicators = Array.from(document.querySelectorAll(`.${pageId}-container .loading-indicator`));
  }
  
  // Update all found indicators
  loadingIndicators.forEach(indicator => {
    console.log(`[Visualization Sync][${pageId}] Updating loading indicator: ${plotStatus}`);
    if (plotStatus === 'loading') {
      indicator.style.display = 'flex';
    } else {
      indicator.style.display = 'none';
    }
  });
});
