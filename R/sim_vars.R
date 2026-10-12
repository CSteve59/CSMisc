#' Simulate a numeric variable
#'
#' Describes a numeric variable for [sim_population()]. With no formula it is
#' drawn from a normal distribution. With a formula, the formula gives the
#' expected value and normal noise is added on top.
#'
#' @param formula Optional one-sided formula for the expected value, e.g.
#'   `~ 2 + 0.5*age + 0.3*treated`. It can use any variable defined earlier in
#'   [sim_population()]. Write interactions as `age:treated` or `age*treated`
#'   (both mean "age times treated" here). For a categorical predictor, use a
#'   comparison such as `(gender == "f")`.
#' @param mean Mean, used only when there is no formula.
#' @param sd Standard deviation: the spread of the variable itself with no
#'   formula, or the residual noise around the formula.
#' @param min,max Optional lower and upper bounds. Values are drawn from a
#'   truncated normal, so nothing falls outside the bounds and nothing piles up
#'   at the edge. Works with or without a formula.
#'
#' @return A variable specification to pass to [sim_population()].
#' @export
#'
#' @examples
#' sim_num(mean = 40, sd = 12)
#' sim_num(mean = 47, sd = 17, min = 18, max = 95)
#' sim_num(~ 1 + 0.5 * x, sd = 1)
sim_num <- function(formula = NULL, mean = 0, sd = 1, min = -Inf, max = Inf) {
  check_formula(formula)
  if (min >= max) stop("`min` must be smaller than `max`.", call. = FALSE)
  new_sim_var("num", formula = formula, mean = mean, sd = sd, min = min, max = max)
}

#' Simulate a binary (0/1) variable
#'
#' Describes a binary variable for [sim_population()]. With no formula, each
#' value is 1 with probability `p`. With a formula, the formula is on the
#' log-odds scale (a logistic model).
#'
#' @inheritParams sim_num
#' @param p Probability of a 1, used only when there is no formula.
#'
#' @return A variable specification to pass to [sim_population()].
#' @export
#'
#' @examples
#' sim_bin(p = 0.5)
#' sim_bin(~ -1 + 0.04 * age)
sim_bin <- function(formula = NULL, p = 0.5) {
  check_formula(formula)
  new_sim_var("bin", formula = formula, p = p)
}

#' Simulate a categorical variable
#'
#' Describes a categorical variable for [sim_population()]. In this version the
#' categories are drawn independently of other variables. Other variables can
#' still depend on it, e.g. `0.4 * (gender == "f")`.
#'
#' @param levels Character vector of category names.
#' @param probs Probability of each category (same length as `levels`). If
#'   `NULL`, all categories are equally likely.
#'
#' @return A variable specification to pass to [sim_population()].
#' @export
#'
#' @examples
#' sim_cat(levels = c("m", "f", "nb"), probs = c(0.48, 0.48, 0.04))
sim_cat <- function(levels, probs = NULL) {
  if (!is.null(probs) && length(probs) != length(levels)) {
    stop("`probs` must have the same length as `levels`.", call. = FALSE)
  }
  new_sim_var("cat", levels = levels, probs = probs)
}

#' Simulate a count variable
#'
#' Describes a count variable (0, 1, 2, ...) for [sim_population()]. With no
#' formula, values are Poisson with mean `lambda`. With a formula, the formula
#' is on the log scale (a Poisson regression).
#'
#' @inheritParams sim_num
#' @param lambda Mean count, used only when there is no formula.
#'
#' @return A variable specification to pass to [sim_population()].
#' @export
#'
#' @examples
#' sim_count(lambda = 3)
#' sim_count(~ 0.5 + 0.02 * age)
sim_count <- function(formula = NULL, lambda = 1) {
  check_formula(formula)
  new_sim_var("count", formula = formula, lambda = lambda)
}

#' Repeat each person across the levels of a categorical variable
#'
#' Use this in [sim_population()] for designs where each person is measured more
#' than once (pre/post, several conditions, several waves). Every person gets one
#' row per level, and the level becomes a categorical column that later
#' variables can use in their formulas.
#'
#' Position matters. Variables listed **above** this one are drawn once per
#' person, so a person keeps the same value in every row. Variables listed
#' **below** it are drawn separately for every row.
#'
#' @param levels Character vector of level names, in order, e.g.
#'   `c("Pre", "Post")`. At least two.
#'
#' @return A variable specification to pass to [sim_population()].
#' @export
#'
#' @examples
#' sim_within(c("Pre", "Post"))
sim_within <- function(levels) {
  if (length(levels) < 2) {
    stop("`levels` needs at least two values, e.g. c(\"Pre\", \"Post\").", call. = FALSE)
  }
  new_sim_var("within", levels = as.character(levels))
}

# Internal helpers ---------------------------------------------------------

new_sim_var <- function(type, ...) {
  structure(list(type = type, ...), class = "sim_var")
}

check_formula <- function(formula) {
  if (!is.null(formula) && !inherits(formula, "formula")) {
    stop(
      "The first argument must be a formula like ~ 1 + 0.5*x. ",
      "For a plain distribution, name the arguments, e.g. sim_num(mean = 40, sd = 10).",
      call. = FALSE
    )
  }
}
