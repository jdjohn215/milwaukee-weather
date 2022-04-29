library(ggplot2)
library(readr)
library(tidyr)
library(dplyr)
library(lubridate)
library(stringr)

ghcn <- read_csv("data/GHCN_USW00014839.csv") %>%
  group_by(year) %>%
  arrange(day_of_year) %>%
  mutate(cum_precip = cumsum(PRCP)) %>%
  ungroup()

year.to.plot <- max(ghcn$year)
last.date <- max(ghcn$date)

this.year <- ghcn %>%
  filter(year == year.to.plot)

past.years <- ghcn %>%
  group_by(year) %>%
  filter(n() > 364) %>%
  ungroup()

past.years %>%
  ggplot(aes(day_of_year, cum_precip, group = year)) +
  geom_step(size = 0.1)

daily.summary.stats <- past.years %>%
  filter(year != year.to.plot) %>%
  select(day_of_year, cum_precip) %>%
  group_by(day_of_year) %>%
  summarise(max = max(cum_precip, na.rm = T),
            min = min(cum_precip, na.rm = T),
            x5 = quantile(cum_precip, 0.05, na.rm = T),
            x20 = quantile(cum_precip, 0.2, na.rm = T),
            x40 = quantile(cum_precip, 0.4, na.rm = T),
            x60 = quantile(cum_precip, 0.6, na.rm = T),
            x80 = quantile(cum_precip, 0.8, na.rm = T),
            x95 = quantile(cum_precip, 0.95, na.rm = T)) %>%
  ungroup()

# month breaks
month.breaks <- ghcn %>%
  filter(year == 2019) %>%
  group_by(month) %>%
  slice_min(order_by = day_of_year, n = 1) %>%
  ungroup() %>%
  select(month, day_of_year) %>%
  mutate(month_name = month.abb)

# pctile labels
pctile.labels <- daily.summary.stats %>% 
  filter(day_of_year == 365) %>% 
  pivot_longer(cols = -day_of_year, names_to = "pctile", values_to = "precip") %>% 
  mutate(pctile = ifelse(str_sub(pctile, 1, 1) == "x", 
                         paste0(str_sub(pctile, 2, -1), "th"), pctile))

cum.precip.graph <- daily.summary.stats %>%
  filter(day_of_year < 366) %>%
  ggplot(aes(x = day_of_year)) +
  # draw vertical lines for the months
  geom_vline(xintercept = c(month.breaks$day_of_year, 365),
             linetype = "dotted", lwd = 0.2) +
  # ribbon between the lowest and 5th, 95th and max percentiles
  geom_ribbon(aes(ymin = min, ymax = max),
              fill = "#bdc9e1") +
  # ribbon between the 5th and 20th, 80th to 95th percentiles
  geom_ribbon(aes(ymin = x5, ymax = x95),
              fill = "#74a9cf") +
  # ribbon between the 20th and 40th, 60th and 80th percentiles
  geom_ribbon(aes(ymin = x20, ymax = x80),
              fill = "#2b8cbe") +
  # ribbon between the 40th and 60th percentiles
  geom_ribbon(aes(ymin = x40, ymax = x60),
              fill = "#045a8d") +
  # y-axis breaks
  geom_hline(yintercept = seq(0, 50, 5),
             color = "white", lwd = 0.1) +
  # line for this year's values
  geom_line(data = this.year,
            aes(y = cum_precip), lwd = 1.2) +
  ggrepel::geom_label_repel(data = filter(this.year, day_of_year == max(day_of_year)),
                            aes(y = cum_precip, label = round(cum_precip, 1)),
                            point.padding = 5, direction = "y", alpha = 0.5) +
  geom_segment(data = pctile.labels, aes(x = 365, xend = 367, y = precip, yend = precip)) +
  geom_text(data = pctile.labels, aes(367.5, precip, label = pctile),
            hjust = 0, family = "serif", size = 3) +
  scale_y_continuous(breaks = seq(-10, 100, 10),
                     labels = scales::unit_format(suffix = "in."),
                     expand = expansion(0.01),
                     name = NULL) +
  scale_x_continuous(expand = expansion(c(0, 0.04)),
                     breaks = month.breaks$day_of_year + 15,
                     labels = month.breaks$month_name,
                     name = NULL) +
  labs(title = "Cumulative annual precipitation at Milwaukee's Mitchell Airport",
       subtitle = paste("The line shows precipitation for",
                        paste0(lubridate::year(last.date), "."),
                        "The ribbons cover the",
                        "historical range. The last date shown is", 
                        format(last.date, "%b %d, %Y.")),
       caption = paste("Records begin on April 1, 1938.",
                       "This graph was last updated on", format(Sys.Date(), "%B %d, %Y."))) +
  theme(panel.background = element_blank(),
        panel.border = element_blank(),
        panel.grid = element_blank(),
        plot.background = element_rect(fill = "linen",
                                       colour = "linen"),
        plot.title.position = "plot",
        plot.title = element_text(face = "bold", size = 16),
        axis.ticks = element_blank())

cum.precip.graph

ggsave("graphs/AnnualCumulativePrecipitation_USW00014839.png", plot = cum.precip.graph,
       width = 8, height = 4)
