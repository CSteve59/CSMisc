#' Simulate data for practicing analyses
#'
#' Describe a set of variables and the true effects between them, and get back
#' a simulated dataset. Because you set the truth, you can check whether an
#' analysis recovers it.
#'
#' @section The pieces:
#' [sim_population()] builds the dataset. You give it `n` and a list of named
#' variables, each made by a helper:
#'
#' * [sim_num()] for numeric variables (normal), optionally bounded with `min`
#'   and `max`
#' * [sim_bin()] for binary variables, 0 or 1
#' * [sim_count()] for counts (Poisson)
#' * [sim_cat()] for categories
#' * [sim_within()] to repeat each person across levels (pre/post, conditions)
#'
#' Variables are built in the order you list them, and each one can use the
#' variables listed above it.
#'
#' @section Writing formulas:
#' * With no formula, a helper draws from a plain distribution, e.g.
#'   `sim_num(mean = 40, sd = 12)`.
#' * With a formula, the formula sets each person's expected value, e.g.
#'   `sim_num(~ 2 + 0.5*age + 0.3*treated, sd = 1)`. The coefficients are the
#'   true effects.
#' * Interactions: `age:treated` and `age*treated` both mean age times treated.
#' * Categorical predictors: use a comparison, e.g. `0.4*(group == "test")`.
#' * Any R function works: `log(x)`, `x^2`, `ifelse(x > 5, 1, 0)`.
#' * For `sim_bin()` the formula is on the log-odds scale; for `sim_count()` it
#'   is on the log scale.
#' * `sd` is the random error around the formula and defaults to 1. Use
#'   `sd = 0` for an exact calculation such as `sim_num(~ x + 2, sd = 0)`.
#'
#' @section Two kinds of noise:
#' In repeated-measures data, a variable listed **above** [sim_within()] is
#' drawn once per person (each person has their own value, shared across their
#' rows). It creates stable differences between people, so a person's
#' measurements are correlated. The `sd` of a variable listed **below**
#' [sim_within()] is a fresh error for every row.
#'
#' @section Output:
#' The result has an `id` column (one value per person) followed by your
#' variables. Use `keep = c("id", "y")` to return only some columns and
#' `seed = 1` for reproducible data. The recipes you supplied are saved in
#' `attr(x, "spec")`.
#'
#' @section Getting help:
#' `?sim_population` for the main function, `?sim_num` (and the other helpers)
#' for each variable type, and `help(package = "mypkg")` for the full list.
#'
#' @examples
#' # Continuous predictor with a floor on age
#' d <- sim_population(
#'   n = 500, seed = 1,
#'   age     = sim_num(mean = 47, sd = 17, min = 18, max = 95),
#'   turnout = sim_bin(~ -1 + 0.04 * (age - 18))
#' )
#' head(d)
#'
#' # Between groups: control vs test, with an interaction
#' d <- sim_population(
#'   n = 500, seed = 1,
#'   group = sim_cat(c("control", "test")),
#'   exp   = sim_num(mean = 10, sd = 5, min = 0),
#'   y     = sim_num(~ 40 + 2*exp + 4*(group == "test") + 0.5*exp*(group == "test"),
#'                   sd = 3)
#' )
#' head(d)
#'
#' # Within subjects: the same people measured Pre and Post
#' d <- sim_population(
#'   n = 200, seed = 1,
#'   person = sim_num(sd = 3),                 # per person
#'   time   = sim_within(c("Pre", "Post")),    # two rows per person
#'   y      = sim_num(~ 50 + 3*(time == "Post") + person, sd = 1)
#' )
#' head(d)
#'
#' # Independent samples: different people in each wave
#' d <- sim_population(
#'   n = 200, seed = 1,
#'   test = sim_cat(c("Pre", "Post")),
#'   y    = sim_num(~ 50 + 3*(test == "Post"), sd = 2)
#' )
#' head(d)
#'
#' # Mixed design: group (between) by time (within)
#' d <- sim_population(
#'   n = 200, seed = 2,
#'   group = sim_cat(c("control", "test")),
#'   noise = sim_num(sd = 2),
#'   time  = sim_within(c("Pre", "Post")),
#'   y     = sim_num(~ 50 + 3*(time == "Post") + 5*(group == "test")*(time == "Post") + noise,
#'                   sd = 1)
#' )
#' head(d)
#'
#' @keywords internal
"_PACKAGE"
