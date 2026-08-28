read_michigan_counties <- function(gazetteer_zip, state_fips = "26") {
  if (!file.exists(gazetteer_zip)) stop("County Gazetteer archive is missing: ", gazetteer_zip, call. = FALSE)
  members <- unzip(gazetteer_zip, list = TRUE)$Name
  text_member <- members[grepl("\\.txt$", members, ignore.case = TRUE)]
  if (length(text_member) != 1L) stop("Expected one county Gazetteer text file.", call. = FALSE)
  connection <- unz(gazetteer_zip, text_member)
  data <- readr::read_delim(connection, delim = "|", show_col_types = FALSE, trim_ws = TRUE)
  names(data) <- tolower(names(data))
  data |>
    dplyr::filter(substr(.data$geoid, 1, 2) == state_fips) |>
    dplyr::transmute(
      geoid = as.character(.data$geoid),
      county_name = sub(" County$", "", as.character(.data$name)),
      latitude = as.numeric(.data$intptlat),
      longitude = as.numeric(.data$intptlong)
    ) |>
    dplyr::arrange(.data$geoid)
}

daymet_single_pixel_url <- function(latitude, longitude, years) {
  paste0(
    "https://daymet.ornl.gov/single-pixel/api/data?lat=",
    sprintf("%.6f", latitude),
    "&lon=", sprintf("%.6f", longitude),
    "&vars=tmin,tmax,prcp&years=", paste(years, collapse = ",")
  )
}

download_daymet_county <- function(geoid, latitude, longitude, years, cache_dir) {
  ensure_dirs(cache_dir)
  destination <- file.path(cache_dir, paste0("daymet_", geoid, "_", min(years), "_", max(years), ".csv"))
  if (!file.exists(destination) || file.info(destination)$size == 0) {
    url <- daymet_single_pixel_url(latitude, longitude, years)
    tmp <- paste0(destination, ".part")
    on.exit(unlink(tmp), add = TRUE)
    utils::download.file(url, tmp, mode = "wb", quiet = TRUE)
    if (!file.rename(tmp, destination)) stop("Could not finalize Daymet download for ", geoid)
    Sys.sleep(0.05)
  }
  destination
}

parse_daymet_county <- function(path, geoid, county_name, latitude, longitude) {
  raw <- readr::read_csv(path, skip = 6, show_col_types = FALSE, progress = FALSE)
  names(raw) <- tolower(names(raw))
  year_col <- grep("^year$", names(raw), value = TRUE)
  prcp_col <- grep("^prcp", names(raw), value = TRUE)
  tmax_col <- grep("^tmax", names(raw), value = TRUE)
  tmin_col <- grep("^tmin", names(raw), value = TRUE)
  if (!all(lengths(list(year_col, prcp_col, tmax_col, tmin_col)) == 1L)) {
    stop("Unexpected Daymet columns in ", path, call. = FALSE)
  }

  annual <- raw |>
    dplyr::transmute(
      year = as.integer(.data[[year_col]]),
      precipitation_mm = as.numeric(.data[[prcp_col]]),
      tmax_c = as.numeric(.data[[tmax_col]]),
      tmin_c = as.numeric(.data[[tmin_col]])
    ) |>
    dplyr::mutate(tmean_c = (.data$tmax_c + .data$tmin_c) / 2) |>
    dplyr::group_by(.data$year) |>
    dplyr::summarise(
      mean_annual_temp_c = mean(.data$tmean_c, na.rm = TRUE),
      annual_precip_mm = sum(.data$precipitation_mm, na.rm = TRUE),
      days = dplyr::n(),
      .groups = "drop"
    )

  tibble::tibble(
    geoid = geoid,
    county_name = county_name,
    representative_latitude = latitude,
    representative_longitude = longitude,
    climate_start_year = min(annual$year),
    climate_end_year = max(annual$year),
    climate_years = dplyr::n_distinct(annual$year),
    mean_annual_temp_c = mean(annual$mean_annual_temp_c, na.rm = TRUE),
    mean_annual_precip_mm = mean(annual$annual_precip_mm, na.rm = TRUE),
    spatial_method = "Daymet 1-km cell at an interior county representative point"
  )
}

build_county_climate <- function(counties, years, cache_dir) {
  purrr::pmap_dfr(
    counties[c("geoid", "county_name", "latitude", "longitude")],
    function(geoid, county_name, latitude, longitude) {
      log_step(paste("Daymet", geoid, county_name))
      path <- download_daymet_county(geoid, latitude, longitude, years, cache_dir)
      parse_daymet_county(path, geoid, county_name, latitude, longitude)
    }
  )
}
