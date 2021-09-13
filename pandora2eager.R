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

## Infer colour chemistry from sequencer name
infer_color_chem <- function(x) {
  color_chem <- NULL
    if (x %in% c("K00233 (HiSeq4000)","D00829 (HiSeq2500)","M02279 (MiSeq1)", "M06210 (MiSeq2)")) {
    color_chem=4
  } else if (x %in% c("NS500382 (Rosa)","NS500559 (Tosca)" )) {
    color_chem=2
  } else if (x %in% c("MinIon 1", "MinIon 2", "MinIon HKI")) {
    color_chem=NA
    message("MinIon sequencing does not have color chemistry. Set to NA.")
  } else {
    message("Color chemistry inference was not successful. Uninferred color chemistries set to 'Unknown'. Contact: lamnidis@shh.mpg.de.")
    color_chem="Unknown"
  }
  return(as.integer(color_chem))
}

## Infer strandedness and udg_treatment from protocol number
infer_library_specs <- function(x) {
  udg_treatment <- NULL
  strandedness <- NULL
  words <- str_split(x, " " , simplify = T)
  ## ssLib non-UDG
  if ((words[,1] == "ssLibrary" || words[,1] == "SsLibrary") && tail(words[1,],1) == "2018") {
    strandedness = "single"
    udg_treatment = "none"

  ## ssLib Unknown UDG
  } else if (words[,1] == "ssLibrary" && tail(words[1,],1) == "EVA") {
    message("Inference of UDG treatment failed for protocol '",x,"'. Setting to 'Unknown'.
You will need to fill in this information manually, since this protocol could refer to either UDG treatment.
")
    strandedness = "single"
    udg_treatment = "Unknown"
    
    ## ssLib automated non-UDG Leipzig
  } else if (words[,1] == "Automated_ss_library_preparation_noUDG_EVA_CoreUnit") {
    strandedness = "single"
    udg_treatment = "none"

  ## ssLib automated half-UDG Leipzig
  } else if (words[,1] == "Automated_ss_library_preparation_partialUDG_EVA_CoreUnit") {
    strandedness = "single"
    udg_treatment = "half"
    
  ## External
  } else if (words[,1] %in% c("Extern", "External")) {
    strandedness = "Unknown"
    udg_treatment = "Unknown"
    message("Cannot infer strandedness and UDG treatment for external libraries. Setting both to \"Unknown\".")

  ## Modern DNA
  } else if (words[,1] == "Illumina") {
    strandedness = "double"
    udg_treatment = "none"
  
  ## dsLib
  } else if (words[,1] == "dsLibrary") {
    strandedness = "double"

    ## Non UDG
    if (words[,3] == "UDG" ) {
      udg_treatment = "none"
      
    ## Half UDG
    } else if (words[,3] == "half") {
      udg_treatment = "half"
      
    ## Full UDG
    } else if (words[,3] == "full") {
      udg_treatment = "full"
    }
    
  ## Blanks
  } else if (words[,1] == "Capture") {
      udg_treatment = "none"
      strandedness = "double"
  
  ## Inference failed?
  } else {
      message("Inference of strandedness and UDG treatment failed for library protocol '",x,"'. Setting both fields to 'Unknown'. Please fill in this informations manually. 
Contact lamnidis@shh.mpg.de if you think the library protocol stated could be automatically inferred.
")
    udg_treatment = "Unknown"
    strandedness = "Unknown"
  }
  return(c(strandedness, udg_treatment))
}

## Main function that queries pandora, formats info and spits out a table with the necessary information for eager.
collect_and_format_info<- function(query_list_seq, con) {
  ## Get complete pandora table
  complete_pandora_table <- join_pandora_tables(
    get_df_list(
      c(make_complete_table_list(
        c("TAB_Site", "TAB_Raw_Data")
      )), con = con
    )
  )
  
  ## Get tabs of Organisms, Protocols and Sequencer names
  df_list <- get_df_list(
    c("TAB_Organism", "TAB_Protocol", "TAB_Sequencing_Sequencer"),con
  )
  
  results <- inner_join(complete_pandora_table, query_list_seq, by=c("sequencing.Full_Sequencing_Id"="Sequencing")) %>%
    select(library.Full_Library_Id, capture.Full_Capture_Id, sequencing.Sequencer, sequencing.Sequencing_Id, individual.Full_Individual_Id, library.Protocol, individual.Organism, raw_data.FastQ_Files) %>%
    ## Infer protocol and Organism names from Pandora indexes
    mutate(Protocol=map_chr(`library.Protocol`, function(prot) {df_list[["TAB_Protocol"]] %>% filter(`protocol.Id`==prot) %>% .[["protocol.Name"]]}),
           Organism=map_chr(`individual.Organism`, function(org) {df_list[["TAB_Organism"]] %>% filter(`organism.Id`==org) %>% .[["organism.Name"]]}),
           Sequencer=df_list[["TAB_Sequencing_Sequencer"]][["sequencer.Name"]][`sequencing.Sequencer`]) %>%
    ## Infer SE/PE sequencing from number of FastQs per lane.
    mutate(
      num_fq=map_int(`raw_data.FastQ_Files`, function(fq) {ncol(str_split(fq, " ", simplify = T))}), 
      num_r1=map(`raw_data.FastQ_Files`, function(fq) {sum(grepl("_R1_",str_split(fq, " ", simplify = T)))}),
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
      ## Library Strandedness and UDG Treatment from protocol name
      Strandedness=map_chr(`Protocol`, function (.) {infer_library_specs(.)[1]}), 
      UDG_Treatment=map_chr(`Protocol`, function(.){infer_library_specs(.)[2]}), 
      ## Colour Chemistry from sequencer name
      Colour_Chemistry=map_int(`Sequencer`, infer_color_chem),
      ## BAM column always set to NA
      BAM=NA
    ) %>%
    ## Rename final column names to valid Eager input headers
    rename(Sample_Name=individual.Full_Individual_Id, Library_ID=capture.Full_Capture_Id,) %>%
    ## Keep only final tsv columns in correct order
    select(Sample_Name, Library_ID, Lane, Colour_Chemistry, SeqType, Organism, Strandedness, UDG_Treatment, R1, R2, BAM)
  return(results)
}

## MAIN ##
args = commandArgs(trailingOnly=TRUE)

if (length(args) < 2) {
  write("No input file given. \n\nusage: Rscript query_pandora_for_data.R /path/to/input_seq_IDs_file.txt /path/to/pandora/.credentials [-r/--rename].\n\nOptions:\n\t -r/--rename\tChanges all dots (.) in the Library_ID field of the output to underscores (_).\n\t\t\tSome tools used in nf-core/eager will strip everything after the first dot (.)\n\t\t\tfrom the name of the input file, which can cause naming conflicts in rare cases.\n", file=stderr())
  quit(status = 1)
}

query_list_seq <- read_tsv(args[1], col_names = "Sequencing", col_types = 'c')
con <- get_pandora_connection(cred_file = args[2])

results <- collect_and_format_info(query_list_seq, con)

if (!is.na(args[3]) && args[3] == "--debug") {
  write_tsv(results, "Debug_table.txt")
} else if (!is.na(args[3]) && ( args[3] == "--rename" || args[3] == "-r")) {
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

