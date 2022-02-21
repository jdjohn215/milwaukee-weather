## Defining the Github Actions workflow

Each Github Action is defined with a [YAML](https://en.wikipedia.org/wiki/YAML) file (`.yml`). The two `.yml` files in this directory are identical except for the triggering mechanism. `UpdateGraphs_manual` is manually triggered by clicking a button [from the web browser](https://github.com/jdjohn215/milwaukee-weather/actions). `UpdateGraphs_scheduled` is run automatically at a time prescribed by a [CRON job](https://en.wikipedia.org/wiki/Cron).


## Part 1
The first section of the workflow is the specification of the triggering event. For the manual version it looks like this:

```
on:
  workflow_dispatch:
```

For the scheduled version, it looks like this.

```
on:
 schedule:
   - cron: "0 18 * * *"
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
* `env` here you set environmental variables
  * `RENV_PATHS_ROOT` is the root directory of my cache of package dependencies, created with the package {{renv}}. The directory changes based on the virtual environment chosen in `runs-on`. [See here.](https://rstudio.github.io/renv/reference/paths.html#details).
* 
```
jobs:
  render:
    name: Update graphs
    runs-on: ubuntu-latest
    timeout-minutes: 5
    env:
      RENV_PATHS_ROOT: ~/.local/share/renv
```

Next come all the steps of the workflow.
```
    steps:
```    

First, [this action](https://github.com/actions/checkout) simply checks-out the repository, so that its available to the workflow.
```    
      - uses: actions/checkout@v2
```

This step [sets up R](https://github.com/r-lib/actions/tree/v2/setup-r) for use on the runner.

* `install-r` setting this to false means we use the preinstalled version of R in this Github Action image. This is faster.
* `use-public-rspm` setting this to true means that packages are downloaded from RStudio's package manager, rather than straight from CRAN. RStudio's manager precompiles binaries for Linux, so this is much faster than CRAN.
```
      - uses: r-lib/actions/setup-r@v2
        with:
          install-r: false
          use-public-rspm: true
```

This [step caches package dependencies](https://github.com/actions/cache), so that they don't have to be reinstalled each time the workflow runs. This saves lots of time.

* `path` sets the OS-specific path defined already defined by the environmental variable
* `key` specifies the key of the cache to use.

The {{renv}} package uses a lockfile (`renv.lock`) to record the required packages and their versions. When this is changed locally and pushed to the repository, the changes are added to the cache during the next workflow run.
```
      - name: Cache packages
        uses: actions/cache@v2
        with:
          path: ${{ env.RENV_PATHS_ROOT }}
          key: ${{ runner.os }}-renv-${{ hashFiles('**/renv.lock') }}
          restore-keys: |
            ${{ runner.os }}-renv-
```

This step restores the packages from the cache, installing the ones that have changed (in the lockfile) since the last workflow run.
```
      - name: Restore packages
        shell: Rscript {0}
        run: |
          if (!requireNamespace("renv", quietly = TRUE)) install.packages("renv")
          renv::restore()
```

Essentially, this step simply runs the Rscript to retrieve the new data, but I run this script using the [retry action](https://github.com/nick-fields/retry) in case the internet connection fails.

* `timeout_seconds` ends the step after the specified length of time
* `max_attemps` specifies how many times to try the command after failing or timing out
* `continue_on_error` indicates how the workflow should proceed if this step fails all 3 times. By specifying `true`, the workflow will finish running, just without using updated data.
```
      - name: Retrieve data
        uses: nick-fields/retry@v2
        with:
          timeout_seconds: 30
          max_attempts: 3
          command: Rscript -e 'source("R/Retrieve_GHCN_USW00014839.R")'
          continue_on_error: true
```

This step commits the data retrieved in the previous step to the repository. Using the [`git-auto-commit-action`](https://github.com/stefanzweifel/git-auto-commit-action) is a simple way to do this. More complicated git commands might need to be written out explicitly.
```
      - name: Commit data
        uses: stefanzweifel/git-auto-commit-action@v4
        with:
          commit_message: Update data
```

This step simply runs the Rscript which builds the graph.
```
      - name: Build graph
        run:  Rscript -e 'source("R/BuildDailyHigh.R")'
```

This step commits the graph.
```
      - name: Commit graph
        uses: stefanzweifel/git-auto-commit-action@v4
        with:
          commit_message: Update graph
```
