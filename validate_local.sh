#!/bin/bash

# Define scripts in a list (array)
SCRIPTS=(
  "bundle exec ruby exclude/validate-eur.rb"
  "bundle exec ruby exclude/validate-html.rb --swap-localhost" # will opften fail locally -> execute at last!
)

# Loop through each script in the list
for script in "${SCRIPTS[@]}"; do
  echo "----------------------------------------"
  echo "Running: $script"
  echo "----------------------------------------"
  
  # Execute the current script
  $script
  
  # Check the exit code of the last command ($?)
  # If it is not 0, a failure occurred
  if [ $? -ne 0 ]; then
    echo "❌ ERROR: '$script' failed!"
    echo "Aborting execution."
    exit 1
  fi
done

echo "----------------------------------------"
echo "✅ All scripts completed successfully!"
exit 0

