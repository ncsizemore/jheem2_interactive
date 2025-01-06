
# Script generates Team HTML
# Each team member's file needs to have the same format: one line for the full name, then last name, short name, and bio.

TEAM.MEMBER.DATA = lapply(list.files('resources/team'), function(file) {
    file.text = unlist(read.delim(paste0('resources/team/', file), header=F), recursive = F) # because has everything in a list
    return(list(full.name = file.text[[1]],
                last.name = file.text[[2]],
                short.name = file.text[[3]],
                bio = file.text[[4]]))
})
names(TEAM.MEMBER.DATA) = sapply(TEAM.MEMBER.DATA, function(x) {x$last.name})
TEAM.MEMBER.DATA = TEAM.MEMBER.DATA[sort(names(TEAM.MEMBER.DATA))]

TEAM.SIDEBAR.COMPONENTS = lapply(TEAM.MEMBER.DATA, function(person) {
    withTags({
        p(a(onclick = paste0("document.getElementById('", person$short.name, "').scrollIntoView({behavior: 'smooth', block: 'start'});"),
            person$full.name))
    })
})

TEAM.BIO.COMPONENTS = lapply(TEAM.MEMBER.DATA, function(person) {
    return(withTags({
        div(id = person$short.name,
            h3(person$full.name),
            table(class = 'team_image_table',
                  tr(
                      td(img(src = paste0("images/team/", person$short.name, ".jpg"),
                             alt = person$full.name,
                             style = "float: left;"),
                         person$bio)
                  )
            ))
    }))
})

TEAM.CONTENT = withTags({
    table(class = 'team_table fill_page3',
          tbody(
              tr(
                  td(class = 'team_td',
                     div(class='team_sidebar controls_color',
                         TEAM.SIDEBAR.COMPONENTS)
                     ),
                  td(class = 'team_td',
                     div(class = 'team_main content_color',
                         div(style='height: 30px'),
                         div(class='about_header_padding header_color', # not sure why this isn't "team_header_padding"
                             h1('The Team Behind the JHEEM')),
                         div(class='about_padding',
                             TEAM.BIO.COMPONENTS)
                         ))
              )
          ))
})
