# Target directory to validate
TARGET_DIR = '_site'.freeze
BLOG_DIR = File.join(TARGET_DIR, 'aktuelles').freeze

# Expected files and directories in root
EXPECTED_ITEMS = %w[
  aktuelles assets legal spenden-fuer-guten-zweck tags ueber-uns
  404.html feed.xml index.html llms-full.txt llms.txt robots.txt sitemap.xml
].freeze

# System files to ignore
#IGNORED_ITEMS = %w[.DS_Store .gitkeep .keep thumbs.db].freeze
IGNORED_ITEMS = %w[].freeze

# --- CONFIGURATION FOR STRICT CHECKS ---
# Define what files are expected in which directories
EXPECTED_FILES_PATTERN_A = %w[index.html index.md].freeze
EXPECTED_FILES_PATTERN_B = %w[index.html].freeze

DIRECT_STRICT_DIRS_A = %w[spenden-fuer-guten-zweck ueber-uns].freeze
DIRECT_STRICT_DIRS_B = %w[tags legal].freeze

unless Dir.exist?(TARGET_DIR)
  STDERR.puts "Error: #{TARGET_DIR} directory does not exist. Please run 'jekyll build' first."
  exit 1
end

# Track overall validation status
@validation_failed = false

# HELPER METHOD: Validates any directory against a specific list of expected files
def validate_directory_contents(full_path, display_name, expected_files)
  unless Dir.exist?(full_path)
    @validation_failed = true
    puts '=' * 50
    puts "Validation Failed: Directory does not exist: #{display_name}"
    puts '=' * 50
    return
  end

  actual_files = Dir.children(full_path) - IGNORED_ITEMS

  if actual_files.sort != expected_files.sort
    @validation_failed = true
    puts '=' * 50
    puts "Validation Failed for directory: #{display_name}"
    puts '=' * 50
    puts "Expected exactly: #{expected_files.join(', ')}"
    puts "Found:            #{actual_files.empty? ? 'Empty directory' : actual_files.join(', ')}"
  end
end

# 1. Validate root directory structure
actual_items = Dir.children(TARGET_DIR) - IGNORED_ITEMS
unexpected_items = actual_items - EXPECTED_ITEMS
missing_items    = EXPECTED_ITEMS - actual_items

unless unexpected_items.empty? && missing_items.empty?
  @validation_failed = true
  puts '=' * 50
  puts "Validation Failed for root directory: #{TARGET_DIR}"
  puts '=' * 50

  unless unexpected_items.empty?
    puts "\nUnexpected items found:"
    unexpected_items.each { |item| puts "  - #{item}" }
  end

  unless missing_items.empty?
    puts "\nMissing expected items:"
    missing_items.each { |item| puts "  - #{item}" }
  end
end

# 2. Validate strict directories

# A) Check all sub-directories inside /blog (using Pattern A)
if Dir.exist?(BLOG_DIR)
  blog_subdirs = Dir.children(BLOG_DIR) - IGNORED_ITEMS
  blog_subdirs.each do |subdir|
    full_subdir_path = File.join(BLOG_DIR, subdir)
    next unless Dir.exist?(full_subdir_path) # Skip files in the root of /blog, only check dirs
    
    validate_directory_contents(full_subdir_path, "blog/#{subdir}", EXPECTED_FILES_PATTERN_A)
  end
end

# B) Check listed directories directly (Pattern A)
DIRECT_STRICT_DIRS_A.each do |dir_name|
  full_path = File.join(TARGET_DIR, dir_name)
  validate_directory_contents(full_path, dir_name, EXPECTED_FILES_PATTERN_A)
end

# C) Check listed directories directly (Pattern B)
DIRECT_STRICT_DIRS_B.each do |dir_name|
  full_path = File.join(TARGET_DIR, dir_name)
  validate_directory_contents(full_path, dir_name, EXPECTED_FILES_PATTERN_B)
end

# 3. Final exit status
if @validation_failed
  puts "\nProcess aborted to prevent accidental publication."
  exit 1
else
  puts "Success: #{TARGET_DIR} structure and all strict directories match perfectly!"
  exit 0
end
