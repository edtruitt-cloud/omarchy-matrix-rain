#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float iWidth;
    float iHeight;
    float walkSpeed;
    float density;
    float atlasCols;
    float atlasRows;
    vec4 glyphSet;     // glyphs used: (start, count, start2, count2) in the atlas
    float cellScale;
    vec4 headColor;
    vec4 bodyColor;
    vec4 tailColor;
    vec4 hazeColor;
    vec4 bgColor;
    // Wallpaper look (Screensaver.qml): trail length, glyph flicker, CRT,
    // multi-colour modes (0 single, 1 per-stream, 2 gradient, 3 rainbow).
    float trailScale;
    float glyphFlicker;
    float crt;
    float colorMode;
    vec4 colorA;
    vec4 colorB;
    vec4 colorC;
    vec4 colorD;
    float colorVariation;
    // Events: glitch tear, 0/1 glyphs, sideways camera drift.
    float glitch;
    float glitchSeed;
    float binary;
    float panX;
    // Glyph shape and stream motion (wallpaper LOOK settings).
    float mirror;
    float weight;
    float gravity;
    float speedVariety;
    float trailVariety;
    float drift;       // Drift event: some streams pulled ahead, some behind
    // Light.
    float headGlow;
    float bloom;
    float aberration;
    float vignette;
    float headMode;    // 0 the look's own heads, 1 headFixed, 2 same as the body
    vec4 headFixed;
    // Depth layer colours, as on the wallpaper: the rain is slot 0 and layer
    // k is slot k; slices pass through them with distance. layerSlots = the
    // number of layer slots in use (0 = everything in the rain's colour).
    float layerSlots;
    vec4 l1Info;     // layer 1: mode, variation
    vec4 l1Head;
    vec4 l1Body;
    vec4 l1Tail;
    vec4 l1A;
    vec4 l1B;
    vec4 l1C;
    vec4 l1D;
    vec4 l2Info;     // layer 2: mode, variation
    vec4 l2Head;
    vec4 l2Body;
    vec4 l2Tail;
    vec4 l2A;
    vec4 l2B;
    vec4 l2C;
    vec4 l2D;
    vec4 l3Info;     // layer 3: mode, variation
    vec4 l3Head;
    vec4 l3Body;
    vec4 l3Tail;
    vec4 l3A;
    vec4 l3B;
    vec4 l3C;
    vec4 l3D;
    vec4 l4Info;     // layer 4: mode, variation
    vec4 l4Head;
    vec4 l4Body;
    vec4 l4Tail;
    vec4 l4A;
    vec4 l4B;
    vec4 l4C;
    vec4 l4D;
    vec4 l5Info;     // layer 5: mode, variation
    vec4 l5Head;
    vec4 l5Body;
    vec4 l5Tail;
    vec4 l5A;
    vec4 l5B;
    vec4 l5C;
    vec4 l5D;
    vec2 cascade;      // Cascade event: progress (0 = off), seed
};

layout(binding = 1) uniform sampler2D atlas;

float hash(float n) {
    return fract(sin(n) * 43758.5453123);
}

float hash2(float a, float b) {
    return fract(sin(a * 12.9898 + b * 78.233) * 43758.5453);
}

vec3 pick4(float i) {
    return i < 0.5 ? colorA.rgb : i < 1.5 ? colorB.rgb : i < 2.5 ? colorC.rgb : colorD.rgb;
}

// One colour look: its mode and variation, head, body and tail, and the four
// colours multi-colour modes pick from.
struct Look {
    float mode;
    float variation;
    vec3 head;
    vec3 body;
    vec3 tail;
    vec3 a;
    vec3 b;
    vec3 c;
    vec3 d;
};

Look slotLook(int k) {
    if (k == 1)
        return Look(l1Info.x, l1Info.y, l1Head.rgb, l1Body.rgb, l1Tail.rgb, l1A.rgb, l1B.rgb, l1C.rgb, l1D.rgb);
    if (k == 2)
        return Look(l2Info.x, l2Info.y, l2Head.rgb, l2Body.rgb, l2Tail.rgb, l2A.rgb, l2B.rgb, l2C.rgb, l2D.rgb);
    if (k == 3)
        return Look(l3Info.x, l3Info.y, l3Head.rgb, l3Body.rgb, l3Tail.rgb, l3A.rgb, l3B.rgb, l3C.rgb, l3D.rgb);
    if (k == 4)
        return Look(l4Info.x, l4Info.y, l4Head.rgb, l4Body.rgb, l4Tail.rgb, l4A.rgb, l4B.rgb, l4C.rgb, l4D.rgb);
    if (k == 5)
        return Look(l5Info.x, l5Info.y, l5Head.rgb, l5Body.rgb, l5Tail.rgb, l5A.rgb, l5B.rgb, l5C.rgb, l5D.rgb);
    return Look(colorMode, colorVariation, headColor.rgb, bodyColor.rgb, tailColor.rgb, colorA.rgb, colorB.rgb, colorC.rgb, colorD.rgb);
}

vec3 pickLook(Look L, float i) {
    return i < 0.5 ? L.a : i < 1.5 ? L.b : i < 2.5 ? L.c : L.d;
}

// A glyph from the chosen set (one or two ranges of the atlas).
float setGlyph(float r) {
    float total = max(glyphSet.y + glyphSet.w, 1.0);
    float k = min(floor(r * total), total - 1.0);
    return k < glyphSet.y ? glyphSet.x + k : glyphSet.z + (k - glyphSet.y);
}

vec3 hueColor(float h) {
    return clamp(abs(fract(h + vec3(0.0, 2.0, 1.0) / 3.0) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
}

// One look's colours for a glyph: head, body and tail (multi-colour modes
// pick the body per stream and derive the head and tail from it).
void lookColors(Look L, vec2 id, float screenY, float t, out vec3 headCol, out vec3 bodyCol, out vec3 tailCol) {
    headCol = L.head;
    bodyCol = L.body;
    tailCol = L.tail;
    if (L.mode > 0.5) {
        vec3 body;
        if (L.mode < 1.5) {
            body = pickLook(L, floor(hash2(id.x + 23.0, id.y) * 4.0));
        } else if (L.mode < 2.5) {
            float y = clamp(screenY, 0.0, 1.0) * 3.0;
            float i = min(floor(y), 2.0);
            body = mix(pickLook(L, i), pickLook(L, i + 1.0), y - i);
        } else {
            body = hueColor(fract(id.x * 0.037 + id.y * 0.11 + t / 64.0));
        }
        float v = hash2(id.x + 41.0, id.y);
        body *= 1.0 - L.variation * v * v * v;
        bodyCol = body;
        headCol = mix(body, vec3(1.0), 0.91);
        tailCol = body * 0.32;
    }
}

vec3 glyphColor(float dist, float intensity, vec2 id, float screenY, float t, float z) {
    // Colours follow the Matrix Rain wallpaper setting (Screensaver.qml).
    // With depth layer colours, a slice's distance picks the layer slots it
    // lies between (rain nearest, the last layer farthest) and blends them,
    // so colours travel with the slices as they rush toward you.
    vec3 headCol, bodyCol, tailCol;
    // The nearest slices (you walk through them) stay the rain's own colour.
    float pos = clamp((z - 0.12) / 0.6, 0.0, 1.0) * layerSlots;
    int k = int(floor(pos));
    float f = pos - floor(pos);
    lookColors(slotLook(k), id, screenY, t, headCol, bodyCol, tailCol);
    if (f > 0.0 && float(k) < layerSlots) {
        vec3 h2, b2, t2;
        lookColors(slotLook(k + 1), id, screenY, t, h2, b2, t2);
        headCol = mix(headCol, h2, f);
        bodyCol = mix(bodyCol, b2, f);
        tailCol = mix(tailCol, t2, f);
    }
    if (headMode > 1.5)
        headCol = bodyCol;
    else if (headMode > 0.5)
        headCol = headFixed.rgb;
    float headMix = 1.0 - smoothstep(0.0, 0.045 * (1.0 + 2.5 * headGlow), dist);
    vec3 color = mix(tailCol, bodyCol, intensity);
    color = mix(color, headCol, headMix);
    return color * (1.0 + headGlow * 0.6 * headMix);
}

float streamAt(vec2 id, float row, float t) {
    // Speed and trail variety spread the original ranges (1 = original).
    float speed = max(1.0, 13.0 + (hash2(id.x, id.y + 3.0) - 0.5) * 10.0 * speedVariety) * max(walkSpeed, 0.2);
    float headRow = t * speed + hash2(id.x + 19.0, id.y) * 90.0 + drift * (hash2(id.x + 53.0, id.y) - 0.5) * 40.0;
    float trailLen = max(3.0, 27.0 + (hash2(id.x + 7.0, id.y + 2.0) - 0.5) * 18.0 * trailVariety) * clamp(trailScale, 0.3, 2.5);
    float period = trailLen + mix(3.0, 10.0, hash2(id.x + 5.0, id.y + 11.0));
    float behind = mod(headRow - row, period);
    if (behind > trailLen)
        return -1.0;
    return behind / trailLen;
}

// `grad` is how far `local` moves per screen pixel. Passing it explicitly
// keeps the mip level continuous: implicit derivatives jump at every glyph
// cell edge and sample a blurry mip, drawing outline lines.
// `grad` is how far `local` moves per screen pixel. Passing it explicitly
// keeps the mip level continuous: implicit derivatives jump at every glyph
// cell edge and sample a blurry mip, drawing outline lines.
float glyphAt(vec2 tile, vec2 local, float grad, float blur) {
    vec2 uv = (tile + clamp(local, 0.0, 1.0)) / vec2(atlasCols, atlasRows);
    return textureGrad(atlas, uv, vec2(grad * blur / atlasCols, 0.0), vec2(0.0, grad * blur / atlasRows)).a;
}

// `special` lights a glyph on its own (Cascade), even where no stream is.
vec4 sampleGlyph(vec2 id, float row, vec2 local, float grad, float t, float dist, float screenY, float z, float special) {
    float tick = floor(t * (5.0 + 8.0 * hash2(id.x, id.y + 4.0)) * glyphFlicker + row * 0.35);
    float g = setGlyph(hash2(id.x + tick, row + id.y));
    if (binary > 0.5)  // '0' and '1' are atlas glyphs 45 and 46
        g = 45.0 + floor(hash2(id.x + tick, row + id.y) * 2.0);
    if (mirror > 0.0 && hash2(id.x * 3.1 + id.y, row + floor(tick * 0.37)) < mirror)
        local.x = 1.0 - local.x;
    vec2 tile = vec2(mod(g, atlasCols), floor(g / atlasCols));
    float glyph = glyphAt(tile, local, grad, 1.0);
    if (weight > 0.0) {
        float o = 0.05 * weight;
        glyph = max(glyph, max(glyphAt(tile, local - vec2(o, 0.0), grad, 1.0), glyphAt(tile, local + vec2(o, 0.0), grad, 1.0)));
        glyph = min(1.0, glyph * (1.0 + weight));
    }
    float halo = bloom > 0.0 ? min(1.0, glyphAt(tile, local, grad, 7.0) * 2.2) * bloom : 0.0;
    if (glyph < 0.08 && halo < 0.02)
        return vec4(0.0);

    float intensity = 1.0 - smoothstep(0.0, 0.42, dist);
    intensity *= intensity;
    float headMix = 1.0 - smoothstep(0.0, 0.04 * (1.0 + 2.5 * headGlow), dist);
    vec3 color = glyphColor(dist, intensity, id, screenY, t, z);
    float lit = max(intensity, special);
    if (special > 0.0) {
        vec3 h, b, tl;
        lookColors(slotLook(0), id, screenY, t, h, b, tl);
        color = mix(color, mix(b, h, 0.7) * 1.35, special);
    }
    float shape = glyph + halo * 0.85 * (1.0 - glyph);
    vec3 fringe = vec3(1.0);
    if (aberration > 0.0 && glyph > 0.0) {
        float o = 0.09 * aberration;
        float gl = glyphAt(tile, local - vec2(o, 0.0), grad, 1.0);
        float gr = glyphAt(tile, local + vec2(o, 0.0), grad, 1.0);
        shape = max(shape, max(gl, gr));
        fringe = vec3(gl, glyph, gr) / max(shape, 0.001);
    }
    color *= shape * fringe * (0.80 + 0.55 * lit) * (1.0 + 0.8 * bloom * halo);
    float alpha = shape * clamp(lit + headMix + special, 0.0, 1.0);
    return vec4(color, alpha);
}

void main() {
    vec2 uv = qt_TexCoord0 * 2.0 - 1.0;
    uv.x *= max(iWidth, 1.0) / max(iHeight, 1.0);

    float t = time;
    float spd = max(walkSpeed, 0.2);

    // Walk: stride bob and a slow weave so streams pass left and right of you.
    uv.x += sin(t * 0.33) * 0.05 + sin(t * 0.11) * 0.02;
    uv.y += sin(t * 8.4) * 0.014 + sin(t * 4.2) * 0.006;
    uv.y -= 0.06;
    uv.x += panX;
    // Gravity: squeeze the rows near the top and stretch them lower down,
    // so streams move slowly up there and faster as they fall.
    if (gravity > 0.0)
        uv.y -= gravity * 0.35 * uv.y * uv.y;
    float screenY = qt_TexCoord0.y;

    // Glitch event: random horizontal bands tear sideways.
    float torn = 0.0;
    if (glitch > 0.0) {
        float band = floor(qt_TexCoord0.y * 40.0);
        if (hash(band * 1.7 + glitchSeed) < 0.35 * glitch) {
            torn = 1.0;
            uv.x += (hash(band * 7.3 + glitchSeed) - 0.5) * glitch * 0.5;
        }
    }

    vec3 acc = vec3(0.0);
    float alpha = 0.0;

    // Depth slices rush toward the camera. Small z = you are walking through
    // a stream (glyphs fill the view). Large z = distant curtain of rain.
    const int LAYERS = 16;
    float nLayers = float(LAYERS);
    for (int i = 0; i < LAYERS; i++) {
        if (alpha > 0.97)
            break;

        float fi = float(i);
        float z = fract(fi / nLayers - t * spd * 0.22);
        float persp = 0.035 + z * 2.15;
        vec2 p = uv * persp;
        p.x += sin(t * 0.19 + fi * 0.4) * 0.22;

        // Glyph size follows the wallpaper's letter size (16 px = 1.0).
        float cell = 0.10 * clamp(cellScale, 0.4, 1.8);
        float pitch = cell * 1.38;
        float col = floor(p.x / pitch);
        float row = floor(p.y / cell);
        vec2 local = vec2(fract(p.x / pitch) * (pitch / cell), fract(p.y / cell));
        if (local.x > 1.0)
            continue;

        vec2 id = vec2(col, fi + 3.0);
        if (hash2(id.x + 11.0, id.y + 3.0) > clamp(density, 0.12, 0.98))
            continue;

        // Cascade: a wave across the screen that lights every letter, each at
        // its own moment, and not at a steady speed.
        float special = 0.0;
        if (cascade.x > 0.0) {
            float x = qt_TexCoord0.x;
            float w = x + 0.07 * sin(6.2832 * x * 1.3 + cascade.y) + 0.035 * sin(6.2832 * x * 3.7 + cascade.y * 2.1);
            float d = cascade.x - (w + hash2(col * 1.31 + cascade.y + id.y, row * 0.77) * 0.16);
            if (d > 0.0)
                special = smoothstep(0.0, 0.012, d) * exp(-d * 7.0);
        }

        float dist = streamAt(id, row, t);
        if (dist < 0.0) {
            if (special <= 0.002)
                continue;
            dist = 1.0;
        }

        // uv spans 2 units over iHeight pixels, scaled by persp, in cells of `cell`.
        float grad = persp * 2.0 / (max(iHeight, 1.0) * cell);
        vec4 gcol = sampleGlyph(id, row, vec2(local.x, 1.0 - local.y), grad, t, dist, screenY, z, special);
        if (gcol.a < 0.02)
            continue;

        float near = 1.0 - z;
        float fade = pow(near, 1.15);
        float passThrough = exp(-z * 9.0);
        float layerA = gcol.a * mix(fade, 1.0, passThrough * 0.65);
        vec3 lit = gcol.rgb * (0.55 + 0.85 * near) * (1.0 + 1.8 * passThrough);

        acc += lit * layerA * (1.0 - alpha);
        alpha += layerA * (1.0 - alpha);
    }

    float haze = 0.12 * exp(-abs(uv.y) * 0.22);
    // With depth layer colours, the distant haze takes the farthest one on.
    vec3 hazeCol = layerSlots > 0.0 ? mix(hazeColor.rgb, slotLook(int(layerSlots)).body * 0.2, 0.7) : hazeColor.rgb;
    acc += hazeCol * haze * (1.0 - alpha);
    alpha = max(alpha, haze);

    vec3 bg = bgColor.rgb;
    vec3 color = mix(bg, acc, clamp(alpha, 0.0, 1.0));

    if (torn > 0.5)
        color = color.gbr;  // torn bands shift colour
    if (crt > 0.0) {
        // Scanlines and darker corners, as on the wallpaper.
        float scan = 1.0 - crt * 0.45 * step(1.0, mod(floor(qt_TexCoord0.y * iHeight), 3.0));
        float vd = length(qt_TexCoord0 - 0.5) * 1.41;
        color *= scan * (1.0 - crt * 0.55 * vd * vd);
    }
    if (vignette > 0.0) {
        float vd = length(qt_TexCoord0 - 0.5) * 1.41;
        color *= 1.0 - vignette * 0.85 * vd * vd;
    }
    fragColor = vec4(color, 1.0) * qt_Opacity;
}
