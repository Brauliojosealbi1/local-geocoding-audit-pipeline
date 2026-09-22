# ==============================================================================
# 02_fuzzy_address_matcher.R
# Algoritmos de normalización canónica, solapamiento de tokens y concordancia
# ==============================================================================

library(dplyr)
library(stringr)
library(tidyr)
library(stringdist)

clean_canonical_string <- function(txt) {
  res <- txt %>%
    as.character() %>%
    toupper() %>%
    iconv(to = "ASCII//TRANSLIT") %>%
    str_replace_all("[-.,/]", " ") %>%
    str_replace_all("\\b0+(\\d+)\\b", "\\1") %>%
    str_replace_all("\\b0+\\b", "0") %>%
    str_squish()
  
  if_else(is.na(res) | res == "", NA_character_, res)
}

detect_pattern_safe <- function(text_vec, pattern_vec) {
  valid <- !is.na(text_vec) & !is.na(pattern_vec) & nzchar(text_vec) & nzchar(pattern_vec)
  out <- rep(FALSE, length(text_vec))
  if (any(valid)) {
    out[valid] <- str_detect(text_vec[valid], fixed(pattern_vec[valid]))
  }
  return(out)
}

calculate_token_overlap_ratio <- function(source_vec, target_display_vec) {
  stop_words <- c("CALLE", "AVENIDA", "AV", "DE", "LA", "EL", "LOS", "LAS", "Y", "EN", "SN", "N", "NO")
  
  mapply(function(src, tgt) {
    if (is.na(src) || is.na(tgt) || !nzchar(src) || !nzchar(tgt)) return(NA_real_)
    tokens <- unlist(str_split(src, "\\s+"))
    valid_tokens <- tokens[nchar(tokens) > 2 & !(tokens %in% stop_words) & !str_detect(tokens, "^\\d+$")]
    if (length(valid_tokens) == 0) return(if (detect_pattern_safe(tgt, src)) 1.0 else 0.0)
    matches <- sum(sapply(valid_tokens, function(tok) detect_pattern_safe(tgt, tok)))
    return(round(matches / length(valid_tokens), 4))
  }, source_vec, target_display_vec, USE.NAMES = FALSE)
}