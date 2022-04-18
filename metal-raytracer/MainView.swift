//
//  MainView.swift
//  metal-raytracer
//
//  Created by Arpan Dhatt on 4/17/22.
//

import Foundation
import MetalKit
import Metal

typealias float3 = SIMD3<Float>

struct Uniforms {
    var origin: float3
    var sphere_center: float3
    var upper_left: float3
    var horizontal: float3
    var vertical: float3
}

class MainView : MTKView {
    var commandQueue: MTLCommandQueue!
    var rayPass: MTLComputePipelineState!
    var uniforms: Uniforms!
    var frameCount: UInt64!
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        
        self.frameCount = 0
        
        self.framebufferOnly = false
        
        self.device = MTLCreateSystemDefaultDevice()
        
        self.commandQueue = device?.makeCommandQueue()
        
        let library = device?.makeDefaultLibrary()
        let rayFunc = library?.makeFunction(name: "ray_pass")
        
        do {
            rayPass = try device?.makeComputePipelineState(function: rayFunc!)
        } catch let error as NSError {
            print(error)
        }
    }
}

extension MainView {
    override func draw(_ dirtyRect: NSRect) {
        guard let drawable = self.currentDrawable else { return }
        
        // calculate uniforms
        let focal_distance: Float = 1.0;
        let aspect_ratio = Float(drawable.texture.width) / Float(drawable.texture.height)
        let viewport_height: Float = 2.0;
        let viewport_width: Float = aspect_ratio * viewport_height;
        let uniforms = Uniforms(
            origin: float3.zero,
            sphere_center: float3(x: sin(Float(frameCount) / 60), y: 0.0, z: 5.0),
            upper_left: simd_float3(x: -viewport_width / 2.0, y: viewport_height / 2.0, z: focal_distance),
            horizontal: simd_float3(x: viewport_width / Float(drawable.texture.width), y: 0.0, z: 0.0),
            vertical: simd_float3(x: 0.0, y: viewport_height / Float(drawable.texture.height), z: 0.0)
        )
        frameCount += 1
        
        let commandBuffer = commandQueue.makeCommandBuffer()
        let computeCommandEncoder = commandBuffer?.makeComputeCommandEncoder()
        computeCommandEncoder?.setBytes([uniforms], length: MemoryLayout<Uniforms>.size, index: 0)
        computeCommandEncoder?.setTexture(drawable.texture, index: 0)
        
        let w = rayPass.threadExecutionWidth
        let h = rayPass.maxTotalThreadsPerThreadgroup / w
        
        let threadsPerGrid = MTLSizeMake(drawable.texture.width, drawable.texture.height, 1)
        let threadsPerThreadgroup = MTLSize(width: w, height: h, depth: 1)
        
        computeCommandEncoder?.setComputePipelineState(rayPass)
        computeCommandEncoder?.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        
        computeCommandEncoder?.endEncoding()
        commandBuffer?.present(drawable)
        commandBuffer?.commit()
    }
}
