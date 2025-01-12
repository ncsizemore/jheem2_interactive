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
    },

    // Render current state
    render() {
        Object.entries(this.state.panels).forEach(([position, data]) => {
            const panel = $(`.${position}-panel`);
            const button = panel.find('.toggle-button');
            
            // Update panel
            panel.toggleClass('collapsed', !data.visible);
            
            // Update button icon
            const iconClass = position === 'right' ? 
                (data.visible ? 'fa-chevron-right' : 'fa-chevron-left') :
                (data.visible ? 'fa-chevron-left' : 'fa-chevron-right');
            
            button.find('i')
                .removeClass('fa-chevron-left fa-chevron-right')
                .addClass(iconClass);
        });

        // Trigger resize after transition
        setTimeout(() => {
            window.dispatchEvent(new Event('resize'));
        }, 300);
    }
};

// Initialize on document ready
$(document).ready(function() {
    // Use a single handler for all toggle buttons
    $('.toggle-button').on('click', function(e) {
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