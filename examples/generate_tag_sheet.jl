using AprilTags
using Plots

# Note: generateTagSheet is only loaded and available after 'using Plots'
# because it is implemented as a package extension.

println("Generating an A4 sheet of AprilTags...")

# Define the output path in the examples folder (within the workspace)
output_path = joinpath(@__DIR__, "printable_sheet.svg")

# Call the generator function.
# Passing an empty array (Int[]) automatically fills the entire A4 page with sequential tags starting from 0.
plt = generateTagSheet(Int[]; outputPath=output_path)

println("A4 AprilTag sheet generated successfully!")
println("Saved to: $output_path")
