#' Creates a team member card
#' @param member List containing member data
#' @return Shiny UI element
create_member_card <- function(member) {
    # Default image if member's image is missing
    image_path <- file.path("images", "team", member$image)
    fallback_image <- "images/team/default-profile.jpg"

    # Check if image exists in www directory
    if (!file.exists(file.path("www", image_path))) {
        warning(sprintf("Image not found for %s, using default", member$full_name))
        image_path <- fallback_image
    }

    tags$article(
        class = "team-member",
        tags$img(
            src = image_path,
            alt = sprintf("Photo of %s", member$full_name),
            class = "team-member-photo",
            onerror = sprintf("this.src='%s';", fallback_image) # JavaScript fallback
        ),
        tags$div(
            class = "team-member-content",
            tags$h3(member$full_name),
            tags$h4(member$title),
            tags$p(member$bio)
        )
    )
}
