// Panel state management
const PanelStateManager = {
    state: {
        panels: {
            left: { visible: true },
            right: { visible: true }
        }
    },

    // Update state and trigger render
    updatePanelState(position, isVisible) {
        this.state.panels[position].visible = isVisible;
        this.render();

        // Notify Shiny of state change
        if (window.Shiny) {
            Shiny.setInputValue('panel_state', this.state);
        }

        // Force recalculation of button positions
        this.updateButtonPositions();
    },

    updateButtonPositions() {
        const leftPanel = $('.left-panel');
        const rightPanel = $('.right-panel');

        // Update left button position
        const leftButton = leftPanel.find('.toggle-button');
        leftButton.css('left', this.state.panels.left.visible ? '300px' : '0');

        // Update right button position
        const rightButton = rightPanel.find('.toggle-button');
        rightButton.css('right', this.state.panels.right.visible ? '300px' : '0');
    },

    // Render current state
    render() {
        Object.entries(this.state.panels).forEach(([position, data]) => {
            const panel = $(`.${position}-panel`);
            const button = panel.find('.toggle-button');

            // Update panel
            panel.toggleClass('collapsed', !data.visible);

            // Update button icon and ensure it stays visible
            const iconClass = position === 'left' ?
                (data.visible ? 'fa-chevron-left' : 'fa-chevron-right') :
                (data.visible ? 'fa-chevron-right' : 'fa-chevron-left');

            button
                .find('i')
                .removeClass('fa-chevron-left fa-chevron-right')
                .addClass(iconClass);
        });

        this.updateButtonPositions();

        // Trigger resize after transition
        setTimeout(() => {
            window.dispatchEvent(new Event('resize'));
        }, 300);
    }
};

// Initialize on document ready
$(document).ready(function () {
    // Use a single handler for all toggle buttons
    $('.toggle-button').on('click', function (e) {
        e.preventDefault();

        // Determine which panel we're toggling
        const isRightPanel = $(this).closest('.right-panel').length > 0;
        const position = isRightPanel ? 'right' : 'left';

        // Toggle the state
        const currentState = PanelStateManager.state.panels[position].visible;
        PanelStateManager.updatePanelState(position, !currentState);

        // Log for debugging
        console.log(`Toggling ${position} panel, new state:`, !currentState);
    });

    // Initial state setup
    PanelStateManager.render();
    console.log('Panel controls initialized');
});