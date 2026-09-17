#!/bin/bash

# stops script in case of error
set -e

# fetch latest release tag of 'ruby/setup-ruby' via API
echo "Fetching latest release from GitHub API..."
LATEST_RELEASE_TAG=$(curl -s "https://api.github.com/repos/ruby/setup-ruby/releases" | \
  grep -oP '"tag_name":\s*"\K[^"]+' | \
  grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | \
  head -n 1)
if [ -z "$LATEST_RELEASE_TAG" ]; then
  echo "[ERROR] Could not fetch data from the ruby/setup-ruby repository."
  exit 1
fi
echo "--------------------------------------------------------"
echo "GitHub Actions Setup Ruby"
echo "--------------------------------------------------------"
echo "Repository:            https://github.com/ruby/setup-ruby"
echo "Latest Release Tag:    $LATEST_RELEASE_TAG"
echo "--------------------------------------------------------"

# fetch README of latest release and extract section 'Supported Versions'
SUPPORTED_SECTION=$(curl -s "https://raw.githubusercontent.com/ruby/setup-ruby/${LATEST_RELEASE_TAG}/README.md" | \
 awk '
    /### Supported Versions/ { flag=1; next } 
    /^#[#[:space:]]*/ && flag { exit } 
    flag { print }
  ')
if [ -z "$SUPPORTED_SECTION" ]; then
  echo "[ERROR] Could not locate the section 'Supported Versions' inside the README.md."
  exit 1
fi
echo -e "Supported Versions:\n"
echo "$SUPPORTED_SECTION"
echo "--------------------------------------------------------"

# Extract supported Ruby versions
SUPPORTED_RUBY_VERSIONS=$(echo "$SUPPORTED_SECTION" | \
  grep -i "ruby" | \
  grep "until" | \
  awk -F'|' '{print $3}' | \
  sed -E 's/^[^0-9]*//; s/[[:space:]]*$//')
if [ -z "$SUPPORTED_RUBY_VERSIONS" ]; then
  echo "[ERROR] Could not locate the supported Ruby version"
  exit 1
fi
echo "Supported Ruby Versions:"
echo "$SUPPORTED_RUBY_VERSIONS"
echo "--------------------------------------------------------"

# Extract all version numbers from the table cell and find the highest one (including previews)
HIGHEST_RUBY_VERSION=$(echo "$SUPPORTED_RUBY_VERSIONS" | awk '
  {
    # Replace commas, pipes, and backticks with spaces to isolate tokens cleanly
    gsub(/[,|`]/, " ")
    
    # Loop through every word/token in the cleaned string
    for (i = 1; i <= NF; i++) {
      # Match tokens that are valid version numbers, now allowing suffixes like -preview1
      if ($i ~ /^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9]+)?$/ || $i ~ /^[0-9]+\.[0-9]+$/) {
        print $i
      }
    }
  }
' | sort -V | tail -n 1)
if [ -z "$HIGHEST_RUBY_VERSION" ]; then
  echo "[ERROR] Could not identify any valid Ruby version numbers without grep."
  exit 1
fi
echo "Highest Ruby version found in README: $HIGHEST_RUBY_VERSION"

# print collected version information
echo ""
echo "========================================================"
echo "Repository:            https://github.com"
echo "Latest Release Tag:    $LATEST_RELEASE_TAG"
echo "--------------------------------------------------------"
echo "Supported Ruby Versions:"
echo "$SUPPORTED_RUBY_VERSIONS"
echo "--------------------------------------------------------"
echo "Highest Ruby version: $HIGHEST_RUBY_VERSION"
echo "========================================================"

# extract local .ruby-version file
if [ ! -f .ruby-version ]; then
  echo "[CRITICAL ERROR] Local '.ruby-version' file is missing!"
  exit 1
fi
LOCAL_VERSION=$(cat .ruby-version | tr -d '[:space:]')
echo "Local version (.ruby-version): $LOCAL_VERSION"
echo "--------------------------------------------------------"

# 1. Exact Match Check
if [ "$LOCAL_VERSION" == "$HIGHEST_RUBY_VERSION" ]; then
  echo "[SUCCESS] Perfect! Local version matches the highest pipeline support ($HIGHEST_RUBY_VERSION)."
  exit 0
fi

# 2. Preview Handle Check
# Check if the pipeline version contains a hyphen (e.g., 4.1.0-preview1)
if [[ "$HIGHEST_RUBY_VERSION" == *'-'* ]]; then
  # Strip the preview suffix to get the base version (e.g., 4.1.0)
  BASE_PIPELINE_VERSION=$(echo "$HIGHEST_RUBY_VERSION" | cut -d'-' -f1)
  
  # Use sort -V to check if LOCAL_VERSION is strictly smaller than BASE_PIPELINE_VERSION
  # If the local version comes first in a sorted list, it means LOCAL_VERSION < BASE_PIPELINE_VERSION
  FIRST_IN_SORT=$(echo -e "${LOCAL_VERSION}\n${BASE_PIPELINE_VERSION}" | sort -V | head -n 1)
  
  if [ "$FIRST_IN_SORT" == "$LOCAL_VERSION" ] && [ "$LOCAL_VERSION" != "$BASE_PIPELINE_VERSION" ]; then
    echo "[SUCCESS] Valid! Local version ($LOCAL_VERSION) is older than the upcoming preview ($HIGHEST_RUBY_VERSION)."
    echo "You are safe until the stable $BASE_PIPELINE_VERSION release is published."
    exit 0
  fi
fi

# If neither condition met, trigger the mismatch error
echo "[CRITICAL ERROR] Ruby version mismatch detected!"
echo "Highest pipeline support: $HIGHEST_RUBY_VERSION"
echo "Local environment:        $LOCAL_VERSION"
echo "Build aborted to prevent configuration mismatches."
exit 1
