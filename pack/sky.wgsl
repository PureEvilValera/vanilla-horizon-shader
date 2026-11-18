// The sky: vanilla's own colour along the ray, the glow of the sun on the horizon, and a cool halo
// around the moon at night. The sun (vanilla's square quad), the moon with its phases, the stars
// and the clouds stay the engine's own.
//
// The dawn and the dusk have their own settings (`dawn_*`, `dusk_*`), blended by the side of the
// sky the sun is on, so a sunrise never borrows the sunset's orange.
fn sky(input: SkyInput) -> vec4<f32> {
    if frame.dimension != 0 {
        return input.color;
    }
    var color = input.color.rgb;
    let dir = input.direction;
    let sun = frame.sun_direction;

    // How close this ray is to the sun, in two widths: the halo right around it and a broad wash.
    let d = max(dot(dir, sun), 0.0);
    let size = clamp(side_mix(dawn_glow_size, dusk_glow_size), 0.2, 4.0);
    let tight = pow(d, 90.0 / size);
    let wide = pow(d, 8.0 / size);

    // The sun's colour: white once it is up, warm at the horizon, and orange as the hour says.
    let low = sun_low();
    let warmth = clamp(side_mix(dawn_warmth, dusk_warmth), 0.0, 1.0);
    let warm = mix(vec3<f32>(1.0, 0.914, 0.75), vec3<f32>(1.0, 0.30, 0.07), low * warmth);

    // A low sun throws its light along the horizon on its own side of the sky.
    let flat = normalize(vec3<f32>(dir.x, 0.0, dir.z) + vec3<f32>(0.0001));
    let to_sun = normalize(vec3<f32>(sun.x, 0.0, sun.z) + vec3<f32>(0.0001));
    let band = pow(max(dot(flat, to_sun), 0.0), 3.0) * pow(max(1.0 - abs(dir.y), 0.0), 3.0) * low;

    // The glow stays near the horizon: `horizon` is 0 overhead, so the dome keeps vanilla's colour
    // and only the strip above the ground takes the sun's orange.
    let horizon = pow(1.0 - clamp(abs(dir.y), 0.0, 1.0), 2.2);
    let amount = clamp(side_mix(dawn_glow, dusk_glow), 0.0, 2.0) * (1.0 - 0.85 * bad_weather());
    color += warm * (tight * 0.045 * (0.35 + 0.65 * low) + (wide * 0.13 + band * 0.32) * horizon) * amount;

    // The moon keeps its own, cool light: a halo of its own, never the sunset's orange.
    let night = nightfall();
    if night > 0.001 && moon_glow > 0.0 {
        let dm = max(dot(dir, frame.moon_direction), 0.0);
        let halo = pow(dm, 220.0) * 0.5 + pow(dm, 24.0) * 0.12;
        let hue = mix(vec3<f32>(0.34, 0.49, 1.0), vec3<f32>(1.0, 0.87, 0.68), clamp(moon_tint, 0.0, 1.0));
        color += hue * halo * clamp(moon_glow, 0.0, 2.0) * night * (1.0 - 0.8 * bad_weather());
    }
    return vec4<f32>(clamp(color, vec3<f32>(0.0), vec3<f32>(1.0)), input.color.a);
}
