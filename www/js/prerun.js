$(document).ready(function() {
  // Initialize panel states
  let leftPanelVisible = true;
  let rightPanelVisible = true;

  function updateContainerClass() {
    const container = $('.prerun-container');
    container.removeClass('left-collapsed right-collapsed both-collapsed');
    
    if (!leftPanelVisible && !rightPanelVisible) {
      container.addClass('both-collapsed');
    } else if (!leftPanelVisible) {
      container.addClass('left-collapsed');
    } else if (!rightPanelVisible) {
      container.addClass('right-collapsed');
    }
  }

  function updateToggles() {
    // Update left toggle
    const leftToggle = $('#toggle-interventions');
    leftToggle.find('i')
      .removeClass('fa-chevron-left fa-chevron-right')
      .addClass(leftPanelVisible ? 'fa-chevron-left' : 'fa-chevron-right');

    // Update right toggle
    const rightToggle = $('#toggle-settings');
    rightToggle.find('i')
      .removeClass('fa-chevron-left fa-chevron-right')
      .addClass(rightPanelVisible ? 'fa-chevron-right' : 'fa-chevron-left');

    // Trigger resize after transition
    setTimeout(() => {
      window.dispatchEvent(new Event('resize'));
    }, 300);
  }

  // Toggle intervention panel
  $('#toggle-interventions').on('click', function(e) {
    e.preventDefault();
    e.stopPropagation();
    leftPanelVisible = !leftPanelVisible;
    
    $('.intervention-panel').toggleClass('collapsed', !leftPanelVisible);
    updateContainerClass();
    updateToggles();
  });

  // Toggle settings panel
  $('#toggle-settings').on('click', function(e) {
    e.preventDefault();
    e.stopPropagation();
    rightPanelVisible = !rightPanelVisible;
    
    $('.settings-panel').toggleClass('collapsed', !rightPanelVisible);
    updateContainerClass();
    updateToggles();
  });

  // Initial setup
  updateContainerClass();
  updateToggles();
});