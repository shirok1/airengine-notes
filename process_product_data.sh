#!/bin/bash

# 检查是否提供了文件路径参数
if [ -z "$1" ]; then
  echo "用法: $0 <主HTML文件路径>"
  exit 1
fi

main_file="$1"
base_dir=$(dirname "$main_file")
# 获取 resources 目录的绝对路径，假设它在 docs/resources
resources_dir=$(realpath "${base_dir}/..")

# 读取主HTML文件内容并转换为UTF-8
main_file_content=$(iconv -f gb2312 -t utf-8 "$main_file")

# 1. 提取产品名称
product_name=$(echo "$main_file_content" | scrape -te '//h1')

# 2. 提取“产品特点”页面链接并构建绝对路径
feature_file_rel=$(echo "$main_file_content" | scrape -a href -e '//a[contains(text(), "产品特点")]')
# Assuming feature file is in the same directory as the main file, or in a 'dc' subdirectory relative to 'docs/resources'
# Need to handle cases where feature_file_rel might be empty or not found
if [ -z "$feature_file_rel" ]; then
    echo "Warning: Product features link not found for $main_file" >&2
    features_html=""
else
    # Adjust path based on common patterns observed: ../dc/file.html or ../file.html
    if [[ "$feature_file_rel" == ../dc/* ]]; then
        feature_file_abs=$(realpath "${base_dir}/${feature_file_rel#../dc/}")
    else
        feature_file_abs=$(realpath "${resources_dir}/${feature_file_rel#../}")
    fi

    # Check if feature file exists
    if [ ! -f "$feature_file_abs" ]; then
        echo "Error: Feature file not found: $feature_file_abs" >&2
        features_html=""
    else
        # Read feature content and extract HTML
        feature_content=$(iconv -f gb2312 -t utf-8 "$feature_file_abs")
        features_html=$(echo "$feature_content" | scrape -e '//h1[contains(text(), "产品特点")]/following-sibling::div')
    fi
fi


# 3. 提取所有“硬件结构”链接和标题
hrefs=$(echo "$main_file_content" | scrape -a href -e '//a[contains(text(), "硬件结构")]')
titles=$(echo "$main_file_content" | scrape -t -e '//a[contains(text(), "硬件结构")]')

# Combine hrefs and titles, handling potential empty outputs
if [ -z "$hrefs" ] || [ -z "$titles" ]; then
    hardware_links_and_titles=""
else
    hardware_links_and_titles=$(paste -d'|' <(echo "$hrefs") <(echo "$titles"))
fi


# Output extracted raw data
echo "PRODUCT_NAME: $product_name"
echo "---FEATURES_HTML_START---"
echo "$features_html"
echo "---FEATURES_HTML_END---"

echo "---HARDWARE_SPECS_START---"
# Loop through each hardware structure link and title
IFS=$'
' # Set IFS to newline to correctly handle lines with spaces
if [ -n "$hardware_links_and_titles" ]; then
    for entry in $hardware_links_and_titles;
    do
        hardware_file_rel=$(echo "$entry" | cut -d'|' -f1)
        hardware_title=$(echo "$entry" | cut -d'|' -f2)

        # Construct absolute path for hardware file
        # Assuming hardware file is in the resources directory, and relative path is ../w_product_...html
        # Use realpath to resolve the absolute path correctly
        hardware_file_abs=$(realpath "${resources_dir}/${hardware_file_rel#../}")

        # Check if hardware file exists
        if [ ! -f "$hardware_file_abs" ]; then
            echo "Error: Hardware file not found: $hardware_file_abs" >&2
            tech_specs_text="Error: File not found."
        else
            # Read hardware content and extract technical specifications
            hardware_content=$(iconv -f gb2312 -t utf-8 "$hardware_file_abs")
            tech_specs_text=$(echo "$hardware_content" | scrape -te '//h4[contains(text(), "技术指标")]/following-sibling::div//table')
            if [ -z "$tech_specs_text" ]; then
                tech_specs_text="Warning: Technical specifications table not found in $hardware_file_abs."
            fi
        fi

        echo "---HARDWARE_BLOCK_START---"
        echo "HARDWARE_TITLE: $hardware_title"
        echo "TECH_SPECS_TEXT: $tech_specs_text"
        echo "---HARDWARE_BLOCK_END---"
    done
else
    echo "Warning: No hardware structure links found."
fi
echo "---HARDWARE_SPECS_END---"