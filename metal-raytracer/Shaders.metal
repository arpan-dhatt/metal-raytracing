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

half4 ray_color(Ray r) {
    half3 unit_dir = r.dir / length(r.dir);
    half t = 0.5 * (unit_dir.y + 1.0);
    return (1.0-t)*half4(1.0, 1.0, 1.0, 0.0) + t*half4(0.5, 0.7, 1.0, 0.0);
}

kernel void ray_pass(texture2d<half, access::write> out [[ texture(0) ]],
                     constant Uniforms *unifs [[ buffer(0) ]],
                     uint2 gid [[thread_position_in_grid]]) {
    Ray r = create_ray(unifs, gid);
    out.write(ray_color(r), gid);
}
