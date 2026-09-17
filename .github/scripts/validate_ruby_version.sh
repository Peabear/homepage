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

# Extract all version numbers from the table cell and find the highest one
HIGHEST_RUBY_VERSION=$(echo "$SUPPORTED_RUBY_VERSIONS" | awk '
  {
    # Replace commas, pipes, and backticks with spaces to isolate tokens cleanly
    gsub(/[,|`]/, " ")
    
    # Loop through every word/token in the cleaned string
    for (i = 1; i <= NF; i++) {
      # Match only tokens that are valid version numbers (e.g., 2.2 or 4.0.7)
      if ($i ~ /^[0-9]+\.[0-9]+(\.[0-9]+)?$/) {
        print $i
      }
    }
  }
' | sort -V | tail -n 1)
if [ -z "$HIGHEST_RUBY_VERSION" ]; then
  echo "[ERROR] Could not identify any valid Ruby version numbers without grep."
  exit 1
fi
echo "Highest Ruby version: $HIGHEST_RUBY_VERSION"

# print collected version information
echo ""
echo "========================================================"
echo "Repository:            https://github.com/ruby/setup-ruby"
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

# compare versions
if [ "$LOCAL_VERSION" == "$HIGHEST_RUBY_VERSION" ]; then
  echo "[SUCCESS] Perfect! Local version matches the highest pipeline support ($HIGHEST_RUBY_VERSION)."
else
  echo "[CRITICAL ERROR] Ruby version mismatch detected!"
  echo "Highest pipeline support: $HIGHEST_RUBY_VERSION"
  echo "Local environment: $LOCAL_VERSION"
  echo "Build aborted to prevent configuration mismatches."
  exit 1
fi
