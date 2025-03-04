library(aws.iam)
library(aws.s3)

##-- CONSTRUCTOR --##

# A multi-cache is a list with elements
# $disk.caches - a list
# $mem.cache


# Put in the appropriate disk cache
# AND put in mem cache
# Returns true if successful, false if there was an error
pull.simsets.to.cache <- function(session,
                                  codes,
                                  cache,
                                  pull.to.explicit=NULL)
{
    codes = gsub('\\.Rdata', '', codes)
    
    for (code in codes)
    {
        key = codes.to.keys.for.cache(code)
        if (1==2) return(NULL)
        else
        {
            filename = paste0(code, '.Rdata')
            
            tryCatch({
                
                if (is.sim.stored(filename))
                    simset = sims.load(filename)
                else    
                {
                    show.error.message(session,
                                       title="Simulation File(s) Unavailable",
                                       message="The simulation file(s) needed are not currently available on the remote server. We apologize, but we cannot process the requested interventions at this time.")
                    
                    if (!is.null(pull.to.explicit))
                        return (NULL)
                    else
                        return (F)
                }
            },
            error = function(e){
                show.error.message(session,
                                   title="Error Retrieving File(s)",
                                   message = "There was an unexpected error while retrieving the file(s) from the remote server. We apologize - please try again in a few minutes.")
                
                if (!is.null(pull.to.explicit))
                    return (NULL)
                else
                    return (F)
            })
            
            if (!is.null(pull.to.explicit))
            {
                cache = put.simset.to.explicit.cache(codes=code,
                                                     simsets = simset,
                                                     cache = cache,
                                                     explicit.name = pull.to.explicit)
            }
            else
            {
                disk.cache$set(key, simset)
                cache$mem.cache$set(key, simset)
            }
        }
    }
    
    #-- Return TRUE for success --#
    if (!is.null(pull.to.explicit))
        return (cache)
    else
        return (T)
}