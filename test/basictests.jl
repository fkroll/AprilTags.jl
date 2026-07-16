using AprilTags
using ImageCore
using FileIO
using ImageMagick
using ImageDraw
using ColorTypes
using FixedPointNumbers
using Test


@testset "AprilTags" begin
    # To test without extra dependancies
    # image = rand(UInt8, 480,640)
    # image[50:79,50:79]     = kron(reinterpret(UInt8,getAprilTagImage(0)), ones(UInt8, 3,3))
    # image[150:179,150:179] = kron(reinterpret(UInt8,getAprilTagImage(1)), ones(UInt8, 3,3))
    # image[250:279,250:279] = kron(reinterpret(UInt8,getAprilTagImage(2)), ones(UInt8, 3,3))
    # image = Gray.(reinterpret(N0f8, image))
    #
    #
    # imageCol = RGB.(image)
    # refpoints = [[63.9, 63.9],
    #             [163.9, 163.9],
    #             [263.9, 263.9]]

    image = load(dirname(Base.source_path()) *"/../data/tagtest.jpg")
    imageCol = load(dirname(Base.source_path()) *"/../data/colortag.jpg")
    refpoints = [[404.5, 176.1],
                 [134.0, 216.1],
                 [412.0, 130.1]]

    @testset "Low-level API" begin
        # test wrappers
        #create april tag detector
        td = apriltag_detector_create()

        #create tag family
        tf = tag36h11_create()

        #add family to detector
        apriltag_detector_add_family(td, tf)

        #create image8 object for april tags
        image8, imbuf = AprilTags.get_image_u8(image)

        # run detector on image preserving the buffer
        detections = GC.@preserve imbuf apriltag_detector_detect(td, image8)

        # copy detections
        tags = getTagDetections(detections)

        #extract tag centres
        cpoints = map(tag->[tag.c[2],tag.c[1]],tags)
        @test cpoints ≈ refpoints atol=0.5

        # test conversions
        image8_from_u8, imbuf_from_u8 = AprilTags.get_image_u8(reinterpret(UInt8, image)[:,:])
        @test image8_from_u8.width == image8.width
        @test image8_from_u8.height == image8.height
        @test image8_from_u8.stride == image8.stride
        #TODO: maybe add test for content of pointer

        apriltag_detections_destroy(detections)
        # Cleanup: free the detector and tag family when done.
        apriltag_detector_destroy(td)
        tag36h11_destroy(tf)
    end

    @testset "Raw Pointer Interface" begin
        detector = AprilTagDetector()
        
        # Prepare contiguous UInt8 memory for a transposed image to simulate raw camera feed
        img_u8 = reinterpret(UInt8, image)[:,:]
        (rows, cols) = size(img_u8)
        img_u8_contig = collect(img_u8') # contiguous row-major representation in memory
        
        # Test raw pointer detection
        buf_ptr = pointer(img_u8_contig)
        tags_raw = detector(buf_ptr, cols, rows, cols)
        @test length(tags_raw) == 3
        cpoints_raw = map(tag->[tag.c[2],tag.c[1]], tags_raw)
        @test cpoints_raw ≈ refpoints atol=0.5

        # Test threadcall raw pointer detection
        tags_raw_tc = threadcalldetect(detector, buf_ptr, cols, rows, cols)
        @test length(tags_raw_tc) == 3

        # Test detectAndPose raw pointer detection
        tags_pose_raw, poses_raw = detectAndPose(detector, buf_ptr, cols, rows, cols, -520.0, 520.0, 320.0, 240.0, 2.0)
        @test length(tags_pose_raw) == 3
        @test length(poses_raw) == 3

        freeDetector!(detector)
    end

    @testset "High-level API" begin
        # test the high level convenience functions
        detector = AprilTagDetector()
        tags2 = detector(image)

        @test length(detector(gray.(image))) == 3
        @test length(detector(reinterpret(UInt8,image)[:,:])) == 3

        tagsth = AprilTags.threadcalldetect(detector, image)
        @test length(tagsth) == 3

        #test on random image, should detect zero tags
        @test length(detector(rand(Gray{N0f8},100,100))) == 0

        #getters -- compare with default
        @test detector.nThreads == 1
        @test detector.quad_decimate == 2.0 # TODO: default changed to 2 - consider changing back
        @test detector.quad_sigma == 0.0
        @test detector.refine_edges == 1
        @test detector.decode_sharpening == 0.25

        #setters -- set new values
        detector.nThreads = 4
        detector.quad_decimate = 2.0
        detector.quad_sigma = 0.1
        detector.refine_edges = 0
        detector.decode_sharpening = 0.2
        # detector.refine_decode = 1
        # detector.refine_pose = 1

        #getters -- compare with set values just now
        @test detector.nThreads == 4
        @test detector.quad_decimate == 2.0
        @test detector.quad_sigma == 0.1f0
        @test detector.refine_edges == 0
        @test detector.decode_sharpening == 0.2
        # @test detector.refine_decode == 1
        # @test detector.refine_pose == 1

        #test @show overload
        # @test sprint((t,s)->show(t,"text/plain",s), detector) == "AprilTagDetector\nnThreads: 4\nquad_decimate: 1.0\nquad_sigma: 0.0\nrefine_edges: 1\nrefine_decode: 1\nrefine_pose: 1\n"
        @test sprint((t,s)->show(t,"text/plain",s), detector) == "AprilTagDetector\nnThreads: 4\nquad_decimate: 2.0\nquad_sigma: 0.1\nrefine_edges: 0\ndecode_sharpening: 0.2\n"

        cpoints = map(tag->[tag.c[2],tag.c[1]],tags2)
        freeDetector!(detector)
        @test cpoints ≈ refpoints atol=0.5


        pose = homography_to_pose(tags2[1].H, -520., 520., 320., 240.)
        # TODO create better ref pose
        refpose = [ 0.630694   0.130624  -0.764959  -5.43;
                    0.373828  -0.914963   0.151975  -6.20;
                   -0.680057  -0.381812  -0.625892 -19.62;
                    0.0        0.0        0.0        1.0]
        @test pose.linear ≈ refpose[1:3,1:3] atol = 0.05
        @test pose.translation ≈ refpose[1:3,4] atol = 0.1

        #test drawing functions
        fx = 524.040
        fy = 524.040
        cx = 319.254
        cy = 251.227
        K = [fx 0  cx;
              0 fy cy]
        imCol = RGB.(image)
        foreach(tag->drawTagBox!(imCol, tag), tags2)
        # test one pixel to be correctly drawn
        t1xy = round.(Int,tags2[1].p[1])
        @test imCol[t1xy[2],t1xy[1]] == RGB{N0f8}(0.0, 1.0, 0.0)
        #thicker lines also
        foreach(tag->drawTagBox!(imCol,tag, width = 2, drawReticle = false), tags2)
        foreach(tag->drawTagBox!(imCol,tag, width = 3, drawReticle = true), tags2)
        #TODO: verify that drawing is correct

        # test for bounds error in drawing functions with thicker lines
        foreach(tag->drawTagBox!(imCol,tag, width = 1000, drawReticle = true), tags2)

        foreach(tag->drawTagAxes!(imCol,tag, K), tags2)
        #TODO: verify that drawing tag axis is correct

        # test constructors for other families
        detector2 = AprilTagDetector(AprilTags.tag25h9)
        freeDetector!(detector2)

        detector2 = AprilTagDetector(AprilTags.tag16h5)
        freeDetector!(detector2)

        detector2 = AprilTagDetector(AprilTags.tag36h11)
        freeDetector!(detector2)

        detector2 = AprilTagDetector(AprilTags.tagStandard41h12)
        freeDetector!(detector2)

        # detector2 = AprilTagDetector(AprilTags.tagStandard52h13)
        # freeDetector!(detector2)

        # detector2 = AprilTagDetector(AprilTags.tag36h10)
        # freeDetector!(detector2)

        reftag36h11_0 = Gray{N0f8}[ 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0;
                                    1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0;
                                    1.0 0.0 1.0 1.0 0.0 1.0 0.0 1.0 0.0 1.0;
                                    1.0 0.0 0.0 1.0 1.0 1.0 0.0 1.0 0.0 1.0;
                                    1.0 0.0 0.0 1.0 1.0 0.0 0.0 0.0 0.0 1.0;
                                    1.0 0.0 1.0 0.0 1.0 0.0 0.0 0.0 0.0 1.0;
                                    1.0 0.0 0.0 1.0 0.0 1.0 1.0 0.0 0.0 1.0;
                                    1.0 0.0 0.0 0.0 0.0 1.0 0.0 0.0 0.0 1.0;
                                    1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0;
                                    1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0]
        @test reftag36h11_0 == getAprilTagImage(0)

        # reftag36h10_0 = Gray{N0f8}[ 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0;
        #                             1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0;
        #                             1.0 0.0 0.0 0.0 0.0 1.0 1.0 1.0 0.0 1.0;
        #                             1.0 0.0 0.0 0.0 1.0 0.0 1.0 0.0 0.0 1.0;
        #                             1.0 0.0 1.0 0.0 0.0 1.0 0.0 0.0 0.0 1.0;
        #                             1.0 0.0 1.0 0.0 1.0 0.0 1.0 0.0 0.0 1.0;
        #                             1.0 0.0 0.0 1.0 1.0 0.0 1.0 0.0 0.0 1.0;
        #                             1.0 0.0 0.0 0.0 0.0 1.0 1.0 1.0 0.0 1.0;
        #                             1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0;
        #                             1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0]
        # @test reftag36h10_0 == getAprilTagImage(0, AprilTags.tag36h10)

        reftag16h5_0 = Gray{N0f8}[  1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0;
                                    1.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0;
                                    1.0 0.0 0.0 0.0 1.0 0.0 0.0 1.0;
                                    1.0 0.0 0.0 0.0 1.0 1.0 0.0 1.0;
                                    1.0 0.0 0.0 0.0 0.0 1.0 0.0 1.0;
                                    1.0 0.0 1.0 0.0 1.0 1.0 0.0 1.0;
                                    1.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0;
                                    1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0]
        @test reftag16h5_0 == getAprilTagImage(0, AprilTags.tag16h5)

        reftag25h9_0 = Gray{N0f8}[  1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0;
                                    1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0;
                                    1.0 0.0 1.0 0.0 1.0 0.0 1.0 0.0 1.0;
                                    1.0 0.0 0.0 1.0 0.0 1.0 1.0 0.0 1.0;
                                    1.0 0.0 1.0 0.0 0.0 1.0 0.0 0.0 1.0;
                                    1.0 0.0 1.0 1.0 1.0 1.0 1.0 0.0 1.0;
                                    1.0 0.0 1.0 0.0 0.0 0.0 1.0 0.0 1.0;
                                    1.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 1.0;
                                    1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0 1.0]
        @test reftag25h9_0 == getAprilTagImage(0, AprilTags.tag25h9)

        reftagStandard41h12_0 = Gray{N0f8}[1.0 1.0 0.0 1.0 1.0 1.0 1.0 0.0 0.0;
                                           0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0;
                                           1.0 0.0 1.0 1.0 1.0 1.0 1.0 0.0 0.0;
                                           0.0 0.0 1.0 1.0 1.0 1.0 1.0 0.0 1.0;
                                           0.0 0.0 1.0 0.0 0.0 1.0 1.0 0.0 0.0;
                                           0.0 0.0 1.0 0.0 1.0 0.0 1.0 0.0 1.0;
                                           1.0 0.0 1.0 1.0 1.0 1.0 1.0 0.0 0.0;
                                           0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0 0.0;
                                           1.0 1.0 0.0 1.0 0.0 0.0 1.0 0.0 0.0]
        @test reftagStandard41h12_0 == getAprilTagImage(0, AprilTags.tagStandard41h12, blackborder=false)

        # TODO test, just placeholder for now
        detector = AprilTagDetector()
        detector.quad_decimate = 1.0 #NOTE see line 84
        fx = 524.040
        fy = 524.040
        cx = 319.254
        cy = 251.227
        taglength = 0.172
        (tags, poses) = detectAndPose(detector, image, fx, fy, cx, cy, taglength)
        # TODO test here, this is just result used as test.
        ref_R = [ 0.627703   0.120213  -0.769115;
                 -0.388707   0.904419  -0.175877;
                  0.674460   0.409359   0.614434]
        ref_t = [-0.461887,  0.494238,  1.69053]
        @test poses[1].linear ≈ ref_R atol = 0.01
        @test poses[1].translation ≈ ref_t atol = 0.01
        freeDetector!(detector)

    end

    include("homography.jl")

    @testset "Errors" begin
        #testing freed detectors errors
        detector = AprilTagDetector()
        freeDetector!(detector)
        @test_throws ErrorException tags = detector(image)
        @test_throws ErrorException tags = AprilTags.threadcalldetect(detector, image)
        @test_throws ErrorException AprilTags.setnThreads(detector, 4)
        @test_throws ErrorException AprilTags.setquad_decimate(detector, 1.0)
        @test_throws ErrorException AprilTags.setquad_sigma(detector,0.0)
        @test_throws ErrorException AprilTags.setrefine_edges(detector,1)
        @test_throws ErrorException AprilTags.setdecode_sharpening(detector,0.2)
        # @test_throws ErrorException AprilTags.setrefine_decode(detector,1)
        # @test_throws ErrorException AprilTags.setrefine_pose(detector,1)

        @test_throws ErrorException AprilTags.getnThreads(detector)
        @test_throws ErrorException AprilTags.getquad_decimate(detector)
        @test_throws ErrorException AprilTags.getquad_sigma(detector)
        @test_throws ErrorException AprilTags.getrefine_edges(detector)
        @test_throws ErrorException AprilTags.getdecode_sharpening(detector)
        # @test_throws ErrorException AprilTags.getrefine_decode(detector)
        # @test_throws ErrorException AprilTags.getrefine_pose(detector)

        @test freeDetector!(detector) == nothing
        #testing NULL tag families errors
        detector = AprilTagDetector()
        detector.tf = C_NULL
        @test_throws ErrorException tags = detector(image)
        @test_throws ErrorException tags = AprilTags.threadcalldetect(detector, image)
        @test freeDetector!(detector) == nothing
    end

    @testset "Color Image Conversion" begin
        detector = AprilTagDetector()
        detector.quad_decimate = 1.0 #NOTE see line 84
        tags = detector(imageCol)
        @test length(tags) == 1
        freeDetector!(detector)
    end

    @testset "Generator stub error" begin
        @test_throws ErrorException generateTagSheet(Int[])
    end

    @testset "Generator implementation" begin
        using CairoMakie, Makie
        output_temp = joinpath(dirname(Base.source_path()), "../scratch/test_sheet.svg")
        plt1 = generateTagSheet(Int[]; outputPath=output_temp)
        @test isfile(output_temp)
        @test plt1 isa Makie.Figure
        rm(output_temp, force=true)
        
        plt2 = generateTagSheet([1, 2, 3]; outputPath=output_temp)
        @test isfile(output_temp)
        rm(output_temp, force=true)

        plt3 = generateTagSheet([1, 2, 3]; outputPath=output_temp, boxSizeMm=20.0)
        @test isfile(output_temp)
        @test plt3 isa Makie.Figure
        rm(output_temp, force=true)
    end
end
