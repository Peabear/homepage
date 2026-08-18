require 'html-proofer'
require 'pp'
require 'yaml'

# Target directory
target_directory = "./_site"

# Read url and baseurl from _config.yml
config_file = "_config.yml"
baseurl = ""
url = ""

begin
  # YAML.load_file automatically fails if the file does not exist
  config = YAML.load_file(config_file) || {}
  
  # .fetch directly raises a KeyError if the key is missing
  url = config.fetch('url')
  baseurl = config.fetch('baseurl')
  
  puts "Loaded from #{config_file}: url='#{url}', baseurl='#{baseurl}'"
rescue => e
  puts "Critical Error: Failed to load configuration from #{config_file} (#{e.message})."
  exit 1
end


# Prepare URL swapping depending on url, baseurl and the --swap-localhost parameter
swap_localhost = ARGV.include?('--swap-localhost')
url_swaps = {}
if !url.empty? && url != "/"
  url_swaps[%r{^#{Regexp.escape(url)}}] = ""
end
if swap_localhost
  url_swaps[%r{^https?://localhost:4000}] = ""
  url_swaps[%r{^https?://127\.0\.0\.1:4000}] = ""
end
if !baseurl.empty? && baseurl != "/"
  url_swaps[%r{^#{Regexp.escape(baseurl)}}] = ""
end


puts "\n--- Active URL Swapping Configuration ---"
url_swaps.each do |regex, replacement|
  puts "Match: #{regex.inspect}  =>  Replace with: '#{replacement}'"
end
puts "-----------------------------------------\n\n"

# Definition of options
options = {
  check_favicon: true,
  check_opengraph: true,
  enforce_https: true,

  ignore_empty_mailto: true,
  ignore_status_codes: [403],
  ignore_urls: [                               # Ignores URLs (as real RegEx)
    /www\.facebook\.com\/Aeaezebaer\//
  ],

  swap_urls: url_swaps,

  # Pass custom parameters down to the Typhoeus connection worker
  typhoeus: {
    followlocation: true,
    headers: {
      "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
      "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
      "Accept-Language" => "en-US,en;q=0.9"
    }
  }
}

begin
  # 1. First, validate the standard HTML directories using HTML-Proofer
  puts "Starting HTML-Proofer for the folder #{target_directory}..."
  directory_proofer = HTMLProofer.check_directory(target_directory, options)
  
  directory_failed = false
  begin
    directory_proofer.run
  rescue => e
    puts "HTML Directory check failed: #{e.message}"
    directory_failed = true
  end

  # 2. Extract and natively validate links exclusively from llms.txt (In-Memory)
  llm_file_failed = false
  llm_file = "/llms.txt"
  full_file_path = File.join(target_directory, llm_file)
  
  if File.exist?(full_file_path)
    puts "Validating links inside LLM interface: #{llm_file}"
    content = File.read(full_file_path)
    
    # Precise Regex to capture all markdown links [text](url), even when nested in brackets
    extracted_urls = content.scan(/\[.*?\]\((.*?)\)/).flatten.uniq
    
    extracted_urls.each do |url|
      # Apply your configured url_swaps dynamically to the extracted URL
      processed_url = url.dup
      url_swaps.each do |regex, replacement|
        processed_url.gsub!(regex, replacement)
      end
      
      # Determine if the URL belongs to your local domain (starts with /, ./ or became relative after swap)
      # If the original URL was 'http://localhost:4000/publications/idex.md', it is now '/publications/idex.md'
      is_local = processed_url.start_with?("/") || processed_url.start_with?("./") || !processed_url.include?("://")
      
      if is_local
        # Clean up URL parameters or anchor fragments (#)
        clean_path = processed_url.split("#").first.split("?").first
        
        # Prevent empty path concatenation errors if a link points to root "/"
        clean_path = "index.html" if clean_path.empty? || clean_path == "/"
        
        target_path = File.join(target_directory, clean_path)
        
        # Check for direct file existence or fallback to directory indexing
        is_valid_file = File.exist?(target_path)
        is_valid_dir = File.directory?(target_path) && (File.exist?(File.join(target_path, "index.html")) || File.exist?(File.join(target_path, "index.md")))
        
        unless is_valid_file || is_valid_dir
          puts "❌ Broken Link found in #{llm_file}: '#{url}' (Resolved to local path: #{target_path})"
          llm_file_failed = true
        end
      end
    end
  else
    puts "Note: #{llm_file} not found in build directory. Skipping file-specific validation."
  end

  # 3. Final system exit handling based on combined results
  if directory_failed || llm_file_failed
    puts "\nValidation failed. Please fix the errors listed above."
    exit 1
  else
    puts "\nGreat! All checks passed successfully (including verified LLM markdown index links)."
    exit 0
  end

rescue => e
  puts "Critical script failure: #{e.message}"
  exit 1
end
