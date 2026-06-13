# Network functions (statbank_nodes, statbank_tables, statbank_get, ...) are not tested
# against the live API; these tests cover the pure building blocks.

fake_vars <- tibble::tibble(
  code        = c("time", "place of birth"),
  text        = c("tid", "fødested"),
  values      = list(c("2023", "2024", "2025"), c("Total", "Greenland")),
  valueTexts  = list(c("2023", "2024", "2025"), c("I alt", "Grønland")),
  elimination = c(FALSE, FALSE),
  time        = c(TRUE, FALSE)
)

test_that(".sb_match_selection() defaults unmentioned variables to all", {
  out <- daos:::.sb_match_selection(fake_vars, list())
  expect_equal(out, list(time = "*", `place of birth` = "*"))
})

test_that(".sb_match_selection() matches variables by code and by text", {
  by_code <- daos:::.sb_match_selection(fake_vars, list(time = "2024"))
  by_text <- daos:::.sb_match_selection(fake_vars, list(tid = "2024"))
  expect_equal(by_code$time, "2024")
  expect_equal(by_text$time, "2024")
})

test_that(".sb_match_selection() maps value texts to value codes", {
  out <- daos:::.sb_match_selection(fake_vars, list(`fødested` = "Grønland"))
  expect_equal(out$`place of birth`, "Greenland")
})

test_that(".sb_match_selection() folds Danish letters in names and values", {
  out <- daos:::.sb_match_selection(fake_vars, list(foedested = "Groenland"))
  expect_equal(out$`place of birth`, "Greenland")
})

test_that(".sb_match_selection() accepts numeric values and several values", {
  out <- daos:::.sb_match_selection(fake_vars, list(tid = c(2023, 2025)))
  expect_equal(out$time, c("2023", "2025"))
})

test_that(".sb_match_selection() aborts on unknown variables and values", {
  expect_error(daos:::.sb_match_selection(fake_vars, list(alder = "*")),
               "No variable matches")
  expect_error(daos:::.sb_match_selection(fake_vars, list(tid = "1066")),
               "No value matches")
  expect_error(daos:::.sb_match_selection(fake_vars, list("2024")),
               "must be named")
})

test_that(".sb_parse_jsonstat() expands dimensions with the last varying fastest", {
  x <- list(
    id   = list("time", "area"),
    size = list(2L, 2L),
    dimension = list(
      time = list(
        label = "tid",
        category = list(
          index = list("2023" = 0L, "2024" = 1L),
          label = list("2023" = "2023", "2024" = "2024")
        )
      ),
      area = list(
        label = "område",
        category = list(
          index = list(T = 0L, G = 1L),
          label = list(T = "I alt", G = "Grønland")
        )
      )
    ),
    value = list(1, 2, 3, 4)
  )
  out <- daos:::.sb_parse_jsonstat(x)
  expect_equal(names(out), c("tid", "område", "value"))
  expect_equal(out$tid, c("2023", "2023", "2024", "2024"))
  expect_equal(out$område, c("I alt", "Grønland", "I alt", "Grønland"))
  expect_equal(out$value, c(1, 2, 3, 4))
})

test_that(".sb_parse_jsonstat() can use codes for column names and cells", {
  x <- list(
    id   = list("gender"),
    size = list(2L),
    dimension = list(
      gender = list(
        label = "køn",
        category = list(
          index = list("0" = 0L, "1" = 1L),
          label = list("0" = "Kvinde", "1" = "Mand")
        )
      )
    ),
    value = list(5, 7)
  )
  texts <- daos:::.sb_parse_jsonstat(x)
  codes <- daos:::.sb_parse_jsonstat(x, col_names = "code", values = "code")
  expect_equal(names(texts), c("køn", "value"))
  expect_equal(texts$køn, c("Kvinde", "Mand"))
  expect_equal(names(codes), c("gender", "value"))
  expect_equal(codes$gender, c("0", "1"))
})

test_that(".sb_parse_jsonstat() orders categories by index, not list order", {
  x <- list(
    id   = list("k"),
    size = list(2L),
    dimension = list(
      k = list(
        label = "k",
        category = list(
          index = list(b = 1L, a = 0L),
          label = list(b = "B", a = "A")
        )
      )
    ),
    value = list(10, NULL)
  )
  out <- daos:::.sb_parse_jsonstat(x)
  expect_equal(out$k, c("A", "B"))
  expect_equal(out$value, c(10, NA))
})

test_that(".sb_extract_info() collects notes, source, and contact", {
  x <- list(
    source  = "Statistics Greenland",
    updated = "2026-02-09T06:04:30Z",
    note    = list("1) Fodnote om opgørelsen."),
    dimension = list(
      time = list(label = "tid", note = list("Brud i serien i 1977.")),
      type = list(label = "art")
    ),
    extension = list(contact = list(list(raw = "Lars Pedersen. LARP@stat.gl")))
  )
  info <- daos:::.sb_extract_info(x)
  expect_equal(info$notes,
               c("1) Fodnote om opgørelsen.", "tid: Brud i serien i 1977."))
  expect_equal(info$source, "Statistics Greenland")
  expect_equal(info$contact, "Lars Pedersen. LARP@stat.gl")
})

test_that(".sb_strip_html() removes tags and collapses whitespace", {
  expect_equal(
    daos:::.sb_strip_html("Folketal <em>[BEDSAT1]</em>"),
    "Folketal [BEDSAT1]"
  )
  expect_equal(daos:::.sb_strip_html("a &amp; b"), "a & b")
})

test_that(".sb_resolve_table() needs the table list for bare ids", {
  expect_equal(daos:::.sb_resolve_table("BE/BE01/BEXSAT1.PX", "da"),
               "BE/BE01/BEXSAT1.PX")
  expect_error(daos:::.sb_resolve_table("NOTCACHED.PX", "xx"),
               "has not been fetched")
})

test_that(".sb_url() builds and encodes the endpoint per bank", {
  expect_equal(daos:::.sb_url("", "da", "gl"),
               "https://bank.stat.gl/api/v1/da/Greenland")
  expect_equal(daos:::.sb_url("BE/BE01", "en", "gl"),
               "https://bank.stat.gl/api/v1/en/Greenland/BE/BE01")
  expect_equal(daos:::.sb_url("IP/IP02", "fo", "fo"),
               "https://statbank.hagstova.fo/api/v1/fo/H2/IP/IP02")
})

test_that(".sb_bank() rejects unknown banks", {
  expect_error(daos:::.sb_bank("xx"), "Unknown statbank")
  expect_equal(daos:::.sb_bank("fo")$db, "H2")
})

test_that(".sb_resolve_lang() defaults per bank and validates", {
  expect_equal(daos:::.sb_resolve_lang(NULL, "gl"), "da")
  expect_equal(daos:::.sb_resolve_lang(NULL, "fo"), "fo")
  expect_equal(daos:::.sb_resolve_lang("en", "fo"), "en")
  expect_error(daos:::.sb_resolve_lang("da", "fo"), "not available")
})
