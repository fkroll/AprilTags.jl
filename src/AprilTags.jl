module AprilTags

using AprilTags_jll
using Preferences
using Requires
using DocStringExtensions
using LinearAlgebra, Statistics
using Colors, ImageDraw, FixedPointNumbers
using StaticArrays, FixedSizeArrays, CoordinateTransformations
import Base.convert

const TagPose{T} = AffineMap{SMatrix{3,3,T,9}, SVector{3,T}}


# Resolve the libapriltag library path.
# On platforms where AprilTags_jll has no pre-built binary (e.g. aarch64-apple-darwin /
# Apple Silicon), fall back to a path supplied via LocalPreferences.toml.
# To set a local path, run:
#   using Preferences
#   set_preferences!("AprilTags_jll", "libapriltag_path" => "/path/to/libapriltag.dylib"; force=true)
const libapriltag = if AprilTags_jll.is_available()
    AprilTags_jll.libapriltag
else
    let pref = @load_preference("libapriltag_path", nothing)
        if pref !== nothing
            pref
        else
            # Last-resort: let the OS dynamic linker find it
            "libapriltag"
        end
    end
end

export
#helpers
AprilTag,
AprilTagDetector,
TagPose,
freeDetector!,
getTagDetections,
homography_to_pose,
homographytopose,
threadcalldetect,
getAprilTagImage,
detectAndPose,
tagOrthogonalIteration,
# wrappers
apriltag_detector_create,
tag36h11_create,
tag36h11_destroy,

apriltag_detector_add_family,
apriltag_detector_detect,
apriltag_detections_destroy,
apriltag_detector_destroy,
threadcall_apriltag_detector_detect,
matd_destroy,

#drawing and plotting
drawTagBox!,
drawTagAxes!,
generateTagSheet

include("wrapper.jl")
include("helpers.jl")
include("tagdraw.jl")
include("additionalutils.jl")
include("calibrationutils.jl")

function generateTagSheet(args...; kwargs...)
    error("generateTagSheet is not loaded. Please run `using Makie` to load this functionality.")
end

function __init__()
    # conditional requirement
    @require FreeTypeAbstraction="663a7486-cb36-511b-a19d-713bb74d65c9" include("tagtext.jl")
end

end # module
