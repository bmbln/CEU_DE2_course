# Get the Snuffboxes ----------------------------------------------------

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


# Set up R w/ AWS ----------------------------------------------------

### the key is saved on my local instances 
keyfile = list.files(path=".", pattern="accessKeys.csv", full.names=TRUE)
if (identical(keyfile, character(0))){
  stop("ERROR: AWS key file not found")
} 
keyTable <- read.csv(keyfile, header = T) 
AWS_ACCESS_KEY_ID <- as.character(keyTable$Access.key.ID)
AWS_SECRET_ACCESS_KEY <- as.character(keyTable$Secret.access.key)
Sys.setenv("AWS_ACCESS_KEY_ID" = AWS_ACCESS_KEY_ID,
           "AWS_SECRET_ACCESS_KEY" = AWS_SECRET_ACCESS_KEY,
           "AWS_DEFAULT_REGION" = "eu-west-1") 

# Load up into S3 ---------------------------------------------------------
library(aws.s3)

BUCKET = "bmbln" # MY BUCKET

s3sync(path = 'images', 
       bucket = BUCKET, 
       direction = 'upload', 
       verbose = T, 
       recursive = T)

# Amazon Rekognition: Snuffboxes ------------------------------------------------

library(paws.machine.learning)

get_labels_snuff <- function( bucket_name ) {
  svc <- paws.machine.learning::rekognition()
  #get file names from the bucket
  pics <- get_bucket_df( bucket_name , max = Inf)$Key
  
  #get labels for each picture
  label_df <- rbindlist(
    lapply(pics, function(x){
    
      snuff_labels <- svc$detect_labels( 
        list(
         S3Object = list(
          Bucket = bucket_name,
          Name = x)
         ), MaxLabels = 10)
      
      #sometimes it throws an error so let's seek some help from tryCatch
      df <- tryCatch( 
        {rbindlist( snuff_labels$Labels, fill = T) %>% 
          subset(select = c('Name', 'Confidence')) %>% 
          mutate( Object = x ) } , 
        error=function(e){}
        )
      
      return(df)
    })
    )
  
  # return what we have
  return(label_df)
}

snuffbox_labels <- get_labels_snuff(BUCKET)

#some stuff came back duplicated 
snuffbox_labels <- unique( snuffbox_labels )

#save labels into a csv file
write_csv( snuffbox_labels , file = 'datasets/snuffbox_labels.csv')

# let's not burn my university's money and delete the bucket with the images 
delete_bucket(BUCKET)

# What we have? Some word clouds? ----------------------------------------------

# for the word cloud
library(wordcloud)
library(RColorBrewer)

#Not snuffbox for sure, what else?
snuffbox_labels_words <- snuffbox_labels %>% 
  group_by(Name) %>% 
  summarise( Confidence = sum(Confidence) , 
             Count = n() )

set.seed(1234)

#use confidence as frequency
wordcloud(words = snuffbox_labels_words$Name, 
          freq = (snuffbox_labels_words$Confidence), 
          random.order = F ,
          colors = brewer.pal( 8 , "Dark2" ) ,
          scale = c( 1.5 , .4 ) )

#filter for labels that AWS was more than 95% confident about
snuffbox_labels_words_mostconfident <- snuffbox_labels %>% 
  filter( Confidence > 95 ) %>% 
  group_by(Name) %>% 
  summarise_if( is.numeric , sum)

wordcloud( words = snuffbox_labels_words_mostconfident$Name , 
          freq = snuffbox_labels_words_mostconfident$Confidence ,
          random.order = F, 
          colors = brewer.pal( 8 , "Dark2") , 
          scale = c( 2 , .45 ) )

#filter for labels that AWS was less than 60% confident about
snuffbox_labels_words_leastconfident <- snuffbox_labels %>% 
  filter( Confidence < 60 ) %>% 
  group_by(Name) %>% 
  summarise_if( is.numeric , sum)

wordcloud( words = snuffbox_labels_words_leastconfident$Name , 
           freq = snuffbox_labels_words_leastconfident$Confidence ,
           random.order = F, 
           colors = brewer.pal( 8 , "Dark2") , 
           scale = c( 1.5 , .45 ) )

