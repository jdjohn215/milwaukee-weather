library(readr)
library(dplyr)
library(tidyr)


# station readme
#   https://www1.ncdc.noaa.gov/pub/data/ghcn/daily/by_station/readme-by_station.txt

# data readme
#   https://www1.ncdc.noaa.gov/pub/data/ghcn/daily/readme.txt

# obtain the updated file
#   readr::read_csv downloads and unzips .csv.gz
ghcn <- data.table::fread("https://www1.ncdc.noaa.gov/pub/data/ghcn/daily/by_station/USW00014839.csv.gz",
                          col.names = c("id", "yearmoda", "element", "value",
                                        "mflag", "qflag", "sflag", "obs_time"),
                          colClasses = list(character=c(1:3,5:8),
                                            numeric=4)) |>
  as_tibble()

# subset and format
ghcn.wide <- ghcn |>
  select(yearmoda, element, value) |>
  filter(element %in% c("PRCP", "SNOW", "SNWD", "TMAX", "TMIN")) |>
  separate(col = yearmoda, sep = c(4,6), into = c("year", "month", "day")) |>
  pivot_wider(names_from = element, values_from = value) |>
  # convert from tenths of mm to inches
  mutate(PRCP = PRCP * 0.00393701,
         SNOW = SNOW * 0.00393701,
         SNWD = SNWD * 0.00393701) |>
  # convert from tenths of degrees C to F
  mutate(TMAX = ((TMAX / 10) * (9/5)) + 32,
         TMIN = ((TMIN / 10) * (9/5)) + 32) |>
  mutate(date = as.Date(paste(year, month, day, sep = "-")),
         day_of_year = lubridate::yday(date)) |>
  select(year, month, day, date, day_of_year, PRCP, SNOW, SNWD,
         TMAX, TMIN)

write_csv(ghcn.wide, "data/GHCN_USW00014839.csv")