library(httr)
library(aws.s3)
library(jsonlite)
library(lubridate)


#### PREP 1: Read keys saved locally. NOT UPLOADED TO THE REPO! 
keyfile = list.files(path=".", pattern="accessKeys.csv", full.names=TRUE)
if (identical(keyfile, character(0))){
  stop("ERROR: AWS key file not found")
} 
keyTable <- read.csv(keyfile, header = T) # *accessKeys.csv == the CSV downloaded from AWS containing your Access & Secret keys
AWS_ACCESS_KEY_ID <- as.character(keyTable$Access.key.ID)
AWS_SECRET_ACCESS_KEY <- as.character(keyTable$Secret.access.key)
#ACTIVATE FOR AWS CONNECTION
Sys.setenv("AWS_ACCESS_KEY_ID" = AWS_ACCESS_KEY_ID,
           "AWS_SECRET_ACCESS_KEY" = AWS_SECRET_ACCESS_KEY,
           "AWS_DEFAULT_REGION" = "eu-west-1") 


#### Set Date as the DATE_PARAM variable in your R script
DATE_PARAM="2021-10-07"
date <- as.Date(DATE_PARAM, "%Y-%m-%d")


#### There is a Pageviews API endpoint, where you can retrieve the 1000 Most viewed articles (metrics/pageviews/top). Retrieve them for  Pageviews API endpointacross all devices (all-access) for the date set in DATE_PARAM
#I decided to go for the fr.wikipedia.org - it wasn't specified in the task description. 
url <- paste(
  "https://wikimedia.org/api/rest_v1/metrics/pageviews/top/fr.wikipedia.org/all-access/",
  format(date, "%Y/%m/%d"), sep='')

wiki.server.response = GET(url)
#check whether the response is OK: 200 
wiki.response.status = status_code(wiki.server.response)
print(paste('Wikipedia API Response: ', wiki.response.status, sep=''))

#### Create a local folder called raw-views and save the API response to this folder in a file called raw-views-YYYY-MM-DD, where the YYYY-MM-DD is the DATE_PARAM value in the filename in the YYYY-MM-DD format.
RAW_LOCATION_BASE = 'data/raw-views'
dir.create( file.path( RAW_LOCATION_BASE ) , showWarnings = TRUE, recursive = TRUE)

raw.output.filename = paste( "raw-views-" , DATE_PARAM , '.txt' ,
                            sep = '' )
raw.output.fullpath = paste( RAW_LOCATION_BASE , '/', 
                            raw.output.filename , sep = '' )
write( wiki.response.body , raw.output.fullpath )


#### Upload the file you created to S3 into your bucket into an object called datalake/raw/raw-views-YYYY-MM-DD.txt
BUCKET = "bmbln" # MY BUCKET

put_object( file = raw.output.fullpath ,
           object = paste('datalake/raw/' , 
                          raw.output.filename ,
                          sep = "" ) ,
           bucket = BUCKET ,
           verbose = TRUE )

#### Convert the response into a JSON lines formatted file
## Write the file to your computer to data/views/views-YYYY-MM-DD.json
##  Each line must contain the following records: article, views, rank (from the response), and add the date (DATE_PARAM value) and a retrieved_at value (the current local timestamp).


wiki.response.parsed = content(wiki.server.response , 'parsed' )
top.views = wiki.response.parsed$items[[1]]$articles

current.time = Sys.time() 
json.lines = ""
for (page in top.views){
  record = list(
    article = page$article,
    views = page$views,
    rank = page$rank,
    date = format( date , "%Y-%m-%d" ) ,
    retrieved_at = current.time
  )
  
  json.lines = paste( json.lines , 
                     toJSON( record ,
                            auto_unbox = TRUE ) ,
                     "\n" , 
                     sep = '' )
}

JSON_LOCATION_BASE='data/views'
dir.create(file.path(JSON_LOCATION_BASE), showWarnings = TRUE)

json.lines.filename = paste("views-", format(date, "%Y-%m-%d"), '.json',
                            sep='')
json.lines.fullpath = paste(JSON_LOCATION_BASE , '/', 
                            json.lines.filename , sep='')

write( json.lines , file = json.lines.fullpath )

put_object( file = json.lines.fullpath,
           object = paste( 'datalake/views/' , 
                          json.lines.filename ,
                          sep = "" ) ,
           bucket = BUCKET,
           verbose = TRUE )
