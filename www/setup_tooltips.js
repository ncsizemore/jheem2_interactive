
window.addEventListener('load', () => 
                            {
                                var i;
                                var sub_elem;
                                var data_value;
                                var id;
                                var main_nav = document.getElementById("main_nav");
                                // alert("Running the JS");
                                
                                // Iterate through the contents of each <li> in the navbar and 
                                //  make an id out of the data-value attribute
                                for (i = 0; i < main_nav.children.length; i++) 
                                {
                                    sub_elem = main_nav.children[i].children[0];
                                    
                                    data_value = sub_elem.getAttribute('data-value');
                                    //alert("Fixing id for data value" + data_value);
                                    id = data_value.toLowerCase();
                                    id = id.replace(/ /g,"_");
                                    id = id.replace(/\W/g, '');
                                    
                                    sub_elem.id = id;
                                } 
                            });