// Rain and snow: the streaks take the colour this pack gives them. Horizon applies no light here,
// so the streak lights itself — by the sky it falls through and by the block light it falls into.
//
// `Rain colour` has three anchors: −1 is vanilla's own streak, 0 the pack's cool blue, 1 its
// neutral grey. Between them it blends.
override rain_tint: f32 = 1.0;
override rain_brightness: f32 = 1.85;

fn weather(input: WeatherInput) -> vec4<f32> {
    let day = daylight();
    // Sky light, dimmed at night and in a storm.
    let sky = input.light.y * mix(0.18, 1.0, day) * (1.0 - 0.4 * frame.thunder);
    // Block light, so a streak under a torch or a lantern takes a warm cast.
    let lamp_amount = clamp(input.light.x, 0.0, 1.0) * 0.8;
    let light = max(sky, lamp_amount);

    let gain = clamp(rain_brightness, 0.0, 2.0);
    let t = clamp(rain_tint, -1.0, 1.0);
    // The three anchors.
    let neutral = vec3<f32>(max(light, 0.05) * gain);
    let cool = neutral * vec3<f32>(0.72, 1.05, 1.45);
    let vanilla = input.color.rgb * gain;

    var streak = select(
        mix(vanilla, cool, clamp(t + 1.0, 0.0, 1.0)),
        mix(cool, neutral, clamp(t, 0.0, 1.0)),
        t >= 0.0);
    // Under a torch the streak warms, the way a real one catches the light it falls through.
    streak = mix(streak, streak * vec3<f32>(1.0, 0.8, 0.55), clamp(lamp_amount, 0.0, 1.0));
    if input.snow {
        // Snow stays white whatever the slider says; only its brightness follows.
        streak = vec3<f32>(0.95, 0.97, 1.0) * max(light, 0.25) * gain;
    }
    let alpha = input.color.a * select(0.30, 0.85, input.snow);
    return vec4<f32>(streak, alpha);
}
