# =============== GEO AI Tool ================
# =============== GEO_Classify_AI ================

#' @title AI-Powered GEO Data Classifier (Batch Processing)
#' @description Automatically classifies GEO datasets into 5 standardized types:
#' **scRNA-seq**, **stRNA-seq**, **Bulk RNA-seq**, **Microarray**, or **Other**.
#' Uses batch processing to handle large datasets efficiently.
#'
#' @section Input Data Requirements:
#' The input \code{input_data} must contain at least:
#' \itemize{
#'   \item \strong{ID Column}: Unique identifier (e.g., "GSE", "Accession").
#'   \item \strong{Description Column}: Text describing the study (e.g., "Title", "Summary", "Description").
#'   \item \strong{Platform Column (Optional)}: Sequencing platform info (e.g., "Platform", "GPL").
#' }
#'
#' @param input_data Data.frame. The raw metadata table.
#' @param batch_size Numeric. Number of rows to process per API call (Default 50).
#' @param api_key OpenAI API Key.
#' @param model LLM model (default "gpt-5-nano").
#' @param base_url API Base URL.
#' @param verbose Logical. Show progress bar.
#'
#' @return A data.frame with a new column \code{AI_SeqType} appended.
#' @export
#' @importFrom openai OpenAI
#' @importFrom jsonlite fromJSON
#' @importFrom glue glue
#' @importFrom dplyr bind_rows
#' @importFrom utils txtProgressBar setTxtProgressBar
#'
#' @examples
#' \dontrun{
#'   # 1. 读取原始数据
#'   # raw_df <- read.csv("1.肝癌.xlsx - Sheet1.csv")
#'
#'   # 2. 运行分类 (打标签)
#'   classified_df <- GEO_Classify_AI(
#'     input_data = raw_df,
#'     api_key = "sk-xxxxxx"
#'   )
#'
#'   # 3. 查看分类结果统计
#'   table(classified_df$AI_SeqType)
#'
#'   # 4. (可选) 将结果保存，供后续筛选使用
#'   # save(classified_df, file = "geo_classified.Rdata")
#' }
GEO_Classify_AI <- function(input_data,
                            batch_size = 50,
                            api_key = NULL,
                            model = "gpt-5-nano",
                            base_url = "https://api.gpt.ge/v1",
                            verbose = TRUE) {

  # 1. Setup
  if (is.null(api_key)) api_key <- Sys.getenv("OPENAI_API_KEY")
  if (api_key == "") stop("Please provide 'api_key'.")

  if (!is.data.frame(input_data) || nrow(input_data) == 0) {
    warning("Input data is empty.")
    return(input_data)
  }

  # 2. Smart Column Detection
  cols <- names(input_data)

  # ID (GSE)
  id_col <- grep("数据集编号|GSE|Accession|dataset_id", cols, ignore.case=T, value=T)[1]
  if(is.na(id_col)) id_col <- cols[1]

  # Platform
  plat_col <- grep("测序平台|Platform|GPL|Instrument|sequencing_platform", cols, ignore.case=T, value=T)[1]

  # Description/Design
  desc_col <- grep("实验设计|Title|Summary|Description|experimental_design", cols, ignore.case=T, value=T)[1]

  if(is.na(desc_col)) stop("Could not find a 'Description/Title' column. AI needs text to classify.")

  if (verbose) message(glue::glue("ℹ️  Columns Identified: ID='{id_col}', Platform='{plat_col}', Desc='{desc_col}'"))

  # 3. Batch Processing Setup
  n_rows <- nrow(input_data)
  n_batches <- ceiling(n_rows / batch_size)
  client <- openai::OpenAI(api_key = api_key, base_url = base_url)

  results_list <- list()

  if (verbose) {
    message(glue::glue("🚀 Starting Classification ({model}): {n_rows} datasets in {n_batches} batches..."))
    pb <- utils::txtProgressBar(min = 0, max = n_batches, style = 3)
  }

  # 4. Loop Batches
  for (i in 1:n_batches) {
    start_idx <- (i - 1) * batch_size + 1
    end_idx <- min(i * batch_size, n_rows)
    batch_df <- input_data[start_idx:end_idx, ]

    # Prepare Text for AI
    batch_text <- apply(batch_df, 1, function(row) {
      p_txt <- if(!is.na(plat_col)) paste0("[Plat: ", row[plat_col], "]") else ""
      d_txt <- as.character(row[desc_col])
      # Truncate to save tokens (keep enough context)
      if (nchar(d_txt) > 300) d_txt <- paste0(substr(d_txt, 1, 297), "...")
      paste0(row[id_col], " | ", p_txt, " ", d_txt)
    })

    # Construct Prompt
    sys_prompt <- glue::glue("
      You are a Bioinformatics Classifier.

      --- TASK ---
      Classify each dataset into ONE category based on Platform and Description.

      --- CATEGORIES ---
      1. **scRNA-seq**: Single cell RNA sequencing (Keywords: 10x, Chromium, Single cell, scRNA, Drop-seq, Smart-seq).
      2. **stRNA-seq**: Spatial Transcriptomics (Keywords: Visium, Spatial, GeoMx, Slide-seq).
      3. **Microarray**: Chip/Array based (Keywords: GPL, Affymetrix, Agilent, Array, Expression profiling by array).
      4. **Bulk RNA-seq**: High throughput sequencing of tissue/bulk (Keywords: Illumina HiSeq/NextSeq, RNA-Seq) AND NOT Single Cell.
      5. **Other**: Methylation, ChIP-seq, miRNA, or Unknown.

      --- INPUT FORMAT ---
      ID | [Plat: ...] Description

      --- OUTPUT FORMAT ---
      JSON Object: {{ \"classifications\": [ {{ \"id\": \"GSE...\", \"type\": \"Category\" }}, ... ] }}

      --- DATA BATCH ---
      {paste(batch_text, collapse = '\n')}
    ")

    # API Call with Retry Logic
    success <- FALSE
    retry_count <- 0

    while (!success && retry_count < 3) {
      tryCatch({
        resp <- client$chat$completions$create(
          model = model,
          messages = list(list(role = "system", content = sys_prompt)),
          temperature = 0,
          response_format = list(type = "json_object")
        )

        # Parse JSON
        content <- resp$choices[[1]]$message$content
        parsed <- jsonlite::fromJSON(content)
        res_df <- as.data.frame(parsed$classifications)

        # Mapping back to batch_df robustly
        batch_results <- data.frame(ID = batch_df[[id_col]], AI_SeqType = "Unknown", stringsAsFactors = FALSE)

        # Match IDs (Robust merge to handle potential AI shuffling)
        match_idx <- match(batch_results$ID, res_df$id)
        valid_idx <- !is.na(match_idx)
        batch_results$AI_SeqType[valid_idx] <- res_df$type[match_idx[valid_idx]]

        results_list[[i]] <- batch_results
        success <- TRUE

      }, error = function(e) {
        retry_count <<- retry_count + 1
        if(verbose) message(glue::glue("\n⚠️ Batch {i} failed (Attempt {retry_count}): {e$message}"))
        Sys.sleep(1) # Wait before retry
      })
    }

    if (verbose) utils::setTxtProgressBar(pb, i)
  }

  if (verbose) close(pb)

  # 5. Combine & Merge Results
  all_classifications <- dplyr::bind_rows(results_list)

  # Merge back to original dataframe (Preserve original order)
  final_df <- input_data
  # Add/Update the column
  final_df$AI_SeqType <- all_classifications$AI_SeqType[match(final_df[[id_col]], all_classifications$ID)]

  # 6. Summary Report
  if (verbose) {
    message("\n✅ Classification Complete! Summary:")
    print(table(final_df$AI_SeqType))
  }

  return(final_df)
}


# =============== GEO_Screen_AI.R ================

#' @title AI-Powered GEO Dataset Screener
#' @title AI-Powered GEO Dataset Screener
#' @description Smartly screens datasets using LLM semantic understanding.
#' If \code{input_data} is not provided, it automatically uses the built-in \code{geo_database}.
#'
#' @param input_data Data.frame. Metadata table. Defaults to \code{NULL} (uses built-in package data).
#' @param disease String. Disease keyword (e.g., "胰腺癌").
#' @param data_type String. Sequencing type (e.g., "空间转录组").
#' @param target_species String. Target organism (e.g., "Homo sapiens").
#' @param other_req String. Any additional requirements.
#' @param batch_size Numeric. Rows per AI call (Default 500).
#' @param api_key OpenAI API Key.
#' @param model LLM model (default "gpt-5-nano").
#' @param base_url API Base URL.
#' @param verbose Print debug info.
#'
#' @return A filtered data.frame.
#' @export
#' @importFrom openai OpenAI
#' @importFrom dplyr filter select arrange desc distinct mutate
#' @importFrom glue glue
#' @importFrom jsonlite fromJSON
#' @importFrom stringr str_extract
#' @importFrom rlang sym
#' @importFrom utils txtProgressBar setTxtProgressBar
#'
#' @examples
#' \dontrun{
#'   # ==========================================
#'   # 场景 1: 直接使用内置数据 (最简模式)
#'   # ==========================================
#'   # 无需传入 input_data，直接搜！
#'   res <- GEO_Screen_AI(
#'     disease = "胰腺癌",
#'     data_type = "单细胞",
#'     api_key = "sk-xxxxxx"
#'   )
#'
#'   # ==========================================
#'   # 场景 2: 使用自己的数据
#'   # ==========================================
#'   # my_data <- read.csv("new_geo.csv")
#'   # res <- GEO_Screen_AI(input_data = my_data, disease = "Liver", ...)
#' }
GEO_Screen_AI <- function(input_data = NULL,
                          disease = NULL,
                          data_type = NULL,
                          target_species = NULL,
                          other_req = NULL,
                          batch_size = 500,
                          api_key = NULL,
                          model = "gpt-5-nano",
                          base_url = "https://api.gpt.ge/v1",
                          verbose = TRUE) {

  # 1. Handle Input Data (Auto-Load Built-in)
  if (is.null(input_data)) {
    if (exists("geo_database")) {
      input_data <- geo_database
      if (verbose) message(glue::glue("ℹ️  No input provided. Using built-in 'geo_database' ({nrow(input_data)} rows)."))
    } else {
      # Fallback for dev environment or if lazyload fails
      tryCatch({
        input_data <- get("geo_database", envir = asNamespace("GEOScreenAI"))
        if (verbose) message(glue::glue("ℹ️  Using built-in 'geo_database' from namespace ({nrow(input_data)} rows)."))
      }, error = function(e) {
        stop("❌ Input data is missing and built-in 'geo_database' not found. Please provide 'input_data'.")
      })
    }
  }

  # 2. Environment Check
  if (is.null(api_key)) api_key <- Sys.getenv("OPENAI_API_KEY")
  if (api_key == "") stop("Please provide 'api_key'.")

  if (!is.data.frame(input_data) || nrow(input_data) == 0) {
    warning("Input data is empty.")
    return(input_data)
  }

  # 3. Smart Column Detection
  cols <- names(input_data)

  id_col <- grep("数据集编号|GSE|Accession|dataset_id", cols, ignore.case=T, value=T)[1]
  if(is.na(id_col)) id_col <- cols[1]

  sp_col <- grep("物种|Species|Organism|species", cols, ignore.case=T, value=T)[1]
  type_col <- grep("AI_SeqType|SequencingType|DataType", cols, ignore.case=T, value=T)[1]
  dis_col <- grep("disease_type|Disease|Condition", cols, ignore.case=T, value=T)[1]
  desc_col <- grep("实验设计|Title|Summary|Description|experimental_design", cols, ignore.case=T, value=T)[1]

  num_cols <- names(input_data)[sapply(input_data, is.numeric)]
  samp_col_num <- grep("样本量|Sample|Count|N_|sample_size", num_cols, ignore.case=T, value=T)[1]
  samp_col_any <- grep("样本量|Sample|Count|N_|sample_size", cols, ignore.case=T, value=T)[1]
  samp_col <- if(!is.na(samp_col_num)) samp_col_num else samp_col_any

  if (verbose) {
    dis_msg <- if(is.na(dis_col)) "NA (Will check Description)" else dis_col
    message(glue::glue("ℹ️  Context Mapping: ID='{id_col}', Type='{type_col}', Disease='{dis_msg}'"))
  }

  # 4. Construct Prompt Criteria
  criteria_list <- c()
  if (!is.null(disease)) criteria_list <- c(criteria_list, glue::glue("- Target Disease: {disease} (Check [Disease] tag OR Description)"))
  if (!is.null(data_type)) criteria_list <- c(criteria_list, glue::glue("- Data Type: {data_type} (Check [Type] tag)"))
  if (!is.null(target_species)) criteria_list <- c(criteria_list, glue::glue("- Species: {target_species} (Check [Sp] tag)"))
  if (!is.null(other_req)) criteria_list <- c(criteria_list, glue::glue("- Other Req: {other_req}"))

  if (length(criteria_list) == 0) {
    warning("No criteria provided. Returning full dataset.")
    return(input_data)
  }
  criteria_str <- paste(criteria_list, collapse = "\n")

  # 5. Batch AI Processing
  n_total <- nrow(input_data)
  n_batches <- ceiling(n_total / batch_size)
  all_selected_ids <- c()

  client <- openai::OpenAI(api_key = api_key, base_url = base_url)

  if (verbose) {
    message(glue::glue("🧠 Scanning {n_total} datasets ({model}) in {n_batches} batches..."))
    pb <- utils::txtProgressBar(min = 0, max = n_batches, style = 3)
  }

  for (i in 1:n_batches) {
    start_i <- (i - 1) * batch_size + 1
    end_i <- min(i * batch_size, n_total)
    batch_df <- input_data[start_i:end_i, ]

    # Construct Context
    data_summary <- apply(batch_df, 1, function(row) {
      info_parts <- c()
      if(!is.na(sp_col)) info_parts <- c(info_parts, paste0("[Sp: ", row[sp_col], "]"))
      if(!is.na(type_col)) info_parts <- c(info_parts, paste0("[Type: ", row[type_col], "]"))
      if(!is.na(dis_col)) info_parts <- c(info_parts, paste0("[Disease: ", row[dis_col], "]"))

      extra_desc <- ""
      if(!is.na(desc_col)) extra_desc <- as.character(row[desc_col])
      if (nchar(extra_desc) > 300) extra_desc <- paste0(substr(extra_desc, 1, 297), "...")

      info_str <- paste(c(info_parts, extra_desc), collapse = " ")
      paste0(row[id_col], ": ", info_str)
    })

    sys_prompt <- glue::glue("
      You are a Bioinformatics Expert.

      --- TASK ---
      Select IDs matching criteria.

      --- CRITERIA ---
      {criteria_str}

      --- RULES ---
      1. **Semantic**: '胰腺癌' == 'Pancreatic Cancer'. '单细胞' == 'scRNA-seq'.
      2. **Fallback**: If [Disease] tag missing, search Description.
      3. **Output**: JSON {{ \"selected_ids\": [\"ID1\", \"ID2\"] }}

      --- DATA BATCH ---
      {paste(data_summary, collapse = '\n')}
    ")

    tryCatch({
      resp <- client$chat$completions$create(
        model = model,
        messages = list(list(role = "system", content = sys_prompt)),
        temperature = 0,
        response_format = list(type = "json_object")
      )
      ids <- jsonlite::fromJSON(resp$choices[[1]]$message$content)$selected_ids
      all_selected_ids <- c(all_selected_ids, ids)
    }, error = function(e) {
      if(verbose) message(glue::glue("\n⚠️ Batch {i} Error: {e$message}"))
    })

    if (verbose) utils::setTxtProgressBar(pb, i)
  }
  if (verbose) close(pb)

  # 6. Post-Processing
  if (length(all_selected_ids) > 0) {
    if (verbose) message(glue::glue("✅ AI Selected: {length(all_selected_ids)} datasets."))
    final_df <- input_data[input_data[[id_col]] %in% all_selected_ids, ]
  } else {
    message("⚠️  No datasets matched.")
    return(input_data[0, ])
  }

  final_df <- final_df %>% dplyr::distinct(!!rlang::sym(id_col), .keep_all = TRUE)

  if (!is.na(samp_col)) {
    sample_nums <- stringr::str_extract(as.character(final_df[[samp_col]]), "^\\d+")
    if (all(is.na(sample_nums))) sample_nums <- final_df[[samp_col]]

    final_df <- final_df %>%
      dplyr::mutate(tmp_sort_N = suppressWarnings(as.numeric(sample_nums))) %>%
      dplyr::arrange(dplyr::desc(tmp_sort_N)) %>%
      dplyr::select(-tmp_sort_N)
  }

  prio_cols <- c(id_col, sp_col, type_col, dis_col, samp_col, desc_col)
  prio_cols <- prio_cols[!is.na(prio_cols) & prio_cols %in% names(final_df)]
  other_cols <- setdiff(names(final_df), prio_cols)
  final_df <- final_df %>% dplyr::select(dplyr::all_of(c(prio_cols, other_cols)))

  return(final_df)
}
