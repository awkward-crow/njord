test_that("shared_max_within_72h keeps one storm per event", {
  df <- data.frame(
    track_id = 1:7,
    central_time = c("2000-01-01 00:00", "2000-01-03 00:00",
                     "2000-01-05 00:00", "2000-02-01 00:00",
                     "2000-02-02 00:00", "2001-01-01 00:00",
                     "2000-01-02 00:00"),
    max_gust = c(30, 30, 30, 28, 28, 30, NA),
    ssi = c(1, 3, 2, 5, 5, 9, 0))
  expect_equal(shared_max_within_72h(df),
               c(TRUE, FALSE, TRUE, FALSE, TRUE, FALSE, FALSE))
})
