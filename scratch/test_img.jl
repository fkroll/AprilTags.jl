using AprilTags

# Get a tag image
img = getAprilTagImage(0, AprilTags.tag36h11)
println("Image size: ", size(img))
println("First few rows:")
for r in 1:size(img, 1)
    println(join([Float64(img[r, c]) for c in 1:size(img, 2)], " "))
end
