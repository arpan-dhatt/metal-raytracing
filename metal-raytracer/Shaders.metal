//
//  Shaders.metal
//  metal-raytracer
//
//  Created by Arpan Dhatt on 4/17/22.
//

#include <metal_stdlib>
using namespace metal;

kernel void clear_pass(texture2d<half, access::write> out [[ texture(0) ]],
                       uint2 gid [[thread_position_in_grid]]) {
    if((gid.x >= out.get_width()) || (gid.y >= out.get_height())) { return; }
    out.write(vec<half, 4>(1, 0, 0, 0), gid);
}
