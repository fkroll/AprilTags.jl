using AprilTags
using CairoMakie


println("Generating an A4 sheet of AprilTags...")

output_path = joinpath(@__DIR__, "tag_sheet.pdf")

generateTagSheet(Int[]; outputPath=output_path, boxSizeMm=20.0, spacingMm=20.0, marginMm = 20.0)


println("A4 AprilTag sheet generated successfully!")
println("Saved to: $output_path")
