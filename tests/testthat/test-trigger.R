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
