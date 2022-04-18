//
//  Shaders.metal
//  metal-raytracer
//
//  Created by Arpan Dhatt on 4/17/22.
//

#include <metal_stdlib>
using namespace metal;

struct Ray {
    half3 pos;
    half3 dir;
};

struct Uniforms {
    float3 origin;
    float3 upper_left;
    float3 horizontal;
    float3 vertical;
};

Ray create_ray(constant Uniforms *unifs, uint2 uv) {
    return {
        half3(unifs->origin),
        half3(unifs->upper_left + unifs->horizontal * uv.x - unifs->vertical * uv.y - unifs->origin)
    };
}

void create_rays(constant Uniforms *unifs, uint2 uv, thread Ray* rays) {
    for (uint i = 0; i < 2; i++) {
        for (uint j = 0; j < 2; j++) {
            float3 offset = 0.333 * unifs->horizontal * i - 0.333 * unifs->vertical * j;
            rays[i * 2 + j] = {
                half3(unifs->origin),
                half3(unifs->upper_left + unifs->horizontal * uv.x - unifs->vertical * uv.y - unifs->origin + offset)
            };
        }
    }
}

half hit_sphere(half3 center, half radius, thread const Ray& r) {
    half3 oc = r.pos - center;
    half a = dot(r.dir, r.dir);
    half b = 2.0 * dot(oc, r.dir);
    half c = dot(oc, oc) - radius * radius;
    half disc = b*b - 4*a*c;
    if (disc < 0) {
        return -1.0;
    } else {
        return (-b - sqrt(disc)) / (2.0 * a);
    }
}

half3 ray_color(thread const Ray& r) {
    half t = hit_sphere(half3(0.0, 0.0, 5.0), 1.0, r);
    half3 unit_dir = r.dir / length(r.dir);
    if (t > 0.0) {
        half3 norm = unit_dir * t + r.pos;
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
        col += 0.25 * ray_color(rays[i]);
    }
    out.write(half4(col, 1.0), gid);
}
