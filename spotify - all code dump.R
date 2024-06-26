library(ggplot2)
library(igraph)
library(readr)
library(dplyr)
library(tidyr)
library(Matrix)
library(png)
setwd("C:/Users/Charl/Programming/SpotifyPlaylistSplitter")
#playlist <- read_delim("spotify_playlist.csv", delim = ",",escape_double = TRUE)
get_playlist_data <- function(n=-1) {
  # Read the data
  playlist <- read_delim("spotify_playlists.csv", delim = ",", escape_double = TRUE)
  
  # Select the first n rows
  if (n > 0){
    playlist <- playlist[1:n,]
  }
  
  #################  DATA CLEANING ####################
  # Fix the column names
  colnames(playlist) <- gsub(' "trackname"', 'track_name', colnames(playlist))
  colnames(playlist) <- gsub(' "artistname"', 'artist_name', colnames(playlist))
  colnames(playlist) <- gsub(' "playlistname"', 'playlist_name', colnames(playlist))
  
  return(playlist)
}
get_charlies_playlists <- function() {
  # Read the data
  playlist <- read_delim("Charlies_playlists.csv", delim = ",", escape_double = TRUE)
  return(playlist)
}
get_song_user_matrix <- function(
    rows_to_scrape=-1, 
    min_song_occurences,
    song_list = c(),
    include_charlie = FALSE
){
  playlist <- get_playlist_data(rows_to_scrape) %>%
    mutate(song = paste(artist_name, track_name, sep = " - ")) %>%
    select(user_id,song) %>%
    unique()
  #Removes irrelevant songs if present
  if (length(song_list)>=1){
    playlist <- playlist %>%
      filter(song %in% song_list)
  }
  if (include_charlie){
    playlist <- rbind(playlist, get_charlies_playlists() %>%
                        select(user_id,song) %>%
                        unique()
    )
  }
  playlist <- playlist %>%
    group_by(song) %>%
    filter(n() >= min_song_occurences) %>% #Remove all songs occuring only once, since they cannot be analysed
    ungroup() %>%
    ####### From here transforms the list of users/songs into an adjacency matrix
    group_by(user_id, song) %>%
    summarize(value = 1) %>%
    ungroup() %>%
    spread(key = song, value = value, fill = 0)
  
  playlist <- as.data.frame(playlist)
  rownames(playlist) <- playlist[, 1]
  playlist <- as.matrix(playlist[,-1]) # Remove user_id column
  
  return(playlist)
}
get_song_playlist_matrix <- function(
    rows_to_scrape=-1,
    min_playlist_length=1, 
    max_playlist_length=1000, 
    min_song_occurences=1,
    song_list = c(),
    include_charlie = FALSE)
{
  playlist <- get_playlist_data(rows_to_scrape) %>%
    mutate(song = paste(artist_name, track_name, sep = " - ")) %>%
    mutate(playlist_name = paste(playlist_name, substr(user_id, 1, 4), sep = " -")) %>%
    select(playlist_name,song) %>%
    unique()
  #Removes irrelevant songs if present
  if (length(song_list)>=1){
    playlist <- playlist %>%
      filter(song %in% song_list)
  }
  if (include_charlie){
    playlist <- rbind(playlist, get_charlies_playlists() %>%
                        select(playlist_name,song) %>%
                        unique()
    )
  }
  playlist <- playlist %>%
    group_by(song) %>%
    filter(n() >= min_song_occurences) %>% #Remove all songs occuring only once, since they cannot be analysed
    ungroup() %>%
    group_by(playlist_name) %>%
    filter(n() >= min_playlist_length) %>% #Removes all playlists that are too short to provide useful data
    filter(n() <= max_playlist_length) %>%
    ungroup() %>% #Up to here returns cleaned up list of playlists and songs
    ######From here transforms it into an adjacency matrix
    group_by(playlist_name, song) %>%
    summarize(value = 1) %>%
    ungroup() %>%
    spread(key = song, value = value, fill = 0)
  playlist <- as.data.frame(playlist)
  rownames(playlist) <- playlist[, 1]
  playlist <- as.matrix(playlist[,-1]) # Remove playlist_name column
  return(playlist)
}



####### Create weighted graph of song adjacencies
# Calculate the common songs matrix
song_matrix <- get_song_user_matrix(
  rows_to_scrape = 30000,
  min_song_occurences = 2
)
adjacency_matrix <- t(song_matrix) %*% song_matrix
adjacency_matrix <- adjacency_matrix[1:1000,1:1000]
g <- graph_from_adjacency_matrix(adjacency_matrix,mode = c("undirected"), weighted=TRUE,diag=FALSE)
edge_density(g)
transitivity(g, type="global")
diameter(g)
deg <- degree(g, mode="all")
hist(deg, breaks=1:vcount(g)-1, main="Histogram of node degree")

######## Bipartite graph linking users and songs
song_matrix = get_song_user_matrix(
  rows_to_scrape = 5000,
  min_song_occurences = 1
)
g<- graph_from_biadjacency_matrix(song_matrix)
l <- layout_with_kk(g)
plot(g, 
     vertex.label = NA,
     vertex.size=ifelse(V(g)$type, 2, 5),
     vertex.color=ifelse(V(g)$type, "blue", "orange"),
     vertex.frame.color="white",
     #edge.width = E(g)$weight/50,
     #edge.color = edge_colors,
     edge.curved=0.1,
     layout=l,
     rescale=T)



######## #################### #################### #################### #################### ############
#Do the same process but looking at playlists and songs, as opposed to users:
######## #################### #################### #################### #################### ############

######## PLAYLIST ADJACENCY ANALYSIS
song_matrix = get_song_playlist_matrix(
  rows_to_scrape = 40000, # maybe try adjusting this upwars
  min_playlist_length = 5, 
  max_playlist_length = 9999,
  min_song_occurences = 2
)
adjacency_matrix <- song_matrix %*% t(song_matrix)
adjacency_matrix[adjacency_matrix < 10] <- 0
max(adjacency_matrix)
g <- graph_from_adjacency_matrix(adjacency_matrix,mode = c("undirected"), weighted=TRUE,diag=FALSE)

# Plot the graph
l <- layout_with_fr(g, weights = NA)
l <- norm_coords(l, ymin=-1, ymax=1, xmin=-1, xmax=1) # Normalize them so that they are in the -1, 1 interval:
l <- layout_with_kk(g)
l <- layout_on_sphere(g)
l <- layout_in_circle(g, order=sort(rownames(song_matrix)))
# Define a color palette
palette <- colorRampPalette(c("lightgrey", "black"))
# Map edge weights to colors
edge_colors <- palette(30)[cut((E(g)$weight**0.5)/4, breaks = 30)]
plot(g, 
     vertex.label = NA,
     vertex.size=2,
     vertex.color="blue",
     vertex.frame.color="white",
     edge.width = (E(g)$weight**0.5)/4,
     edge.color = edge_colors,
     edge.curved=0.1,
     layout=l,
     rescale=T)

deg <- degree(g, mode="all")
hist(deg, breaks=1:vcount(g)-1, main="Histogram of node degree")

####### SONG ADJACENCY ANALYSIS USING PLAYLISTS
song_matrix = get_song_playlist_matrix(
  rows_to_scrape = 10000,
  min_playlist_length = 5,
  min_song_occurences = 1
)
adjacency_matrix <- t(song_matrix) %*% song_matrix
adjacency_matrix <- adjacency_matrix[1:1000,1:1000]
g <- graph_from_adjacency_matrix(adjacency_matrix,mode = c("undirected"), weighted=TRUE,diag=FALSE)
edge_density(g)
transitivity(g, type="global")
diameter(g)
deg <- degree(g, mode="all")
hist(deg, breaks=1:vcount(g)-1, main="Histogram of node degree")

###### BIPARTITE GRAPH LOOKING AT CONNECTIONS BETWEEN SONGS AND PLAYLISTS
song_matrix = get_song_playlist_matrix(
  rows_to_scrape = 5000,
  min_playlist_length = 5,
  max_playlist_length = 1000,
  min_song_occurences = 1
)
g<- graph_from_biadjacency_matrix(song_matrix)
l <- layout_with_kk(g)
plot(g, 
     vertex.label = NA,
     vertex.size=ifelse(V(g)$type, 2, 5),
     vertex.color=ifelse(V(g)$type, "blue", "orange"),
     vertex.frame.color="white",
     #edge.width = E(g)$weight/50,
     #edge.color = edge_colors,
     edge.curved=0.1,
     layout=l,
     rescale=T)



###################################################################################################
################## Analyse adjacencies for specific songs from a specific playlist ################
###################################################################################################
song_matrix = get_song_playlist_matrix(
  rows_to_scrape = 60000,
  min_playlist_length = 1000,
  max_playlist_length = 10000,
  min_song_occurences = 1
)
playlist_names <- rownames(song_matrix)
playlist_name = playlist_names[3]
playlist_row_index <- which(rownames(song_matrix) == playlist_name)
songs_in_playlist <- colnames(song_matrix)[song_matrix[playlist_row_index,] != 0]

####### SONG ADJACENCY ANALYSIS USING PLAYLISTS
song_matrix = get_song_playlist_matrix(
  rows_to_scrape = 1000000,
  min_playlist_length = 5,
  min_song_occurences = 1,
  max_playlist_length = 500,
  song_list = songs_in_playlist
)
adjacency_matrix <- t(song_matrix) %*% song_matrix
g <- graph_from_adjacency_matrix(adjacency_matrix,mode = c("undirected"), weighted=TRUE,diag=FALSE)
rm(adjacency_matrix)
edge_density(g)
transitivity(g, type="global")
diameter(g)
deg <- degree(g, mode="all")
hist(deg, breaks=1:vcount(g)-1, main="Histogram of node degree")
l <- layout_with_fr(g)
#https://stackoverflow.com/questions/22453273/how-to-visualize-a-large-network-in-r
plot(g, 
     vertex.label = NA,
     vertex.size=1,
     vertex.color="blue",
     vertex.frame.color="white",
     edge.curved=0.1,
     layout=l,
     rescale=T)
ceb <- cluster_edge_betweenness(g) 
plot(ceb,
     g, 
     vertex.label = NA,
     vertex.size=1,#ifelse(V(g)$type, 2, 5),
     vertex.frame.color=NA,#"white",
     edge.width = 0.1,
     edge.color = NA,
     edge.curved=0.1,
     #layout=l,
     rescale=T)
ceb_louvain <- cluster_louvain(g)
plot(ceb_louvain,
     g, 
     vertex.label = NA,
     vertex.size=1,#ifelse(V(g)$type, 2, 5),
     vertex.frame.color=NA,#"white",
     edge.width = 0.1,
     edge.color = NA,
     edge.curved=0.1,
     layout=layout_with_fr(g),
     rescale=T)
print(community)
length(ceb)
membership_vector <- membership(ceb)

library(linkcomm)

# Convert the adjacency matrix to an edge list
edge_list <- get.edgelist(g)

# Detect overlapping communities using link communities
lc <- getLinkCommunities(edge_list, hcmethod = "average")

# Print the link communities
plot(lc, 
     type='graph',
     vlabel = FALSE,
     vshape = 'circle',
     vsize = 1,
     node.pies = FALSE,)
num_lc_clusters = length(lc$clusters)
for (cluster_number in 1:num_lc_clusters){#num_lc_clusters){
  songs_in_cluster = getNodesIn(lc,cluster_number)
  if (length(songs_in_cluster) > 10){
    subgraph <- induced_subgraph(g, songs_in_cluster)
    
    # 2. Get the weights of the edges
    edge_weights <- E(subgraph)$weight
    
    # 3. Calculate mean and median
    mean_weight <- mean(edge_weights)
    median_weight <- median(edge_weights)
    if(mean_weight>5 && median_weight>=4){
      print(songs_in_cluster)
    }
  }
}


#TODO: Split playlists
#TODO: Rather than split playlists, split the songs linked to a user,
#   then compare those splits to the playlists they'd already generated
#   This should give an idea of how well the process works.


song_info <- read.csv("spotify_song_info.csv")

