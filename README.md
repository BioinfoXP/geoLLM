---

# GEOScreenAI 🧬🤖

[](https://www.google.com/search?q=https://github.com/username/GEOScreenAI/actions)
[](https://www.google.com/search?q=https://lifecycle.r-lib.org/articles/stages.html%23experimental)
**GEOScreenAI** is an R package designed to revolutionize how researchers filter Gene Expression Omnibus (GEO) metadata.

Unlike traditional methods that rely on rigid Regular Expressions (Regex) or manual keyword searching, **GEOScreenAI uses Large Language Models (LLMs)** to semantically understand and classify datasets. It can distinguish between "Pancreatic Cancer" and "Liver Cancer" even if the text is complex, and accurately identify sequencing types (scRNA-seq, Spatial, Bulk) from messy descriptions.

## 🌟 Key Features

* **Pure AI Screening**: No keyword hard-coding. It understands "Single Cell"  "10x"  "scRNA-seq".
* **Batch Processing**: Automatically handles large datasets (e.g., 2000+ rows) in batches to avoid token limits.
* **Auto-Classification**: Turns messy metadata into standardized categories (scRNA-seq, stRNA-seq, Microarray, etc.).
* **Built-in Database**: Comes with a pre-classified database for immediate testing.
* **Multi-Language Support**: Search in Chinese or English; the AI understands both.

## 📦 Installation

You can install the development version of GEOScreenAI from GitHub:

```r
# Install devtools if you haven't already
if (!requireNamespace("devtools", quietly = TRUE))
    install.packages("devtools")

# Install GEOScreenAI
devtools::install_github("BioinfoXP/GEOScreenAI")

```

*(Replace `YourUserName` with your actual GitHub username)*

## 🔑 Configuration

Before using the package, you need to set up your LLM API key. This package is compatible with OpenAI-style APIs (e.g., OpenAI, SiliconFlow, DeepSeek).

```r
library(GEOScreenAI)

# Option 1: Set environment variable (Recommended for security)
Sys.setenv(OPENAI_API_KEY = "sk-xxxxxxxxxxxxxxxxxxxxxxxx")

# Option 2: Pass directly in functions
# api_key = "sk-..."

```

**Note on Models:** The package defaults to `gpt-5-nano` via `https://api.gpt.ge/v1`. You can customize the `base_url` and `model` in all functions.

## 🚀 Quick Start

### Scenario 1: Using Built-in Data (Zero Setup)

The package includes a pre-classified dataset (`geo_database`). You can screen it immediately without loading your own files.

```r
# Find "Pancreatic Cancer" datasets that are "Spatial Transcriptomics"
results <- GEO_Screen_AI(
  disease = "胰腺癌",           # AI understands Chinese input
  data_type = "空间转录组",      # AI maps this to "stRNA-seq/Visium"
  model = "gpt-5-nano"
)

# View results
head(results)

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

Now use `GEO_Screen_AI` to find exactly what you need.

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

If you want to use **DeepSeek** or **SiliconFlow**:

```r
res <- GEO_Screen_AI(
  disease = "Liver Cancer",
  base_url = "https://api.siliconflow.cn/v1",# you can the api url
  model = "deepseek-ai/DeepSeek-V3", # you can change the model
  api_key = "sk-..."
)

```

## 📄 License

MIT © [Your Name]
