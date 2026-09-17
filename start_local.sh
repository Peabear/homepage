#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Define ANSI color codes for clean terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if the .ruby-version file exists
if [ ! -f .ruby-version ]; then
  echo -e "${RED}[CRITICAL ERROR] '.ruby-version' file is missing!${NC}"
  exit 1
fi

# Read the required version and strip any whitespaces or line breaks
REQUIRED_VERSION=$(cat .ruby-version | tr -d '[:space:]')

# Extract the currently active Ruby version (e.g., "3.2.2" or "4.0.0")
CURRENT_VERSION=$(rbenv version-name 2>/dev/null || ruby -v | awk '{print $2}' | sed 's/p.*//')

# Compare active version against the required version
if [[ "$CURRENT_VERSION" != "$REQUIRED_VERSION"* ]]; then
  echo -e "${RED}[CRITICAL ERROR] Ruby version mismatch!${NC}"
  echo -e "Required version (from .ruby-version): ${BLUE}$REQUIRED_VERSION${NC}"
  echo -e "Currently active Ruby version:        ${RED}$CURRENT_VERSION${NC}"
  echo -e "Please switch your Ruby version using your version manager, e.g. 'rbenv install'."
  exit 1
fi
echo -e "${GREEN}[SUCCESS] Ruby version verified ($CURRENT_VERSION).${NC}"

# Execute the Jekyll server command
echo -e "${BLUE}Starting Jekyll server with LiveReload...${NC}\n"
bundle exec jekyll serve --livereload
