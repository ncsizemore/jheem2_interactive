

shinyjs.download_plotly = function(params)
{
    var id = params['id'];
    var filename = params['filename'];
    var elem = document.getElementById(id);
  
    var width = params['width'];
    var height = params['height'];
//    var width = elem.offsetWidth;
//    var height = elem.offsetHeight;
    
    Plotly.downloadImage(elem,
                         {format: 'png', 
                          width: width, 
                          height: height,
                          filename: filename
                         })
}