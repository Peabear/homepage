require 'yaml'
require 'fileutils'

# Define paths
posts_dir = '_posts'
# Change this path if you want to use a different folder or filename
custom_data_file = '_data/peabear.yml' 

total_income = 0
posts_data = []

# Check if the posts directory exists
unless Dir.exist?(posts_dir)
  puts "Error: The directory '#{posts_dir}' was not found."
  exit
end

# Get all files in the directory and sort them by filename
files = Dir.glob(File.join(posts_dir, '*')).sort

files.each do |file|
  next unless File.file?(file)
  content = File.read(file)
  
  # Regex to extract the YAML frontmatter (between the --- lines)
  if content =~ /\A(---\s*\n.*?)\n---\s*\n/m
    begin
      frontmatter = YAML.safe_load($1)
      
      # Check if the 'income' attribute is present
      if frontmatter && frontmatter.key?('income')
        income = frontmatter['income'].to_f
        title = frontmatter['title'] || File.basename(file)
        
        total_income += income
        posts_data << { title: title, income: income }
      end
    rescue => e
      puts "Error parsing file #{File.basename(file)}: #{e.message}"
    end
  end
end

# Round down to the nearest 500 (e.g., 30850 becomes 30500)
rounded_income = (total_income / 500).floor * 500

# Print the summary to the terminal
puts "========================================"
puts "Exact Income:   #{total_income} EUR"
puts "Rounded Income: #{rounded_income} EUR (rounded down to nearest 500)"
puts "========================================"
puts ""

# Print the sorted list of posts
puts "Posts ordered by filename:"
posts_data.each do |post|
  puts "#{post[:title]}: #{post[:income]} EUR"
end

# Update the custom YAML file
begin
  dir_name = File.dirname(custom_data_file)
  FileUtils.mkdir_p(dir_name) unless Dir.exist?(dir_name)

  data = File.exist?(custom_data_file) ? YAML.load_file(custom_data_file) : {}
  data ||= {}

  # Formatiert die Zahl mit Punkten als Tausendertrennzeichen (z.B. 30500 -> "30.500")
  formatted_income = rounded_income.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\1.')

  # Speichert den formatierten String
  data['income'] = formatted_income

  File.write(custom_data_file, data.to_yaml)
  puts "\n[Success] File '#{custom_data_file}' successfully updated with formatted income: #{formatted_income}"
rescue => e
  puts "\n[Error] Failed to write to '#{custom_data_file}': #{e.message}"
end
