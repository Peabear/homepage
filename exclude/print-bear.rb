require 'yaml'

# Path to the Jekyll posts directory
posts_dir = '_posts'

# A hash to store our results: { "Bear Name" => [unique years] }
bear_years = Hash.new { |hash, key| hash[key] = [] }

# Check if the directory exists
unless Dir.exist?(posts_dir)
  puts "Error: The directory '#{posts_dir}' was not found."
  exit
end

# Get all files in the directory
files = Dir.glob(File.join(posts_dir, '*'))

files.each do |file|
  next unless File.file?(file)

  filename = File.basename(file)
  
  # Extract the year from the first 4 characters of the filename
  year = filename[0..3]
  
  # Check if the first 4 characters are actually a 4-digit number (Jekyll format)
  next unless year =~ /\A\d{4}\z/

  content = File.read(file)
  
  # Regex to extract the YAML frontmatter
  if content =~ /\A(---\s*\n.*?)\n---\s*\n/m
    begin
      frontmatter = YAML.safe_load($1)
      
      # Check if the 'bear' attribute is present and not empty
      if frontmatter && frontmatter.key?('bear') && frontmatter['bear']
        bear_name = frontmatter['bear'].to_s.strip
        
        # Add the year to this bear's list unless it's already there
        bear_years[bear_name] << year unless bear_years[bear_name].include?(year)
      end
    rescue => e
      puts "Error parsing file #{filename}: #{e.message}"
    end
  end
end

# Print the final list
puts "========================================"
puts "Bears ranked by number of years featured:"
puts "========================================"
puts ""

if bear_years.empty?
  puts "No entries with a 'bear' attribute found."
else
  # Sort bears descending by the count of unique years.
  # If counts are equal, sort alphabetically by name.
  sorted_bears = bear_years.sort_by { |name, years| [-years.size, name] }

  sorted_bears.each do |bear, years|
    # Sort the years chronologically and join them with a comma
    sorted_years = years.sort.join(', ')
    # Print: <Count> - <Bear Name>: <Years>
    puts "#{years.size} - #{bear}: #{sorted_years}"
  end
end
