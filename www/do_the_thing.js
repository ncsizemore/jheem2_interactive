
do_the_thing = function(x)
{
    if (x)
        alert("x is TRUE!")
    else
        alert("x is FALSE!")
}

shinyjs.do_the_thing = function()
{
    do_the_thing(true);
}




get_display_size = function(on_load)
{
    // The Window
    var window_height = window.innerHeight;//document.body.clientWidth;
    var window_width = window.innerWidth;//document.body.clientHeight;
    
    // Underneath
    var prerun_under_height = document.getElementById('under_display_prerun').offsetHeight;
    if (prerun_under_height == 0 && on_load)
        prerun_under_height = 116;
        
    var custom_under_height = document.getElementById('under_display_custom').offsetHeight;
    if (custom_under_height == 0 && on_load)
        custom_under_height = 62;
        
    // Above
    var body_height = document.body.getBoundingClientRect().height;

    var prerun_display_rect = document.getElementById('prerun_table').getBoundingClientRect();
    var prerun_figure_rect = document.getElementById('figure_prerun').getBoundingClientRect();

    var prerun_above_height = 0;
    if (prerun_display_rect.height != 0)
        prerun_above_height = body_height - prerun_display_rect.height +
                                (prerun_figure_rect.top - prerun_display_rect.top);
    if (prerun_above_height == 0 && on_load)
        prerun_above_height = 94;
    
    
    var custom_display_rect = document.getElementById('custom_table').getBoundingClientRect();
    var custom_figure_rect = document.getElementById('figure_custom').getBoundingClientRect();
    
    var custom_above_height = 0;
    if (custom_display_rect.height != 0)
        custom_above_height = body_height - custom_display_rect.height + 
                                (custom_figure_rect.top - custom_display_rect.top);
    if (custom_above_height == 0 && on_load)
        custom_above_height = 94;
        
//    alert('window_height = ' + window_height + ', prerun_under_height = ' + prerun_under_height + ", prerun_above_height = " + prerun_above_height);
    
    // Package and set it
    if (prerun_under_height != 0 && prerun_above_height != 0)
    {
        var rv_prerun = {width: window_width,
                        height: window_height - prerun_under_height - prerun_above_height};
    
        Shiny.setInputValue('display_size_prerun', rv_prerun);
    }
    
    if (custom_under_height != 0 && custom_above_height != 0)
    {
        var rv_custom = {width: window_width,
                        height: window_height - custom_under_height - custom_above_height};
        alert("I happened, promise!");
        Shiny.setInputValue('display_size_custom', rv_custom);
    }
}


shinyjs.ping_display_size_onload = function()
{
    alert("Victory?");
    get_display_size(true);

}