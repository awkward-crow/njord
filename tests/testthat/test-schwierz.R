test_that("schwierz_mdr is zero up to 20 m/s and constant from 60 m/s", {
  v <- c(0, 20, 60, 80)
  mdr <- schwierz_mdr(v, mdd_scale = 1, paa_scale = 1)
  expect_equal(mdr[1:2], c(0, 0))
  expect_equal(mdr[3], mdr[4])
})

test_that("welker_mdr and uk_mdr lie above the Schwierz curve", {
  v <- seq(25, 80, by = 5)
  schwierz <- schwierz_mdr(v, mdd_scale = 1, paa_scale = 1)
  expect_true(all(welker_mdr(v) > schwierz))
  expect_true(all(uk_mdr(v) > schwierz))
})
