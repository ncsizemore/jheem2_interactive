# global.R


# Source configuration system
source("src/ui/config/load_config.R")

# Source components and helpers
source("src/ui/components/common/popover/popover.R")

# Source state management system
source("src/ui/state/types.R")
source("src/ui/state/store.R")
source("src/ui/state/visualization.R")
source("src/ui/state/controls.R")
source("src/ui/state/validation.R")

# Source data layer components
source("src/adapters/simulation_adapter.R")
source("src/adapters/intervention_adapter.R")

# Source display components
source("src/ui/components/common/display/plot_panel.R")
source("src/ui/components/common/display/table_panel.R")
source("src/ui/components/common/display/toggle.R")
source("src/ui/components/common/display/plot_controls.R")

# Source error handling
source("src/ui/components/common/errors/boundaries.R")
source("components/layout/panel.R")
source("src/ui/components/selectors/base.R")
source("src/ui/components/selectors/custom_components.R")
source("src/ui/components/selectors/choices_select.R")

source("src/ui/components/pages/prerun/layout.R")
source("src/ui/components/pages/custom/layout.R")


# Source server handlers
source("src/ui/components/pages/prerun/index.R")
source("src/ui/components/pages/custom/index.R")

# Source other required files
source("helpers/display_size.R")
source("src/ui/components/common/display/handlers.R")
source("server/contact_handlers.R")

# Source page components
source("src/ui/components/pages/about/about.R")
source("src/ui/components/pages/about/content.R")
source("src/ui/components/pages/faq/faq.R")
source("src/ui/components/pages/faq/content.R")
source("src/ui/components/pages/team/team.R")
source("src/ui/components/pages/team/content.R")
source("src/ui/components/pages/team/member_card.R")
source("src/ui/components/pages/contact/contact.R")
source("src/ui/components/pages/contact/content.R")
source("src/ui/components/pages/contact/form.R")
source("src/ui/components/pages/overview/overview.R")
source("src/ui/components/pages/overview/content.R")

library(jheem2)
source("../jheem_analyses/applications/ryan_white/ryan_white_specification.R")

