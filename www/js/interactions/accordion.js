
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

shinyjs.trigger_accordion = function(id)
{
    do_trigger_accordion(document.getElementById(id));
}

do_trigger_accordion = function(elem)
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
    
    if (elem.hasAttribute("data-remove_class_targets"))
    {
        var remove_class_ids = elem.getAttribute('data-remove_class_targets').split(";");
        var remove_classes = elem.getAttribute('data-remove_classes').split(";");
        for (var i=0; i<remove_class_ids.length; i++)
            remove_class(document.getElementById(remove_class_ids[i]), remove_classes[i]);
    }
    
    if (elem.hasAttribute("data-add_class_targets"))
    {
        var add_class_ids = elem.getAttribute('data-add_class_targets').split(";");
        var add_classes = elem.getAttribute('data-add_classes').split(";");
        for (var i=0; i<add_class_ids.length; i++)
            add_class(document.getElementById(add_class_ids[i]), add_classes[i]);
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

  var acc = document.getElementsByClassName('accordion_trigger');
  for (var i = 0; i < acc.length; i++) 
  {
        acc[i].addEventListener("click", function(){
            do_trigger_accordion(this);
        });
  }
});