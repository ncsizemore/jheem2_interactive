
shinyjs.chime = function()
{
    var snd = new Audio("Ripples.mp3");
    snd.play();
}

shinyjs.chime_if_checked = function(check_id)
{
    if (document.getElementById(check_id).checked)
    {
        var snd = new Audio("Ripples.mp3");
        snd.play();
    }
}