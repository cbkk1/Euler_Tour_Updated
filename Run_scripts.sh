#!/bin/bash

# Output file to save results
output_file="a_out_results.txt"
> "$output_file" # Clear the file if it exists

# Iterate var1 over powers of 2 from 1 to 67108864
for ((var1=1; var1<=67108864; var1*=2)); do
  # Generate a random var2 less than var1
  var2=$((RANDOM % var1))
  
  echo "Running ./a.out with vertices = $var1 and root vertex = $var2..." >> "$output_file"
  
  # Execute ./a.out with var1 and var2, and append outputs to the file
  echo -e "$var1\n$var2" | ./a.out >> "$output_file"
  
  # Add a separator for better readability
  echo "---------------------------------------" >> "$output_file"
done

echo "Execution complete. Results saved to $output_file."
