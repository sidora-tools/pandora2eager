#' Collect UDG and strandedness information for Pandora library preparation protocols
#'
#' @param con A pandora database connection object.
#'
#' @return A tibble containg the protocol_name, udg, and strandedness of all library protocols in pandora.
#' @importFrom magrittr %>%
#'
load_library_protocol_info <- function(con) {
  ## Load relevant information from Protocol tab of pandora
  pandora_library_protocol_info <- sidora.core::get_df("TAB_Protocol", con) %>%
    dplyr::filter(`protocol.Type` == "Library") %>%
    dplyr::select(
      `protocol_name` = `protocol.Name`,
      `udg` = `protocol.Library_UDG`,
      `strandedness` = `protocol.Library_Strandedness`
    ) %>%
    ## Validate
    validate_protocol_info()

  pandora_library_protocol_info
}

#' Validate pandora library info
#'
#' @param x tibble.
#'
#' @return tibble
#' @importFrom magrittr %>%
#'
validate_protocol_info <- function(x) {
  x %>% dplyr::mutate(
      ## Validate UDG
      `udg` = dplyr::case_when(
        `udg` %in% c('none', 'half', 'full') ~ `udg`,
        `udg` == 'partial' ~ 'half',
        is.na(`udg`) ~ 'Unknown',
        TRUE ~ 'Invalid'
      ),
      ## Validate Strandedness
      `strandedness` = dplyr::case_when(
        `strandedness` %in% c('single', 'double') ~ `strandedness`,
        is.na(`strandedness`) ~ 'Unknown',
        TRUE ~ 'Invalid'
      )
  )
}
