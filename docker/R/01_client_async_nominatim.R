# ==============================================================================
# 01_client_async_nominatim.R
# Cliente HTTP asíncrono multi-hilo para consumo de Nominatim Local
# ==============================================================================

library(curl)
library(jsonlite)
library(dplyr)
library(stringr)

geocode_reverse_local_pool <- function(df_coords, base_url = "http://localhost:8080/reverse", pool_size = 20) {
  # Deduplicación dimensional de coordenadas
  coords_unique <- df_coords %>%
    select(coord_x_lon, coord_y_lat) %>%
    filter(!is.na(coord_x_lon) & !is.na(coord_y_lat)) %>%
    filter(coord_x_lon != 0 & coord_y_lat != 0) %>%
    distinct()
  
  if (nrow(coords_unique) == 0) {
    stop("ERROR: No se detectaron coordenadas válidas para consultar.")
  }
  
  urls <- sprintf(
    "%s?lat=%f&lon=%f&format=jsonv2&addressdetails=1&zoom=18",
    base_url,
    coords_unique$coord_y_lat,
    coords_unique$coord_x_lon
  )
  
  responses_raw <- vector("list", length(urls))
  pool <- new_pool(total_con = pool_size, host_con = pool_size)
  
  # Resolución de lazy evaluation mediante entornos léxicos aislados
  for (i in seq_along(urls)) {
    local({
      idx <- i
      h <- new_handle(url = urls[idx])
      handle_setheaders(h, "User-Agent" = "SpatialAuditEngine/1.0")
      multi_add(
        handle = h,
        done = function(res) { responses_raw[[idx]] <<- rawToChar(res$content) },
        fail = function(err) { responses_raw[[idx]] <<- NA_character_ },
        pool = pool
      )
    })
  }
  
  multi_run(pool = pool)
  
  # Parseo estructurado
  parse_record <- function(json_str, lon, lat) {
    if (is.na(json_str) || !nzchar(json_str)) {
      return(tibble(coord_x_lon = lon, coord_y_lat = lat, osm_road = NA_character_, 
                    osm_suburb = NA_character_, osm_display = NA_character_, osm_status = "NO_RESPONSE"))
    }
    dat <- tryCatch(fromJSON(json_str), error = function(e) NULL)
    if (is.null(dat) || !is.null(dat$error)) {
      return(tibble(coord_x_lon = lon, coord_y_lat = lat, osm_road = NA_character_, 
                    osm_suburb = NA_character_, osm_display = NA_character_, osm_status = "ERROR_PARSING"))
    }
    addr <- dat$address
    tibble(
      coord_x_lon = lon,
      coord_y_lat = lat,
      osm_road    = dplyr::coalesce(addr$road, addr$pedestrian, addr$path, NA_character_),
      osm_suburb  = dplyr::coalesce(addr$suburb, addr$neighbourhood, addr$quarter, addr$village, NA_character_),
      osm_display = dplyr::coalesce(dat$display_name, NA_character_),
      osm_status  = "RESOLVED"
    )
  }
  
  dim_resolved <- mapply(
    parse_record, 
    responses_raw, 
    coords_unique$coord_x_lon, 
    coords_unique$coord_y_lat, 
    SIMPLIFY = FALSE
  ) %>% bind_rows()
  
  return(dim_resolved)
}