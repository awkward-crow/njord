test_that("uk_mean_gust is the weighted mean over cells with a gust", {
  wts <- list(idx = c(1, 2), weight = c(1, 0.5))
  expect_equal(uk_mean_gust(c(30, 24, 99), wts), 28)
  expect_equal(uk_mean_gust(c(30, NA, 99), wts), 30)
  expect_true(is.nan(uk_mean_gust(c(NA, NA, 99), wts)))
})

test_that("uk_mean_gust_index is the weighted mean over cells with a gust", {
  grid <- terra::rast(nrows = 1, ncols = 3, xmin = 0, xmax = 0.75,
                      ymin = -0.125, ymax = 0.125)
  cover <- terra::setValues(grid, c(1, 0.5, 0))
  names(cover) <- "UK"
  cover_path <- tempfile(fileext = ".tif")
  terra::writeRaster(cover, cover_path)
  wts <- uk_weights(cover_path)
  gust_path <- function(v) {
    path <- tempfile(fileext = ".tif")
    terra::writeRaster(terra::setValues(grid, v), path)
    path
  }
  expect_equal(uk_mean_gust_index(gust_path(c(30, 24, 99)), wts), 28)
  expect_equal(uk_mean_gust_index(gust_path(c(30, NA, 99)), wts), 30)
})
