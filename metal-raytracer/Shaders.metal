//
//  Shaders.metal
//  metal-raytracer
//
//  Created by Arpan Dhatt on 4/17/22.
//

#include <metal_stdlib>
using namespace metal;

struct Ray {
    float3 pos;
    float3 dir;
};

struct Sphere {
    float3 center;
    float radius;
    float3 albedo;
};

struct Hit {
    float3 norm;
    half3 attenuation;
    float t;
};

struct Uniforms {
    float3 origin;
    uint samples;
    uint sphere_count;
    float3 upper_left;
    float3 horizontal;
    float3 vertical;
};

Ray create_ray(constant Uniforms *unifs, uint2 uv) {
    return {
        float3(unifs->origin),
        float3(unifs->upper_left + unifs->horizontal * uv.x - unifs->vertical * uv.y - unifs->origin)
    };
}

void create_rays(constant Uniforms *unifs, uint2 uv, thread Ray* rays) {
    for (uint i = 0; i < 2; i++) {
        for (uint j = 0; j < 2; j++) {
            float3 offset = 0.333 * unifs->horizontal * i - 0.333 * unifs->vertical * j;
            float3 dir = unifs->upper_left + unifs->horizontal * uv.x - unifs->vertical * uv.y - unifs->origin + offset;
            rays[i * 2 + j] = {
                unifs->origin,
                dir / length(dir)
            };
        }
    }
}

Hit hit_sphere(float3 center, float radius, half3 attenuation, thread const Ray& r) {
    float3 oc = r.pos - center;
    float a = dot(r.dir, r.dir);
    float b = 2.0 * dot(oc, r.dir);
    float c = dot(oc, oc) - radius * radius;
    float disc = b*b - 4*a*c;
    if (disc < 0) {
        return { float3(), attenuation, -1.0 };
    } else {
        float t = (-b - sqrt(disc)) / (2.0 * a);
        float3 norm = r.pos + r.dir * t - center;
        return { norm / length(norm), attenuation, t };
    }
}

half3 extend_ray(constant Uniforms *unifs,
                 constant Sphere *spheres,
                 device float *rand_floats,
                 device float3 *rand_units,
                 uint id,
                 uint j,
                 thread Ray *rays,
                 thread bool *active) {
    Hit hit = { float3(0), half3(0), -1.0};
    Ray r = rays[j];
    for (uint i = 0; i < unifs->sphere_count; i++) {
        Hit temp = hit_sphere(spheres[i].center, spheres[i].radius, half3(spheres[i].albedo), r);
        if (temp.t > 0.0 && (hit.t == -1.0 || temp.t < hit.t)) hit = temp;
    }
    if (hit.t > 0.0) {
        Ray new_r = {r.pos + r.dir * hit.t + hit.norm * 0.001, hit.norm + rand_units[id]};
        new_r.dir /= length(new_r.dir);
        rays[j] = new_r;
        return hit.attenuation;
    }
    hit.t = 0.5 * (r.dir.y + 1.0);
    active[j] = false;
    return (1.0-hit.t)*half3(1.0, 1.0, 1.0) + hit.t*half3(0.5, 0.7, 1.0);
}

uint randomize(thread uint *rand_state, uint in) {
    uint r = *rand_state + in;
    r ^= r << 13;
    r ^= r >> 17;
    r ^= r << 5;
    *rand_state = r;
    return r;
}

kernel void ray_pass(texture2d<half, access::write> out [[ texture(0) ]],
                     constant Uniforms *unifs [[ buffer(0) ]],
                     constant Sphere *spheres [[ buffer(1) ]],
                     device float *rand_floats [[ buffer(2) ]],
                     device float3 *rand_units [[ buffer(3) ]],
                     uint2 gid [[thread_position_in_grid]]) {
    half3 col = half3(1.0);
    uint random_state = 1234;
    for (uint i = 0; i < unifs->samples; i++) {
        for (uint j = 0; j < 4; j++) {
            Ray rays[4];
            create_rays(unifs, gid, rays);
            half3 ray_col = half3(1.0);
            bool active[4] = { true, true, true, true };
            for (uint k = 0; k < 2; k++) {
                if (active[j]) {
                    uint id = gid.x * out.get_width() + gid.y + j * 719 * i + k;
                    id = randomize(&random_state, id);
                    ray_col *= extend_ray(unifs, spheres, rand_floats, rand_units, id & 4095, j, rays, active);
                }
            }
            col += ray_col;
        }
    }
    
    out.write(sqrt(half4(col / (unifs->samples * 4.0), 1.0)), gid);
}
