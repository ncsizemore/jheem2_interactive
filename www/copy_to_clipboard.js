copyToClipboard = function(str, hide_id, show_id)
{
    var el = document.createElement('textarea');
    el.value = str;
    el.setAttribute('readonly', '');
    el.style.position = 'absolute';
    el.style.left = '-9999px';
    document.body.appendChild(el);
    
    el.select();
    el.setSelectionRange(0, 99999);
    
    document.execCommand('copy');
    document.body.removeChild(el);
    
    
    document.getElementById(hide_id).style.display = "none";
    document.getElementById(show_id).style.display = "block";
}