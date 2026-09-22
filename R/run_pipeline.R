# ==============================================================================
# run_pipeline.R
# Orquestador del flujo analitico y generacion de reportes
# ==============================================================================

source("R/01_client_async_nominatim.R")
source("R/02_fuzzy_address_matcher.R")

cat("[INFO] Cargando datos sinteticos...\n")
df_input <- read.csv("data/mock_spatial_data.csv", stringsAsFactors = FALSE)

cat("[INFO] Consultando cluster local...\n")
dim_osm <- geocode_reverse_local_pool(df_input, base_url = "http://localhost:8080/reverse")

df_audited <- df_input %>%
  left_join(dim_osm, by = c("coord_x_lon", "coord_y_lat")) %>%
  mutate(
    addr_norm    = clean_canonical_string(source_address),
    display_norm = clean_canonical_string(osm_display),
    road_norm    = clean_canonical_string(osm_road),
    suburb_norm  = clean_canonical_string(osm_suburb),
    parish_norm  = clean_canonical_string(target_parish),
    
    token_overlap = calculate_token_overlap_ratio(addr_norm, display_norm),
    jw_road_sim   = stringsim(addr_norm, road_norm, method = "jw", p = 0.1),
    jw_parish_sim = stringsim(parish_norm, suburb_norm, method = "jw", p = 0.1),
    
    flag_parish_in_display = detect_pattern_safe(display_norm, parish_norm),
    
    audit_address_status = case_when(
      is.na(addr_norm) ~ "MISSING_SOURCE_ADDRESS",
      osm_status != "RESOLVED" ~ paste0("API_", osm_status),
      detect_pattern_safe(display_norm, addr_norm) | (!is.na(token_overlap) & token_overlap >= 0.70) ~ "HIGH_MATCH",
      (!is.na(token_overlap) & token_overlap >= 0.40) | (!is.na(jw_road_sim) & jw_road_sim >= 0.75) ~ "PARTIAL_MATCH",
      TRUE ~ "DISCREPANCY"
    ),
    
    audit_parish_status = case_when(
      is.na(parish_norm) ~ "MISSING_TARGET_PARISH",
      osm_status != "RESOLVED" ~ paste0("API_", osm_status),
      is.na(suburb_norm) ~ "SUBURB_NOT_IN_OSM",
      parish_norm == suburb_norm ~ "EXACT_MATCH",
      flag_parish_in_display | (!is.na(jw_parish_sim) & jw_parish_sim >= 0.85) ~ "CONTAINED_OR_FUZZY_MATCH",
      TRUE ~ "PARISH_DISCREPANCY"
    )
  )

cat("\n[CONTROL] Auditoria de Direcciones:\n")
print(table(df_audited$audit_address_status, useNA = "ifany"))

cat("\n[CONTROL] Auditoria Administrativa:\n")
print(table(df_audited$audit_parish_status, useNA = "ifany"))
