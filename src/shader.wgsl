struct VertexInput {
    @location(0) position: vec3<f32>,
};

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
};

struct GlobalUniform {
    resolution: vec2<f32>,
    time: f32,
    seed: u32,
}

@group(0) @binding(0)
var<uniform> globals: GlobalUniform;

@vertex
fn vs_main(input: VertexInput) -> VertexOutput {
    var output: VertexOutput;
    output.position = vec4<f32>(input.position, 1.0);
    return output;
}

@fragment
fn fs_main(vertex_output: VertexOutput) -> @location(0) vec4<f32> {
    var aspect_ratio = globals.resolution.x / globals.resolution.y;
    var frag_coord = vec2<f32>(vertex_output.position.xy / globals.resolution.xy - 0.5);
    frag_coord.x *= aspect_ratio;

    var camera_pos = vec3<f32>(0.0, 2.0, -2.0); // Changed camera position
    var camera_dir = normalize(vec3<f32>(frag_coord.x, -frag_coord.y, 1.0)); // Changed camera direction
    var ray_origin = camera_pos;
    var ray_direction = camera_dir;

    var distance = ray_march(ray_origin, ray_direction);
    var position = ray_origin + ray_direction * distance;

    // ambient light
    

    // lighting
    let diffuse = get_light(position);
    let color = vec3<f32>(diffuse, diffuse, diffuse);

    return vec4<f32>(color, 1.0);
}

fn calc_shadow(ro: vec3<f32>, rd: vec3<f32>, k: f32) -> f32 {
    var res = 1.0;
    var t = 0.05;

    for (var i = 0u; i < 150u; i = i + 1u) {
        let pos = ro + t * rd;
        let h = get_dist(pos);
        res = min(res, k * max(h, 0.0) / t);
        if (res < 0.0001) {
            break;
        }
        t += clamp(h, 0.01, 0.5);
    }

    return res;
}

fn get_light(position: vec3<f32>) -> f32 {
    let surf_dist = 0.01;

    var radius = 5.0; // Set the radius of the circle
    var speed = 1.0; // Set the speed of the movement
    var angle = globals.time * speed; // Compute the angle as a function of time
    var light_pos_time = vec3<f32>(radius * cos(angle), 5.0, radius * sin(angle)); // Compute the light position using trigonometric functions

    var light_dir = normalize(light_pos_time - position);
    var light_dist = length(light_pos_time - position);

    var normal = get_normal(position);
    var diffuse = clamp(dot(normal, light_dir), 0.0, 1.0) / light_dist;

    let shadow = calc_shadow(position + normal * surf_dist, light_dir, 32.0);
    diffuse *= shadow;

    let occlusion = calcOcclusion(position, normal, f32(globals.seed));
    diffuse *= occlusion;

    return diffuse;
}

fn get_normal(position: vec3<f32>) -> vec3<f32> {
    var eps = 0.01;
    var normal = vec3<f32>(
        get_dist(position + vec3<f32>(eps, 0.0, 0.0)) - get_dist(position - vec3<f32>(eps, 0.0, 0.0)),
        get_dist(position + vec3<f32>(0.0, eps, 0.0)) - get_dist(position - vec3<f32>(0.0, eps, 0.0)),
        get_dist(position + vec3<f32>(0.0, 0.0, eps)) - get_dist(position - vec3<f32>(0.0, 0.0, eps)),
    );
    return normalize(normal);
}


fn ray_march(ray_origin: vec3<f32>, ray_direction: vec3<f32>) -> f32 {
    let max_dist = 100.0;
    let max_steps = 100u;
    let surf_dist = 0.01;

    var t = 0.0;
    for (var i = 0u; i < max_steps; i = i + 1u) {
        var p = ray_origin + ray_direction * t;
        var distance = get_dist(p);
        t += distance;
        if (t > max_dist || distance < surf_dist) {
            break;
        }
    }

    return t;
}

fn get_dist(p: vec3<f32>) -> f32 {
    // z is away from camera
    // w is radius
    var s = vec4(0.0, 1.0, 6.0, 1.0);

    // let box = sdBox(p - s.xyz, vec3<f32>(s.w, s.w, s.w));


    let sphere =  sdSphere(p - s.xyz, s.w);
    let sphere_dist = sphere;
    let plane_dist = p.y;
    let dist = min(sphere_dist, plane_dist);
    return dist;
}

// Signed distance functions
// Signed distance functions
// Signed distance functions
// Signed distance functions
// Signed distance functions
// Signed distance functions

fn sdSphere(p2: vec3<f32>, s: f32) -> f32 {
    var p3: vec3<f32>;
    var s1: f32;

    p3 = p2;
    s1 = s;
    let e6: vec3<f32> = p3;
    let e8: f32 = s1;
    return (length(e6) - e8);
}

fn sdBox(p: vec3<f32>, b: vec3<f32>) -> f32 {
  let q = abs(p) - b;
  return length(max(q, vec3<f32>(0.))) + min(max(q.x, max(q.y, q.z)), 0.);
}

fn sdRoundBox(p: vec3<f32>, b: vec3<f32>, r: f32) -> f32 {
  let q = abs(p) - b;
  return length(max(q, vec3<f32>(0.))) + min(max(q.x,max(q.y, q.z)), 0.) - r;
}

fn sdCappedTorus(p: vec3<f32>, R: f32, r: f32, sincos: vec2<f32>) -> f32 {
  let q = vec3<f32>(abs(p.x), p.y, p.z);
  let k = select(length(q.xy), dot(q.xy, sincos), sincos.y * q.x > sincos.x * q.y);
  return sqrt(dot(q, q) + R * R - 2. * R * k) - r;
}

fn hash2(a: f32) -> vec2<f32> {
    let a3 = vec3<f32>(a, a * 1e4, a * 1e8);
    let h = fract(sin(a3) * 43758.5453123);
    return h.xy;
}

fn calcOcclusion(pos: vec3<f32>, nor: vec3<f32>, ra: f32) -> f32 {
    var occ = 0.0;

    for (var i = 0u; i < 32u; i = i + 1u) {
        let h = 0.01 + 4.0 * pow(f32(i) / 31.0, 2.0);
        let an = hash2(ra + f32(i) * 13.1) * vec2<f32>(3.14159, 6.2831);
        var dir = vec3<f32>(sin(an.x) * sin(an.y), sin(an.x) * cos(an.y), cos(an.x));
        dir *= sign(dot(dir, nor));
        occ += clamp(5.0 * get_dist(pos + h * dir) / h, -1.0, 1.0);
    }

    return clamp(occ / 32.0, 0.0, 1.0);
}