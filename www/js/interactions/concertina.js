
add_class = function(elem, to_add)
{
//    var classes = elem.getAttribute('class');
    var classes = elem.className;
    classes += " " + to_add;
//    elem.setAttribute('class', trim(classes));
    elem.className = classes;
}

remove_class = function(elem, to_remove)
{
//    var classes_split = elem.getAttribute('class').split(" ");
    var classes_split = elem.className.split(" ");

    var classes = "";
    for (var i = 0; i < classes_split.length; i++)
    {
        if (classes_split[i] != to_remove)
            classes += " " + classes_split[i];
    }
    
 //   elem.setAttribute('class', trim(classes));
    elem.className = classes;
}

shinyjs.trigger_concertina = function(id)
{
    do_trigger_concertina(document.getElementById(id));
}

do_trigger_concertina = function(elem)
{
    if (elem.hasAttribute("data-show_targets"))
    {
        var show_ids = elem.getAttribute('data-show_targets').split(";");
        for (var i=0; i<show_ids.length; i++)
            document.getElementById(show_ids[i]).style.display = "block";
    }
    
    if (elem.hasAttribute("data-hide_targets"))
    {
        var hide_ids = elem.getAttribute('data-hide_targets').split(";");
        for (var i=0; i<hide_ids.length; i++)
            document.getElementById(hide_ids[i]).style.display = "none";
    }
    
    if (elem.hasAttribute("target_container_ids")) {
        
        var target_container_ids = elem.getAttribute("target_container_ids").split(";");
        if (elem.hasAttribute("remove_classes") && elem.hasAttribute("add_classes")) {
            
            var remove_classes = elem.getAttribute('remove_classes').split(" ");
            var add_classes = elem.getAttribute('add_classes').split(" ");
            
            for (var i=0; i<target_container_ids.length; i++) {
                var target_elem = document.getElementById(target_container_ids[i]);
                for (var j=0; j<remove_classes.length; j++) {
                    
                    if (target_elem.classList.contains(remove_classes[j])) {
                        remove_class(target_elem, remove_classes[j]);
                        add_class(target_elem, add_classes[j]);
                        break
                    }
                }
            }
        }
    }
    
    if (elem.hasAttribute("data-shiny_targets"))
    {
        var shiny_ids = elem.getAttribute('data-shiny_targets').split(";");
        var shiny_values = elem.getAttribute('data-shiny_values').split(";");
        for (var i=0; i<shiny_ids.length; i++)
            Shiny.setInputValue(shiny_ids[i], shiny_values[i]);
    }
}

window.addEventListener('load', () => {
    var acc = document.getElementsByClassName('concertina_trigger');
    for (var i = 0; i < acc.length; i++)
    {
        acc[i].addEventListener("click", function(){
            do_trigger_concertina(this);
        })
    }
})