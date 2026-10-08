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
  config = YAML.load_file(config_file) || {}
  url = config.fetch('url')
  baseurl = config.fetch('baseurl')
  
  puts "Loaded from #{config_file}: url='#{url}', baseurl='#{baseurl}'"
rescue => e
  puts "Critical Error: Failed to load configuration from #{config_file} (#{e.message})."
  exit 1
end

# Prepare URL swapping strictly for HTML-Proofer (Step 2)
swap_localhost = ARGV.include?('--swap-localhost')
url_swaps = {}
clean_base = baseurl.to_s.gsub(%r{^/|/$}, "")

if !url.empty? && url != "/"
  url_swaps[%r{^#{Regexp.escape(url)}}] = ""
end

if swap_localhost
  url_swaps[%r{^https?://localhost:4000}] = ""
  url_swaps[%r{^https?://127\.0\.0\.1:4000}] = ""
end

if !clean_base.empty?
  url_swaps[%r{^/#{Regexp.escape(clean_base)}(?=/|$)}] = ""
end

puts "\n--- Active HTML-Proofer Swapping Configuration ---"
url_swaps.each do |regex, replacement|
  puts "Match: #{regex.inspect}  =>  Replace with: '#{replacement}'"
end
puts "--------------------------------------------------\n\n"


begin
  # STEP 1: PRE-CHECK FOR BASEURL AND REAL FILE EXISTENCE WITH LINE NUMBERS
  puts "Checking for missing baseurl prefixes and broken local files in HTML files..."
  missing_baseurl_found = false
  
  # Pre-compile the scan pattern for maximum performance
  link_pattern = /href=["'](\/[^"']+)["']|src=["'](\/[^"']+)["']/

  Dir.glob("#{target_directory}/**/*.html").each do |html_file|
    line_number = 0
    
    File.foreach(html_file, encoding: "utf-8") do |line|
      line_number += 1
      
      line.scan(link_pattern).flatten.compact.each do |matched_path|
        # Skip empty links, page-internal anchors, and root references
        next if matched_path == "/" || matched_path.start_with?("/#") || matched_path.start_with?("mailto:", "feed:")
        
        # 1. Strict Baseurl Guardian Enforcement (Only runs if a baseurl is configured)
        if !clean_base.empty?
          next if matched_path.start_with?("/legal") # Exception rule for root permalink
          
          if !matched_path.start_with?("/#{clean_base}/") && matched_path != "/#{clean_base}"
            puts "❌ Baseurl Error in #{html_file} on line #{line_number}: Found missing prefix in link/asset '#{matched_path}'"
            missing_baseurl_found = true
            next
          end
        end

        # 2. FILE EXISTENCE CHECK (Finds ALL typos instantly)
        # Strip the valid baseurl prefix to map the link to the local filesystem
        local_path = matched_path.dup
        local_path = local_path.sub(%r{^/#{clean_base}/?}, "") if !clean_base.empty?
        
        # Clean fragment anchors (#) and query variables (?)
        local_path = local_path.split("#").first.to_s.split("?").first.to_s
        
        # Fallback root path maps straight to index.html
        local_path = "index.html" if local_path.empty? || local_path == "/"
        
        # Remove any leading slash to append safely to target_directory
        local_path = local_path.sub(%r{^/}, "")
        target_path = File.join(target_directory, local_path)
        
        # Verify if the file or folder structure actually exists on your hard drive
        is_valid_file = File.exist?(target_path)
        is_valid_dir = File.directory?(target_path) && (
          File.exist?(File.join(target_path, "index.html")) || 
          File.exist?(File.join(target_path, "index.md"))
        )
        
        unless is_valid_file || is_valid_dir
          puts "❌ Broken Path Error in #{html_file} on line #{line_number}: The file/folder does not exist! Path: '#{matched_path}' (Resolved locally to: #{target_path})"
          missing_baseurl_found = true
        end
      end
    end
  end

  if missing_baseurl_found
    puts "\nBuild stopped: Path errors or missing baseurl prefixes detected."
    exit 1
  else
    puts "✓ HTML paths and file integrity verified successfully."
  end


  # STEP 2: RUN STANDARD HTML-PROOFER
  options = {
    check_favicon: true,
    check_opengraph: true,
    enforce_https: true,
    check_html: true,  
    assume_extension: true,
    directory_index_file: "index.html",
    root_dir: target_directory, 
    ignore_empty_mailto: true,
    ignore_status_codes: [403],
    ignore_urls: [
      /www\.facebook\.com\/Aeaezebaer\//
    ],
    swap_urls: url_swaps,
    typhoeus: {
      followlocation: true,
      headers: {
        "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
        "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
        "Accept-Language" => "en-US,en;q=0.9"
      }
    }
  }

  puts "\nStarting HTML-Proofer for folder #{target_directory}..."
  directory_failed = false
  
  begin
    directory_proofer = HTMLProofer.check_directory(target_directory, options)
    directory_proofer.run
  rescue SystemExit => e
    directory_failed = true if e.status != 0
  rescue => e
    puts "HTML Directory check failed: #{e.message}"
    directory_failed = true
  end


  # STEP 3: NATIVELY VALIDATE LINKS INSIDE BOTH LLM TEXT FILES (Optimized)
  llm_files_failed = false
  target_llm_files = ["/llms.txt", "/llms-full.txt"]
  
  # Compile regex infrastructure ONCE before splitting down loops
  domain_list = ["https?://localhost:4000", "https?://127\\.0\\.0\\.1:4000"]
  domain_list << Regexp.escape(url).gsub(%r{^https?://}, "https?://") if !url.empty? && url != "/"
  compiled_domain_regex = %r{^(?:#{domain_list.join("|")})?/}

  target_llm_files.each do |llm_file|
    full_file_path = File.join(target_directory, llm_file)
    
    if File.exist?(full_file_path)
      puts "\nValidating links inside LLM interface: #{llm_file}"
      content = File.read(full_file_path)
      extracted_urls = content.scan(/\[.*?\]\((.*?)\)/).flatten.uniq

      extracted_urls.each do |url_entry|
        next if url_entry.nil? || url_entry.to_s.strip.empty?

        # 1. Strip optional markdown image/link titles in quotes
        clean_url_entry = url_entry.split(/["']/).first.to_s.strip

        # Validate and skip mailto: URIs
        if clean_url_entry.start_with?("mailto:")
          # Extract the pure email address after the prefix
          email_address = clean_url_entry.sub(/^mailto:/, "").strip
          
          # Standard RFC-compliant Regex for basic email format validation
          email_pattern = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i
          
          unless email_address =~ email_pattern
            puts "❌ Invalid Email Format in #{llm_file}: '#{url_entry}' is not a valid email address."
            llm_files_failed = true
          end
          next
        end

        # Skip feed: URIs instantly before local checks trigger
        next if clean_url_entry.start_with?("feed:")


        # 2. Baseurl Guardian Verification
        is_local = clean_url_entry.start_with?("/") || clean_url_entry.start_with?("./") || !clean_url_entry.include?("://")
        is_internal_absolute = clean_url_entry =~ compiled_domain_regex

        if !clean_base.empty? && (is_local || is_internal_absolute)
          # ignore page-internal anchors starting with '#'
          unless clean_url_entry.start_with?("#")
            # Flag if missing the baseurl prefix while not being the legal permalink exception
            if !clean_url_entry.include?("/#{clean_base}/") && !clean_url_entry.include?("/#{clean_base}") && !clean_url_entry.include?("/legal")
              puts "❌ Baseurl Error in #{llm_file}: Link '#{url_entry}' is missing the required prefix '/#{clean_base}/'."
              llm_files_failed = true
              next
            end
          end
        end


        # 3. Local Path Resolution
        if is_local || is_internal_absolute
          # Strip domains and extract pure relative path
          local_path = clean_url_entry.gsub(compiled_domain_regex, "")
          
          # Clean fragment anchors (#) and query variables (?)
          local_path = local_path.split("#").first.to_s.split("?").first.to_s
          
          # Ensure it starts with a single leading slash for uniform slicing
          local_path = "/#{local_path}".gsub(%r{//+}, "/")
          
          # Strip the valid baseurl prefix cleanly from the start
          local_path = local_path.sub(%r{^/#{clean_base}/?}, "")
          
          # Fallback root path maps straight to index.html
          local_path = "index.html" if local_path.empty? || local_path == "/"
          
          # Remove any leftover leading slash to append safely to target_directory
          local_path = local_path.sub(%r{^/}, "")
          target_path = File.join(target_directory, local_path)
          
          is_valid_file = File.exist?(target_path)
          is_valid_dir = File.directory?(target_path) && (
            File.exist?(File.join(target_path, "index.html")) || 
            File.exist?(File.join(target_path, "index.md"))
          )
          
          unless is_valid_file || is_valid_dir
            puts "❌ Broken Link found in #{llm_file}: '#{url_entry}' (Resolved to local path: #{target_path})"
            llm_files_failed = true
          end
        end
      end
      
      puts "✓ Verification for #{llm_file} completed."
    else
      puts "\nNote: #{llm_file} not found in build directory. Skipping file-specific validation."
    end
  end


  # STEP 4: SYSTEM EXIT HANDLING
  if directory_failed || llm_files_failed
    puts "\nValidation failed. Please fix the errors listed above."
    exit 1
  else
    puts "\nGreat! All checks passed successfully (including verified HTML and LLM index files)."
    exit 0
  end

rescue => e
  puts "Critical script failure: #{e.message}"
  exit 1
end
