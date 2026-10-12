#' Quick plots of a simulated population
#'
#' A thin wrapper around ggplot2 for quick looks at data from
#' [sim_population()]. Give it the data and the variables as bare names (no
#' quotes); it picks a sensible plot and returns an ordinary ggplot object, so
#' you can keep adding layers, themes and labels with `+`.
#'
#' @details
#' With `type = "auto"` the plot is chosen from the variables:
#'
#' * `x` numeric, no `y`: histogram
#' * `x` categorical, no `y`: bar chart of counts
#' * `x` numeric, `y` numeric: scatterplot
#' * `x` categorical, `y` numeric: boxplot
#'
#' A variable counts as categorical if it is a factor, character or logical, or
#' a number with only two distinct values (like a 0/1 `treated` variable). A 0/1
#' variable used for `color`, `fill` or a facet is automatically treated as a
#' category, so you get separate colors instead of a color gradient.
#'
#' `type = "means"` draws the mean of `y` at each level of `x` with a 95%
#' confidence interval, joined by lines. Map `color` to a second variable to
#' compare groups, which is handy for pre/post and difference-in-differences
#' designs. For `x` with more than two numeric values (such as waves 1, 2, 3),
#' wrap it in `factor()`: `x = factor(wave)`.
#'
#' For boxes, violins, histograms, densities and bars, `color` also fills the
#' shapes unless you give `fill` yourself.
#'
#' @param data A data frame, usually from [sim_population()].
#' @param x,y Variables for the axes, as bare names. Leave `y` out for a
#'   one-variable plot.
#' @param color,fill Optional variable to map to color or fill.
#' @param facet Optional variable to split the plot into panels.
#' @param facet_rows,facet_cols Optional variables for a grid of panels (rows by
#'   columns). Ignored if `facet` is given.
#' @param type One of `"auto"` (the default), `"point"`, `"box"`, `"violin"`,
#'   `"means"`, `"histogram"`, `"density"` or `"bar"`.
#' @param smooth If `TRUE`, add a fitted line to a scatterplot (one per color
#'   group when `color` is mapped). It is a straight regression line, or a
#'   logistic curve (predicted probability) when `y` is a 0/1 variable.
#' @param alpha Transparency of the points, boxes, bars and so on. The default
#'   depends on the plot type.
#' @param bins Number of bins for a histogram.
#' @param title,subtitle,caption Optional title, subtitle and caption.
#' @param xlab,ylab Optional axis titles. Defaults to the variable names.
#' @param legend_title Optional title for the color/fill legend.
#' @param theme A ggplot2 theme. Defaults to [ggplot2::theme_minimal()]; use
#'   e.g. `theme = ggplot2::theme_bw()` or `ggplot2::theme_classic()` to change it.
#'
#' @return A ggplot object.
#' @export
#'
#' @examples
#' d <- sim_population(
#'   n = 400, seed = 1,
#'   group = sim_cat(c("control", "test")),
#'   exp   = sim_num(mean = 10, sd = 5, min = 0),
#'   y     = sim_num(~ 40 + 2*exp + 4*(group == "test") + 0.5*exp*(group == "test"), sd = 3)
#' )
#'
#' plot_sim(d, x = exp)                                  # histogram
#' plot_sim(d, x = exp, y = y, color = group, smooth = TRUE)   # scatter + lines
#' plot_sim(d, x = group, y = y)                         # boxplot
#' plot_sim(d, x = exp, fill = group, type = "density")
#' plot_sim(d, x = exp, y = y, facet = group)
#'
#' # Titles and theme
#' plot_sim(d, x = exp, y = y, color = group,
#'   title = "Pay by experience", xlab = "Years of experience", ylab = "Pay",
#'   legend_title = "Group", theme = ggplot2::theme_bw())
plot_sim <- function(data, x, y = NULL, color = NULL, fill = NULL,
                     facet = NULL, facet_rows = NULL, facet_cols = NULL,
                     type = c("auto", "point", "box", "violin", "means",
                              "histogram", "density", "bar"),
                     smooth = FALSE, alpha = NULL, bins = 30,
                     title = NULL, subtitle = NULL, caption = NULL,
                     xlab = NULL, ylab = NULL, legend_title = NULL,
                     theme = ggplot2::theme_minimal()) {
  type <- match.arg(type)
  fill_given <- !missing(fill)

  if (!is.data.frame(data)) {
    stop("`data` must be a data frame, e.g. the result of sim_population().", call. = FALSE)
  }
  if (missing(x)) {
    stop("`x` is required, e.g. plot_sim(d, x = age).", call. = FALSE)
  }

  x_q      <- rlang::enquo(x)
  y_q      <- rlang::enquo(y)
  color_q  <- rlang::enquo(color)
  fill_q   <- rlang::enquo(fill)
  facet_q  <- rlang::enquo(facet)
  rows_q   <- rlang::enquo(facet_rows)
  cols_q   <- rlang::enquo(facet_cols)
  is_null  <- rlang::quo_is_null

  # Look at the variables to choose (and check) the plot type ---------------
  xv <- eval_var(x_q, data)
  has_y <- !is_null(y_q)
  yv <- if (has_y) eval_var(y_q, data) else NULL
  x_is_cat <- is_discrete(xv)

  if (type == "auto") {
    type <- if (!has_y) {
      if (x_is_cat) "bar" else "histogram"
    } else if (x_is_cat) {
      "box"
    } else {
      "point"
    }
  }

  needs_y <- type %in% c("point", "box", "violin", "means")
  if (needs_y && !has_y) {
    stop("type = \"", type, "\" needs a `y` variable.", call. = FALSE)
  }
  if (!needs_y && has_y) {
    stop("type = \"", type, "\" uses only `x`; leave `y` out.", call. = FALSE)
  }
  if (has_y && !is.numeric(yv)) {
    stop("`y` must be numeric.", call. = FALSE)
  }
  if (type %in% c("histogram", "density") && x_is_cat) {
    stop("type = \"", type, "\" needs a numeric `x`.", call. = FALSE)
  }
  if (type %in% c("box", "violin", "means") && !x_is_cat) {
    stop(
      "type = \"", type, "\" needs a categorical `x`. ",
      "For a numeric x use type = \"point\", or wrap it: x = factor(", rlang::as_label(x_q), ").",
      call. = FALSE
    )
  }

  # 0/1 variables used to group things should be treated as categories ------
  data <- discretize(data, color_q)
  data <- discretize(data, fill_q)
  data <- discretize(data, facet_q)
  data <- discretize(data, rows_q)
  data <- discretize(data, cols_q)
  if (type %in% c("box", "violin", "means", "bar")) data <- discretize(data, x_q)

  # Build the aesthetics ------------------------------------------------------
  fill_types <- c("box", "violin", "histogram", "density", "bar")
  if (type %in% fill_types && !fill_given && !is_null(color_q)) {
    fill_q <- color_q
  }
  maps <- list(x = x_q, y = y_q, colour = color_q, fill = fill_q)
  if (type == "means") {
    maps$group <- if (!is_null(color_q)) color_q else if (!is_null(fill_q)) fill_q else rlang::quo(1)
  }
  maps <- maps[!vapply(maps, is_null, logical(1))]

  # A 0/1 outcome gets a logistic curve instead of a straight line
  y_binary <- has_y && is.numeric(yv) && all(yv %in% c(0, 1, NA))

  alpha_or <- function(default) if (is.null(alpha)) default else alpha

  p <- ggplot2::ggplot(data, ggplot2::aes(!!!maps))

  layers <- switch(
    type,
    point = if (y_binary) {
      list(ggplot2::geom_jitter(width = 0, height = 0.04, alpha = alpha_or(0.2)))
    } else {
      list(ggplot2::geom_point(alpha = alpha_or(0.4)))
    },
    box = list(ggplot2::geom_boxplot(alpha = alpha_or(0.6))),
    violin = list(ggplot2::geom_violin(alpha = alpha_or(0.6))),
    means = {
      dodge <- ggplot2::position_dodge(width = 0.2)
      list(
        ggplot2::stat_summary(fun.data = mean_ci, geom = "errorbar", width = 0.1, position = dodge),
        ggplot2::stat_summary(fun = mean, geom = "line", position = dodge),
        ggplot2::stat_summary(fun = mean, geom = "point", size = 3, position = dodge)
      )
    },
    histogram = list(ggplot2::geom_histogram(bins = bins, alpha = alpha_or(0.6), position = "identity")),
    density = list(ggplot2::geom_density(alpha = alpha_or(0.4))),
    bar = list(ggplot2::geom_bar(alpha = alpha_or(0.8), position = "dodge"))
  )
  p <- p + layers

  if (smooth && type == "point") {
    p <- p + if (y_binary) {
      ggplot2::geom_smooth(method = "glm", formula = y ~ x,
                           method.args = list(family = "binomial"), se = TRUE)
    } else {
      ggplot2::geom_smooth(method = "lm", formula = y ~ x, se = TRUE)
    }
  }

  # Panels, theme and labels --------------------------------------------------
  if (!is_null(facet_q)) {
    p <- p + ggplot2::facet_wrap(ggplot2::vars(!!facet_q))
  } else if (!is_null(rows_q) || !is_null(cols_q)) {
    rows <- if (is_null(rows_q)) NULL else ggplot2::vars(!!rows_q)
    cols <- if (is_null(cols_q)) NULL else ggplot2::vars(!!cols_q)
    p <- p + ggplot2::facet_grid(rows = rows, cols = cols)
  }

  p <- p + theme + ggplot2::labs(title = title, subtitle = subtitle, caption = caption)
  if (!is.null(xlab)) p <- p + ggplot2::labs(x = xlab)
  if (!is.null(ylab)) p <- p + ggplot2::labs(y = ylab)
  if (!is.null(legend_title)) {
    p <- p + ggplot2::labs(colour = legend_title, fill = legend_title)
  }
  p
}

# Internal helpers ---------------------------------------------------------

# Evaluate a variable (a quosure) in the data, with a friendly error.
eval_var <- function(q, data) {
  tryCatch(
    rlang::eval_tidy(q, data),
    error = function(e) {
      stop(
        "Can't find `", rlang::as_label(q), "` in the data. Columns are: ",
        paste(names(data), collapse = ", "), ".",
        call. = FALSE
      )
    }
  )
}

# Categorical: factor, character, logical, or a number with two or fewer values.
is_discrete <- function(v) {
  is.factor(v) || is.character(v) || is.logical(v) ||
    (is.numeric(v) && length(unique(v)) <= 2)
}

# Turn a bare-name 0/1 column into a factor so it gets discrete colors/panels.
discretize <- function(data, q) {
  if (rlang::quo_is_null(q) || !rlang::quo_is_symbol(q)) return(data)
  nm <- rlang::as_name(q)
  v <- data[[nm]]
  if (!is.null(v) && is.numeric(v) && length(unique(v)) <= 2) {
    data[[nm]] <- factor(v)
  }
  data
}

# Mean and 95% confidence interval, for the "means" plot.
mean_ci <- function(v) {
  m <- mean(v)
  se <- stats::sd(v) / sqrt(length(v))
  data.frame(y = m, ymin = m - 1.96 * se, ymax = m + 1.96 * se)
}
