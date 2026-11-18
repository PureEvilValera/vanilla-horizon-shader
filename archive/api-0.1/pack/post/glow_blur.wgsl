// Glow, second half: a nine-tap blur of the prefiltered bright parts, still at a quarter of the
// world's size. The last pass adds it, which is what turns the sun into a veiled light instead of a
// hard disc.
fn post(input: PostInput) -> vec4<f32> {
    let texel = 4.0 / frame.resolution;
    var sum = vec3<f32>(0.0);
    var weights = 0.0;
    for (var i = 0; i < 9; i++) {
        let o = vec2<f32>(f32(i % 3), f32(i / 3)) - 1.0;
        let w = 1.0 - 0.3 * (abs(o.x) + abs(o.y));
        sum += textureSampleLevel(vh_glow, linear_sampler, input.uv + o * texel * 2.0, 0.0).rgb * w;
        weights += w;
    }
    return vec4<f32>(sum / weights, 1.0);
}
