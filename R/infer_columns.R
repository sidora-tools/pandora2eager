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
  } else if (x %in% c("NS500382 (Rosa)","NS500559 (Tosca)", "LH00454 (NovaSeq X Plus)" )) {
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
#' @param pandora_library_protocol_info Tibble with pandora protocol info
#' @param x character. The libbary protocol as it appears in Pandora.
#'
#' @return character vector
#' @importFrom magrittr %>%
#' @importFrom magrittr %$%
#' @export
infer_library_specs <- function(x, pandora_library_protocol_info) {
  udg_treatment <- NULL
  strandedness  <- NULL

  ## . %$% x is equivalent to . %>% pull(x)
  udg_treatment <- pandora_library_protocol_info %>% dplyr::filter(`protocol_name` == x) %$% `udg`
  strandedness  <- pandora_library_protocol_info %>% dplyr::filter(`protocol_name` == x) %$% `strandedness`

  ## Throw message if unknown and warning if failed
  if (udg_treatment == "Unknown" | strandedness == "Unknown") {
    message("Inference of strandedness and/or UDG treatment failed for library protocol '",x,"'. Field(s) set to 'Unknown'. Please fill in this informations manually.
Contact @TCLamnidis if you think the library protocol stated could be automatically inferred.
")
  } else if (udg_treatment == "Invalid" | strandedness == "Invalid") {
    warning("ERROR: Invalid inference of strandedness and/or UDG treatment failed for library protocol '",x,"'!")
  }

  return(c(strandedness, udg_treatment))
}
