# CSMisc

Simulate data for practicing statistical analyses.

You describe the variables and the true effects behind them (main effects, interactions, group differences, repeated measures), and `sim\\\_population()` generates a dataset. Because you set the truth, you can check whether an analysis recovers it.

## Installation

```r
# install.packages("remotes")
remotes::install\\\_github("CSteve59/CSMisc")
```

## Quick start

```r
library(CSMisc)

d <- sim\\\_population(
  n = 1000, seed = 1,
  age     = sim\\\_num(mean = 40, sd = 12, min = 18),
  treated = sim\\\_bin(p = 0.5),
  trust   = sim\\\_num(\\\~ 2 + 0.03\\\*age + 0.5\\\*treated + 0.02\\\*age:treated, sd = 1)
)

head(d)
summary(lm(trust \\\~ age \\\* treated, data = d))
```

The true effects are in the formula: intercept 2, age 0.03, treated 0.5, and age-by-treated 0.02. The estimates won't match exactly, because any one simulated dataset has sampling error. A larger `n` gets closer.

## How it works

There are two layers.

* **Recipes.** `sim\\\_num()`, `sim\\\_bin()`, `sim\\\_count()`, `sim\\\_cat()` and `sim\\\_within()` don't generate anything. Each one returns a description of a variable.
* **The builder.** `sim\\\_population(n, ...)` takes your recipes and builds the data frame one variable at a time, **in the order you list them**. Each variable can use any variable listed above it.

For each variable, one of two things happens:

* **No formula:** it's drawn from a plain distribution, e.g. `sim\\\_num(mean = 40, sd = 12)`.
* **Formula:** the formula sets each person's expected value from earlier variables, and random noise is added around it, e.g. `sim\\\_num(\\\~ 2 + 0.5\\\*age, sd = 1)`.

## Variable types

|Helper|Use for|No formula|With a formula|
|-|-|-|-|
|`sim\\\_num(formula, mean, sd, min, max)`|continuous|normal(`mean`, `sd`)|formula is the mean; `sd` is the error around it|
|`sim\\\_bin(formula, p)`|0/1|1 with probability `p`|formula is on the log-odds scale (logistic)|
|`sim\\\_count(formula, lambda)`|counts|Poisson with mean `lambda`|formula is on the log scale (Poisson regression)|
|`sim\\\_cat(levels, probs)`|categories|sampled using `probs` (equal if omitted)|not supported yet|
|`sim\\\_within(levels)`|repeated measures|see [Within subjects](#3-within-subjects-the-same-people-measured-twice)||

`min` and `max` in `sim\\\_num()` truncate the distribution: nothing falls outside the bounds and nothing piles up at the edge. They work with or without a formula.

## Writing formulas

Everything after the `\\\~` is ordinary R code that can use the variables listed above it.

* **Coefficients are the true effects.** `\\\~ 2 + 0.03\\\*age + 0.5\\\*treated` means an intercept of 2, an age effect of 0.03, and a treated effect of 0.5.
* **Interactions:** `age:treated` and `age\\\*treated` both mean "age times treated" here.
* **Categorical predictors:** write a comparison, `0.4\\\*(group == "test")`. It equals 1 for the test group and 0 otherwise. There is no automatic dummy coding.
* **Any R function works:** `log(x)`, `x^2`, `ifelse(x > 5, 1, 0)`, or a function you defined yourself.
* **Centering:** the intercept is the value when everything is 0, so for something like age use `(age - 18)` to make the intercept the value at age 18.
* **Binary and count formulas** are on the log-odds and log scales, like logistic and Poisson regression.
* **`sd` defaults to 1.** It's the random error around the formula. Use `sd = 0` for an exact calculation: `sim\\\_num(\\\~ x + 2, sd = 0)`.
* **Order matters.** A variable can only use ones listed above it.

## Output

* The result starts with an `id` column (one value per person), followed by your variables.
* `keep = c("id", "y")` returns only those columns, in that order.
* `seed = 1` makes the data reproducible. It calls `set.seed()`, so it also changes your session's random state.
* Your recipes are saved with the data: `attr(d, "spec")`.

## Cookbook: common study designs

### 1\. A continuous predictor, with a floor

Age and turnout, with nobody under 18:

```r
d <- sim\\\_population(
  n = 5000, seed = 1,
  age     = sim\\\_num(mean = 47, sd = 17, min = 18, max = 95),
  turnout = sim\\\_bin(\\\~ -1 + 0.04 \\\* (age - 18))
)

glm(turnout \\\~ I(age - 18), data = d, family = binomial)   # true: -1 and 0.04
```

Ages come out as decimals. Use `d$age <- floor(d$age)` for whole years.

### 2\. Between groups: control vs test

One row per person, with group as a categorical variable:

```r
d <- sim\\\_population(
  n = 1000, seed = 1,
  group = sim\\\_cat(c("control", "test")),
  exp   = sim\\\_num(mean = 10, sd = 5, min = 0),
  y     = sim\\\_num(\\\~ 40 + 2\\\*exp + 4\\\*(group == "test") + 0.5\\\*exp\\\*(group == "test"), sd = 3)
)

summary(lm(y \\\~ exp \\\* group, data = d))
```

Group membership is random, so the sizes are close to equal but not exact. For unequal groups use `probs = c(0.7, 0.3)`. For a simple treated/untreated split, `treated = sim\\\_bin(p = 0.5)` is shorter.

### 3\. Within subjects: the same people measured twice

```r
d <- sim\\\_population(
  n = 500, seed = 1,
  person = sim\\\_num(sd = 3),                    # stable differences between people
  time   = sim\\\_within(c("Pre", "Post")),       # each person now has two rows
  y      = sim\\\_num(\\\~ 50 + 3\\\*(time == "Post") + person, sd = 1)
)

head(d)
```

`sim\\\_within()` expands each person into one row per level and adds the level as a column you can use in formulas. **Position matters:**

* Variables listed **above** it are drawn once per person, so a person keeps the same value in every row.
* Variables listed **below** it are drawn separately for every row.

That gives you two kinds of noise:

* **Person-level noise** (a variable above `sim\\\_within()`, like `person`): every person has their own value, shared across their rows. This is what makes a person's Pre and Post scores correlated.
* **Row-level noise** (the `sd` below it): a fresh error for every measurement.

Without person-level noise, Pre and Post are unrelated, and a within-subjects design has no advantage. With no other predictors, the Pre/Post correlation is roughly the person variance divided by the total variance:

|Person sd|Row `sd`|Pre/Post correlation|
|-|-|-|
|3|1|about 0.90|
|1|3|about 0.10|
|none|3|about 0|

### 4\. Independent samples: different people before and after

If Pre and Post are two separate populations rather than the same people, make `test` an ordinary group variable:

```r
d <- sim\\\_population(
  n = 1000, seed = 1,
  test = sim\\\_cat(c("Pre", "Post")),
  exp  = sim\\\_num(mean = 10, sd = 5, min = 0),
  y    = sim\\\_num(\\\~ 40 + 2\\\*exp\\\*(test == "Pre") + 3\\\*exp\\\*(test == "Post"), sd = 2, min = 40),
  keep = c("id", "test", "exp", "y")
)
```

Each `id` is one row. `n` is the total number of people, split roughly in half. The waves can differ in who they include too: `exp = sim\\\_num(\\\~ 10 + 2\\\*(test == "Post"), sd = 5, min = 0)`.

### 5\. Mixed design: group (between) by time (within)

Put the between-person variable above `sim\\\_within()` so it's drawn once per person:

```r
d <- sim\\\_population(
  n = 500, seed = 2,
  group = sim\\\_cat(c("control", "test")),       # per person
  noise = sim\\\_num(sd = 2),                     # per person
  time  = sim\\\_within(c("Pre", "Post")),
  y     = sim\\\_num(\\\~ 50 + 3\\\*(time == "Post") + 1\\\*(group == "test") +
                      5\\\*(group == "test")\\\*(time == "Post") + noise, sd = 1)
)

summary(lm(y \\\~ group \\\* time, data = d))
```

The last term is the treatment effect: only the test group changes at Post, on top of the shift everyone gets. (`lm()` treats rows as independent, so for a real analysis use a mixed model. This is just to check the coefficients.)

### 6\. Chains of variables: mediation and confounding

```r
d <- sim\\\_population(
  n = 1000, seed = 1,
  ses       = sim\\\_num(),
  education = sim\\\_num(\\\~ 0.5\\\*ses, sd = 1),
  trust     = sim\\\_num(\\\~ 0.3\\\*education + 0.1\\\*ses, sd = 1)
)
```

The indirect effect of `ses` on `trust` is 0.5 x 0.3 = 0.15, and the direct effect is 0.1.

### 7\. Power analysis

Simulate many datasets and count how often the effect is detected:

```r
p <- replicate(500, {
  d <- sim\\\_population(
    n = 100,
    treated = sim\\\_bin(p = 0.5),
    y       = sim\\\_num(\\\~ 0.3\\\*treated, sd = 1)
  )
  summary(lm(y \\\~ treated, data = d))$coefficients\\\["treated", "Pr(>|t|)"]
})

mean(p < 0.05)   # estimated power at n = 100
```

## Plotting

`plot\\\_sim()` makes quick ggplot2 plots. Name variables without quotes:

```r
d <- sim\\\_population(
  n = 400, seed = 1,
  group = sim\\\_cat(c("control", "test")),
  exp   = sim\\\_num(mean = 10, sd = 5, min = 0),
  y     = sim\\\_num(\\\~ 40 + 2\\\*exp + 4\\\*(group == "test"), sd = 3)
)

plot\\\_sim(d, x = exp)                                       # histogram
plot\\\_sim(d, x = exp, y = y, color = group, smooth = TRUE)  # scatter + lines
plot\\\_sim(d, x = group, y = y)                              # boxplot
plot\\\_sim(d, x = exp, fill = group, type = "density")       # overlaid densities
plot\\\_sim(d, x = exp, y = y, facet = group)                 # panels
plot\\\_sim(d, x = group, y = y, type = "means")              # means with 95% CI
```

|Argument|What it does|
|-|-|
|`x`, `y`|Axis variables (leave `y` out for a one-variable plot)|
|`color`, `fill`|Map a variable to color or fill|
|`facet`|Split into panels; `facet\\\_rows` and `facet\\\_cols` make a grid|
|`type`|`"auto"` (default), `"point"`, `"box"`, `"violin"`, `"means"`, `"histogram"`, `"density"`, `"bar"`|
|`smooth`|Add a regression line to a scatterplot|
|`title`, `subtitle`, `caption`, `xlab`, `ylab`, `legend\\\_title`|Titles and labels|
|`theme`|Any ggplot2 theme; default `ggplot2::theme\\\_minimal()`, e.g. `theme = ggplot2::theme\\\_bw()`|
|`alpha`, `bins`|Fine-tuning|

Notes: 0/1 variables used for color or facets are treated as categories. For a
pre/post by group (difference-in-differences) picture, use
`type = "means"` with `x = test` and `color = group`. For numeric waves, use
`x = factor(wave)`. The result is a regular ggplot, so `+ labs(...)` works.

## Getting help

```r
?sim\\\_population      # the main function
?sim\\\_num             # each variable type has its own page (sim\\\_bin, sim\\\_cat, sim\\\_count, sim\\\_within)
?CSMisc               # the package overview: formulas, designs, noise
help(package = "CSMisc")
example(sim\\\_population)
```

## Not supported yet

* A categorical variable can't depend on other variables (it's drawn on its own).
* No ordinal variables (e.g. Likert items).
* Group sizes are random, not exactly equal.
* No nested or clustered data beyond repeated measures (e.g. students within schools).
* Within a person, a later measurement can't depend directly on an earlier one. Put anything shared across measurements in a variable above `sim\\\_within()`.
* No missing data.

## Adding a new variable type

`sim\\\_population()` doesn't need to change, so this is three steps:

1. In `R/sim\\\_vars.R`, add a constructor that calls `new\\\_sim\\\_var("yourtype", ...)`.
2. In `R/sim\\\_population.R`, add a `"yourtype"` branch to the `switch()` inside `draw\\\_var()`.
3. Run `devtools::document()` and `devtools::load\\\_all()`, then test it.

## Developer notes: adding a function

```r
usethis::use\\\_r("my\\\_function")      # 1. creates R/my\\\_function.R; write the function and its roxygen comments
usethis::use\\\_package("dplyr")      # 2. only if it uses another package; call it as dplyr::filter()
devtools::document()               # 3. rebuilds the help pages and NAMESPACE
devtools::load\\\_all()               # 4. loads the package so you can try it
devtools::check()                  # 5. optional: catches common problems
```

Then commit and push (`git add -A`, `git commit -m "Add my\\\_function"`, `git push`), and confirm with `remotes::install\\\_github("CSteve59/CSMisc")` in a fresh R session.

Packages that ship with R, like `stats`, still need declaring once with `usethis::use\\\_package("stats")`.

## License

MIT. See `LICENSE.md`.

