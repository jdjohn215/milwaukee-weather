## Defining the Github Actions workflow

A Github Action is defined with a [YAML](https://en.wikipedia.org/wiki/YAML) file (`.yml`), in this case `UpdateGraphs.yml`.


## Part 1
The first section of the workflow is the specification of the triggering event. It includes a manual trigger and a scheduled trigger at a time prescribed by a [CRON job](https://en.wikipedia.org/wiki/Cron). The manual trigger lets me click to run the job whenever I want through my GitHub repository. The CRON job runs automatically.

```
on:
  schedule:
    - cron: "0 19 * * *"
  workflow_dispatch:
```

## Part 2

Name the entire workflow.

```
name: Milwaukee weather update
```

## Part 3

Next, define the jobs. A workflow could include multiple jobs, but this one just has one.

I'm breaking this section up into chunks to make it easier to explain.

* `runs-on` could be one of [several options](https://docs.github.com/en/actions/using-github-hosted-runners/about-github-hosted-runners), including windows and mac-os, but Ubuntu charges the fewest minutes.
* `timeout-minutes` kills the workflow instance after a set period of time. The default is 6 hours, so you'll want to lower this yourself. Set it to something safely above how long your workflow *should* take.

```
jobs:
  render:
    name: Update graphs
    runs-on: ubuntu-latest
    timeout-minutes: 30
```

Next come all the steps of the workflow.
```
    steps:
```

First, [this action](https://github.com/r-lib/actions/tree/v2/setup-r) installs and caches a current R installation. The only modification I make to the default configuration is to use the Posit CRAN mirror with precompiled binaries instead of CRAN directly. This saves a lot of time installing packages for the first time since we already specified that this workflow will run on an ubuntu server.

```
- name: Set up R
        uses: r-lib/actions/setup-r@v2
        with:
          # use Posit's CRAN mirror with precompiled binaries
          use-public-rspm: true
```

[This action](https://github.com/r-lib/actions/tree/v2/setup-r-dependencies) sets up the R dependencies and caches them.

```
- name: Install packages
        uses: r-lib/actions/setup-r-dependencies@v2 # automatically sets up cache
        with:
          packages: |
            any::ggplot2 
            any::readr
            any::tidyr
            any::dplyr
            any::lubridate
            any::stringr
            any::ggrepel
            any::scales
            any::here
            any::data.table
            any::R.utils
```

[This action](https://github.com/actions/checkout) simply checks-out the repository, so that its available to the workflow.

```    
      - name: Check out repository
        uses: actions/checkout@v4
```

Essentially, this step simply runs the Rscript to retrieve the new data, but I run this script using the [retry action](https://github.com/nick-fields/retry) in case the internet connection fails.

* `timeout_seconds` ends the step after the specified length of time
* `max_attemps` specifies how many times to try the command after failing or timing out
* `continue_on_error` indicates how the workflow should proceed if this step fails all 3 times. By specifying `true`, the workflow will finish running, just without using updated data.

```
      - name: Retrieve data
        uses: nick-fields/retry@v3
        with:
          timeout_seconds: 30
          max_attempts: 3
          command: Rscript -e 'source("R/Retrieve_GHCN_USW00014839.R")'
          continue_on_error: true
```

This step simply runs the Rscript which builds the daily high temperature graph.

```
      - name: Build temperature graph
        run:  Rscript -e 'source("R/BuildDailyHigh.R")'
```

Another step builds the precipitation graph.

```
      - name: Build precipitation graph
        run:  Rscript -e 'source("R/BuildCumulativePrecipitation.R")'
```

The final step commits the graph using an [action](https://github.com/stefanzweifel/git-auto-commit-action) with sensible defaults for this purpose. Using the `git-auto-commit-action` is a simple way to do this. More complicated git commands might need to be written out explicitly.

```
      - name: Commit graphs
        uses: stefanzweifel/git-auto-commit-action@v5
        with:
          commit_message: Update data & graphs
```
