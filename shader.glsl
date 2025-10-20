
// shader.glsl: Interactive Menger Sponge Shader

#ifdef VERTEX
vec4 position(mat4 transform_projection, vec4 vertex_position) {
    return transform_projection * vertex_position;
}
#endif

#ifdef PIXEL

// --- Uniforms from main.lua ---
uniform float time;             // For color animation
uniform vec4 rotationQuat;      // For interactive rotation (as a quaternion)
uniform float cameraDistance;   // For zoom

//extern vec2 love_ScreenSize;

// --- Render Parameters ---
const int MAX_STEPS = 100;
const float MAX_DIST = 100.0;
const float SURF_DIST = 0.001;

// --- Quaternion Rotation ---
// Rotates a vector v by a quaternion q
vec3 quat_rotate(vec4 q, vec3 v) {
    return v + 2.0 * cross(q.xyz, cross(q.xyz, v) + q.w * v);
}

// --- Menger Sponge SDF ---
float sdMengerSponge(vec3 p) {
    float d = max(max(abs(p.x), abs(p.y)), abs(p.z)) - 1.0;
    float scale = 1.0;
    for (int i = 0; i < 6; i++) {
        vec3 a = mod(p * scale, 2.0) - 1.0;
        scale *= 3.0;
        vec3 r = abs(1.0 - 3.0 * abs(a));
        float da = max(r.x, r.y);
        float db = max(r.y, r.z);
        float dc = max(r.z, r.x);
        float c = (min(da, min(db, dc)) - 1.0) / scale;
        d = max(d, c);
    }
    return d;
}

// --- Scene SDF ---
float map(vec3 p) {
    // Apply interactive rotation from Lua using a quaternion
    p = quat_rotate(rotationQuat, p);
    return sdMengerSponge(p);
}

// --- Get Normal ---
vec3 getNormal(vec3 p) {
    float d = map(p);
    vec2 e = vec2(0.001, 0.0);
    vec3 n = d - vec3(map(p - e.xyy), map(p - e.yxy), map(p - e.yyx));
    return normalize(n);
}

// --- Raymarch ---
float rayMarch(vec3 ro, vec3 rd) {
    float dO = 0.0;
    for (int i = 0; i < MAX_STEPS; i++) {
        vec3 p = ro + rd * dO;
        float dS = map(p);
        dO += dS;
        if (dO > MAX_DIST || dS < SURF_DIST) break;
    }
    return dO;
}

// --- Main Effect Function ---
vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec2 uv = (2.0 * screen_coords/love_ScreenSize.xy - 1.0);
    uv.x *= love_ScreenSize.x / love_ScreenSize.y;

    vec3 ro = vec3(0.0, 0.0, cameraDistance);
    vec3 rd = normalize(vec3(uv, -2.0));

    float d = rayMarch(ro, rd);
    vec3 col = vec3(0.0);

    if (d < MAX_DIST) {
        vec3 p = ro + rd * d;
        vec3 normal = getNormal(p);
        
        vec3 lightPos = vec3(2.0, 3.0, 4.0);
        vec3 lightDir = normalize(lightPos - p);
        float diffuse = max(dot(normal, lightDir), 0.1);
        
        // "Rave" color effect using time
        vec3 dynamicColor;
        dynamicColor.r = 0.5 + 0.5 * sin(p.x * 2.0 + time * 1.5);
        dynamicColor.g = 0.5 + 0.5 * sin(p.y * 2.0 + time * 1.5 + 2.0);
        dynamicColor.b = 0.5 + 0.5 * sin(p.z * 2.0 + time * 1.5 + 4.0);

        col = dynamicColor * diffuse;
    }

    return vec4(col, 1.0);
}
#endif
