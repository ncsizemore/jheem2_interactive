


shinyjs.scrollTo = function(scroll_to_id, scroll_within_id)
{
    var elem = document.getElementById(scroll_to_id);
    var offset = 0;
    
    while (!elem && elem.id != scroll_within_id)
    {
        offset = offset + elem.offset().top;
    }
    
    scrollTop = offset;
}