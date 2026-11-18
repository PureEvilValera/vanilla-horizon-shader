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
// A layer of mist in the first blocks above the sea's level, thickest at the ground: its own amount
// for the dawn and for the dusk, and how many blocks it climbs.
override dawn_mist: f32 = 0.55;
override dusk_mist: f32 = 0.0;
override night_mist: f32 = 2.0;
// An extra amount for the deep of the night, on top of the night's own.
override midnight_mist: f32 = 0.65;
override mist_height: f32 = 3.5;
// How far from the player, in chunks, the mist starts: 0 has it from the camera, 1 keeps the first
// sixteen blocks clear, 3 the first forty-eight.
override mist_start: f32 = 1.0;

fn skyline_at(uv: vec2<f32>, color: vec3<f32>) -> vec3<f32> {
    if skyline <= 0.0 || frame.dimension != 0 || frame.eye_in != 0u {
        return color;
    }
    let depth = depth_at(uv);
    if depth == 0.0 {
        return color;
    }
    // The far edge of the loaded terrain fades into vanilla's own fog colour, smoothly by distance.
    // Two earlier versions sampled the picture above the pixel for the sky — the sun, the moon and
    // the stars are in that picture, so their image was painted onto the far terrain (the sun and
    // the moon came out doubled). The fog colour is the horizon's colour and has no sprites in it.
    let dist = length(view_position(uv, depth));
    let far = smoothstep(frame.fog_render.x, frame.fog_render.y, dist);
    if far <= 0.0 {
        return color;
    }
    return mix(color, frame.fog_color, far * clamp(skyline, 0.0, 1.0));
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

// The air in the lowest blocks of a valley, at any distance: marched along the view ray to the
// surface's depth, so the mist sits in the world (a hollow fills, a hill top stays clear) and needs
// no second texture. `depth` is the world's, so the sky has none of it.
fn ground_mist(uv: vec2<f32>, depth: f32) -> vec4<f32> {
    // The dawn and the dusk share the layer through their own weights; the night has its own amount
    // and is gated out of both, so the three never add up into a wall of fog.
    // The night is split in two, and the two cross over: `Night mist` rules the evening right after
    // the sun sets and thins as the night deepens, `Midnight mist` takes the small hours. With the
    // second at 0 a player keeps just the mist that follows the sunset.
    let deep = smoothstep(-0.15, -0.50, frame.sun_direction.y);
    let evening = nightfall() * (1.0 - deep);
    let day_amount = sun_low() * clamp(side_mix(dawn_mist, dusk_mist), 0.0, 2.0);
    let night_amount = evening * clamp(night_mist, 0.0, 2.0)
        + deep * clamp(midnight_mist, 0.0, 2.0);
    let amount = day_amount + night_amount;
    if amount <= 0.0 || depth == 0.0 || frame.dimension != 0 {
        return vec4<f32>(0.0);
    }
    let p = view_position(uv, depth);
    // `Mist start` keeps the near field clear: the layer fades in over a few blocks past it.
    let begin = max(mist_start, 0.0) * 16.0;
    var ramp = 1.0;
    if begin > 0.0 {
        ramp = smoothstep(begin, begin + 24.0, length(p));
    }
    if ramp <= 0.0 {
        return vec4<f32>(0.0);
    }
    let steps = 12.0;
    let height = max(mist_height, 0.5);
    var sum = 0.0;
    for (var i = 1; i <= 12; i++) {
        let t = f32(i) / steps;
        let y = frame.camera_position.y + p.y * t;
        sum += exp(-max(y - 62.0, 0.0) / height) * t;
    }
    let density = sum / steps;
    // The mist of a dawn or a dusk takes the fog's own colour warmed; the night's is lit by the moon
    // instead, so it reads as grey-blue air rather than the black of `fog_color` (vanilla's fog at
    // midnight is darker than the ground, and a mist painted with it only darkened the view).
    let warm = mix(frame.fog_color, frame.fog_color * vec3<f32>(1.7, 0.9, 0.55), sun_low());
    let moon_hue = mix(vec3<f32>(0.45, 0.55, 0.9), vec3<f32>(0.9, 0.85, 0.75), clamp(moon_tint, 0.0, 1.0));
    let moonlit = moon_hue * (0.012 + 0.028 * clamp(moon_strength, 0.0, 2.0));
    let colour = (warm * day_amount + moonlit * night_amount) / max(amount, 1e-3);
    return vec4<f32>(colour, clamp(density * amount * 1.8 * ramp, 0.0, 0.95));
}

fn post(input: PostInput) -> vec4<f32> {
    let amount = rays_amount() * rays_strength();
    var color = skyline_at(input.uv, input.color.rgb);
    // Mist over the low air, before the rays and the glow so those still read through it.
    let mist = ground_mist(input.uv, input.depth);
    color = mix(color, mist.rgb, mist.a);
    if amount > 0.0 {
        // The rays take the sun's warmth, and already hold the dawn-and-dusk gate themselves. The
        // gain stays under 1: a shaft is lit air, not a second sun.
        color += rays_at(input.uv) * rays_hue() * amount * 0.55;
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
    // 0.2: the picture is linear light, so there is more than white to keep; `[tonemap]` maps it.
    let ceiling = vec3<f32>(max(frame.headroom, 1.0));
    return vec4<f32>(clamp(color, vec3<f32>(0.0), ceiling), input.color.a);
}
