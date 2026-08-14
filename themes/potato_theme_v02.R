POTATO_JOURNAL_ACCESSIBLE <- c(
  blue = "#0072B2",
  vermillion = "#D55E00",
  bluish_green = "#009E73",
  reddish_purple = "#CC79A7",
  orange = "#E69F00",
  sky_blue = "#56B4E9",
  black = "#000000",
  yellow = "#F0E442"
)

POTATO_SEMANTIC <- c(
  TEXT = "#202020",
  CONTROL = "#7A7A7A",
  TREATMENT = "#0072B2",
  SECONDARY = "#D55E00",
  POSITIVE = "#009E73",
  HIGHLIGHT = "#E69F00",
  AUXILIARY = "#CC79A7",
  DOWN = "#0072B2",
  UP = "#D55E00",
  NS = "#C8C8C8",
  MISSING = "#E6E6E6"
)

POTATO_SEQUENTIAL_BLUE <- c(
  "#F7FBFF", "#DDEAF4", "#9CC7E5", "#4A98C9", "#08519C"
)

POTATO_DIVERGING_EFFECT <- c(
  "#0072B2", "#56B4E9", "#F7F7F7", "#E69F00", "#D55E00"
)

POTATO_HIGH_IMPACT_OMICS <- c(
  lavender = "#B8A6D9",
  warm_yellow = "#E6C76A",
  soft_teal = "#55B8B2",
  powder_blue = "#8FB6D8",
  soft_salmon = "#E49A8F",
  mist_grey = "#D5D8DC",
  deep_blue = "#4F719D",
  salmon_line = "#D97B6D",
  neutral_dark = "#4D5663"
)

POTATO_DOTPLOT_PURPLE <- c(
  "#F2EDF7", "#D9C6E8", "#B891D0", "#8B4FB3", "#6A1B9A"
)

POTATO_HIGH_IMPACT_OMICS_LAYOUT <- data.frame(
  slot = c(
    "anchor_left", "anchor_right", "support_left",
    "support_middle", "support_right", "closure_wide"
  ),
  x = c(0.03, 0.54, 0.00, 0.38, 0.66, 0.39),
  y = c(0.01, 0.01, 0.53, 0.54, 0.54, 0.79),
  width = c(0.45, 0.43, 0.34, 0.25, 0.31, 0.58),
  height = c(0.49, 0.49, 0.42, 0.22, 0.22, 0.16),
  stringsAsFactors = FALSE
)

potato_theme <- function(base_size = 12, base_family = "Arial") {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("ggplot2 is required")
  }

  ggplot2::theme_classic(base_size = base_size, base_family = base_family) +
    ggplot2::theme(
      text = ggplot2::element_text(colour = POTATO_SEMANTIC[["TEXT"]]),
      axis.title = ggplot2::element_text(size = 12, face = "plain"),
      axis.text = ggplot2::element_text(size = 11, colour = POTATO_SEMANTIC[["TEXT"]]),
      axis.ticks = ggplot2::element_line(linewidth = 0.45, colour = POTATO_SEMANTIC[["TEXT"]]),
      axis.line = ggplot2::element_line(linewidth = 0.5, colour = POTATO_SEMANTIC[["TEXT"]]),
      plot.title = ggplot2::element_text(size = 16, face = "bold", hjust = 0),
      plot.subtitle = ggplot2::element_text(size = 12, hjust = 0),
      plot.tag = ggplot2::element_text(size = 14, face = "bold"),
      legend.title = ggplot2::element_text(size = 11),
      legend.text = ggplot2::element_text(size = 10.5),
      strip.text = ggplot2::element_text(size = 11, face = "bold"),
      panel.grid = ggplot2::element_blank(),
      plot.margin = ggplot2::margin(2.5, 2.5, 2.5, 2.5, unit = "mm")
    )
}

set_potato_theme <- function(base_size = 12, base_family = "Arial") {
  ggplot2::theme_set(potato_theme(base_size = base_size, base_family = base_family))
}

potato_theme_high_impact_omics <- function(base_size = 12, base_family = "Arial") {
  potato_theme(base_size = base_size, base_family = base_family) +
    ggplot2::theme(
      plot.title = ggplot2::element_blank(),
      panel.border = ggplot2::element_blank(),
      legend.key = ggplot2::element_blank(),
      legend.background = ggplot2::element_blank(),
      plot.tag = ggplot2::element_text(size = 16, face = "bold"),
      plot.margin = ggplot2::margin(2, 2, 2, 2, unit = "mm")
    )
}

potato_theme_embedding <- function(base_family = "Arial") {
  ggplot2::theme_void(base_family = base_family, base_size = 12) +
    ggplot2::theme(
      text = ggplot2::element_text(colour = "#202020"),
      plot.tag = ggplot2::element_text(size = 16, face = "bold"),
      legend.title = ggplot2::element_text(size = 10.5, face = "plain"),
      legend.text = ggplot2::element_text(size = 10.5),
      legend.key = ggplot2::element_blank(),
      legend.background = ggplot2::element_blank(),
      plot.margin = ggplot2::margin(1.5, 1.5, 1.5, 1.5, unit = "mm")
    )
}

potato_scale_colour_high_impact_omics <- function(...) {
  ggplot2::scale_colour_manual(
    values = unname(POTATO_HIGH_IMPACT_OMICS[c(
      "lavender", "warm_yellow", "soft_teal", "powder_blue", "soft_salmon", "mist_grey"
    )]),
    ...
  )
}

potato_scale_fill_high_impact_omics <- function(...) {
  ggplot2::scale_fill_manual(
    values = unname(POTATO_HIGH_IMPACT_OMICS[c(
      "lavender", "warm_yellow", "soft_teal", "powder_blue", "soft_salmon", "mist_grey"
    )]),
    ...
  )
}

potato_scale_dotplot_purple <- function(...) {
  ggplot2::scale_colour_gradientn(colours = POTATO_DOTPLOT_PURPLE, ...)
}

potato_scale_colour_discrete <- function(...) {
  ggplot2::scale_colour_manual(values = unname(POTATO_JOURNAL_ACCESSIBLE), ...)
}

potato_scale_fill_discrete <- function(...) {
  ggplot2::scale_fill_manual(values = unname(POTATO_JOURNAL_ACCESSIBLE), ...)
}

potato_scale_colour_effect <- function(limits = NULL, midpoint = 0, ...) {
  ggplot2::scale_colour_gradient2(
    low = "#0072B2", mid = "#F7F7F7", high = "#D55E00",
    midpoint = midpoint, limits = limits, ...
  )
}

potato_scale_fill_effect <- function(limits = NULL, midpoint = 0, ...) {
  ggplot2::scale_fill_gradient2(
    low = "#0072B2", mid = "#F7F7F7", high = "#D55E00",
    midpoint = midpoint, limits = limits, ...
  )
}

potato_scale_colour_sequential <- function(...) {
  ggplot2::scale_colour_gradientn(colours = POTATO_SEQUENTIAL_BLUE, ...)
}

potato_scale_fill_sequential <- function(...) {
  ggplot2::scale_fill_gradientn(colours = POTATO_SEQUENTIAL_BLUE, ...)
}

check_potato_font <- function(family = "Arial", fallback = "Liberation Sans") {
  if (!requireNamespace("systemfonts", quietly = TRUE)) {
    warning("systemfonts is unavailable; Arial presence was not verified")
    return(invisible(family))
  }

  resolved <- systemfonts::match_font(family)$family
  if (!identical(tolower(resolved), tolower(family))) {
    warning(sprintf("%s was not resolved exactly; use %s only with an explicit manifest warning", family, fallback))
  }
  invisible(resolved)
}

save_potato_figure <- function(
  plot,
  stem,
  content_width_mm,
  content_height_mm,
  orientation = c("portrait", "landscape"),
  padding_mm = 2.5,
  dpi = 600,
  save_a4_proof = TRUE
) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("ggplot2 is required")
  }
  orientation <- match.arg(orientation)
  stopifnot(content_width_mm > 0, content_height_mm > 0, padding_mm >= 0)

  a4 <- if (orientation == "portrait") c(width = 210, height = 297) else c(width = 297, height = 210)
  cropped <- c(
    width = content_width_mm + 2 * padding_mm,
    height = content_height_mm + 2 * padding_mm
  )

  if (cropped[["width"]] > a4[["width"]] || cropped[["height"]] > a4[["height"]]) {
    stop("Declared content footprint exceeds the selected A4 orientation")
  }

  dir.create(dirname(stem), recursive = TRUE, showWarnings = FALSE)
  plot_with_padding <- plot + ggplot2::theme(
    plot.margin = ggplot2::margin(padding_mm, padding_mm, padding_mm, padding_mm, unit = "mm")
  )

  ggplot2::ggsave(
    paste0(stem, ".pdf"), plot_with_padding,
    width = cropped[["width"]], height = cropped[["height"]], units = "mm",
    device = grDevices::cairo_pdf, bg = "white"
  )
  svg_device <- if (requireNamespace("svglite", quietly = TRUE)) {
    svglite::svglite
  } else {
    grDevices::svg
  }
  tiff_device <- function(filename, width, height, units = "in", res = 300, bg = "white", ...) {
    device_type <- if (isTRUE(capabilities("cairo"))) "cairo" else getOption("bitmapType")
    grDevices::tiff(
      filename = filename, width = width, height = height, units = units,
      res = res, bg = bg, compression = "lzw", type = device_type, ...
    )
  }

  ggplot2::ggsave(
    paste0(stem, ".svg"), plot_with_padding,
    width = cropped[["width"]], height = cropped[["height"]], units = "mm",
    device = svg_device,
    bg = "white"
  )
  ggplot2::ggsave(
    paste0(stem, ".tiff"), plot_with_padding,
    width = cropped[["width"]], height = cropped[["height"]], units = "mm",
    dpi = dpi, device = tiff_device, bg = "white"
  )
  ggplot2::ggsave(
    paste0(stem, ".png"), plot_with_padding,
    width = cropped[["width"]], height = cropped[["height"]], units = "mm",
    dpi = dpi, bg = "white"
  )

  if (isTRUE(save_a4_proof)) {
    save_potato_a4_proof(
      plot = plot,
      filename = paste0(stem, "_A4_proof.pdf"),
      content_width_mm = content_width_mm,
      content_height_mm = content_height_mm,
      orientation = orientation,
      margin_mm = 15
    )
  }

  invisible(list(
    a4_mm = a4,
    content_mm = c(width = content_width_mm, height = content_height_mm),
    cropped_mm = cropped,
    padding_mm = padding_mm,
    scaled_to_fill_a4 = FALSE
  ))
}

save_potato_a4_proof <- function(
  plot,
  filename,
  content_width_mm,
  content_height_mm,
  orientation = c("portrait", "landscape"),
  margin_mm = 15
) {
  orientation <- match.arg(orientation)
  a4 <- if (orientation == "portrait") c(width = 210, height = 297) else c(width = 297, height = 210)
  if (content_width_mm + margin_mm > a4[["width"]] || content_height_mm + margin_mm > a4[["height"]]) {
    stop("Content plus placement margin exceeds A4")
  }

  grDevices::cairo_pdf(filename, width = a4[["width"]] / 25.4, height = a4[["height"]] / 25.4)
  on.exit(grDevices::dev.off(), add = TRUE)
  grid::grid.newpage()
  vp <- grid::viewport(
    x = grid::unit(margin_mm, "mm"),
    y = grid::unit(a4[["height"]] - margin_mm, "mm"),
    width = grid::unit(content_width_mm, "mm"),
    height = grid::unit(content_height_mm, "mm"),
    just = c("left", "top")
  )
  grid::pushViewport(vp)
  grid::grid.draw(ggplot2::ggplotGrob(plot))
  grid::popViewport()
  invisible(filename)
}
