# Script to retrieve unq_ids used for data matching
# Retrieving consensus ASV sequences for usage in picrust2
# Quang Nguyen 
# unq ids not shared in repo 
library(phyloseq)
library(tidyverse)
library(biomformat)
library(seqinr)
library(glue)

# get directory
save_dir <- "//dartfs-hpc/rc/Lab/H/HoenA/Lab/QNguyen/ResultsFiles/"
source_dir <- "//dartfs-hpc/rc/Lab/H/HoenA/Lab/QNguyen/SourceFiles/"
crosswalk_dir <- "//dartfs-hpc/rc/Lab/H/HoenA/Lab/Share/SourceFiles/IDcrosswalk_jan2020/"

# listing files 
list.files(crosswalk_dir)

# Get raw data 
samples_6w <- readRDS(file = paste0(save_dir, "data/raw_6W_tar_phyloseq_obj.rds"))
samples_12m <- readRDS(file = paste0(save_dir, "data/raw_12M_tar_phyloseq_obj.rds"))

# crosswalk file 
crosswalk_6w <- read.csv(file = paste0(crosswalk_dir,"mbl.nmr.6W.paired.st.csv"), header = F)
crosswalk_12m <- read.csv(file = paste0(crosswalk_dir, "mbl.nmr.12M.paired.st.csv"), header = F)
# Retrieve sample names for quality control statistics
unq_6w <- sample_names(samples_6w)
unq_12m <- sample_names(samples_12m)

# Retrieve the names 
mblids_6w <- crosswalk_6w$V2[match(unq_6w, crosswalk_6w$V1)]
mblids_12m <- crosswalk_12m$V2[match(unq_12m, crosswalk_12m$V1)]

# Retrieve metabolomic ids  
uncids_6w <- crosswalk_6w$V3[match(unq_6w, crosswalk_6w$V1)]
uncids_12m <- crosswalk_12m$V3[match(unq_12m, crosswalk_12m$V1)]

write.table(uncids_6w, file = "output/unc_samp_ids_6w.csv", row.names = FALSE, col.names = c("ids"))
write.table(uncids_12m, file = "output/unc_samp_ids_12m.csv", row.names = FALSE, col.names = c("ids"))

# Retrieve Erika's matching
list.files(source_dir)
refid_6w <- read.csv(paste0(source_dir, "subject_samp_ids_6w.csv")) %>% pull(MBL_ID)
refid_12m <- read.csv(paste0(source_dir, "subject_samp_ids_12m.csv")) %>% pull(MBL_ID)

# check which ids are missing
mblids_6w[which(is.na(match(mblids_6w, refid_6w)))] 
mblids_12m[which(is.na(match(mblids_12m, refid_12m)))] 


write.table(mblids_6w, file  = "output/samp_ids_6w.csv", row.names = FALSE, col.names = c("ids"))
write.table(mblids_12m, file = "output/samp_ids_12m.csv", row.names = FALSE, col.names = c("ids"))


# Get index of which ASV that has a presence in less than 10 percent of samples  
get_index <- function(physeq){
  table <- otu_table(physeq) %>% as("matrix")
  presence <- apply(table,2, function(x) sum(x > 0)) %>% unname()
  index <- which(presence < 0.1 * nrow(table))
  return(index)
}


# Filter samples and write to biom file
seq_6w <- readRDS(file = paste0(source_dir, "AH_Jan2020/sv6W_ST/seqtab.nochim.colnames_6W_ST.rds")) %>%
  as.list()
# Get sequence names
names(seq_6w) <- paste0("SV",1:length(seq_6w))
# Filter out ASVs with at least presence in 10% of samples
samples_6w <- filter_taxa(samples_6w, function(x) sum(x > 0) >= 0.1*length(x), TRUE)

idx <- which(names(seq_6w) %in% taxa_names(samples_6w))
seq_6w <- seq_6w[idx]

write.fasta(seq_6w, names = names(seq_6w), file.out = "picrust2/seqs/6w_asv_filt.fa")

biom_6w <- make_biom(
  data = t(otu_table(samples_6w))
)
write_biom(biom_6w, biom_file = "picrust2/bioms/biom_6w.biom")

# Get sequences for 12m 
seq_12m <- readRDS(file = paste0(source_dir, "AH_Jan2020/sv12M_ST/seqtab.nochim.colnames_12M_ST.rds")) %>%
  as.list()
names(seq_12m) <- paste0("SV", 1:length(seq_12m))
samples_12m <- filter_taxa(samples_12m, function(x) sum(x > 0) >= 0.1 * length(x), TRUE)
idx <- which(names(seq_12m) %in% taxa_names(samples_12m))
seq_12m <- seq_12m[idx]
write.fasta(as.list(seq_12m), names = names(seq_12m), file.out = "picrust2/seqs/12m_asv_filt.fa")

biom_12m <- make_biom(
  data = t(otu_table(samples_12m))
)
write_biom(biom_12m, biom_file = "picrust2/bioms/biom_12m.biom")


# Section on getting quality scores post filtering 
list.files(source_dir)
filt_6w <- read.csv(file = paste0(source_dir, "filter.16s.6W.csv"))
filt_12m <- read.csv(file = paste0(source_dir, "filter.16s.12M.csv"))
tail(filt_6w)
tail(filt_12m)

# Get IDS
samples <- readRDS(file = glue("{dir}NMR/nmr_binned_ST_08May2018_v08Jan2020_v2.rds", dir = source_dir))
samples <- samples %>% rename("ids" = "TubeLabel")
master_tube_ids <- bind_rows(tibble(ids = uncids_6w, time = "6W"), tibble(ids = uncids_12m, time = "12M"))
master_tube_ids <- c(uncids_6w, uncids_12m)
drcc_ids <- left_join(master_tube_ids, samples) %>% select(ids, time, DRCC_ID)

write.table(drcc_ids, file  = "output/drcc_ids.csv", row.names = FALSE)
