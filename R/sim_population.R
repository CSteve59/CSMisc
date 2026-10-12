#' Simulate a population
#'
#' Builds a data frame one variable at a time, in the order you list them. Each
#' variable can depend on any variable listed before it, so you control the true
#' effects (including interactions) that generated the data.
#'
#' @param n Number of people to simulate.
#' @param ... Named variable specifications made with [sim_num()], [sim_bin()],
#'   [sim_cat()], [sim_count()], or [sim_within()]. The names become the column
#'   names.
#' @param seed Optional random seed, for reproducible data.
#' @param keep Optional character vector of variables to return, in that order.
#'   By default every variable is returned.
#'
#' @return A data frame with an `id` column (one value per person) followed by
#'   your variables. It has `n` rows, unless you use [sim_within()]: then each
#'   person gets one row per level (so `n` times the number of levels) and the
#'   same `id` repeats across their rows. The specifications you supplied are
#'   stored in `attr(x, "spec")`, so you can look up the true effects later.
#' @export
#'
#' @examples
#' d <- sim_population(
#'   n = 500, seed = 1,
#'   age     = sim_num(mean = 40, sd = 12),
#'   treated = sim_bin(p = 0.5),
#'   trust   = sim_num(~ 2 + 0.03 * age + 0.5 * treated + 0.02 * age:treated, sd = 1)
#' )
#' head(d)
#'
#' # Pre/post: `noise` is per person, everything below sim_within() is per row
#' d2 <- sim_population(
#'   n = 200, seed = 1,
#'   noise = sim_num(sd = 2),
#'   test  = sim_within(c("Pre", "Post")),
#'   exp   = sim_num(mean = 10, sd = 5, min = 0),
#'   y     = sim_num(~ 40 + 2 * exp + 3 * (test == "Post") + noise),
#'   keep  = c("id", "test", "exp", "y")
#' )
#' head(d2)
sim_population <- function(n, ..., seed = NULL, keep = NULL) {
  specs <- list(...)

  if (length(specs) == 0 || is.null(names(specs)) || any(names(specs) == "")) {
    stop(
      "Every variable needs a name, e.g. ",
      "sim_population(n = 100, age = sim_num(mean = 40, sd = 10)).",
      call. = FALSE
    )
  }
  if ("id" %in% names(specs)) {
    stop("`id` is added automatically; please use a different name.", call. = FALSE)
  }
  is_spec <- vapply(specs, inherits, logical(1), what = "sim_var")
  if (!all(is_spec)) {
    stop(
      "These aren't variable specs: ", paste(names(specs)[!is_spec], collapse = ", "),
      ". Use sim_num(), sim_bin(), sim_cat(), sim_count(), or sim_within().",
      call. = FALSE
    )
  }

  if (!is.null(seed)) set.seed(seed)

  dat <- data.frame(id = seq_len(n))
  for (nm in names(specs)) {
    spec <- specs[[nm]]
    if (spec$type == "within") {
      # Everything above this point is per person. Each person now gets one
      # row per level, and everything below is drawn for every row.
      dat <- expand_within(dat, spec$levels, nm)
    } else {
      dat[[nm]] <- draw_var(spec, dat, nrow(dat), nm)
    }
  }

  if (!is.null(keep)) {
    unknown <- setdiff(keep, names(dat))
    if (length(unknown) > 0) {
      stop(
        "`keep` includes variables that don't exist: ",
        paste(unknown, collapse = ", "),
        call. = FALSE
      )
    }
    dat <- dat[, keep, drop = FALSE]
  }

  attr(dat, "spec") <- specs
  dat
}

# Internal helpers ---------------------------------------------------------

# Repeat every row once per level and add the level as a factor column. The
# `id` column is repeated too, so rows from the same person share an id.
expand_within <- function(dat, levels, name) {
  n <- nrow(dat)
  k <- length(levels)
  dat <- dat[rep(seq_len(n), each = k), , drop = FALSE]
  dat[[name]] <- factor(rep(levels, times = n), levels = levels)
  rownames(dat) <- NULL
  dat
}

# Draw one variable, given the data built so far.
draw_var <- function(spec, dat, n, name) {
  switch(
    spec$type,
    num = {
      mu <- if (is.null(spec$formula)) {
        rep(spec$mean, n)
      } else {
        linear_predictor(spec$formula, dat, n, name)
      }
      rtnorm(n, mu, spec$sd, spec$min, spec$max)
    },
    bin = {
      p <- if (is.null(spec$formula)) {
        rep(spec$p, n)
      } else {
        stats::plogis(linear_predictor(spec$formula, dat, n, name))
      }
      stats::rbinom(n, 1, p)
    },
    cat = {
      factor(
        sample(spec$levels, n, replace = TRUE, prob = spec$probs),
        levels = spec$levels
      )
    },
    count = {
      lambda <- if (is.null(spec$formula)) {
        rep(spec$lambda, n)
      } else {
        exp(linear_predictor(spec$formula, dat, n, name))
      }
      stats::rpois(n, lambda)
    }
  )
}

# Evaluate the right-hand side of a formula using the variables built so far.
linear_predictor <- function(formula, dat, n, name) {
  rhs <- swap_colon(formula[[length(formula)]])
  eta <- tryCatch(
    eval(rhs, envir = dat, enclos = environment(formula)),
    error = function(e) {
      stop(
        "Couldn't build `", name, "`: ", conditionMessage(e),
        ". Variables can only use ones listed before them.",
        call. = FALSE
      )
    }
  )
  if (length(eta) == 1) eta <- rep(eta, n)
  eta
}

# Normal draws, optionally truncated to [min, max] (inverse-CDF method, so
# nothing is clipped and no values pile up at the bounds).
rtnorm <- function(n, mean, sd, min = -Inf, max = Inf) {
  if (is.infinite(min) && is.infinite(max)) {
    return(stats::rnorm(n, mean, sd))
  }
  lo <- stats::pnorm(min, mean, sd)
  hi <- stats::pnorm(max, mean, sd)
  stats::qnorm(stats::runif(n, lo, hi), mean, sd)
}

# In a model formula `a:b` means an interaction; as plain arithmetic it would
# mean a sequence. Treat it as multiplication instead.
swap_colon <- function(e) {
  if (is.call(e)) {
    if (identical(e[[1]], as.name(":"))) e[[1]] <- as.name("*")
    for (i in seq_along(e)[-1]) e[[i]] <- swap_colon(e[[i]])
  }
  e
}
