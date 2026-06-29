"""
    drawTagBox!(image, tag)

Draw a box around the tag.
`imageCol = RGB.(image)
foreach(tag->drawTagBox!(imageCol, tag), tags)
`
"""
function drawTagBox!(image::AbstractMatrix{T}, tag::AprilTag; width::Int = 1, drawReticle::Bool = true) where T <: RGB
    cpoints = map(tag -> Point(round.(Int,tag)...),tag.p)
    # Reticle
    if drawReticle
        midx = (cpoints[3].x + cpoints[1].x) / 2
        midy = (cpoints[3].y + cpoints[1].y) / 2
        x1 = Point(round(midx - (cpoints[2].x - cpoints[1].x) / 4), round(midy - (cpoints[2].y - cpoints[1].y) / 4))
        x2 = Point(round(midx + (cpoints[2].x - cpoints[1].x) / 4), round(midy + (cpoints[2].y - cpoints[1].y) / 4))
        y1 = Point(round(midx - (cpoints[4].x - cpoints[1].x) / 4), round(midy - (cpoints[4].y - cpoints[1].y) / 4))
        y2 = Point(round(midx + (cpoints[4].x - cpoints[1].x) / 4), round(midy + (cpoints[4].y - cpoints[1].y) / 4))
        draw!(image, LineSegment( x1, x2), RGB{N0f8}(1.0, 0.0, 0.0), boundedBresenham)
        draw!(image, LineSegment( y1, y2), RGB{N0f8}(1.0, 0.0, 0.0), boundedBresenham)
    end
    # Make a box around the tag
    if width <= 1
        draw!(image, LineSegment( cpoints[1], cpoints[2]), RGB{N0f8}(0.0, 0.0, 1.0), boundedBresenham)
        draw!(image, LineSegment( cpoints[2], cpoints[3]), RGB{N0f8}(0.0, 0.0, 1.0), boundedBresenham)
        draw!(image, LineSegment( cpoints[3], cpoints[4]), RGB{N0f8}(1.0, 0.0, 0.0), boundedBresenham)
        draw!(image, LineSegment( cpoints[4], cpoints[1]), RGB{N0f8}(0.0, 1.0, 0.0), boundedBresenham)
    else
        drawThickLine!(image, cpoints[1], cpoints[2], RGB{N0f8}(0.0, 0.0, 1.0), width)
        drawThickLine!(image, cpoints[2], cpoints[3], RGB{N0f8}(0.0, 0.0, 1.0), width)
        drawThickLine!(image, cpoints[3], cpoints[4], RGB{N0f8}(1.0, 0.0, 0.0), width)
        drawThickLine!(image, cpoints[4], cpoints[1], RGB{N0f8}(0.0, 1.0, 0.0), width)
    end

    return nothing
end

function boundedBresenham(img::AbstractArray{T, 2}, y0::Int, x0::Int, y1::Int, x1::Int, color::T) where T<:Colorant
    dx = abs(x1 - x0)
    dy = abs(y1 - y0)

    sx = x0 < x1 ? 1 : -1
    sy = y0 < y1 ? 1 : -1;

    err = (dx > dy ? dx : -dy) / 2

    (row,col) = size(img)
    while true
        if 1 <= x0 <= col && 1 <= y0 <= row
            img[y0, x0] = color
        end
        (x0 != x1 || y0 != y1) || break
        e2 = err
        if e2 > -dx
            err -= dy
            x0 += sx
        end
        if e2 < dy
            err += dx
            y0 += sy
        end
    end

    img
end

function drawThickLine!(image, startpoint, endpoint, colour, thickness)
    (row, col) = size(image)
    x1 = startpoint.x
    y1 = startpoint.y
    x2 = endpoint.x
    y2 = endpoint.y


    draw!(image, LineSegment(x1,y1,x2,y2), colour, boundedBresenham)

    if x1 != x2 && abs((y2-y1)/(x2-x1)) < 1
        for tn = 1:thickness
            i = tn ÷ 2
            iseven(tn) && draw!(image, LineSegment(x1,y1-i,x2,y2-i), colour, boundedBresenham)
            isodd(tn)  && draw!(image, LineSegment(x1,y1+i,x2,y2+i), colour, boundedBresenham)
        end
    else
        for tn = 1:thickness
            i = tn ÷ 2
            iseven(tn) && draw!(image, LineSegment(x1-i,y1,x2-i,y2), colour, boundedBresenham)
            isodd(tn)  && draw!(image, LineSegment(x1+i,y1,x2+i,y2), colour, boundedBresenham)
        end
    end
end

"""
    drawTagAxes!(image, tag, CameraMatrix)

Draw the tag x, y, and z axes to show the orientation.
`imageCol = RGB.(image)
foreach(tag->drawTagAxes!(imageCol, tag, K), tags)
`
"""
function drawTagAxes!(image::AbstractMatrix{<:AbstractRGB}, 
                      tag::AprilTag, 
                      K::AbstractMatrix{<:Real} )
    #
    fx = K[1, 1]
    fy = K[2, 2]
    cx = K[1, 3]
    cy = K[2, 3]
    pose = AprilTags.homographytopose(tag.H, fx, fy, cx, cy)

    # project a 3D point in tag frame to 2D image coordinates
    function project(pt3d::SVector{3,Float64})
        p_cam = pose(pt3d)
        return SVector{2,Float64}(
            fx * p_cam[1] / p_cam[3] + cx,
            fy * p_cam[2] / p_cam[3] + cy
        )
    end

    p0 = project(SVector{3,Float64}(0.0, 0.0, 0.0))
    p1 = project(SVector{3,Float64}(1.0, 0.0, 0.0))
    p2 = project(SVector{3,Float64}(0.0, 1.0, 0.0))
    p3 = project(SVector{3,Float64}(0.0, 0.0, 1.0))

    ip0 = Point(round.(Int,p0)...)
    ip1 = Point(round.(Int,p1)...)
    ip2 = Point(round.(Int,p2)...)
    ip3 = Point(round.(Int,p3)...)
    #TODO check that the line stays on the image to avoid bounds errors
    draw!(image, LineSegment(ip0, ip1), RGB{N0f8}(1.0, 0.0, 0.0), boundedBresenham)
    draw!(image, LineSegment(ip0, ip2), RGB{N0f8}(0.0, 1.0, 0.0), boundedBresenham)
    draw!(image, LineSegment(ip0, ip3), RGB{N0f8}(0.0, 0.0, 1.0), boundedBresenham)
    image
end

"""
    $SIGNATURES

Draw a cross on the image at a specified location.
"""
function _drawCrossOnImg!(  cimg_::AbstractMatrix{<:AbstractRGB}, 
                            location::Tuple{Int,Int},
                            len::Real=50, 
                            color::AbstractRGB=RGB{N0f8}(1,0,0))
    #
    draw!(cimg_, Cross(Point(location...), len), color)  
end

