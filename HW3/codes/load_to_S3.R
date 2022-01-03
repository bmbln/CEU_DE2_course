library(aws.s3)

BUCKET = "bmbln" # MY BUCKET

s3sync(path = 'images', 
       bucket = BUCKET, 
       direction = 'upload', 
       verbose = T, 
       recursive = T)