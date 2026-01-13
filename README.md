---

# GEOScreenAI 🧬🤖

[](https://www.google.com/search?q=https://github.com/BioinfoXP/GEOScreenAI/actions)
[](https://www.google.com/search?q=https://lifecycle.r-lib.org/articles/stages.html%23experimental)
**GEOScreenAI** is an R package designed to revolutionize how researchers filter Gene Expression Omnibus (GEO) metadata.

Unlike traditional methods that rely on rigid Regular Expressions (Regex) or manual keyword searching, **GEOScreenAI uses Large Language Models (LLMs)** to semantically understand and classify datasets. It can distinguish between "Pancreatic Cancer" and "Liver Cancer" even if the text is complex, and accurately identify sequencing types (scRNA-seq, Spatial, Bulk) from messy descriptions.

## 🌟 Key Features

* **🧠 Pure AI Screening**: No keyword hard-coding. It understands context: "10x Chromium"  "Single Cell"  "scRNA-seq".
* **📚 Rich Built-in Database**: Comes pre-loaded with **1,975 verified datasets** covering **scRNA-seq, Spatial Transcriptomics, Bulk RNA-seq, and Microarray**. Ready to query out-of-the-box!
* **⚡ Batch Processing**: Automatically handles large datasets (e.g., 2000+ rows) in smart batches to handle token limits efficiently.
* **🏷️ Auto-Classification**: Turns messy raw metadata into standardized categories (`AI_SeqType`).
* **🌐 Multi-Language Support**: Search using Chinese or English queries; the AI understands both perfectly.

## 📦 Installation

You can install the development version of GEOScreenAI from GitHub:

```r
# Install devtools if you haven't already
if (!requireNamespace("devtools", quietly = TRUE))
    install.packages("devtools")

# Install GEOScreenAI
devtools::install_github("BioinfoXP/GEOScreenAI")

```

## 🔑 Configuration

Before using the package, you need to set up your LLM API key. This package is compatible with OpenAI-style APIs (e.g., OpenAI, SiliconFlow, DeepSeek).

```r
library(GEOScreenAI)

# Option 1: Set environment variable (Recommended for security)
Sys.setenv(OPENAI_API_KEY = "sk-xxxxxxxxxxxxxxxxxxxxxxxx")

# Option 2: Pass directly in functions
# api_key = "sk-..."

```

> **Note:** The package defaults to `gpt-5-nano` via `https://api.gpt.ge/v1`. You can customize the `base_url` and `model` in all functions.

## 🚀 Quick Start

### Scenario 1: Mining the Built-in Database (Zero Setup)

**GEOScreenAI** includes a massive built-in database of **1,975 datasets**. You don't need to load any files to start mining data immediately.

```r
library(GEOScreenAI)

# 1. Check what's inside the built-in database
data("geo_database")
table(geo_database$AI_SeqType)
# Output example:
# Bulk RNA-seq   Microarray    scRNA-seq    stRNA-seq        Other
#          850          600          500           25            0

# 2. Screen with AI (e.g., finding Spatial Transcriptomics for Pancreatic Cancer)
results <- GEO_Screen_AI(
  disease = "胰腺癌",           # AI understands Chinese input
  data_type = "空间转录组",      # AI maps this to "stRNA-seq/Visium"
  model = "gpt-5-nano"
)

# 3. View your filtered results
print(head(results))

```

### Scenario 2: Processing Your Own Raw Data

If you have a raw Excel file exported from GEO (e.g., `geo_results.xlsx`), follow this workflow:

#### Step 1: Load and Classify

First, use `GEO_Classify_AI` to clean the data and add an `AI_SeqType` tag.

```r
library(readxl)

# 1. Read your raw data
raw_df <- read_excel("path/to/your/file.xlsx")

# 2. Classify (Standardize metadata)
# This adds a column 'AI_SeqType' (scRNA-seq, Bulk, etc.)
clean_df <- GEO_Classify_AI(
  input_data = raw_df,
  api_key = "your_api_key",
  model = "gpt-5-nano"
)

# (Optional) Save the cleaned data for future use
save(clean_df, file = "my_clean_geo_data.Rdata")

```

#### Step 2: Screen with AI

Now use `GEO_Screen_AI` to find exactly what you need from your cleaned data.

```r
# Screen for specific criteria
final_list <- GEO_Screen_AI(
  input_data = clean_df,
  disease = "Hepatocellular Carcinoma",
  data_type = "scRNA-seq",
  other_req = "Exclude cell lines and xenografts",
  target_species = "Homo sapiens",
  api_key = "your_api_key"
)

# Result is sorted by Sample Size automatically
print(final_list)

```

## 📋 Input Data Requirements

If you provide your own `input_data`, it should be a `data.frame` containing at least the following columns (names are auto-detected, but standard names help):

| Column Content | Recommended Names |
| --- | --- |
| **ID** | `GSE`, `Accession`, `dataset_id` |
| **Description** | `Title`, `Summary`, `Description`, `experimental_design` |
| **Species** | `Species`, `Organism` |
| **Platform** | `Platform`, `GPL`, `sequencing_platform` |
| **Sample Size** | `Sample_Count`, `N`, `sample_size` |

## 🛠 Advanced Usage

### Changing API Provider

You can easily switch to other LLM providers like **DeepSeek** or **SiliconFlow**:

- https://cloud.siliconflow.cn/i/zIsztzpU

```r
res <- GEO_Screen_AI(
  disease = "Liver Cancer",
  base_url = "https://api.siliconflow.cn/v1", # Change the API URL
  model = "deepseek-ai/DeepSeek-V3",          # Change the model
  api_key = "sk-..."
)

```

## 📄 License

MIT © [BioinfoXP]
