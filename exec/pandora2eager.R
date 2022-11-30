#!/usr/bin/env Rscript
if (!require('sidora.core')) {
  if(!require('remotes')) install.packages('remotes')
remotes::install_github('sidora-tools/sidora.core', quiet=T)
} else {library(sidora.core)}
library(purrr)
library(dplyr, warn.conflicts = F)
library(readr)
library(tidyr)
library(stringr)
library(pandora2eager)
library(optparse)

# Function to validate the file type
validate_file_type <- function(option, opt_str, value, parser) {
  valid_entries <- c("bam","fastq_pathogens") ## TODO comment: should this be embedded within the function? You would want to maybe update this over time no? 
  ifelse(value %in% valid_entries, return(value), stop(call.=F, "\n[pandora2eager.R] error: Invalid file type: '", value, 
                                                        "'\nAccepted values: ", paste(valid_entries,collapse=", "),"\n\n"))
}

# Function to read analysis tab for bam or fastq_pathogens options.
get_analysis_tab <- function(query_list_seq, con) {
  # get analysis tab from Pandora
  analysis_tab <- get_df("TAB_Analysis", con) %>%
  mutate(seqID=str_extract(analysis.Full_Analysis_Id, "[A-Z0-9]*.[A-z][0-9]*.[A-Z][A-Z][0-9]*.[0-9]+")) %>%
  inner_join(query_list_seq, by=c("seqID"="Sequencing")) %>%
  select(seqID, analysis.Result, analysis.Result_Directory, analysis.Title)
  return(analysis_tab)
}

## Main function that queries pandora, formats info and spits out a table with the necessary information for eager.
collect_and_format_info<- function(query_list_seq, con, file) {
  ## Get complete pandora table
  complete_pandora_table <- join_pandora_tables(
    get_df_list(
      c(make_complete_table_list(
        c("TAB_Site", "TAB_Raw_Data")
      )), con = con
    )
  ) %>% 
  convert_all_ids_to_values(., con = con)

  results <- inner_join(complete_pandora_table, query_list_seq, by=c("sequencing.Full_Sequencing_Id"="Sequencing")) %>%
    select(library.Full_Library_Id, sequencing.Sequencer, sequencing.Sequencing_Id, capture.Full_Capture_Id,  
    individual.Full_Individual_Id, library.Protocol, individual.Organism, raw_data.FastQ_Files, 
    sequencing.Full_Sequencing_Id) %>%
    mutate(
      ## Library Strandedness and UDG Treatment from protocol name
      Strandedness=map_chr(library.Protocol, function(.){pandora2eager::infer_library_specs(.)[1]}),
      UDG_Treatment=map_chr(library.Protocol, function(.){pandora2eager::infer_library_specs(.)[2]}),  
      ## Colour Chemistry from sequencer name
      Colour_Chemistry=map_int(sequencing.Sequencer, pandora2eager::infer_color_chem)
    )
    if ( is.na(file) ){ results <- results %>% 
    mutate(
      num_fq=map_int(`raw_data.FastQ_Files`, function(fq) {ncol(str_split(fq, " ", simplify = T))}),
      num_r1=map(`raw_data.FastQ_Files`, function(fq) {sum(grepl("_R1_",str_split(fq, " ", simplify = T)))}),
      ## Infer SE/PE sequencing from number of FastQs per lane.
      SeqType=ifelse(num_fq == num_r1, "SE", "PE")) %>%
    select(-starts_with("num_")) %>%
    ## Make R1 and R2 columns out of the FastQ file(s)
    mutate(`raw_data.FastQ_Files`=map(`raw_data.FastQ_Files`, function(fq) {str_replace_all(fq, " ([[:graph:]]*_R2_.{3}.fastq.gz)", paste0(";","\\1"))})) %>%
    separate_rows(`raw_data.FastQ_Files`, sep=" ") %>%
    separate(`raw_data.FastQ_Files`, into=c("R1", "R2"), sep=";", fill="right") %>%
    ## Infer Lane number from FastQ names
    mutate(
      ## Eager cannot handle same lane number for same Library_Id. Therefore lane number for additional sequencing needs to be
      ## artificially inflated (by 8 which is the max lane number in our sequencers). This approach has the advantage that the output
      ## for a given sequencing ID will be consistent and not dependent on the specific input file passed to this script.
      Lane=as.integer(str_replace(`R1`,"[[:graph:]]*_L([[:digit:]]{3})_R[[:graph:]]*", "\\1"))+8*(sequencing.Sequencing_Id-1),
      BAM=NA
    )} else if(file=="bam"){
      analysis_tab <- get_analysis_tab(query_list_seq, con) %>%
      ##Filter all the analysis.Results_Directory that have run through human pipelines
      filter(grepl("Human",analysis.Result_Directory)) %>%
      ##Filter out the bam file for the Libmerge_Genotypes, this will be done within eager
      filter(!grepl("_Libmerge_Genotypes",analysis.Result_Directory)) %>%
      select(seqID, analysis.Result_Directory) %>%
      ##Remove duplicated lines 
      distinct()

      results <- results %>%
      inner_join(analysis_tab, by=c("sequencing.Full_Sequencing_Id"="seqID")
      ) %>%
      mutate(Lane=row_number(), 
      R1="NA", 
      R2="NA", 
      analysis.Result_Directory=str_replace(analysis.Result_Directory, "^/projects1", "/mnt/archgen"),
      BAM=paste0(analysis.Result_Directory,sequencing.Full_Sequencing_Id,".bam"), 
      SeqType="SE")
    } else if(file=="fastq_pathogens"){
      analysis_tab <- get_analysis_tab(query_list_seq, con) %>%
      ##Filter all the analysis.Title that have a fastq with mapped reads (only existing in the prescreening pipelines)
      filter(analysis.Title=="Fastq mapped reads")

      results <- results %>%
      inner_join(analysis_tab, by=c("sequencing.Full_Sequencing_Id"="seqID")) %>%
      mutate(Lane=row_number(), R1= analysis.Result, R2="NA", BAM="NA", SeqType="SE")
    }

    results_Final <- results %>%
    ## Rename final column names to valid Eager input headers
    rename(Sample_Name=individual.Full_Individual_Id, Library_ID=capture.Full_Capture_Id, Organism=individual.Organism) %>%
    ## Keep only final tsv columns in correct order
    select(Sample_Name, Library_ID, Lane, Colour_Chemistry, SeqType, Organism, Strandedness, UDG_Treatment, R1, R2, BAM)
  return(results_Final)
}

## MAIN ##
parser <- OptionParser(usage = "%prog [options] /path/to/input_seq_IDs_file.txt /path/to/pandora/.credentials")
parser <- add_option(parser, c("-r","--rename"),
                        action = 'store_true',
                        dest = "rename",
                        help = 'Changes all dots (.) in the Library_ID field of the output to underscores (_).\n\t\t\tSome tools used in nf-core/eager will strip everything after the first dot (.)\n\t\t\tfrom the name of the input file, which can cause naming conflicts in rare cases.\n',
                        default = FALSE)
parser <- add_option(parser, c("-d","--debug"),
                        action = 'store_true',
                        dest = "debug",
                        help = 'Activate debug mode, it produces a file called: Debug_table.txt',
                        default = FALSE)
parser <- add_option(parser, c("-f","--file_type"),
                        type = 'character',
                        action = "callback",
                        callback = validate_file_type, 
                        default= NA,
                        dest = "file",
                        help= 'Specify the file type of the input files. Accepted values are: \"bam\", \"fastq_pathogens\". \n\t\t\tNote: if this flag is not provided, raw fastq will be used to generate the table')

argv <- parse_args(parser, positional_arguments = 2)
opts <- argv$options

query_list_seq <- read_tsv(argv$args[1], col_names = "Sequencing", col_types = 'c')
con <- get_pandora_connection(cred_file = argv$args[2])

results <- collect_and_format_info(query_list_seq, con, opts$file)

if (opts$debug == TRUE) {
  write_tsv(results, "Debug_table.txt")
}

if (opts$rename == TRUE) {
  cat(
    format_tsv(results %>%
                  mutate(Library_ID=str_replace_all(Library_ID, "[.]", "_")) %>% ## Replace dots in the Library_ID to underscores.
                  select(Sample_Name, Library_ID,  Lane, Colour_Chemistry,
                        SeqType, Organism, Strandedness, UDG_Treatment, R1, R2, BAM))
  )
} else {
  cat(
    format_tsv(results %>%
              select(Sample_Name, Library_ID,  Lane, Colour_Chemistry,
                      SeqType, Organism, Strandedness, UDG_Treatment, R1, R2, BAM))
  )
}

