# components/pages/team.R

#' Load team member data from files
#' @return List of team member data
load_team_members <- function() {
    members <- lapply(list.files('resources/team'), function(file) {
        file_text <- unlist(read.delim(
            paste0('resources/team/', file), 
            header = FALSE
        ), recursive = FALSE)
        
        list(
            full_name = file_text[[1]],
            last_name = file_text[[2]],
            short_name = file_text[[3]],
            bio = file_text[[4]]
        )
    })
    
    # Sort by last name
    names(members) <- sapply(members, function(x) {x$last_name})
    members[sort(names(members))]
}

#' Create sidebar navigation for team members
#' @param members List of team member data
#' @param config Page configuration
#' @return Shiny tags list
create_team_sidebar <- function(members, config) {
    sidebar_links <- lapply(members, function(person) {
        tags$p(
            tags$a(
                onclick = sprintf(
                    "document.getElementById('%s').scrollIntoView({behavior: 'smooth', block: 'start'});",
                    person$short_name
                ),
                person$full_name
            )
        )
    })
    
    tags$div(
        class = config$pages$team$styles$sidebar$class,
        sidebar_links
    )
}

#' Create team member bio sections
#' @param members List of team member data
#' @param config Page configuration
#' @return Shiny tags list
create_team_bios <- function(members, config) {
    lapply(members, function(person) {
        tags$div(
            id = person$short_name,
            tags$h3(person$full_name),
            tags$table(
                class = 'team_image_table',
                tags$tr(
                    tags$td(
                        tags$img(
                            src = paste0("images/team/", person$short_name, ".jpg"),
                            alt = person$full_name,
                            style = "float: left;"
                        ),
                        person$bio
                    )
                )
            )
        )
    })
}

#' Create team page content
#' @param config Page configuration
#' @return Shiny UI element
create_team_content <- function(config) {
    # Load team member data
    members <- load_team_members()
    
    # Create main content
    tags$table(
        class = 'team_table fill_page3',
        tags$tbody(
            tags$tr(
                # Sidebar
                tags$td(
                    class = 'team_td',
                    create_team_sidebar(members, config)
                ),
                # Main content
                tags$td(
                    class = 'team_td',
                    tags$div(
                        class = config$pages$team$styles$main$class,
                        tags$div(style = 'height: 30px'),
                        # Header
                        tags$div(
                            class = config$pages$team$styles$header$class,
                            tags$h1(config$pages$team$title)
                        ),
                        # Bios
                        tags$div(
                            class = config$pages$team$styles$content$class,
                            create_team_bios(members, config)
                        )
                    )
                )
            )
        )
    )
}