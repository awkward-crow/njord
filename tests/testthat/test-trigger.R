test_that("payout is zero below, a ramp within, and the limit above", {
  attachment <- 25
  exhaustion <- 35
  limit <- 2
  expect_equal(payout(c(20, 30, 40), attachment, exhaustion, limit),
               c(0, 1, 2))
})

test_that("basis_risk returns one row per storm with finite basis risk", {
  set.seed(1)
  storms <- paste0("storm_", 1:50)
  index_vec <- setNames(runif(50, 15, 40), storms)
  loss_vec <- setNames(rev(pmax(0, (index_vec - 20) / 400)), rev(storms))
  out <- basis_risk(index_vec, loss_vec, 25, 35)
  expect_named(out, c("event", "index", "loss", "payout", "basis_risk"))
  expect_true(is.finite(mean(out$basis_risk)))
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
