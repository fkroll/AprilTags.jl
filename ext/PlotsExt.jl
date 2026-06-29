module PlotsExt

using Plots
using AprilTags: getAprilTagImage, TagFamilies, tag36h11
import AprilTags: generateTagSheet

function generateTagSheet(
    tagIds::Vector{Int}=Int[];
    markerSizeMm::Real=15.0,
    spacingMm::Real=10.0,
    marginMm::Real=15.0,
    outputFormat::Symbol=:SVG,
    outputPath::String="printable_sheet.svg",
    tagFamily::TagFamilies=tag36h11
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

    dpi = 300
    px_w = round(Int, (page_w / 25.4) * dpi)
    px_h = round(Int, (page_h / 25.4) * dpi)

    gr()

    plt = plot(
        xlim=(0, page_w),
        ylim=(0, page_h),
        size=(px_w, px_h),
        dpi=dpi,
        border=:none,
        ticks=false,
        legend=false,
        aspect_ratio=:equal,
        background_color=:white,
        yflip=true
    )

    for (idx, tagId) in enumerate(tagsToDraw)
        r = (idx - 1) ÷ cols + 1
        c = (idx - 1) % cols + 1

        xStart = offset_x + (c - 1) * (total_sz + spacingMm)
        yStart = offset_y + (r - 1) * (total_sz + spacingMm)

        tagImg = getAprilTagImage(tagId, tagFamily)

        for tr in 1:10
            for tc in 1:10
                if Float64(tagImg[tr, tc]) == 0.0
                    px = xStart + (tc - 1) * block_sz
                    py = yStart + (tr - 1) * block_sz
                    plot!(
                        [px, px + block_sz, px + block_sz, px, px],
                        [py, py, py + block_sz, py + block_sz, py],
                        seriestype=:shape,
                        fillcolor=:black,
                        linecolor=:transparent,
                        linewidth=0,
                        fillalpha=1.0
                    )
                end
            end
        end

        cLen = 8.0
        cWidth = 1.0
        cColor = :gray

        plot!([xStart - cLen, xStart - 1.0], [yStart, yStart], linecolor=cColor, linewidth=cWidth)
        plot!([xStart, xStart], [yStart - cLen, yStart - 1.0], linecolor=cColor, linewidth=cWidth)

        plot!([xStart + total_sz + 1.0, xStart + total_sz + cLen], [yStart, yStart], linecolor=cColor, linewidth=cWidth)
        plot!([xStart + total_sz, xStart + total_sz], [yStart - cLen, yStart - 1.0], linecolor=cColor, linewidth=cWidth)

        plot!([xStart - cLen, xStart - 1.0], [yStart + total_sz, yStart + total_sz], linecolor=cColor, linewidth=cWidth)
        plot!([xStart, xStart], [yStart + total_sz + 1.0, yStart + total_sz + cLen], linecolor=cColor, linewidth=cWidth)

        plot!([xStart + total_sz + 1.0, xStart + total_sz + cLen], [yStart + total_sz, yStart + total_sz], linecolor=cColor, linewidth=cWidth)
        plot!([xStart + total_sz, xStart + total_sz], [yStart + total_sz + 1.0, yStart + total_sz + cLen], linecolor=cColor, linewidth=cWidth)

        annotate!(
            xStart + total_sz / 2.0,
            yStart + total_sz + 3.0,
            text("ID: $tagId", 16, :gray, :center, :sans)
        )
    end

    mkpath(dirname(outputPath))
    savefig(plt, outputPath)
    println("Saved printable A4 sheet with $(length(tagsToDraw)) tags to: $outputPath")
    return plt
end

end # module PlotsExt
