test_that("load_litpop_uk keeps every point and the total value", {
  path <- test_path("../../data-raw/litpop/LitPop_150arcsec_GBR.csv")
  skip_if_not(file.exists(path))
  litpop <- load_litpop_uk(path)
  expect_equal(terra::global(!is.na(litpop), "sum")[[1]], 19349)
  expect_equal(terra::global(litpop, "sum", na.rm = TRUE)[[1]],
               9471908198426)
})
