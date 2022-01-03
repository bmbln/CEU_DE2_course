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