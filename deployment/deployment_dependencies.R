# deployment_dependencies.R
#
# NOTE: This file exists solely to signal to the rsconnect deployment process
# which packages are required by the application. It is not actually used at runtime.
# Simply include this file in the appFiles argument of deployApp() to ensure 
# all dependencies are properly installed during deployment.

# CRAN Packages
library(shiny)
library(shinyjs)
library(shinycssloaders)
library(cachem)
library(magrittr)
library(plotly)
library(httr2)
library(ggmap)
library(ggnewscale)
library(deSolve)
library(yaml)
library(remotes)
library(rsconnect)

# Optional packages
library(blastula)

# Custom packages from GitHub
library(distributions)
library(bayesian.simulations)
library(locations)
library(jheem2)
