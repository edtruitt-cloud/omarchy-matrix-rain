#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float cellSize;
    float speed;
    float density;
    float iWidth;
    float iHeight;
    float atlasCols;
    float atlasRows;
    vec4 glyphSet;     // glyphs used: (start, count, start2, count2) in the atlas
    vec4 headColor;
    vec4 bodyColor;
    vec4 tailColor;
    float seed;   // 0 for the main layer; the depth layer uses another pattern
    float flash;  // 0 = normal; beat / notification brightness boost
    float trailScale;    // trail length (1 = original)
    float glyphFlicker;  // how fast characters change (1 = original, 0 = frozen)
    float colorMode;     // 0 single colour, 1 per-stream, 2 vertical gradient, 3 rainbow
    vec4 colorA;
    vec4 colorB;
    vec4 colorC;
    vec4 colorD;
    float colorVariation;  // multi-colour looks: how much darker a few streams get
    float crt;         // 0..1: scanlines and darker corners
    float glitch;      // 0..1: glitch event strength (bands tear sideways)
    float glitchSeed;  // changes every few frames during a glitch
    float zoom;        // camera zoom about the screen centre (1 = none; Dive event)
    float panX;        // camera slide in pixels (0 = none; Pan event)
    float binary;      // 1 = every glyph is 0 or 1 (Binary event)
    float mirror;      // 0..1: share of glyphs drawn mirrored
    float weight;      // 0..1: bolder glyphs
    float gravity;     // 0..1: streams speed up as they fall
    float speedVariety;  // 0..2: spread of stream speeds (1 = original)
    float trailVariety;  // 0..3: spread of trail lengths (1 = original)
    float drift;       // Drift event phase: some streams pulled ahead, some behind
    float headGlow;    // 0..1: bigger, brighter stream heads
    float bloom;       // 0..1: soft halo around glyphs
    float aberration;  // 0..1: red/blue fringes
    float vignette;    // 0..1: darker corners (separate from CRT)
    vec4 mouse;        // cursor (x, y) in pixels, strength 0..1, radius px
    vec2 cascade;      // Cascade event: progress (0 = off), seed
    float headMode;    // 0 the look's own heads, 1 headFixed, 2 same as the body
    vec4 headFixed;
    vec4 rip0;         // typing ripples: centre (x, y) as screen fractions, age s, strength
    vec4 rip1;
    vec4 rip2;
    vec4 rip3;
    vec4 rip4;
    vec4 rip5;
    float customRows;  // > 0: glyphs come from your own symbols (customAtlas, 16 per row)
};

layout(binding = 1) uniform sampler2D atlas;
layout(binding = 2) uniform sampler2D customAtlas;

// Glyph coverage from the rain's atlas or, for the Custom set, your own.
float tex(vec2 uv, vec2 gx, vec2 gy) {
    return customRows > 0.5 ? textureGrad(customAtlas, uv, gx, gy).a : textureGrad(atlas, uv, gx, gy).a;
}

float hash(float n) {
    return fract(sin(n) * 43758.5453123);
}

vec3 hueColor(float h) {
    vec3 k = clamp(abs(fract(h + vec3(0.0, 2.0, 1.0) / 3.0) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
    return k;
}

vec3 pick4(float i) {
    return i < 0.5 ? colorA.rgb : i < 1.5 ? colorB.rgb : i < 2.5 ? colorC.rgb : colorD.rgb;
}

float hash2(float a, float b) {
    return fract(sin(a * 12.9898 + b * 78.233) * 43758.5453);
}

// Scanlines and a vignette, on the premultiplied output.
vec4 crtFinish(vec4 c) {
    float vd = length(qt_TexCoord0 - 0.5) * 1.41;
    c *= 1.0 - vignette * 0.85 * vd * vd;
    if (crt <= 0.0)
        return c;
    float y = qt_TexCoord0.y * iHeight;
    float scan = 1.0 - crt * 0.45 * step(1.0, mod(floor(y), 3.0));
    return c * scan * (1.0 - crt * 0.55 * vd * vd);
}

// A typing ripple: a bright letter where the key landed and a ring of lit
// letters spreading from it.
float ripple(vec4 r, float col, float row, float nCols, float nRows) {
    if (r.w <= 0.0 || r.z > 1.4)
        return 0.0;
    vec2 d = vec2((col - floor(r.x * nCols)) * 1.45, (row - floor(r.y * nRows)) * 1.35) / 1.4;
    float dist = length(d);
    float life = 1.0 - r.z / 1.4;
    float ring = exp(-pow(dist - r.z * 11.0, 2.0) / 3.0) * life;
    float centre = dist < 0.5 ? max(0.0, 1.0 - r.z / 0.8) : 0.0;
    return min(1.0, r.w * 1.6 * max(ring, centre));
}

// A glyph from the chosen set (one or two ranges of the atlas).
float setGlyph(float r) {
    float total = max(glyphSet.y + glyphSet.w, 1.0);
    float k = min(floor(r * total), total - 1.0);
    return k < glyphSet.y ? glyphSet.x + k : glyphSet.z + (k - glyphSet.y);
}

void main() {
    vec2 pix = qt_TexCoord0 * vec2(iWidth, iHeight);
    // The cursor parts the rain: columns bend around it (the one case where
    // streams do not fall straight down).
    if (mouse.z > 0.0) {
        vec2 d = pix - mouse.xy;
        float f = exp(-dot(d, d) / (mouse.w * mouse.w));
        pix.x -= sign(d.x) * f * mouse.z * mouse.w * 0.55;
    }
    // Camera events: slide sideways, then zoom about the centre. Scaling
    // the coordinates (not the cell size) keeps every stream in its column.
    pix.x += panX;
    pix = 0.5 * vec2(iWidth, iHeight) + (pix - 0.5 * vec2(iWidth, iHeight)) / max(zoom, 0.05);

    // Glitch event: random horizontal bands tear sideways (no-op at 0).
    float torn = 0.0;
    if (glitch > 0.0) {
        float band = floor(pix.y / (max(cellSize, 4.0) * 2.7));
        if (hash(band * 1.7 + glitchSeed) < 0.35 * glitch) {
            torn = 1.0;
            pix.x += (hash(band * 7.3 + glitchSeed) - 0.5) * glitch * iWidth * 0.12;
        }
    }
    float cell = max(cellSize, 4.0);
    // Rows are taller than the letter size so glyphs stand tall, not squashed.
    float cellH = cell * 1.35;
    // Texture gradients from the continuous glyph coordinate. Implicit ones
    // jump at every cell edge and sample a blurry mip there, which draws
    // faint outline lines beside the streams.
    vec2 atlasGrid = customRows > 0.5 ? vec2(16.0, customRows) : vec2(atlasCols, atlasRows);
    vec2 gradX = dFdx(pix / vec2(cell, cellH)) / atlasGrid;
    vec2 gradY = dFdy(pix / vec2(cell, cellH)) / atlasGrid;

    // Letter size is the glyph; a little extra column pitch keeps the rain
    // from packing into a solid curtain.
    float pitch = cell * 1.45;
    float col = floor(pix.x / pitch);
    float row = floor(pix.y / cellH);
    vec2 local = vec2(fract(pix.x / pitch) * (pitch / cell), fract(pix.y / cellH));

    // Glyphs only occupy the left of each pitched column. The rest is void.
    if (local.x > 1.0) {
        fragColor = vec4(0.0);
        return;
    }

    float nRows = max(floor(iHeight / cellH), 8.0);
    float nCols = max(floor(iWidth / pitch), 1.0);

    // Letters that light up on their own: the Cascade event (a wave that
    // lights every letter, each at its own time) and typing ripples.
    float special = 0.0;
    if (cascade.x > 0.0) {
        float x = (col + 0.5) / nCols;
        // Uneven sweep: the wave speeds up and slows down across the screen,
        // and every letter has its own small delay.
        float w = x + 0.07 * sin(6.2832 * x * 1.3 + cascade.y) + 0.035 * sin(6.2832 * x * 3.7 + cascade.y * 2.1);
        float tc = w + hash2(col * 1.31 + cascade.y, row * 0.77) * 0.16;
        float d = cascade.x - tc;
        if (d > 0.0) {
            float c = smoothstep(0.0, 0.012, d) * exp(-d * 7.0);
            if (c > special) special = c;
        }
    }

    special = max(special, max(max(ripple(rip0, col, row, nCols, nRows), ripple(rip1, col, row, nCols, nRows)),
                               max(ripple(rip2, col, row, nCols, nRows), ripple(rip3, col, row, nCols, nRows))));
    special = max(special, max(ripple(rip4, col, row, nCols, nRows), ripple(rip5, col, row, nCols, nRows)));

    // Sparse columns: density is the fraction that rain at all.
    float colSeed = hash(col + 11.0 + seed);
    bool rains = colSeed <= clamp(density, 0.05, 1.0);
    if (!rains && special <= 0.002) {
        fragColor = vec4(0.0);
        return;
    }

    // `time` is already integrated fall distance from QML. Do not multiply
    // by the live speed uniform — that rewinds streams when the synth LFO
    // (lfoDest=speed) slows down, which looks like rain falling up.
    float streamSpeed = max(0.05, 0.675 + (hash(col + 3.0 + seed) - 0.5) * 0.65 * speedVariety);
    // QML wraps `time` every PERIOD units so float precision holds over long
    // sessions. Fall rates are whole cycles per PERIOD, so heads line up
    // exactly across the wrap. Keep PERIOD in sync with Service.qml rainPeriod.
    const float PERIOD = 256.0;
    float fallRate = floor(streamSpeed * 0.22 * PERIOD + 0.5) / PERIOD;
    float head = fract(time * fallRate + hash(col + 19.0 + seed) + drift * (hash(col + 53.0 + seed) - 0.5));
    float yNorm = (row + 0.5) / nRows;
    // Gravity: streams fall slowly near the top and faster further down.
    // Measured in time rather than on screen (each row is where the head is
    // at that moment), so trails stretch as they speed up and the screen
    // fills evenly (warping the head's position bunched the rain at the top
    // and, by the trail wrap, at the bottom).
    // Speed grows steadily down the screen (up to 4x at the bottom at 100%),
    // from a moving start so the top isn't crushed into a crawl.
    float k = 3.0 * gravity;
    // Rows beyond the screen (zoomed-out depth layers reach above and below
    // it) repeat the mapping, so it stays defined and continuous there.
    float yTime = yNorm;
    if (k > 0.0) {
        float lap = floor(yNorm);
        yTime = lap + log(1.0 + k * (yNorm - lap)) / log(1.0 + k);
    }
    float dist = fract(head - yTime + 1.0);

    float trail = clamp((0.31 + (hash(col + 7.0 + seed) - 0.5) * 0.18 * trailVariety) * trailScale, 0.03, 0.95);
    float intensity = 1.0 - smoothstep(0.0, trail, dist);
    intensity *= intensity;

    // Cut the wrap-around so streams don't fill the whole column.
    if (!rains || dist > trail) {
        if (special <= 0.002) {
            fragColor = vec4(0.0);
            return;
        }
        intensity = 0.0;
        dist = 1.0;
    }

    // Head of the stream is hot phosphor; body is the rain colour; tail fades
    // to void. Colours come from Service.qml; the default is classic green.
    vec3 headCol = headColor.rgb;
    vec3 bodyCol = bodyColor.rgb;
    vec3 tailCol = tailColor.rgb;
    if (colorMode > 0.5) {
        // Multi-colour looks: pick this stream's body colour, then derive a
        // near-white head and a dim tail from it, as for single colours.
        vec3 body;
        if (colorMode < 1.5) {
            body = pick4(floor(hash(col + 23.0 + seed) * 4.0));
        } else if (colorMode < 2.5) {
            float y = clamp(pix.y / iHeight, 0.0, 1.0) * 3.0;
            float i = min(floor(y), 2.0);
            body = mix(pick4(i), pick4(i + 1.0), y - i);
        } else {
            // 4 whole hue cycles per 256 time units, so the wrap is seamless.
            body = hueColor(fract(col * 0.037 + time / 64.0));
        }
        float v = hash(col + 41.0 + seed);
        body *= 1.0 - colorVariation * v * v * v;  // most streams near 1, a few darker
        bodyCol = body;
        headCol = mix(body, vec3(1.0), 0.91);
        tailCol = body * 0.32;
    }
    if (headMode > 1.5)
        headCol = bodyCol;
    else if (headMode > 0.5)
        headCol = headFixed.rgb;
    // Change glyphs slowly as they fall so it reads as code, not a static grid.
    float tick = floor(time * (4.0 + 6.0 * streamSpeed) * glyphFlicker + row * 0.15);
    float g = setGlyph(hash2(col + seed * 13.0, row + tick));
    // Binary event: '0' and '1' are atlas glyphs 45 and 46 (build-atlas.py
    // ORIGINAL keeps its 64 characters first).
    if (binary > 0.5)
        g = 45.0 + floor(hash2(col + seed * 13.0, row + tick) * 2.0);
    if (mirror > 0.0 && hash2(col * 3.1 + seed, row + floor(tick * 0.37)) < mirror)
        local.x = 1.0 - local.x;
    vec2 tile = vec2(mod(g, atlasGrid.x), floor(g / atlasGrid.x));
    vec2 uv = (tile + local) / atlasGrid;
    float glyph = tex(uv, gradX, gradY);
    if (weight > 0.0) {
        // Bolder: take the strongest of the glyph and slightly shifted copies.
        float o = 0.05 * weight;
        glyph = max(glyph, tex((tile + vec2(clamp(local.x - o, 0.0, 1.0), local.y)) / atlasGrid, gradX, gradY));
        glyph = max(glyph, tex((tile + vec2(clamp(local.x + o, 0.0, 1.0), local.y)) / atlasGrid, gradX, gradY));
        glyph = min(1.0, glyph * (1.0 + weight));
    }
    float halo = 0.0;
    if (bloom > 0.0)
        halo = min(1.0, tex(uv, gradX * 7.0, gradY * 7.0) * 2.2) * bloom;
    if (glyph < 0.08 && halo < 0.02) {
        fragColor = vec4(0.0);
        return;
    }

    float headMix = 1.0 - smoothstep(0.0, 0.035 * (1.0 + 2.5 * headGlow), dist);
    vec3 color = mix(tailCol, bodyCol, intensity);
    color = mix(color, headCol, headMix);
    color *= 1.0 + headGlow * 0.6 * headMix;
    float lit = max(intensity, special);
    if (special > 0.0)
        color = mix(color, mix(bodyCol, headCol, 0.7) * 1.35, special);
    float shape = glyph + halo * 0.85 * (1.0 - glyph);
    vec3 fringe = vec3(1.0);
    if (aberration > 0.0 && glyph > 0.0) {
        // Red and blue copies shifted apart inside the glyph's tile.
        float o = 0.09 * aberration;
        float gl = tex((tile + vec2(clamp(local.x - o, 0.0, 1.0), local.y)) / atlasGrid, gradX, gradY);
        float gr = tex((tile + vec2(clamp(local.x + o, 0.0, 1.0), local.y)) / atlasGrid, gradX, gradY);
        shape = max(shape, max(gl, gr));
        fringe = vec3(gl, glyph, gr) / max(shape, 0.001);
    }
    color *= shape * fringe * (0.70 + 0.30 * lit);
    color *= (1.0 + flash) * (1.0 + 0.8 * bloom * halo);
    if (torn > 0.5)
        color = color.gbr;  // torn bands shift colour, like a corrupted signal

    fragColor = crtFinish(vec4(color, shape * clamp(lit * 1.25 + headMix + special, 0.0, 1.0)) * qt_Opacity);
}
