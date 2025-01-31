// Panel state management
const PreRunPanelManager = {
  state: {
    leftPanelVisible: true,
    rightPanelVisible: true
  },

  updateContainerClass() {
    const container = $('.prerun-container');
    container.removeClass('left-collapsed right-collapsed both-collapsed');

    if (!this.state.leftPanelVisible && !this.state.rightPanelVisible) {
      container.addClass('both-collapsed');
    } else if (!this.state.leftPanelVisible) {
      container.addClass('left-collapsed');
    } else if (!this.state.rightPanelVisible) {
      container.addClass('right-collapsed');
    }
  },

  updatePanels() {
    // Update panel states
    $('.intervention-panel').toggleClass('collapsed', !this.state.leftPanelVisible);
    $('.settings-panel').toggleClass('collapsed', !this.state.rightPanelVisible);

    // Update toggle button icons
    $('#toggle-interventions i')
      .removeClass('fa-chevron-left fa-chevron-right')
      .addClass(this.state.leftPanelVisible ? 'fa-chevron-left' : 'fa-chevron-right');

    $('#toggle-settings i')
      .removeClass('fa-chevron-left fa-chevron-right')
      .addClass(this.state.rightPanelVisible ? 'fa-chevron-right' : 'fa-chevron-left');

    // Update container classes
    this.updateContainerClass();

    // Trigger resize after transition
    setTimeout(() => {
      window.dispatchEvent(new Event('resize'));
    }, 300);
  },

  togglePanel(side) {
    if (side === 'left') {
      this.state.leftPanelVisible = !this.state.leftPanelVisible;
    } else {
      this.state.rightPanelVisible = !this.state.rightPanelVisible;
    }
    this.updatePanels();
  }
};

// Initialize on document ready
$(document).ready(function () {
  // Toggle intervention panel
  $('#toggle-interventions').on('click', function (e) {
    e.preventDefault();
    e.stopPropagation();
    PreRunPanelManager.togglePanel('left');
  });

  // Toggle settings panel
  $('#toggle-settings').on('click', function (e) {
    e.preventDefault();
    e.stopPropagation();
    PreRunPanelManager.togglePanel('right');
  });

  // Initial setup
  PreRunPanelManager.updatePanels();
});