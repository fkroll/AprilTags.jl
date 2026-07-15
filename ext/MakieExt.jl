module MakieExt

using Makie
using AprilTags: getAprilTagImage, TagFamilies, tag36h11
import AprilTags: generateTagSheet

function generateTagSheet(
    tagIds::Vector{Int}=Int[];
    markerSizeMm::Real=15.0,
    spacingMm::Real=10.0,
    marginMm::Real=15.0,
    outputPath::String="tag_sheet.svg",
    tagFamily::TagFamilies=tag36h11,
    boxSizeMm::Real=0.0
)
    page_w = 210.0
    page_h = 297.0

    block_sz = markerSizeMm / 8.0
    total_sz = 10.0 * block_sz

    print_w = page_w - 2 * marginMm
    print_h = page_h - 2 * marginMm

    cols = floor(Int, (print_w + spacingMm) / (total_sz + spacingMm))
    rows = floor(Int, (print_h + spacingMm) / (total_sz + spacingMm))

    if cols * rows == 0
        error("Marker size ($markerSizeMm mm) is too large for the A4 sheet format.")
    end

    maxMarkers = cols * rows

    if isempty(tagIds)
        tagsToDraw = collect(0:(maxMarkers-1))
    elseif length(tagIds) < maxMarkers
        tagsToDraw = Vector{Int}(undef, maxMarkers)
        for i in 1:maxMarkers
            tagsToDraw[i] = tagIds[mod1(i, length(tagIds))]
        end
    else
        if length(tagIds) > maxMarkers
            @warn "Only $maxMarkers markers out of $(length(tagIds)) will fit on a single A4 sheet."
        end
        tagsToDraw = tagIds[1:maxMarkers]
    end

    grid_w = cols * total_sz + (cols - 1) * spacingMm
    grid_h = rows * total_sz + (rows - 1) * spacingMm
    offset_x = marginMm + (print_w - grid_w) / 2.0
    offset_y = marginMm + (print_h - grid_h) / 2.0

    # Page size in PostScript points (72 pt per inch)
    mm_to_pt = 72.0 / 25.4
    fig = Figure(size = (page_w * mm_to_pt, page_h * mm_to_pt), figure_padding = 0)
    
    ax = Axis(fig[1, 1],
        limits = (0, page_w, 0, page_h),
        yreversed = true,
        backgroundcolor = :white
    )
    hidedecorations!(ax)
    hidespines!(ax)

    for (idx, tagId) in enumerate(tagsToDraw)
        r = (idx - 1) ÷ cols + 1
        c = (idx - 1) % cols + 1

        xStart = offset_x + (c - 1) * (total_sz + spacingMm)
        yStart = offset_y + (r - 1) * (total_sz + spacingMm)

        tagImg = getAprilTagImage(tagId, tagFamily)

        # Transpose tagImg because Makie maps first dimension to X and second to Y.
        # interpolate=false ensures pixel-perfect drawing without interpolation artifacts/thin lines.
        image!(ax, xStart .. xStart + total_sz, yStart .. yStart + total_sz, tagImg', interpolate = false)

        cLen = 8.0
        cWidth = 1.0
        cColor = :black

        # Align crop marks with the outer box if defined, otherwise the tag boundaries
        bx_start = xStart
        by_start = yStart
        b_sz = total_sz
        if boxSizeMm > 0.0
            bx_start = xStart + (total_sz - boxSizeMm) / 2
            by_start = yStart + (total_sz - boxSizeMm) / 2
            b_sz = boxSizeMm
            
            # Draw the outer box
            bx = [bx_start, bx_start + b_sz, bx_start + b_sz, bx_start, bx_start]
            by = [by_start, by_start, by_start + b_sz, by_start + b_sz, by_start]
            lines!(ax, bx, by, color = :black, linewidth = 0.5)
        end

        # Corner tick marks (aligning with bx_start/by_start/b_sz with a 1mm gap, not touching)
        # Top-left corner
        lines!(ax, [bx_start - cLen, bx_start - 1.0], [by_start, by_start], color = cColor, linewidth = cWidth)
        lines!(ax, [bx_start, bx_start], [by_start - cLen, by_start - 1.0], color = cColor, linewidth = cWidth)

        # Top-right corner
        lines!(ax, [bx_start + b_sz + 1.0, bx_start + b_sz + cLen], [by_start, by_start], color = cColor, linewidth = cWidth)
        lines!(ax, [bx_start + b_sz, bx_start + b_sz], [by_start - cLen, by_start - 1.0], color = cColor, linewidth = cWidth)

        # Bottom-left corner
        lines!(ax, [bx_start - cLen, bx_start - 1.0], [by_start + b_sz, by_start + b_sz], color = cColor, linewidth = cWidth)
        lines!(ax, [bx_start, bx_start], [by_start + b_sz + 1.0, by_start + b_sz + cLen], color = cColor, linewidth = cWidth)

        # Bottom-right corner
        lines!(ax, [bx_start + b_sz + 1.0, bx_start + b_sz + cLen], [by_start + b_sz, by_start + b_sz], color = cColor, linewidth = cWidth)
        lines!(ax, [bx_start + b_sz, bx_start + b_sz], [by_start + b_sz + 1.0, by_start + b_sz + cLen], color = cColor, linewidth = cWidth)

        text!(ax,
            xStart + total_sz / 2.0,
            yStart + total_sz + 3.0,
            text = "ID: $tagId",
            fontsize = 12,
            color = :gray,
            align = (:center, :top)
        )
    end

    mkpath(dirname(outputPath))
    ext = lowercase(splitext(outputPath)[2])
    if ext == ".pdf"
        save(outputPath, fig; pt_per_unit = 1.0)
    elseif ext in (".png", ".jpg", ".jpeg", ".bmp", ".tiff")
        save(outputPath, fig; px_per_unit = 600 / 72)
    else
        save(outputPath, fig)
    end
    println("Saved printable A4 sheet with $(length(tagsToDraw)) tags to: $outputPath")
    return fig
end

end # module MakieExt
