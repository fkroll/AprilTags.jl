using AprilTags
using FileIO
using ImageCore


img = load("../data/crop.png")
detector = AprilTagDetector()
println("Detecting on crop.png...")
try
    tags = detector(img)
    println("Found ", length(tags), " tag(s):")
    for (idx, tag) in enumerate(tags)
        println("  [$idx] ID: ", tag.id, ", Center: ", tag.c)
    end
catch e
    println("Failed: ", e)
end
freeDetector!(detector)
