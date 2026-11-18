// The frame: the world as the previous passes left it, with the sun's rays over it.
//
// A pack with a [[post]] chain draws the frame itself, so the player's TAA/FXAA never run; this
// pass is a plain copy plus the rays, and the game's own anti-aliasing is off while it is on.
override bloom: f32 = 0.15;
// Where the loaded terrain ends, its last chunks stood out as a hard band against the sky (a
// server's view distance is often shorter than the render distance the shader knows). Distant
// terrain just under the sky blends into the sky above it over a few pixels, whatever distance it
// ends at; nearby trees and hills against the sky are left alone.
override skyline: f32 = 0.5;

fn skyline_at(uv: vec2<f32>, color: vec3<f32>) -> vec3<f32> {
    if skyline <= 0.0 || frame.dimension != 0 || frame.eye_in != 0u {
        return color;
    }
    let depth = depth_at(uv);
    if depth == 0.0 {
        return color;
    }
    let far = smoothstep(64.0, 160.0, length(view_position(uv, depth))) * 0.7;
    if far <= 0.0 {
        return color;
    }
    let step = 2.0 * max(frame.resolution.y / 720.0, 1.0) / frame.resolution.y;
    for (var i = 1; i <= 10; i++) {
        let up = uv - vec2<f32>(0.0, f32(i) * step);
        if up.y < 0.0 {
            break;
        }
        if depth_at(up) == 0.0 {
            let sky = textureSampleLevel(scene_color, linear_sampler, up, 0.0).rgb;
            let k = 1.0 - f32(i) / 11.0;
            return mix(color, sky, k * k * far * clamp(skyline, 0.0, 1.0));
        }
    }
    return color;
}

// The rays target is a quarter of the world's size and its march is per-pixel noise, so it is read
// through nine taps of its own texels: that averages the noise into a smooth glow and leaves the
// shafts, where sampling it once shows the march's grain and spokes.
fn rays_at(uv: vec2<f32>) -> vec3<f32> {
    let texel = 4.0 / frame.resolution;
    var sum = vec3<f32>(0.0);
    var weights = 0.0;
    for (var i = 0; i < 9; i++) {
        let o = vec2<f32>(f32(i % 3), f32(i / 3)) - 1.0;
        let w = 1.0 - 0.3 * (abs(o.x) + abs(o.y));
        sum += textureSampleLevel(vh_rays, linear_sampler, uv + o * texel * 2.5, 0.0).rgb * w;
        weights += w;
    }
    return sum / weights;
}

fn post(input: PostInput) -> vec4<f32> {
    let amount = rays_amount() * rays_strength();
    var color = skyline_at(input.uv, input.color.rgb);
    if amount > 0.0 {
        // The rays take the sun's warmth, and already hold the dawn-and-dusk gate themselves. The
        // gain stays under 1: a shaft is lit air, not a second sun.
        color += rays_at(input.uv) * rays_hue() * amount * 0.85;
    }
    // Mobs, dropped items and particles are drawn by the game with vanilla's light, so the hour's
    // warmth never reaches them. Anything here that the terrain stage did not mark is such a pixel:
    // it takes the same shift the terrain takes at dawn and dusk.
    if input.depth > 0.0 {
        let texel = vec2<i32>(clamp(input.uv * frame.resolution, vec2<f32>(0.0), frame.resolution - vec2<f32>(1.0)));
        if !surface_at(texel).present {
            let dusk = sun_low() * clamp(side_mix(dawn_orange, dusk_orange), 0.0, 2.0) * 0.45;
            color = mix(color, color * vec3<f32>(1.50, 0.84, 0.48), clamp(dusk, 0.0, 1.0));
        }
    }

    // The glow rides over everything, the way a veiled lens sees a low sun.
    if bloom > 0.0 {
        color += textureSampleLevel(vh_glow_b, linear_sampler, input.uv, 0.0).rgb * bloom * 0.7;
    }
    return vec4<f32>(clamp(color, vec3<f32>(0.0), vec3<f32>(1.0)), input.color.a);
}
