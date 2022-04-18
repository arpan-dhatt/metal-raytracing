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

struct Uniforms {
    float3 origin;
    float3 sphere_center;
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
            rays[i * 2 + j] = {
                unifs->origin,
                unifs->upper_left + unifs->horizontal * uv.x - unifs->vertical * uv.y - unifs->origin + offset
            };
        }
    }
}

float hit_sphere(float3 center, float radius, thread const Ray& r) {
    float3 oc = r.pos - center;
    float a = dot(r.dir, r.dir);
    float b = 2.0 * dot(oc, r.dir);
    float c = dot(oc, oc) - radius * radius;
    float disc = b*b - 4*a*c;
    if (disc < 0) {
        return -1.0;
    } else {
        return (-b - sqrt(disc)) / (2.0 * a);
    }
}

half3 ray_color(constant Uniforms *unifs, thread const Ray& r) {
    float t = hit_sphere(unifs->sphere_center, 1.0, r);
    float3 unit_dir = r.dir / length(r.dir);
    if (t > 0.0) {
        float3 norm = unit_dir * t + r.pos;
        return 0.5 * (half3(norm.x, norm.y, norm.z) + 1.0);
    }
    t = 0.5 * (unit_dir.y + 1.0);
    return (1.0-t)*half3(1.0, 1.0, 1.0) + t*half3(0.5, 0.7, 1.0);
}

kernel void ray_pass(texture2d<half, access::write> out [[ texture(0) ]],
                     constant Uniforms *unifs [[ buffer(0) ]],
                     uint2 gid [[thread_position_in_grid]]) {
    Ray rays[4];
    create_rays(unifs, gid, rays);
    half3 col = half3();
    for (uint i = 0; i < 4; i++) {
        col += 0.25 * ray_color(unifs, rays[i]);
    }
    out.write(half4(col, 1.0), gid);
}
