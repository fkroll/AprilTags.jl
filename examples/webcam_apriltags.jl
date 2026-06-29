### A Pluto.jl notebook ###
# v1.0.1

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    #! format: off
    return quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
    #! format: on
end

# ╔═╡ c3bc88a5-d85c-43bb-a53c-2ee7a0d4c82b
begin
    import Pkg
    Pkg.activate(@__DIR__)
    using AprilTags
    using PlutoUI
    using Images
    using Optim
    using Colors
    using HypertextLiteral
    using LinearAlgebra
    using ADTypes
    using ForwardDiff
end

# ╔═╡ b4d420f1-4db8-4034-8c85-e23f03b8cc15
md"""
# AprilTags.jl Interactive Webcam Detection and Calibration

Welcome to the interactive AprilTags notebook! This notebook allows you to:
1. Capture real-time images from your webcam.
2. Detect AprilTags (specifically from the standard `tag36h11` family) in the captured image.
3. Superimpose bounding boxes and 3D coordinate axes onto the detected tags.
4. Perform camera parameter calibration using a standard 5x8 grid.
"""

# ╔═╡ c7991b1a-8bb7-4b5f-a3d8-e32517ab6f67
md"""
### 1. Camera Parameters

Configure the camera intrinsic matrix $K = \begin{bmatrix} f_x & 0 & c_x \\ 0 & f_y & c_y \end{bmatrix}$ parameters below. 
These values are used to estimate the 3D poses and draw the coordinate axes of the detected tags.
"""

# ╔═╡ a550604f-124b-489e-b9ab-ec5d1136b69b
md"Focal Length X (fx): $(@bind fx PlutoUI.NumberField(1.0:2000.0, 1000.0))"

# ╔═╡ b2d6bfd8-1c4b-419b-ab01-44754519965a
md"Focal Length Y (fy): $(@bind fy PlutoUI.NumberField(1.0:2000.0, 1000.0))"

# ╔═╡ e7c39054-9457-418f-a9cb-f1190cf613c7
md"Center X (cx): $(@bind cx PlutoUI.NumberField(1.0:2000.0, 640.0))"

# ╔═╡ d3cb4bb9-7a54-4f2b-8a8b-c98e27c1ab02
md"Center Y (cy): $(@bind cy PlutoUI.NumberField(1.0:2000.0, 360.0))"

# ╔═╡ cf220bb6-ea54-478f-a0e2-e19efc21ac1f
md"""
### 2. Webcam Input

Click the camera icon below to start the webcam, position an AprilTag in the camera's view, and capture a photo.
"""

# ╔═╡ b1c89012-7bb8-4f81-a3f2-1abcefb15498
@bind img WebcamInput(help=false)

# ╔═╡ a6a908a8-b673-455b-b9ab-b19dfb1ab728
let
    # Process the captured image and detect tags
    if img === nothing || (size(img, 1) == 1 && size(img, 2) == 1)
        md"📷 **No image captured yet.** Click the camera icon on the widget above to capture a frame."
    else
        # Copy the image so we can draw on it
        annotated_img = copy(img)
        
        # Initialize detector
        detector = AprilTagDetector()
        try
            # Run tag detection
            tags = detector(annotated_img)
            
            # Format the camera matrix K
            K = Float64[fx 0.0 cx; 0.0 fy cy]
            
            # Draw annotation boxes and axes
            for tag in tags
                drawTagBox!(annotated_img, tag, width=3, drawReticle=true)
                try
                    drawTagAxes!(annotated_img, tag, K)
                catch err
                    # Ignore drawing axes errors (e.g. if K is singular or invalid)
                end
            end
            
            # Render output
            if isempty(tags)
                @htl("""
                <div style="display: flex; flex-direction: row; align-items: flex-start; gap: 20px;">
                    <div>$(annotated_img)</div>
                    <div style="font-family: sans-serif; padding-top: 10px;">ℹ️ **No AprilTags detected in this frame.**</div>
                </div>
                """)
            else
                tag_rows = map(tags) do t
                    "| $(t.id) | $(t.family) | $(round.(t.c, digits=1)) |"
                end
                
                info_table = Markdown.parse(join([
                    "### Detections",
                    "Found $(length(tags)) tag(s):",
                    "",
                    "| ID | Family | Center (x, y) |",
                    "|---|---|---|",
                    tag_rows...
                ], "\n"))
                
                @htl("""
                <div style="display: flex; flex-direction: row; align-items: flex-start; gap: 20px;">
                    <div>$(annotated_img)</div>
                    <div style="font-family: sans-serif;">$(info_table)</div>
                </div>
                """)
            end
        finally
            freeDetector!(detector)
        end

        annotated_img
    end
end

# ╔═╡ e1229a1b-4db3-448f-8898-8c105ab1c1b1
md"""
### 3. Camera Calibration

To calibrate your camera parameters, configure the calibration grid dimensions and physical tag size below, and point your webcam at the grid.

Ensure that:
1. The camera is parallel to the grid.
2. **All tags** in the configured grid are fully visible and detected in the frame.

You can view/print the calibration grid below, or display it on another screen. As you adjust the parameters below, the grid will automatically update!
"""

# ╔═╡ f4229a1b-4db3-448f-8898-8c105ab1c1b4
md"Calibration Tag Size (mm): $(@bind calib_tag_length_mm PlutoUI.NumberField(5.0:250.0, 15.0))"

# ╔═╡ f4229a1b-4db3-448f-8898-8c105ab1c1b5
md"Grid Rows (VERT): $(@bind calib_vert PlutoUI.NumberField(2:15, 6))"

# ╔═╡ f4229a1b-4db3-448f-8898-8c105ab1c1b6
md"Grid Columns (HORI): $(@bind calib_hori PlutoUI.NumberField(2:15, 9))"

# ╔═╡ f4229a1b-4db3-448f-8898-8c105ab1c1b7
md"Grid Starting Tag ID: $(@bind calib_start_id PlutoUI.NumberField(0:200, 0))"

# ╔═╡ df9087c5-5555-4034-8c85-e23f03b8cc15
@bind run_calib PlutoUI.Button("Calibrate Camera Parameters")

# ╔═╡ bd6a22f6-34a8-4bb8-88b9-8c105ab1c1b2
calibration_output = let
    run_calib
    
    if img === nothing || (size(img, 1) == 1 && size(img, 2) == 1)
        HTML("<span style='color: gray;'>Capture a frame containing the calibration grid first.</span>")
    else
        detector = AprilTagDetector()
        try
            tags_detected = detector(img)
            
            # Construct expected tag IDs range based on UI configuration
            tag_ids = calib_start_id : (calib_start_id + calib_vert * calib_hori - 1)
            valid_tags = filter(t -> t.id in tag_ids, tags_detected)
            
            if length(valid_tags) != calib_vert * calib_hori
                HTML("""
                <div style="background-color: #fce8e6; border: 2px solid #ea4335; padding: 1em; border-radius: 4px; margin-top: 1em; color: #c5221f; font-family: sans-serif;">
                    <strong>❌ Calibration Failed</strong><br>
                    Detected only $(length(valid_tags)) of the $(calib_vert * calib_hori) grid tags (IDs $(first(tag_ids)) to $(last(tag_ids))).<br>
                    Ensure the entire grid is clearly visible, well-lit, and in focus.
                </div>
                """)
            else
                # Sort the tags by ID to match boardPattern shape order
                sorted_tags = sort(valid_tags, by = t -> t.id)
                taglength = calib_tag_length_mm / 1000.0
                
                  # Initial guesses from image size
                c_w = size(img, 2) / 2
                c_h = size(img, 1) / 2
                f_w = size(img, 1)
                f_h = f_w
                
                # Dynamic board pattern reshaped in VERT x HORI vertical-major format
                board_pat = reshape(tag_ids, calib_vert, calib_hori)
                
                # --- STAGE 1: COARSE OPTIMIZATION (Pinhole parameters using BFGS) ---
                imgs_vec = [img]
                tags_vec = [sorted_tags]
                obj_coarse = (fw, fh, cw, ch) -> calcCalibResidualAprilTags!(
                    imgs_vec, tags_vec;
                    taglength = taglength,
                    f_width = fw,
                    f_height = fh,
                    c_width = cw,
                    c_height = ch,
                    VERT = calib_vert,
                    HORI = calib_hori,
                    boardPattern = board_pat
                )
                obj_coarse_ = (params) -> obj_coarse(params...)
                
                res_coarse = optimize(obj_coarse_, [f_w, f_h, c_w, c_h], BFGS(), Optim.Options(iterations = 30, x_abstol = 1e-4))
                calib_params_coarse = res_coarse.minimizer
                
                # --- STAGE 2: FINE OPTIMIZATION (Joint Intrinsics + Extrinsics + NN Distortion using Newton's Method) ---
                # Initial estimate of extrinsic pose from Stage 1 parameters
                board_translations = []
                board_rotations = []
                for tag in sorted_tags
                    idx = findfirst(x -> x == tag.id, board_pat)
                    r, c = idx.I[1], idx.I[2]
                    
                    x_board = (c - 1) * 2.0 * taglength
                    y_board = (r - 1) * 2.0 * taglength
                    
                    pose, err = tagOrthogonalIteration(
                        tag,
                        calib_params_coarse[1], # fx
                        calib_params_coarse[2], # fy
                        calib_params_coarse[3], # cx
                        calib_params_coarse[4], # cy
                        taglength = taglength
                    )
                    
                    R = pose.linear
                    t_board = pose.translation - R * [x_board, y_board, 0.0]
                    push!(board_translations, t_board)
                    push!(board_rotations, R)
                end
                
                avg_t = sum(board_translations) / length(board_translations)
                avg_R = sum(board_rotations) / length(board_rotations)
                
                # Re-orthogonalize the initial rotation matrix
                U, S, V = svd(avg_R)
                calib_R_coarse = U * V'
                
                # Local helper: rotation matrix to Rodrigues vector
                function rotation_matrix_to_vector(R)
                    theta = acos(clamp((tr(R) - 1.0) / 2.0, -1.0, 1.0))
                    if theta < 1e-8
                        return [0.0, 0.0, 0.0]
                    else
                        v = [R[3, 2] - R[2, 3],
                             R[1, 3] - R[3, 1],
                             R[2, 1] - R[1, 2]] / (2.0 * sin(theta))
                        return v * theta
                    end
                end
                
                # Local helper: Rodrigues vector to rotation matrix (ForwardDiff compatible)
                function rodrigues(omega)
                    theta = sqrt(omega[1]^2 + omega[2]^2 + omega[3]^2)
                    T = eltype(omega)
                    I3 = [one(T) zero(T) zero(T);
                          zero(T) one(T) zero(T);
                          zero(T) zero(T) one(T)]
                    
                    if theta < 1e-8
                        factor1 = one(T) - theta^2 / 6.0
                        factor2 = 0.5 - theta^2 / 24.0
                    else
                        factor1 = sin(theta) / theta
                        factor2 = (one(T) - cos(theta)) / (theta^2)
                    end
                    
                    K = [zero(T) -omega[3] omega[2];
                         omega[3] zero(T) -omega[1];
                         -omega[2] omega[1] zero(T)]
                         
                    return I3 + factor1 * K + factor2 * (K * K)
                end
                
                # Joint Intrinsics + Extrinsics + Sinusoidal NN Distortion Cost Function
                function cost_function(params, tags_detected, taglength, VERT, HORI, board_pat)
                    fx, fy, cx, cy = params[1:4]
                    omega = params[5:7]
                    t = params[8:10]
                    nn_params = params[11:32]
                    
                    R = rodrigues(omega)
                    
                    # SIREN (Sinusoidal Representation Network) distortion layer with 4 hidden units
                    W1 = reshape(nn_params[1:8], 4, 2)
                    b1 = nn_params[9:12]
                    W2 = reshape(nn_params[13:20], 2, 4)
                    b2 = nn_params[21:22]
                    
                    resid = zero(eltype(params))
                    tl = taglength
                    tl_2 = tl / 2
                    
                    for tag in tags_detected
                        idx = findfirst(x -> x == tag.id, board_pat)
                        if idx === nothing
                            continue
                        end
                        r, c = idx.I[1], idx.I[2]
                        
                        x_board = (c - 1) * 2.0 * tl
                        y_board = (r - 1) * 2.0 * tl
                        
                        corners_grid = [
                            [-tl_2 + x_board,  tl_2 + y_board, 0.0],
                            [ tl_2 + x_board,  tl_2 + y_board, 0.0],
                            [ tl_2 + x_board, -tl_2 + y_board, 0.0],
                            [-tl_2 + x_board, -tl_2 + y_board, 0.0]
                        ]
                        
                        for c_idx in 1:4
                            P_grid = corners_grid[c_idx]
                            P_camera = R * P_grid + t
                            
                            xn = P_camera[1] / P_camera[3]
                            yn = P_camera[2] / P_camera[3]
                            
                            u = [xn, yn]
                            h1 = sin.(W1 * u + b1)
                            du = W2 * h1 + b2
                            
                            xd = xn + du[1]
                            yd = yn + du[2]
                            
                            u_proj = fx * xd + cx
                            v_proj = fy * yd + cy
                            
                            det_corner = tag.p[c_idx]
                            resid += (det_corner[1] - u_proj)^2 + (det_corner[2] - v_proj)^2
                        end
                    end
                    return resid
                end
                
                omega_coarse = rotation_matrix_to_vector(calib_R_coarse)
                initial_params = [
                    calib_params_coarse...,
                    omega_coarse...,
                    avg_t...,
                    zeros(22)...
                ]
                
                # Construct twice differentiable objective using ForwardDiff via ADTypes
                td = TwiceDifferentiable(
                    p -> cost_function(p, sorted_tags, taglength, calib_vert, calib_hori, board_pat),
                    initial_params,
                    autodiff = ADTypes.AutoForwardDiff()
                )
                
                # Run Newton's Method (the best second-order optimizer)
                res_fine = optimize(td, initial_params, Newton(), Optim.Options(iterations = 45, x_abstol = 1e-5))
                calib_params = res_fine.minimizer
                
                # Extract optimized parameters
                calib_fx, calib_fy, calib_cx, calib_cy = calib_params[1:4]
                calib_R = rodrigues(calib_params[5:7])
                calib_t = calib_params[8:10]
                W1_f = reshape(calib_params[11:18], 4, 2)
                b1_f = calib_params[19:22]
                W2_f = reshape(calib_params[23:30], 2, 4)
                b2_f = calib_params[31:32]
                
                # Calculate corrected distortion metrics over the grid corners
                distortions = Float64[]
                tl_2 = taglength / 2
                for tag in sorted_tags
                    idx = findfirst(x -> x == tag.id, board_pat)
                    r, c = idx.I[1], idx.I[2]
                    x_board = (c - 1) * 2.0 * taglength
                    y_board = (r - 1) * 2.0 * taglength
                    
                    corners_grid = [
                        [-tl_2 + x_board,  tl_2 + y_board, 0.0],
                        [ tl_2 + x_board,  tl_2 + y_board, 0.0],
                        [ tl_2 + x_board, -tl_2 + y_board, 0.0],
                        [-tl_2 + x_board, -tl_2 + y_board, 0.0]
                    ]
                    
                    for P_grid in corners_grid
                        P_camera = calib_R * P_grid + calib_t
                        xn = P_camera[1] / P_camera[3]
                        yn = P_camera[2] / P_camera[3]
                        u = [xn, yn]
                        h1 = sin.(W1_f * u + b1_f)
                        du = W2_f * h1 + b2_f
                        
                        dx_px = calib_fx * du[1]
                        dy_px = calib_fy * du[2]
                        push!(distortions, sqrt(dx_px^2 + dy_px^2))
                    end
                end
                
                max_dist = maximum(distortions)
                mean_dist = sum(distortions) / length(distortions)
                t_cm = calib_t .* 100.0
                
                HTML("""
                <div style="background-color: #e6f4ea; border: 2px solid #34a853; padding: 1.2em; border-radius: 6px; margin-top: 1em; font-family: sans-serif;">
                    <h3 style="margin-top: 0; color: #137333;">🎉 Calibration Completed Successfully!</h3>
                    
                    <h4 style="margin-bottom: 0.5em; color: #202124;">1. Intrinsic Parameters (Pinhole Model)</h4>
                    <p>Copy and update the camera parameters at the top of the page with these values:</p>
                    <ul style="margin-top: 0.2em;">
                        <li><strong>Focal Length X (fx):</strong> <code>$(round(calib_fx, digits=2))</code></li>
                        <li><strong>Focal Length Y (fy):</strong> <code>$(round(calib_fy, digits=2))</code></li>
                        <li><strong>Center X (cx):</strong> <code>$(round(calib_cx, digits=2))</code></li>
                        <li><strong>Center Y (cy):</strong> <code>$(round(calib_cy, digits=2))</code></li>
                    </ul>
                    
                    <h4 style="margin-bottom: 0.5em; color: #202124;">2. Extrinsic Parameters (Camera Pose relative to Board Origin)</h4>
                    <p>Board origin is defined at the center of the top-left tag (ID: $(first(tag_ids))):</p>
                    <ul style="margin-top: 0.2em;">
                        <li><strong>Camera Translation (t):</strong>
                            <ul>
                                <li>X (right): <code>$(round(t_cm[1], digits=2)) cm</code></li>
                                <li>Y (down): <code>$(round(t_cm[2], digits=2)) cm</code></li>
                                <li>Z (distance): <code>$(round(t_cm[3], digits=2)) cm</code></li>
                            </ul>
                        </li>
                        <li style="margin-top: 0.5em;"><strong>Camera Rotation Matrix (R):</strong>
                            <table style="border-collapse: collapse; margin-top: 6px; font-family: monospace; font-size: 0.9em; text-align: right;">
                                <tr>
                                    <td style="padding: 4px 8px; border: 1px solid #ccc; background: #f8f9fa;"><code>$(round(calib_R[1, 1], digits=5))</code></td>
                                    <td style="padding: 4px 8px; border: 1px solid #ccc; background: #f8f9fa;"><code>$(round(calib_R[1, 2], digits=5))</code></td>
                                    <td style="padding: 4px 8px; border: 1px solid #ccc; background: #f8f9fa;"><code>$(round(calib_R[1, 3], digits=5))</code></td>
                                </tr>
                                <tr>
                                    <td style="padding: 4px 8px; border: 1px solid #ccc; background: #f8f9fa;"><code>$(round(calib_R[2, 1], digits=5))</code></td>
                                    <td style="padding: 4px 8px; border: 1px solid #ccc; background: #f8f9fa;"><code>$(round(calib_R[2, 2], digits=5))</code></td>
                                    <td style="padding: 4px 8px; border: 1px solid #ccc; background: #f8f9fa;"><code>$(round(calib_R[2, 3], digits=5))</code></td>
                                </tr>
                                <tr>
                                    <td style="padding: 4px 8px; border: 1px solid #ccc; background: #f8f9fa;"><code>$(round(calib_R[3, 1], digits=5))</code></td>
                                    <td style="padding: 4px 8px; border: 1px solid #ccc; background: #f8f9fa;"><code>$(round(calib_R[3, 2], digits=5))</code></td>
                                    <td style="padding: 4px 8px; border: 1px solid #ccc; background: #f8f9fa;"><code>$(round(calib_R[3, 3], digits=5))</code></td>
                                </tr>
                            </table>
                        </li>
                    </ul>
                    
                    <h4 style="margin-bottom: 0.5em; color: #202124;">3. Lens Distortion Model (Sinusoidal Neural Network)</h4>
                    <ul style="margin-top: 0.2em;">
                        <li><strong>Model Architecture:</strong> 2 &rarr; [4 (Sine)] &rarr; 2 (Linear) (22 parameters)</li>
                        <li><strong>Average Distortion Correction:</strong> <code>$(round(mean_dist, digits=2)) pixels</code></li>
                        <li><strong>Maximum Distortion Correction:</strong> <code>$(round(max_dist, digits=2)) pixels</code></li>
                    </ul>
                </div>
                """)
            end
        catch e
            HTML("<div style='color: red; font-weight: bold; font-family: sans-serif;'>Error during calibration: $(sprint(showerror, e))</div>")
        finally
            freeDetector!(detector)
        end
    end
end

# ╔═╡ Cell order:
# ╟─b4d420f1-4db8-4034-8c85-e23f03b8cc15
# ╟─c7991b1a-8bb7-4b5f-a3d8-e32517ab6f67
# ╟─a550604f-124b-489e-b9ab-ec5d1136b69b
# ╟─b2d6bfd8-1c4b-419b-ab01-44754519965a
# ╟─e7c39054-9457-418f-a9cb-f1190cf613c7
# ╟─d3cb4bb9-7a54-4f2b-8a8b-c98e27c1ab02
# ╟─cf220bb6-ea54-478f-a0e2-e19efc21ac1f
# ╠═b1c89012-7bb8-4f81-a3f2-1abcefb15498
# ╟─a6a908a8-b673-455b-b9ab-b19dfb1ab728
# ╟─e1229a1b-4db3-448f-8898-8c105ab1c1b1
# ╟─f4229a1b-4db3-448f-8898-8c105ab1c1b4
# ╟─f4229a1b-4db3-448f-8898-8c105ab1c1b5
# ╟─f4229a1b-4db3-448f-8898-8c105ab1c1b6
# ╟─f4229a1b-4db3-448f-8898-8c105ab1c1b7
# ╟─df9087c5-5555-4034-8c85-e23f03b8cc15
# ╠═bd6a22f6-34a8-4bb8-88b9-8c105ab1c1b2
# ╠═c3bc88a5-d85c-43bb-a53c-2ee7a0d4c82b
