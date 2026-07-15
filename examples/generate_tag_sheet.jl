using AprilTags
using CairoMakie


println("Generating an A4 sheet of AprilTags...")

output_path = joinpath(@__DIR__, "tag_sheet.pdf")

generateTagSheet(Int[]; outputPath=output_path)


println("A4 AprilTag sheet generated successfully!")
println("Saved to: $output_path")
