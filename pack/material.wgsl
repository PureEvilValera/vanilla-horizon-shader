// Vanilla Horizon: vanilla's own material, with the sun and the moon added on top and the water
// changed. Every block keeps `albedo * tint * lightmap`, so caves, torches, night, the Brightness
// option and vanilla's fog stay exactly as without a pack; the shadow map only shades what the
// sun adds and takes back a bounded share of the sky's light.

// [shadow] option: off means no shadow map and no shadow pass at all.
override shadows: bool = true;
// 0 sharp (one tap), 1 soft (four), 2 very soft (nine).
override shadow_softness: u32 = 0u;
// How dark a shadow is; above it the sun's own light in the shadow fades first.
override shadow_strength: f32 = 1.5;

// [reflection] option: the world's mirror about the water plane is drawn while it is on.
override water_reflections: bool = true;
// How much of the mirror the water shows (0: none, 1: a perfect mirror at grazing angles).
override reflection_strength: f32 = 1.0;
// 0 keeps vanilla's see-throughness, 1 is as clear as the water goes.
override water_transparency: f32 = 0.7;
// How steep the ripples in the water's normals are (0: a flat top, vanilla's shape).
override water_waves: f32 = 1.0;
// The sun's or moon's glint on the water (vanilla has none).
override sun_glint: f32 = 0.2;
// How strongly the far water dissolves into the horizon: 0 leaves its edge sharp, 1 hides it.
override far_water: f32 = 0.4;
// How many blocks before the render distance that dissolve begins: a small number keeps it a thin
// band at the end of the chunks, a large one lets the far half of a lake haze over.
override far_water_start: f32 = 124.0;
// How far the block light of `[[lights]]` shifts the light on the surfaces it reaches: brightness
// stays vanilla's, only the hue moves.
override block_light_warmth: f32 = 0.65;

// How much of the world the rain leaves on: rings where the drops land, and how far the ground is
// soaked through.
override rain_rings_ground: f32 = 1.0;
override rain_rings_water: f32 = 1.0;
override wet_ground: f32 = 1.0;

// How thick the air is by day, against vanilla's own fog: 1 is exactly vanilla, 0 no fog at all.
// The dawn and the dusk do not use it — they keep the pack's own thickness.
override day_fog: f32 = 0.0;
// How much of the fog stays where a face sees no sky: 0 clears the caves and the cellars.
override cave_fog: f32 = 0.0;

// --- Shadows -------------------------------------------------------------------

// 1 where the light reaches the point, 0 in shadow. Outside the map's square, and where there is
// no map, everything is lit, so the pack falls back to vanilla's brightness there.
fn shadow_at(p: vec3<f32>, offset_dir: vec3<f32>, ndl: f32) -> f32 {
    if !shadows || frame.has_shadow == 0u {
        return 1.0;
    }
    let dist = length(p);
    if dist >= frame.shadow_distance {
        return 1.0;
    }
    // A surface lit at a slant falls away from the light across each texel, so the offset and the
    // bias grow with the slant; without them the ground shows stripes at a low sun.
    let c = clamp(ndl, 0.06, 1.0);
    let slope = min(sqrt(1.0 - c * c) / c, 6.0);
    let texel = max(frame.shadow_center_texel, 0.005);
    let s = shadow_position(p + offset_dir * texel * (0.7 + 1.6 * slope));
    if any(s.xy <= vec2<f32>(0.0)) || any(s.xy >= vec2<f32>(1.0)) || s.z >= 1.0 {
        return 1.0;
    }
    let m = frame.shadow_view_proj;
    let z_per_block = length(vec3<f32>(m[0].z, m[1].z, m[2].z));
    let z = s.z - z_per_block * texel * (0.5 + 2.0 * slope);

    // Each compare tap is already a 2x2 bilinear filter, so a fixed grid of them needs no noise.
    let t = 1.0 / max(frame.shadow_resolution, 1.0);
    var lit = 0.0;
    if shadow_softness == 0u {
        lit = textureSampleCompareLevel(shadow_map, shadow_sampler, s.xy, z);
    } else if shadow_softness == 1u {
        for (var i = 0; i < 4; i++) {
            let o = vec2<f32>(f32(i & 1), f32(i >> 1)) * 2.0 - 1.0;
            lit += textureSampleCompareLevel(shadow_map, shadow_sampler, s.xy + o * t, z);
        }
        lit *= 0.25;
    } else {
        for (var i = 0; i < 9; i++) {
            let o = vec2<f32>(f32(i % 3), f32(i / 3)) - 1.0;
            lit += textureSampleCompareLevel(shadow_map, shadow_sampler, s.xy + o * 1.5 * t, z);
        }
        lit /= 9.0;
    }
    // The edge of the map fades into vanilla's brightness instead of ending in a line.
    return mix(lit, 1.0, smoothstep(0.85, 1.0, dist / frame.shadow_distance));
}

// --- Air ------------------------------------------------------------------------

// Vanilla's fog, with its colour warmed on a low sun's side: the haze the distance gets at dawn and
// dusk. The distances are vanilla's own (`fog_start`/`fog_end`), so the density is unchanged.
fn air(color: vec3<f32>, position: vec3<f32>, open: f32) -> vec3<f32> {
    // 0.2: Horizon hands the pack `vanilla_fog`, the very curve it would mix itself, so the
    // density matches vanilla exactly; `Day fog` scales it and the hour decides how much.
    let low = 1.0 - smoothstep(0.0, 0.30, abs(frame.sun_direction.y));
    let density = mix(clamp(day_fog, 0.0, 2.0), 1.0, low);
    // Underground the render-distance fog is all there is, and it reads as a fog bank in a cave:
    // `Cave fog` takes it away where the face sees no sky.
    let underground = mix(clamp(cave_fog, 0.0, 1.0), 1.0, open);
    let day = clamp(vanilla_fog(position) * density * underground, 0.0, 1.0);
    // The edge of the render distance always dissolves, whatever `Day fog` says: the last chunks
    // otherwise stand as a wall against the sky, which is exactly what the pack is asked to hide.
    let edge = smoothstep(frame.fog_render.x, frame.fog_render.y, length(position));
    let k = clamp(max(day, edge * 0.92), 0.0, 1.0);
    if k <= 0.0 {
        return color;
    }
    // The warm haze sits on the ground layer and thins with height, the way a valley fills at dusk.
    let height = frame.camera_position.y + position.y;
    let ground = exp(-max(height - 60.0, 0.0) / 28.0);
    let warm = frame.fog_color * vec3<f32>(1.83, 0.65, 0.21) + vec3<f32>(0.003, 0.0006, 0.0);
    // Only the air a face can see the sky through takes the hour's colour: a cave keeps vanilla's
    // fog, so its walls do not turn orange at dusk and do not haze over at all.
    let amount = low * clamp(side_mix(dawn_haze, dusk_haze), 0.0, 1.0)
        * (1.0 - 0.45 * bad_weather()) * (0.45 + 0.75 * ground) * open;
    let fog = mix(frame.fog_color, warm, amount);
    return mix(color, fog, k);
}

// --- Water ----------------------------------------------------------------------

// The ripples live in the normals, and only on the block's top: its sides keep vanilla's shape, so
// water never opens a gap against what is under it.
fn water_normal(world: vec2<f32>) -> vec3<f32> {
    let e = 0.08;
    var h = vec3<f32>(0.0);
    for (var i = 0; i < 3; i++) {
        let s = f32(i);
        let scale = 0.9 * pow(1.9, s);
        let amp = 0.5 * pow(0.5, s);
        let q = world * scale + animation_offset(vec2<f32>(0.6, 0.35) * (1.0 + s * 0.45));
        h.x += noise(q) * amp;
        h.y += noise(q + vec2<f32>(e * scale, 0.0)) * amp;
        h.z += noise(q + vec2<f32>(0.0, e * scale)) * amp;
    }
    let strength = max(water_waves, 0.0) * (0.09 + frame.rain * 0.1);
    return normalize(vec3<f32>((h.x - h.y) / e * strength, 1.0, (h.x - h.z) / e * strength));
}

fn water(input: MaterialInput) -> Surface {
    let vanilla = input.albedo * input.tint * vec4<f32>(input.lightmap, 1.0);
    let nvpos = normalize(input.position);
    let world = input.position + frame.camera_position;

    var n = input.normal;
    if input.face == 1u {
        n = water_normal(world.xz);
        if dot(n, input.normal) < 0.0 {
            n = -n;
        }
        // The drops that land on the water: the same rings and the same settings as the ground's,
        // bent into the surface so they tilt the mirror and the glint.
        let rings = drop_rings(world.xz * 2.2) + drop_rings(world.xz * 2.2 + vec2<f32>(0.5, 0.37));
        n = normalize(n + vec3<f32>(rings.x, 0.0, rings.y) * 0.45);
    }

    // Fresnel: the mirror shows at grazing angles, the water's own colour from above.
    let ndv = clamp(dot(n, -nvpos), 0.0, 1.0);
    let fresnel = (0.02 + 0.98 * pow(1.0 - ndv, 5.0)) * clamp(reflection_strength, 0.0, 1.0);

    // The mirror: vanilla's sky colour when it is off, Horizon's own mirrored world when it is on.
    var mirror = frame.sky_color;
    if water_reflections && frame.has_reflection == 1u {
        let uv = clamp(input.screen + n.xz * 0.03 * max(water_waves, 0.0), vec2<f32>(0.0), vec2<f32>(1.0));
        mirror = textureSampleLevel(reflection, reflection_sampler, uv, 0.0).rgb;
    }

    var col = mix(vanilla.rgb, mirror, fresnel);
    let sky_share = clamp(input.light.y * (1.25 - 0.75 * input.light.x), 0.0, 1.0);
    let dusk = sun_low() * sky_share;
    col = mix(col, col * vec3<f32>(1.94, 0.70, 0.30),
        clamp(dusk * clamp(side_mix(dawn_orange, dusk_orange), 0.0, 2.0), 0.0, 1.0));
    // The sun's glint, in the light's own direction, gone under clouds and rain.
    let h = normalize(frame.light_direction - nvpos);
    let glint = pow(max(dot(n, h), 0.0), 300.0) * 1.5 * max(sun_glint, 0.0) * (1.0 - 0.8 * bad_weather());
    col += vec3<f32>(glint);

    // The rings on the surface, as on the soaked ground but with their own strength: a thin film
    // of light, see-through at a low setting.
    if input.face == 1u {
        let rings = drop_rings(world.xz * 2.2) + drop_rings(world.xz * 2.2 + vec2<f32>(0.5, 0.37));
        let mask = clamp(length(rings) * clamp(rain_rings_water, 0.0, 2.0) * 0.8
            * clamp(max(frame.rain, frame.thunder), 0.0, 1.0), 0.0, 1.0);
        col = mix(col, vec3<f32>(0.65, 0.79, 1.0), mask);
    }

    // Vanilla's water is see-through; this thins it further (the translucent pass blends the world
    // behind it), and never past a quarter of vanilla's opacity.
    var alpha = vanilla.a * (1.0 - 0.75 * clamp(water_transparency, 0.0, 1.0));
    var water = air(max(col, vec3<f32>(0.0)), input.position, smoothstep(0.32, 0.92, input.light.y));

    // The land hides its edge behind `Skyline haze`, but the water cannot: it is translucent, so the
    // void below the last chunk keeps showing through the fog laid over it. Far water is therefore
    // fogged harder than `Day fog` says and its alpha is taken to solid, and the edge disappears.
    // The same for a surface under the camera: `vanilla_fog` already knows about that.
    let end = frame.fog_render.y;
    let begin = max(end - max(far_water_start, 0.0), frame.fog_render.x * 0.5);
    let far = smoothstep(begin, end, length(input.position)) * clamp(far_water, 0.0, 1.0);
    if far > 0.0 {
        water = mix(water, frame.fog_color, far);
        alpha = mix(alpha, 1.0, far);
    }
    return Surface(vec4<f32>(water, alpha));
}

// --- Rain on the ground ----------------------------------------------------------

// 0..1: how soaked an upward face open to the rain is. The biome at the camera has to rain, it must
// not snow, the face has to see the sky, and `wetness` dries slowly after the rain stops.
fn rain_wetness(input: MaterialInput, n: vec3<f32>) -> f32 {
    if frame.dimension != 0 || frame.precipitation == 2u || frame.downfall <= 0.0 {
        return 0.0;
    }
    let up = smoothstep(0.85, 0.96, n.y);
    let open = smoothstep(0.90, 0.97, input.light.y);
    return clamp(max(frame.wetness, frame.rain) * up * open * clamp(wet_ground, 0.0, 1.0), 0.0, 1.0);
}

// Soaked ground: darker and deeper colours, a thin film of water taking the sky's colour, and the
// rings of the drops that land on it — gone with the distance, where they would only be grain.
fn rain_soaked(color: vec3<f32>, albedo: vec3<f32>, tint: vec3<f32>, input: MaterialInput, wetness: f32) -> vec3<f32> {
    let dist = length(input.position);
    let near = 1.0 - smoothstep(20.0, 56.0, dist);
    if near <= 0.001 {
        return color;
    }
    let world = input.position + frame.camera_position;
    var c = color * (1.0 - 0.28 * wetness * near);
    c = mix(c, frame.sky_color * 0.75, wetness * near * 0.20);
    let rings = drop_rings(world.xz * 2.2) + drop_rings(world.xz * 2.2 + vec2<f32>(0.5, 0.37));
    // A mix, not an addition: the ring is a thin film brighter than the ground, and a low value
    // leaves it almost invisible instead of merely dim.
    let mask = clamp(length(rings) * wetness * near
        * clamp(rain_rings_ground, 0.0, 2.0) * 0.8, 0.0, 1.0);
    c = mix(c, vec3<f32>(0.72, 0.83, 1.0), mask);
    return c;
}

// --- The material ---------------------------------------------------------------

fn material(input: MaterialInput) -> Surface {
    if input.fluid == 1u {
        return water(input);
    }

    let albedo = input.albedo.rgb;
    let tint = input.tint.rgb;
    // Vanilla first and whole: what the scene looks like without the pack. In 0.2 the face's shade
    // and the ambient occlusion come as fields of their own, `input.shade` and `input.ao`.
    var color = albedo * tint * input.shade * input.ao * input.lightmap;

    let n = input.normal;
    let l = frame.light_direction;
    let day = daylight();
    // How much of the sky this point sees. Caves, cellars and roofs sit at 0, where no sun
    // component and no shadow apply at all: that is what keeps vanilla's balance.
    let open = smoothstep(0.32, 0.92, input.light.y);
    // A low sun is warm on what it touches: it tints vanilla's own light instead of adding
    // brightness, so stone and grass turn orange at dusk while a cave stays neutral (its `open` is 0).
    let dusk = sun_low();
    // At dawn and dusk the world takes its colour from the sky's own light: everything the sky
    // reaches turns orange, shaded faces included, while block light (fire, torches, lamps) keeps
    // the colour it has of itself — a torch-lit cellar is not painted by the sunset.
    let sky_share = clamp(input.light.y * (1.25 - 0.75 * input.light.x), 0.0, 1.0);
    let dusk_sky = clamp(dusk * sky_share * clamp(side_mix(dawn_orange, dusk_orange), 0.0, 2.0), 0.0, 1.0);
    color *= mix(vec3<f32>(1.0), vec3<f32>(1.94, 0.70, 0.30), dusk_sky);
    let warm_w = clamp(side_mix(dawn_warmth, dusk_warmth), 0.0, 1.0);
    // A low sun also fills the air with its own colour, so a face turned away from it is still lit
    // by that hour instead of dropping back to a cold daylight.
    color += albedo * tint * vec3<f32>(1.0, 0.28, 0.08) * 0.10 * dusk * sky_share;
    let leaf = input.material == MAT_LEAVES;
    let plant = input.material == MAT_PLANT;

    // Foliage faces the light whichever way it turns, and lets a little of it through.
    let facing = dot(n, l);
    var nl = max(facing, 0.0) * smoothstep(0.0, 0.2, facing);
    if leaf {
        nl = pow(clamp(facing * 0.5 + 0.5, 0.0, 1.0), 1.4) * 0.85;
    } else if plant {
        nl = 0.4 + 0.5 * abs(facing);
    }

    // Day lights with the sun, night with the moon: both go through the same shadow map, so the
    // condition is the light itself, not the day.
    let lit_hour = max(day, nightfall() * clamp(moon_strength, 0.0, 2.0));
    if open > 0.001 && lit_hour > 0.001 && shadows {
        let offset_dir = select(n, l, plant);
        let slant = select(facing, 1.0, plant);
        let shadow = shadow_at(input.position, offset_dir, slant);
        // A shadow takes back a share of vanilla's sky light, and never more than `SHADE` times
        // the player's Shadow depth. This works at Sunlight 0 too: shadows shade vanilla's own
        // sky light, they do not come from the light this pack adds.
        let depth = SHADE * clamp(shadow_strength, 0.0, 3.0) * (1.0 + 0.7 * sun_low());
        // By day the sun shades; at night the same map holds the moon, so its light casts the
        // long falling shadows too — weaker, by whatever `Moonlight` asks for.
        let shade_gate = max(day, nightfall() * clamp(moon_strength, 0.0, 2.0) * 0.5);
        color *= clamp(1.0 - depth * shade_gate * open * (1.0 - shadow), 0.0, 1.0);
        // The direct light is the extra, so at Sunlight 0 the world keeps vanilla's brightness.
        // The faces the low sun reaches take its colour outright: this is a shift of hue, not of
        // brightness, so shadowed faces stay as they are and only lit ones turn orange.
        let lit = clamp(nl * shadow * open * dusk, 0.0, 1.0);
        let tint_k = lit * clamp(side_mix(dawn_orange, dusk_orange), 0.0, 2.0) * 0.5 * warm_w;
        if tint_k > 0.001 {
            color = mix(color, color * vec3<f32>(1.55, 0.80, 0.38), clamp(tint_k, 0.0, 1.0));
        }
        let light_color = direct_color();
        if luma(light_color) > 0.0001 {
            color += albedo * tint * light_color * nl * shadow * open;
            // Leaves and blades let the sun through when it is behind them: the warm rim that
            // makes a sunset read on the ground.
            if leaf || plant {
                let to_eye = normalize(-input.position);
                let through = pow(max(dot(to_eye, -l), 0.0), 4.0);
                // The rim keeps a floor: at Sunlight 0 there is still a sun to shine through the
                // blade, and that is what turns a field gold at dawn and dusk.
                color += albedo * tint * rays_hue() * through * (0.06 + 2.2 * luma(light_color)) * shadow * open;
            }
        }
    }

    // Rain: the ground darkens, catches the sky and shows the drops landing on it.
    let wetness = rain_wetness(input, n);
    if wetness > 0.001 {
        color = rain_soaked(color, albedo, tint, input, wetness);
    }

    // Tell the last pass which pixels are terrain, so it can leave them alone when it tints what
    // the terrain stage never draws: mobs, dropped items, particles.
    set_surface(n, 0.0, 0.0);

    // A block that shines keeps shining: redstone, glowstone and lava. Its group decides how
    // bright and how warm that is; above 1 it goes past white, which is what the glow pass picks up.
    // A block that shines keeps shining, in its own texture's colour: the flame, the lantern's core,
    // the lava. No group settings, no flicker damping.
    color = max(color, albedo * tint * input.emission);

    // The block light of `[[lights]]`: a hue shift on what blocks light reaches, its brightness
    // untouched, so a warm torch reads warm without re-lighting the room.
    let warmth = clamp(block_light_warmth, 0.0, 1.0);
    if warmth > 0.0 && input.light.x > 0.01 {
        let placed = block_light_color(input.position);
        let hue = placed.rgb / max(luma(placed.rgb), 0.001);
        let shift = clamp(placed.a, 0.0, 1.0) * clamp(input.light.x, 0.0, 1.0) * warmth;
        color = color * mix(vec3<f32>(1.0), hue, shift);
    }

    // A light source in hand or on the ground: Horizon's dynamic lights, in their `[[lights]]`
    // colour and shifted exactly as the placed ones, added over vanilla's light (vanilla never
    // lights the ground from a hand). Its own model in the first person is drawn by the game, which
    // no stage of this API can tint.
    let carried = input.colored_light;
    let reach = max(carried.r, max(carried.g, carried.b));
    if reach > 0.001 {
        let unit = carried / max(reach, 0.0001);
        let hue = shift_hue(unit, warmth);
        let peak = max(hue.r, max(hue.g, hue.b));
        color += albedo * tint * hue / max(peak, 0.0001) * reach * 0.9;
    }
    return Surface(vec4<f32>(air(max(color, vec3<f32>(0.0)), input.position, open), input.albedo.a));
}
