test_that("schwierz_mdr is zero up to 20 m/s and constant from 60 m/s", {
  v <- c(0, 20, 60, 80)
  mdr <- schwierz_mdr(v, mdd_scale = 1)
  expect_equal(mdr[1:2], c(0, 0))
  expect_equal(mdr[3], mdr[4])
})

test_that("schwierz_mdr scales linearly with mdd_scale", {
  v <- seq(0, 100, by = 5)
  expect_equal(schwierz_mdr(v, mdd_scale = 0.8),
               0.8 * schwierz_mdr(v, mdd_scale = 1))
})
