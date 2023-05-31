#' Infer colour chemistry from sequencer name
#'
#' @param x character. The sequencer name as it appears in Pandora.
#'
#' @return integer
#' @export
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

#' Infer strandedness and udg_treatment from protocol number
#'
#' @param x character. The libary protocol as it appears in Pandora.
#'
#' @return character vector
#' @export
infer_library_specs <- function(x) {
  udg_treatment <- NULL
  strandedness <- NULL
  words <- stringr::str_split(x, " " , simplify = T)
  ## ssLib non-UDG
  if ((words[,1] == "ssLibrary" || words[,1] == "SsLibrary") && utils::tail(words[1,],1) == "2018") {
    strandedness = "single"
    udg_treatment = "none"

  ## New ssDNA non-UDG protocol added in 2023
  } else if (x == "ssLibrary nonUDG 96well 3.0 2023") {
    strandedness = "single"
    udg_treatment = "none"

    ## ssLib Unknown UDG
  } else if (words[,1] == "ssLibrary" && utils::tail(words[1,],1) == "EVA") {
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
Contact @TCLamnidis if you think the library protocol stated could be automatically inferred.
")
    udg_treatment = "Unknown"
    strandedness = "Unknown"
  }
  return(c(strandedness, udg_treatment))
}
