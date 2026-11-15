// Vanilla Horizon: shared by every stage.
//
// The rule: vanilla's own light (`MaterialInput.lightmap`) is the base and nothing darkens it.
// The sun and the moon only add, and the shadow map only takes away a bounded part of the light
// that comes from the sky. A cave, a cellar and the night keep vanilla's brightness and colours.
//
// Dawn and dusk have their own settings: the shader tells the sunrise from the sunset by the side
// of the sky the sun is on (it rises in the east, x > 0), and blends each value by how close the
// sun is to the horizon on that side. Night is gated out of both, so a setting moon never paints
// the ground with the sunset's orange.
const TAU: f32 = 6.2831853;

// [[materials]] ids from horizon-shaders.toml.
const MAT_LEAVES: u32 = 1u;
const MAT_PLANT: u32 = 2u;
// The light-emitting groups, each with its own glow settings.
const MAT_TORCH: u32 = 3u;
const MAT_LAVA: u32 = 4u;
const MAT_GLOWSTONE: u32 = 5u;
const MAT_CRYSTAL: u32 = 6u;

// A colour shifted along the warm/cool axis by `t` (-1 cool blue, 0 as it is, +1 deep orange),
// keeping its brightness: only the channels move.
fn shift_hue(c: vec3<f32>, t: f32) -> vec3<f32> {
    let k = clamp(t, -1.0, 1.0);
    let warm = max(k, 0.0);
    let cool = max(-k, 0.0);
    return c * vec3<f32>(
        1.0 + 0.45 * warm - 0.30 * cool,
        1.0 - 0.12 * warm + 0.05 * cool,
        1.0 - 0.55 * warm + 0.60 * cool);
}

// How much direct sunlight adds on top of vanilla's light at Sunlight 1.
const SUN_ADD: f32 = 0.18;
// The same for the moon. It matches the sun's share, so `Moonlight` 0.3 already gives a night you
// can read the ground by, and its light is there the whole night, not only while it rises.
const MOON_ADD: f32 = 0.18;
// The most a shadow takes away from vanilla's sky light, so a shadow is shade and never night.
const SHADE: f32 = 0.18;
// A low sun always gives a little of its own warm light: without it the dawn and the dusk would
// stay exactly vanilla's and the shadows would have nothing to cut.
const SUNSET_ADD: f32 = 0.12;

// --- The light of the hour ---------------------------------------------------------

override sun_strength: f32 = 2.0;
override moon_strength: f32 = 2.0;
// How cool or warm the moon's own light is: 0 the pack's cool blue, 1 a warm white.
override moon_tint: f32 = 0.0;
override moon_glow: f32 = 0.2;

// Wind: how hard the leaves and the blades move in a calm hour, in the rain and in a storm.
override wind_calm: f32 = 0.2;
override wind_rain: f32 = 1.9;
override wind_thunder: f32 = 5.0;

// Dawn (the sun in the east).
override dawn_glow: f32 = 0.7;
override dawn_glow_size: f32 = 0.3;
override dawn_haze: f32 = 0.0;
override dawn_warmth: f32 = 0.25;
override dawn_orange: f32 = 0.75;
override dawn_light: f32 = 0.5;
override dawn_rays: f32 = 0.1;
override dawn_rays_color: f32 = -0.25;

// Dusk (the sun in the west).
override dusk_glow: f32 = 0.75;
override dusk_glow_size: f32 = 0.2;
override dusk_haze: f32 = 0.2;
override dusk_warmth: f32 = 0.5;
override dusk_orange: f32 = 2.0;
override dusk_light: f32 = 0.3;
override dusk_rays: f32 = 0.3;
override dusk_rays_color: f32 = 0.5;

// How many cells hold a ring: 0 none, 1 the rain's own count, above it more.
override ring_density: f32 = 1.0;

// One ring per cell: a drop lands at a random spot, its ring spreads and fades, and the harder it
// rains the more cells hold one. Returns the ring's slope, so two calls at different scales and
// offsets read as separate drops instead of a grid.
fn drop_rings(p: vec2<f32>) -> vec2<f32> {
    let cell = floor(p);
    let f = fract(p) - vec2<f32>(0.5);
    // `Ring amount` scales how many cells hold a drop; the rain and the storm add their own.
    let chance = clamp((0.35 + 0.45 * frame.rain + 0.2 * frame.thunder)
        * clamp(ring_density, 0.0, 3.0), 0.0, 1.0);
    let drop = step(hash(cell), chance);
    let phase = fract(frame.time * 1.1 + hash(cell + vec2<f32>(19.7, 7.3)) * 7.0);
    let r = length(f) + 0.0001;
    let ring = smoothstep(0.10, 0.0, abs(r - phase * 0.45)) * (1.0 - phase);
    return f / r * ring * drop * frame.rain;
}

fn luma(c: vec3<f32>) -> f32 {
    return dot(c, vec3<f32>(0.2126, 0.7152, 0.0722));
}

fn overworld() -> bool {
    return frame.dimension == 0;
}

fn bad_weather() -> f32 {
    return max(frame.rain, frame.thunder);
}

// How hard the wind blows this frame: the calm hour's own strength, the rain's and the storm's.
fn wind() -> f32 {
    let calm = mix(max(wind_calm, 0.0), max(wind_rain, 0.0), clamp(frame.rain, 0.0, 1.0));
    return mix(calm, max(wind_thunder, 0.0), clamp(frame.thunder, 0.0, 1.0));
}

// 1 by day, 0 by night, eased across the horizon.
fn daylight() -> f32 {
    return select(0.0, smoothstep(-0.1, 0.12, frame.sun_direction.y), overworld());
}

// 1 by night, 0 by day.
fn nightfall() -> f32 {
    return select(0.0, 1.0 - smoothstep(-0.10, 0.03, frame.sun_direction.y), overworld());
}

// x: the dawn's weight, y: the dusk's, each 0 while the sun is high or below the horizon.
fn sun_side() -> vec2<f32> {
    let up = smoothstep(-0.10, 0.03, frame.sun_direction.y);
    let low = (1.0 - smoothstep(0.02, 0.50, abs(frame.sun_direction.y))) * up;
    let east = smoothstep(-0.15, 0.15, frame.sun_direction.x);
    let west = smoothstep(-0.15, 0.15, -frame.sun_direction.x);
    return low * vec2<f32>(east, west) / max(east + west, 1e-4);
}

// 0 while the sun is high or down, 1 with it on the horizon: the gate for every dawn/dusk setting.
fn sun_low() -> f32 {
    let w = sun_side();
    return w.x + w.y;
}

// One value blended between the dawn's and the dusk's own.
fn side_mix(dawn: f32, dusk: f32) -> f32 {
    let w = sun_side();
    return (dawn * w.x + dusk * w.y) / max(w.x + w.y, 1e-4);
}

// The colour and strength of this frame's direct light: the sun by day, the moon by night.
fn direct_color() -> vec3<f32> {
    let l = frame.light_direction;
    let is_sun = dot(l, frame.sun_direction) > 0.0;
    let high = smoothstep(0.0, 0.30, l.y);
    let orange = vec3<f32>(1.0, 0.50, 0.18);
    let white = vec3<f32>(1.0, 0.96, 0.9);
    let warmth = clamp(side_mix(dawn_warmth, dusk_warmth), 0.0, 1.0);
    let sun = mix(white, mix(white, orange, warmth), 1.0 - high);
    let moon = mix(vec3<f32>(0.62, 0.72, 1.0), vec3<f32>(1.0, 0.92, 0.8), clamp(moon_tint, 0.0, 1.0));
    let weather = 1.0 - 0.85 * bad_weather();
    let boost = side_mix(dawn_light, dusk_light);
    let sun_gain = (SUN_ADD * max(sun_strength, 0.0) + SUNSET_ADD * sun_low() * clamp(boost, 0.0, 2.0))
        * (1.0 + 0.8 * sun_low() * clamp(boost, 0.0, 2.0));
    // The moon's own light, all night long: gated by its elevation only, never by the sun's hour.
    let moon_gain = MOON_ADD * max(moon_strength, 0.0);
    let gain = select(moon_gain, sun_gain, is_sun);
    return select(moon, sun, is_sun) * gain * smoothstep(0.0, 0.06, l.y) * weather;
}

// Sun rays show only while the sun is above the horizon and low, and not in the rain.
fn rays_strength() -> f32 {
    let y = frame.sun_direction.y;
    let low = smoothstep(0.0, 0.06, y) * (1.0 - smoothstep(0.16, 0.40, y));
    // Rays stream toward the sun wherever it is on screen: a camera turned away keeps them until
    // the sun is well behind, so they never blink out when the view swings sideways.
    let v = (frame.view * vec4<f32>(frame.sun_direction, 0.0)).xyz;
    let facing = -v.z / max(length(v), 1e-4);
    return low * (1.0 - bad_weather()) * smoothstep(-0.45, 0.15, facing);
}

// How strong the rays are this hour: the dawn's and the dusk's own settings.
fn rays_amount() -> f32 {
    return clamp(side_mix(dawn_rays, dusk_rays), 0.0, 1.0);
}

// The rays' colour: warm by `Sun warmth`, more or less saturated by `Rays colour`.
fn rays_hue() -> vec3<f32> {
    let warmth = clamp(side_mix(dawn_warmth, dusk_warmth), 0.0, 1.0);
    let c = mix(vec3<f32>(1.0, 0.92, 0.82), vec3<f32>(1.0, 0.55, 0.28), warmth);
    let grey = vec3<f32>(luma(c));
    let tinted = mix(grey, c, clamp(1.0 + 2.0 * side_mix(dawn_rays_color, dusk_rays_color), 0.0, 2.0));
    return tinted / max(luma(tinted), 0.001);
}

// A soft shoulder above 0.78, so bright light rolls into white instead of clipping.
fn shoulder(c: vec3<f32>) -> vec3<f32> {
    let over = max(c - vec3<f32>(0.78), vec3<f32>(0.0));
    return min(c, vec3<f32>(0.78)) + 0.22 * (vec3<f32>(1.0) - exp(-over * 4.5));
}

// Interleaved gradient noise (Jimenez 2014): a cheap, well spread 0..1 value per pixel.
fn ign(pixel: vec2<f32>) -> f32 {
    return fract(52.9829189 * fract(dot(pixel, vec2<f32>(0.06711056, 0.00583715))));
}

// Smooth value noise in -1..1 (the water's ripples).
fn hash(p: vec2<f32>) -> f32 {
    var p3 = fract(vec3<f32>(p.x, p.y, p.x) * 0.2031);
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.x + p3.y) * p3.z);
}

fn noise(p: vec2<f32>) -> f32 {
    let i = floor(p);
    let f = fract(p);
    let u = f * f * (vec2<f32>(-2.0) * f + 3.0);
    return 2.0 * mix(
        mix(hash(i), hash(i + vec2<f32>(1.0, 0.0)), u.x),
        mix(hash(i + vec2<f32>(0.0, 1.0)), hash(i + vec2<f32>(1.0, 1.0)), u.x),
        u.y) - 1.0;
}

// A velocity integrated around an hour-long circle, so the motion stays continuous when
// `frame.time` wraps (it does, every hour).
fn animation_offset(velocity: vec2<f32>) -> vec2<f32> {
    let period = 3600.0;
    let phase = frame.time * (TAU / period);
    let radius = period / TAU;
    let s = sin(phase);
    let c = cos(phase);
    return radius * vec2<f32>(velocity.x * s + velocity.y * (c - 1.0), velocity.x * (1.0 - c) + velocity.y * s);
}
