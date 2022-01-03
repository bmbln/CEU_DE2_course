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
