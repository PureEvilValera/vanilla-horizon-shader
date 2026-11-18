// Glow, first half: only what is brighter than a soft knee is kept, so the sun, its halo and bright
// clouds bloom while ordinary terrain does not. A quarter of the world's size.
override bloom: f32 = 0.15;

fn post(input: PostInput) -> vec4<f32> {
    let c = textureSampleLevel(previous, linear_sampler, input.uv, 0.0).rgb;
    let k = smoothstep(0.70, 0.95, luma(c));
    return vec4<f32>(c * k, 1.0);
}
