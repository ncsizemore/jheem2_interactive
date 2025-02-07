#' Find the project root directory
#' @return Path to project root
get_project_root <- function() {
    path <- getwd()
    while (path != dirname(path)) { # Stop at root directory
        if (any(file.exists(file.path(path, c(".git", ".Rproj"))))) {
            return(path)
        }
        path <- dirname(path)
    }
    stop("Could not find project root")
}

#' Source a file relative to project root
#' @param ... Path components relative to project root
source_project_file <- function(...) {
    # Store current working directory
    old_wd <- getwd()

    # Change to project root temporarily
    root <- get_project_root()
    setwd(root)

    # Source the file
    tryCatch({
        file_path <- file.path(...) # Now relative to project root
        source(file_path)
    }, finally = {
        # Always restore the working directory
        setwd(old_wd)
    })
}

#' Load YAML config for testing
#' @param ... Path components relative to project root
#' @return Config list
load_test_config <- function(...) {
    root <- get_project_root()
    config_path <- file.path(root, ...)
    yaml::read_yaml(config_path)
}
