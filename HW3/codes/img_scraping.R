# necessary libraries for scraping
library(rvest)
library(jsonlite)
library(httr)
library(tidyverse)
library(data.table)

#get number of objects and their ObjectID's 
get_object_list <- function( q ) {
  url <- paste0('https://collectionapi.metmuseum.org/public/collection/v1/search?q=', q , '&title=' , q )
  
  object_list <- fromJSON( url , flatten=T)
  return(object_list[["objectIDs"]])
}

# get object info by objectID and put into a list. Remove nested lists that are anyways useless
get_object_info <- function(objectID) {
  url <- paste0('https://collectionapi.metmuseum.org/public/collection/v1/objects/' , objectID)
  
  json_result <- fromJSON(url , flatten=T)
  json_result <- json_result[ names( json_result ) %in% "tags" == FALSE ] 
  json_result <- json_result[ names( json_result ) %in% "measurements" == FALSE ]
  json_result <- json_result[ names( json_result ) %in% "constituents" == FALSE ]
  json_result <- json_result[ names( json_result ) %in% "additionalImages" == FALSE ]
  return(json_result)
}

# let's get the Snuffboxes!
q <- 'Snuffbox'
object_list <- get_object_list( q = q )

# merge every snuffbox of MET
df_list <- lapply(object_list , get_object_info)
# bind the lists into final data frame 
fin_df <- rbindlist(df_list , fill = T)

## some cleaning and data formatting:
# fix missing values
fin_df[ fin_df == "" ] <- NA
#since the MET API is very poorly performing with the searches, the results are spammed with other objects, like swords, souvenirs, étui, vases, etc. so let's filter rows that contain 'nuffbox' in the title. 
#we don't need everything so let's drop the unnecessary columns as well. 
fin_df <- fin_df %>%
  filter( grepl( 'nuffbox' , title ) ) %>%
  select( objectID , primaryImageSmall , title , objectURL )

#save dataset into a csv file
write_csv( fin_df , file = 'datasets/snuffboxes.csv')

#save the small primary pictures before uploading to S3
RAW_LOCATION_BASE = 'images/'
dir.create( file.path( RAW_LOCATION_BASE ) , showWarnings = T, recursive = T)
#some URLs are broken that shall be skipped
oldw <- getOption( 'warn' )
options(warn = -1)
for (i in 1:length( fin_df$primaryImageSmall ) ) {
  tryCatch( 
    download.file(
      fin_df$primaryImageSmall[i], 
      destfile = paste0('images/', fin_df$objectID[i] ,'.jpg'), 
      mode = 'wb', 
      quiet = T ), 
    error = function(e) print( paste( fin_df$primaryImageSmall[i] , 'did not work out') ) )    
}
options(warn = oldw)
