// Light shafts, at a quarter of the world's size: a march from each pixel toward the sun. The air
// along the way counts as lit where it is open sky and where the shadow map says the sun reaches
// it, so the shafts run over the ground and through valleys instead of only across the sky.
//
// The march follows the one in Petalveil (MIT) by BarmaleyVIP; the shadow-aware air, the noise, the
// skip of the samples outside the picture and the tinting belong to this pack.
// Where the sun is on screen: xy its UV, z 1 when it can drive the march.
fn sun_screen() -> vec3<f32> {
    let v = (frame.view * vec4<f32>(frame.sun_direction, 0.0)).xyz;
    // The direction as a point one unit ahead: its clip w is how far in front of the camera it is.
    let clip = frame.projection * vec4<f32>(v, 1.0);
    let ahead = clip.w;
    if ahead > 0.2 {
        let ndc = clip.xy / ahead;
        let uv = ndc * vec2<f32>(0.5, -0.5) + vec2<f32>(0.5);
        let sane = all(uv > vec2<f32>(-6.0)) && all(uv < vec2<f32>(7.0));
        if sane {
            return vec3<f32>(uv, 1.0);
        }
    }
    // Beside or behind the camera, the march still starts from the sun's own side of the sky, far
    // off the frame: the shafts thin out smoothly instead of blinking off the moment the view
    // swings past the sun.
    let side = vec2<f32>(v.x, -v.y);
    let len = length(side);
    if len < 0.02 {
        return vec3<f32>(0.5, 0.5, 0.0);
    }
    return vec3<f32>(vec2<f32>(0.5) + side / len * 2.5, 1.0);
}

// 1 where the sun reaches the air at `p` (camera-relative), 0 in a shadow. Without a map, or outside
// its square, the air is taken as lit, so the effect never darkens what vanilla lights.
fn air_lit(p: vec3<f32>) -> f32 {
    if frame.has_shadow == 0u {
        return 1.0;
    }
    let bias = max(frame.shadow_center_texel, 0.005) * 2.0;
    let s = shadow_position(p + frame.light_direction * bias);
    if any(s.xy <= vec2<f32>(0.0)) || any(s.xy >= vec2<f32>(1.0)) || s.z >= 1.0 {
        return 1.0;
    }
    return textureSampleCompareLevel(shadow_map, shadow_sampler, s.xy, s.z);
}

fn post(input: PostInput) -> vec4<f32> {
    let strength = rays_strength();
    if rays_amount() <= 0.0 || strength <= 0.0 {
        return vec4<f32>(0.0, 0.0, 0.0, 1.0);
    }
    let sun = sun_screen();
    if sun.z < 1.0 {
        return vec4<f32>(0.0, 0.0, 0.0, 1.0);
    }
    let toward_sun = sun.xy - input.uv;
    // A per-pixel start breaks the march's own rings and spokes into noise; the last pass blurs
    // this target, which averages the noise away and leaves a smooth gradient. The pattern is
    // anchored to the world, not to the screen: a screen-fixed one stays put while the world moves
    // under it, and the shafts then read as a film laid over the picture instead of lit air.
    let jitter = ign(input.pixel + frame.camera_position.xz * 211.0);
    var sum = 0.0;
    for (var i = 0; i < 24; i++) {
        let t = (f32(i) + jitter) / 24.0;
        let uv = input.uv + toward_sun * t;
        // A sample outside the picture says nothing about the air; it is skipped, not clamped, so a
        // sun beyond the frame does not smear the border over the scene.
        if any(uv <= vec2<f32>(0.0)) || any(uv >= vec2<f32>(1.0)) {
            continue;
        }
        let depth = depth_at(uv);
        var lit = 1.0;
        if (depth > 0.0) {
            // The sample sits on terrain: what counts is the air just above it, which the shadow
            // map tells apart — a valley floor in shadow breaks the shaft, a sunlit one lets it run.
            let p = view_position(uv, depth);
            lit = air_lit(p + vec3<f32>(0.0, 1.6, 0.0));
        }
        let falloff = 1.0 - t;
        sum += lit * falloff * falloff;
    }
    // Shafts belong to the air near the ground: they fade out above the sun's own elevation. The
    // fade is measured against the pixel's world ray, not against its place on the screen, so it
    // rocks with the world (walking, head bob) instead of with the camera.
    let ray_dir = normalize(view_position(input.uv, 0.001));
    let above = max(ray_dir.y - frame.sun_direction.y, 0.0);
    let limiter = exp(-above * 6.0);
    return vec4<f32>(vec3<f32>(sum / 24.0 * 2.6) * strength * limiter, 1.0);
}
