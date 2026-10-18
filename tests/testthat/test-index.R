test_that("weighted_mean_index is the weighted mean over cells with a gust", {
  wts <- list(idx = c(1, 2), weight = c(1, 0.5))
  expect_equal(weighted_mean_index(c(30, 24, 99), wts), 28)
  expect_equal(weighted_mean_index(c(30, NA, 99), wts), 30)
  expect_true(is.nan(weighted_mean_index(c(NA, NA, 99), wts)))
})

test_that("area_weights sums the regions' land fractions", {
  grid <- terra::rast(nrows = 1, ncols = 3, nlyrs = 3, xmin = 0, xmax = 0.75,
                      ymin = -0.125, ymax = 0.125)
  cover <- terra::setValues(grid, cbind(UKL = c(1, 0.3, NA),
                                        UKM = c(NA, 0.5, NA),
                                        UK = c(1, 0.8, NA)))
  names(cover) <- c("UKL", "UKM", "UK")
  cover_path <- tempfile(fileext = ".tif")
  terra::writeRaster(cover, cover_path)
  expect_equal(area_weights(cover_path, "UK"),
               list(idx = 1:2, weight = c(1, 0.8)))
  # terra::yFromCell() names a single cell's latitude "y".
  expect_equal(area_weights(cover_path, "UKM"), list(idx = 2L, weight = 0.5),
               ignore_attr = TRUE)
  expect_equal(area_weights(cover_path, c("UKL", "UKM")),
               area_weights(cover_path, "UK"))
})

test_that("exposure_weights splits cell assets by the regions' land share", {
  grid <- terra::rast(nrows = 1, ncols = 3, nlyrs = 3, xmin = 0, xmax = 0.75,
                      ymin = -0.125, ymax = 0.125)
  cover <- terra::setValues(grid, cbind(c(1, 0.3, NA), c(NA, 0.5, NA),
                                        c(1, 0.8, NA)))
  names(cover) <- c("UKL", "UKM", "UK")
  cover_path <- tempfile(fileext = ".tif")
  terra::writeRaster(cover, cover_path)
  assets_path <- tempfile(fileext = ".tif")
  terra::writeRaster(terra::setValues(grid[[1]], c(100, 80, NA)), assets_path)
  expect_equal(exposure_weights(cover_path, assets_path, "UK"),
               list(idx = 1:2, weight = c(100, 80)))
  expect_equal(exposure_weights(cover_path, assets_path, "UKM"),
               list(idx = 2L, weight = 50))
  expect_equal(exposure_weights(cover_path, assets_path, c("UKL", "UKM")),
               exposure_weights(cover_path, assets_path, "UK"))
})
