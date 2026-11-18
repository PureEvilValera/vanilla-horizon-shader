// The pack's own curve, run once per pixel of the window over the linear picture the post chain
// leaves. `frame.headroom` is the peak over paper white: 1 on SDR, more on an HDR display.
//
// Vanilla has no curve at all — it clips at white — so a full filmic curve reads as far more
// contrast than the game has. `Tone curve` blends between that plain clip (0, vanilla's own look)
// and the filmic one (1), and the default sits near the game.
//
// The curve is applied to the pixel's luminance and the colour is scaled by the same factor, so the
// hue and the saturation of a sunset survive it: a per-channel curve (plain ACES) pushes reds hard
// at exactly the light this pack paints at dawn and dusk.
override exposure: f32 = 1.0;
override tone_curve: f32 = 0.25;

fn aces(x: f32) -> f32 {
    let a = 2.51;
    let b = 0.03;
    let c = 2.43;
    let d = 0.59;
    let e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

fn tonemap(input: TonemapInput) -> vec3<f32> {
    let headroom = max(frame.headroom, 1.0);
    let c = max(input.color, vec3<f32>(0.0)) * max(exposure, 0.0);
    // What the game does: keep the light up to paper white as it is, clip the rest.
    let plain = min(c, vec3<f32>(headroom));
    // The filmic curve, on luminance only: the ACES fit lands in display-referred values, so it is
    // converted back, and the pixel keeps its colour.
    let y = max(dot(c, vec3<f32>(0.2126, 0.7152, 0.0722)), 1e-5);
    let ty = pow(aces(y), 2.2);
    let filmic = min(c * (ty / y) * headroom, vec3<f32>(headroom));
    return mix(plain, filmic, clamp(tone_curve, 0.0, 1.0));
}
