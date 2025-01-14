
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
    custom_table = document.getElementById('custom_table');
    
    var custom_display_rect = custom_table.getBoundingClientRect();
    var custom_figure_rect = document.getElementById('figure_custom').getBoundingClientRect();
    var custom_above_height = 0;
    if (custom_display_rect.height != 0)
        custom_above_height = body_height - custom_display_rect.height + 
        (custom_figure_rect.top - custom_display_rect.top);
    if (custom_above_height == 0 && on_load)
        custom_above_height = 94;
    
    //alert('window_height = ' + window_height + ', prerun_under_height = ' + prerun_under_height + ", prerun_above_height = " + prerun_above_height);
    // Package and set it
    if (prerun_under_height != 0 && prerun_above_height != 0)
    {
        var rv_prerun = {width: window_width,
            height: window_height - prerun_under_height - prerun_above_height};
        //alert("setting 'display_size_prerun'");
        Shiny.setInputValue('display_size_prerun', rv_prerun);
    }
    
    if (custom_under_height != 0 && custom_above_height != 0)
    {
        var rv_custom = {width: window_width,
            height: window_height - custom_under_height - custom_above_height};
        //alert("setting 'display_size_custom'");

        Shiny.setInputValue('display_size_custom', rv_custom);
    }
    
} 

window.addEventListener('resize', () => {
    get_display_size(false);
});


shinyjs.ping_display_size_onload = function()
{
    get_display_size(true);
}

shinyjs.ping_display_size = function()
{
    get_display_size(false);
}

shinyjs.set_input_value = function(params)
{
    Shiny.setInputValue(params.name, params.value);
}