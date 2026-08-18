require 'yaml'

# Define file paths
file_path = '_site/llms-full.txt'
data_file = '_data/peabear.yml'
config_file = '_config.yml'

# Critical Check: Output file must exist
unless File.exist?(file_path)
  puts "[CRITICAL ERROR] File '#{file_path}' was not found. Please run 'jekyll build' first."
  exit(1)
end

# 1. Read income from peabear.yml (Strict)
unless File.exist?(data_file)
  puts "[CRITICAL ERROR] Required data file '#{data_file}' is missing."
  exit(1)
end

begin
  peabear_data = YAML.load_file(data_file)
  if peabear_data && peabear_data['income']
    income_value = peabear_data['income'].to_s
    puts "[Success] Read income: '#{income_value}'"
  else
    puts "[CRITICAL ERROR] Key 'income' not found inside #{data_file}."
    exit(1)
  end
rescue => e
  puts "[CRITICAL ERROR] Failed to parse #{data_file}: #{e.message}"
  exit(1)
end

# 2. Read email and baseurl from _config.yml (Strict)
unless File.exist?(config_file)
  puts "[CRITICAL ERROR] Required configuration file '#{config_file}' is missing."
  exit(1)
end

begin
  config_data = YAML.safe_load(File.read(config_file))
  if config_data
    # Extract email strictly
    if config_data['email'] && !config_data['email'].to_s.strip.empty?
      email_value = config_data['email'].to_s
    else
      puts "[CRITICAL ERROR] Key 'email' is missing or empty inside #{config_file}."
      exit(1)
    end

    # Extract baseurl strictly
    if config_data['baseurl']
      baseurl_value = config_data['baseurl'].to_s
    else
      puts "[CRITICAL ERROR] Key 'baseurl' is missing inside #{config_file}."
      exit(1)
    end
    
    puts "[Success] Read config settings -> Email: '#{email_value}', Baseurl: '#{baseurl_value}'"
  else
    puts "[CRITICAL ERROR] Configuration file #{config_file} is empty."
    exit(1)
  end
rescue => e
  puts "[CRITICAL ERROR] Failed to parse #{config_file}: #{e.message}"
  exit(1)
end

# 3. Perform replacements and Quality Control Check
begin
  content = File.read(file_path, encoding: 'utf-8')

  # Hard-replace the 3 specific parameters with the extracted values
  content.gsub!('{{ site.data.peabear.income }}', income_value)
  content.gsub!('{{ site.baseurl }}', baseurl_value)
  content.gsub!('{{ site.email }}', email_value)

  # Write the modified content back to the file
  File.write(file_path, content)
  puts "[Success] Parameters successfully replaced in '#{file_path}'."

  # Quality Control: Scan explicitly for unresolved 'site.' tags (e.g., {{ site.title }})
  # This ignores page or layout variables but strict-checks site objects.
  if content =~ /\{\{.*?site\..*?\}\}/ || content =~ /\{%.*?site\..*?%\}/
    puts "\n========================================================"
    puts "[ERROR] Unresolved 'site.' parameters detected in the file!"
    puts "========================================================"
    
    # Scans the file and prints the exact line number AND the unrendered site parameter
    content.each_line.with_index(1) do |line, line_num|
      if line =~ /(\{\{.*?site\..*?\}\}|\{%.*?site\..*?%\})/
        detected_parameter = $1
        puts "Line #{line_num}: Found unresolved parameter -> #{detected_parameter}"
      end
    end
    
    puts "\nBuild failed to prevent shipping a corrupted llms-full.txt."
    exit(1)
  else
    puts "[Success] Quality check passed: No unresolved 'site.' parameters left in the file!"
  end

rescue => e
  puts "[CRITICAL ERROR] Script aborted due to an unexpected file error: #{e.message}"
  exit(1)
end
