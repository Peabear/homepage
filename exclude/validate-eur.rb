require 'find'

# --- CONFIGURATION ---
# Define all directories that you want to scan recursively.
TARGET_DIRECTORIES = [
  './_posts',
  './_pages'
]
# ---------------------

markdown_files_found = 0
matches_count = 0

puts "Starting recursive currency validation (Checking for exact word 'Euro' or '€')..."
puts "=" * 60

# Helper method to detect markdown files
def md_file?(file_path)
  file_path.end_with?('.md') || file_path.end_with?('.markdown')
end

# Loop through each configured directory
TARGET_DIRECTORIES.each do |dir|
  unless Dir.exist?(dir)
    puts "\n[Warning]: Directory '#{dir}' does not exist. Skipping."
    next
  end

  puts "\nScanning directory: #{File.expand_path(dir)}"
  puts "-" * 60

  # Recursively traverse the directory tree
  Find.find(dir) do |path|
    if File.file?(path) && md_file?(path)
      markdown_files_found += 1
      file_has_matches = false

      begin
        # Read the file line-by-line using UTF-8 encoding
        File.foreach(path, encoding: 'utf-8').with_index(1) do |line, line_num|
          
          # 1. Matches "Euro" as an exact isolated word, ignoring cases where it is connected 
          #    via a hyphen (e.g., 'Euro-Zone' or 'Non-Euro' are ALLOWED and skipped).
          # 2. Matches the literal currency symbol '€'.
          if line =~ /(?<!-)\bEuro\b(?!-)/i || line.include?('€')
            unless file_has_matches
              puts "\nForbidden currency usage found in file: #{path}"
              file_has_matches = true
            end
            puts "  [Line #{line_num}]: #{line.strip}"
            matches_count += 1
          end
        end
      rescue => e
        puts "\n[Error reading file #{path}]: #{e.message}"
      end
    end
  end
end

puts "\n" + "=" * 60
puts "Validation Summary:"
puts "Total markdown files scanned: #{markdown_files_found}"
puts "Total forbidden currency formatting errors found: #{matches_count}"

# Final exit code evaluation after the entire scan finishes
if matches_count > 0
  puts "\n[VALIDATION FAILED]: Please replace all occurrences of the word 'Euro' or symbol '€' with 'EUR'."
  exit(1) # Terminates with failure code for pipelines
else
  puts "\n[SUCCESS]: All markdown files are using correct currency formatting."
  exit(0) # Terminates successfully
end
