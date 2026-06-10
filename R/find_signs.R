#' Find sign combinations that sum to a target
#'
#' Given a set of labelled values and a target total, determines which
#' multipliers (`+1`, `-1`, or `0`) to apply to each value so that the
#' signed sum equals the target. Uses a *meet-in-the-middle* algorithm for
#' efficiency.
#'
#' This is useful for reconciling accounting line items where the sign
#' convention is unknown — for example, finding which items in a set of
#' account balances add up to a reported total.
#'
#' @param df A data frame containing labels and values.
#' @param label_col Column containing item labels (unquoted).
#' @param value_col Column containing numeric values (unquoted).
#' @param total_label Label of the row whose value is the reconciliation
#'   target. Default: `"total"`.
#' @param positive Character vector of labels that must receive a positive
#'   sign. Optional.
#' @param negative Character vector of labels that must receive a negative
#'   sign. Optional.
#' @param by Optional grouping columns (unquoted). When supplied, the
#'   reconciliation is performed separately for each group.
#' @param max_zeros Maximum number of zero coefficients allowed in a valid
#'   solution (i.e. how many items can be excluded). Default: `2L`.
#'
#' @return A tibble with the same label/value structure as the input, where
#'   values have been multiplied by their resolved signs. Groups with no
#'   unique solution are silently dropped (`NULL`).
#'
#' @examples
#' items <- data.frame(
#'   label = c("revenue", "costs", "depreciation", "total"),
#'   value = c(100, 40, 10, 50)
#' )
#' find_signs(items, label, value, total_label = "total")
#'
#' @importFrom cli cli_abort cli_progress_bar cli_progress_update cli_progress_done
#' @importFrom dplyr group_by group_split group_keys bind_cols bind_rows across all_of
#' @importFrom tibble as_tibble
#' @export
find_signs <- function(df, label_col, value_col, total_label = "total",
                       positive = NULL, negative = NULL, by = NULL,
                       max_zeros = 2L) {

  meet_in_middle <- function(v1, v2, target, max_zeros, c1, c2) {
    n1 <- length(v1)
    n2 <- length(v2)

    gen_combinations <- function(n, constraints) {
      ranges <- lapply(constraints, \(c)
        if (c == 1L) c(0L, 1L) else if (c == -1L) c(-1L, 0L) else c(-1L, 0L, 1L)
      )
      sizes <- lengths(ranges)
      total <- prod(sizes)
      mat   <- matrix(0L, nrow = total, ncol = n)
      rep_each <- 1L
      for (k in seq_len(n)) {
        r        <- ranges[[k]]
        rep_bloc <- total / (rep_each * sizes[k])
        mat[, k] <- rep(rep(r, each = rep_each), rep_bloc)
        rep_each <- rep_each * sizes[k]
      }
      mat
    }

    if (n2 == 0) {
      sums2  <- 0
      zeros2 <- 0L
      vals2  <- matrix(integer(0), nrow = 1L)
    } else {
      vals2  <- gen_combinations(n2, c2)
      sums2  <- drop(vals2 %*% v2)
      zeros2 <- rowSums(vals2 == 0L)
    }

    keys2    <- round(sums2 * 1e6)
    ord2     <- order(keys2)
    keys2_s  <- keys2[ord2]
    zeros2_s <- zeros2[ord2]
    vals2_s  <- vals2[ord2, , drop = FALSE]

    if (n1 == 0) {
      sums1  <- 0
      zeros1 <- 0L
      vals1  <- matrix(integer(0), nrow = 1L)
    } else {
      vals1  <- gen_combinations(n1, c1)
      sums1  <- drop(vals1 %*% v1)
      zeros1 <- rowSums(vals1 == 0L)
    }

    need_keys <- round((target - sums1) * 1e6)

    keep1 <- which(zeros1 <= max_zeros)
    if (length(keep1) == 0) return(list())

    need_keys <- need_keys[keep1]
    zeros1    <- zeros1[keep1]
    vals1     <- vals1[keep1, , drop = FALSE]

    hits <- match(need_keys, keys2_s)

    results <- vector("list", length(keep1))
    n_res   <- 0L

    for (i in which(!is.na(hits))) {
      z1 <- zeros1[i]
      j  <- hits[i]

      while (j <= length(keys2_s) && keys2_s[j] == need_keys[i]) {
        if (z1 + zeros2_s[j] <= max_zeros) {
          n_res <- n_res + 1L
          if (n_res > length(results))
            length(results) <- length(results) * 2L
          results[[n_res]] <- c(vals1[i, ], vals2_s[j, ])
        }
        j <- j + 1L
      }
    }

    results[seq_len(n_res)]
  }

  label_col_nm <- deparse(substitute(label_col))
  value_col_nm <- deparse(substitute(value_col))
  by_cols_nm   <- sapply(substitute(by), deparse)[-1]
  if (length(by_cols_nm) == 0) by_cols_nm <- NULL

  find_signs_group <- function(df_group) {

    all_labels <- df_group[[label_col_nm]]
    all_values <- df_group[[value_col_nm]]

    total_idx <- which(all_labels == total_label)
    if (length(total_idx) == 0) {
      cli::cli_abort("No label {.val {total_label}} found in group.")
    }

    total  <- all_values[total_idx]
    labels <- all_labels[-total_idx]
    values <- all_values[-total_idx]

    fixed_mult <- rep(0L, length(labels))
    fixed_mult[labels %in% positive] <-  1L
    fixed_mult[labels %in% negative] <- -1L

    mid <- floor(length(values) / 2)
    v1  <- values[seq_len(mid)]
    v2  <- values[seq(mid + 1, length(values))]
    c1  <- fixed_mult[seq_len(mid)]
    c2  <- fixed_mult[seq(mid + 1, length(values))]

    matches_mult <- meet_in_middle(v1, v2, total, max_zeros, c1, c2)

    if (length(matches_mult) != 1) return(NULL)

    full_mult <- matches_mult[[1]]

    result <- data.frame(
      label = c(labels, total_label),
      value = c(full_mult * values, total),
      stringsAsFactors = FALSE
    )
    names(result) <- c(label_col_nm, value_col_nm)
    result
  }

  if (is.null(by_cols_nm)) {
    return(find_signs_group(df) |> tibble::as_tibble())
  }

  grupper     <- df |> dplyr::group_by(dplyr::across(dplyr::all_of(by_cols_nm))) |> dplyr::group_split()
  gruppe_keys <- df |> dplyr::group_by(dplyr::across(dplyr::all_of(by_cols_nm))) |> dplyr::group_keys()

  results <- vector("list", length(grupper))
  cli::cli_progress_bar("Finding signs", total = length(grupper))
  for (i in seq_along(grupper)) {
    res <- find_signs_group(grupper[[i]])
    if (!is.null(res)) results[[i]] <- dplyr::bind_cols(gruppe_keys[i, ], res)
    cli::cli_progress_update()
  }
  cli::cli_progress_done()

  dplyr::bind_rows(results) |> tibble::as_tibble()
}
