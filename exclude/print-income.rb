require 'yaml'

# Path to the Jekyll posts directory
posts_dir = '_posts'
total_income = 0
posts_data = []

# Check if the directory exists
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

# 1) Print the total sum
puts "========================================"
puts "Total Income: #{total_income} EUR"
puts "========================================"
puts ""

# 2) Print the sorted list
puts "Posts ordered by filename:"
posts_data.each do |post|
  puts "#{post[:title]}: #{post[:income]} EUR"
end
