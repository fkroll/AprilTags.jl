using AprilTags
using Images
using BenchmarkTools
using Printf

function create_benchmark_image(height=400, width=2472; num_tags=8, tag_scale=6)
    # Create a background of moderate gray
    img = fill(Gray{N0f8}(0.5), height, width)
    
    # We will place tags horizontally spaced
    # Tag family: tag36h11 has a 10x10 grid (including border)
    # tag_scale scales it up (e.g. 6x6 -> 60x60 pixels)
    tag_size = 10 * tag_scale
    
    margin_y = (height - tag_size) ÷ 2
    x_spacing = width ÷ (num_tags + 1)
    
    for i in 1:num_tags
        tag_id = i - 1
        tag_img = getAprilTagImage(tag_id) # 10x10 Gray{N0f8}
        scaled_tag = kron(tag_img, ones(tag_scale, tag_scale))
        
        center_x = i * x_spacing
        start_x = center_x - tag_size ÷ 2
        start_y = margin_y
        
        img[start_y:(start_y + tag_size - 1), start_x:(start_x + tag_size - 1)] .= scaled_tag
    end
    return img
end

function run_benchmarks()
    println("Generating 2472x400 image with 8 AprilTags...")
    img = create_benchmark_image()
    
    # Warm up to compile functions
    println("Warming up JIT compiler...")
    detector = AprilTagDetector()
    _ = detector(img)
    _ = threadcalldetect(detector, img)
    freeDetector!(detector)
    
    println("\n### Benchmark 1: Thread Scaling (quad_decimate = 2.0)")
    println("| Threads | Time (ms) | Speed (FPS) | Tags Detected |")
    println("|:-------:|:---------:|:-----------:|:-------------:|")
    
    for threads in [1, 2, 4, 8]
        detector = AprilTagDetector()
        detector.nThreads = threads
        detector.quad_decimate = 2.0
        
        # Benchmark
        t = @belapsed ($detector)($img) samples=30 seconds=2
        t_ms = t * 1000.0
        fps = 1.0 / t
        tags = detector(img)
        
        @printf("| %7d | %9.2f | %11.1f | %13d |\n", threads, t_ms, fps, length(tags))
        freeDetector!(detector)
    end
    
    println("\n### Benchmark 2: Decimation Scaling (nThreads = 4)")
    println("| Decimate | Time (ms) | Speed (FPS) | Tags Detected | Note |")
    println("|:--------:|:---------:|:-----------:|:-------------:|:----|")
    
    for decimate in [1.0, 1.5, 2.0, 3.0, 4.0]
        detector = AprilTagDetector()
        detector.nThreads = 4
        detector.quad_decimate = decimate
        
        t = @belapsed ($detector)($img) samples=30 seconds=2
        t_ms = t * 1000.0
        fps = 1.0 / t
        tags = detector(img)
        
        note = if length(tags) < 8
            "Missed $(8 - length(tags)) tags due to heavy decimation"
        else
            "All tags detected"
        end
        
        @printf("| %8.1f | %9.2f | %11.1f | %13d | %s |\n", decimate, t_ms, fps, length(tags), note)
        freeDetector!(detector)
    end

    println("\n### Benchmark 3: Standard call vs Threadcall (nThreads = 4, quad_decimate = 2.0)")
    println("| Call Type | Time (ms) | Speed (FPS) |")
    println("|:---------:|:---------:|:-----------:|")
    
    # Standard Call
    detector = AprilTagDetector()
    detector.nThreads = 4
    detector.quad_decimate = 2.0
    t_std = @belapsed ($detector)($img) samples=30 seconds=2
    @printf("| Standard  | %9.2f | %11.1f |\n", t_std * 1000.0, 1.0 / t_std)
    
    # Threadcall
    t_tc = @belapsed threadcalldetect($detector, $img) samples=30 seconds=2
    @printf("| Threadcall| %9.2f | %11.1f |\n", t_tc * 1000.0, 1.0 / t_tc)
    freeDetector!(detector)
end

run_benchmarks()
