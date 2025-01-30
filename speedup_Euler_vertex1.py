import matplotlib.pyplot as plt

# File to read the data from
file_path = "a_out_results1.txt"

# Lists to store the number of vertices and execution times
vertices = []
serial_times = []
parallel_times = []

# Read and process the file
with open(file_path, "r") as file:
    current_vertices = None
    current_serial_time = None
    current_parallel_time = None

    for line in file:
        # Extract number of vertices
        if "Running ./a.out with vertices" in line:
            parts = line.split("vertices = ")[1].split(" and root vertex")
            current_vertices = int(parts[0].strip())
        
        # Extract Serial Execution Time
        elif "Serial Execution Time:" in line and "ns" in line:
            current_serial_time = int(line.split("Serial Execution Time:")[1].split("ns")[0].strip())
        
        # Extract Parallel Execution Time
        elif "Parallel Execution Time:" in line and "ns" in line:
            current_parallel_time = int(line.split("Parallel Execution Time:")[1].split("ns")[0].strip())
        
        # If all values for the current entry are collected, append them to the lists
        if current_vertices is not None and current_serial_time is not None and current_parallel_time is not None:
            vertices.append(current_vertices)
            serial_times.append(current_serial_time)
            parallel_times.append(current_parallel_time)

            # Reset current values for the next entry
            current_vertices = None
            current_serial_time = None
            current_parallel_time = None

# Debug: Print the data to verify parsing
print("Vertices:", vertices)
print("Serial Times:", serial_times)
print("Parallel Times:", parallel_times)

# Check for data consistency
if len(vertices) != len(serial_times) or len(vertices) != len(parallel_times):
    print("Error: Data length mismatch. Ensure the file is correctly formatted.")
    exit()

# Calculate speedup (skip entries where parallel time is 0 to avoid division by zero)
speedup = [s / p if p > 0 else 0 for s, p in zip(serial_times, parallel_times)]

# Plotting the graph
plt.figure(figsize=(10, 6))
plt.plot(vertices, speedup, marker="o", label="Speedup", color="blue")

# Customizing the plot
plt.title("Speedup vs Number of Vertices")
plt.xlabel("Number of Vertices")
plt.ylabel("Speedup (Serial Time / Parallel Time)")
plt.xscale("log", base=2)  # Logarithmic scale for X-axis (powers of 2)
plt.grid(True, which="both", linestyle="--", linewidth=0.5)
plt.legend()
plt.tight_layout()

# Save and display the plot
plt.savefig("speedup_plot.png")
plt.show()
