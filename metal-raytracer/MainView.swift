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
typealias float4 = SIMD4<Float>

struct Uniforms {
    var origin: float3
    var sphere_count: UInt32
    var upper_left: float3
    var horizontal: float3
    var vertical: float3
}

struct Sphere {
    var center: float3
    var radius: Float
}

class MainView : MTKView {
    var commandQueue: MTLCommandQueue!
    var rayPass: MTLComputePipelineState!
    var uniforms: Uniforms!
    var frameCount: UInt64!
    
    var randFloatBuf: MTLBuffer!
    var randUnitSphere: MTLBuffer!
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        
        self.frameCount = 0
        
        self.framebufferOnly = false
        
        self.device = MTLCreateSystemDefaultDevice()
        
        self.commandQueue = device?.makeCommandQueue()
        
        self.randFloatBuf = createRandFloatBuf(length: 4096);
        self.randUnitSphere = createRandUnitSphere(length: 4096);
        
        let library = device?.makeDefaultLibrary()
        let rayFunc = library?.makeFunction(name: "ray_pass")
        
        do {
            rayPass = try device?.makeComputePipelineState(function: rayFunc!)
        } catch let error as NSError {
            print(error)
        }
    }
    
    func createRandFloatBuf(length: Int) -> MTLBuffer? {
        var floats = Array.init(repeating: Float(0.0), count: length);
        for i in 0..<length {
            floats[i] = Float.random(in: 0..<1.0);
        }
        return device?.makeBuffer(bytes: floats, length: MemoryLayout<Float>.stride * floats.count, options: .storageModeShared)
    }
    
    func createRandUnitSphere(length: Int) -> MTLBuffer? {
        var float3s = Array.init(repeating: float3.zero, count: length)
        for i in 0..<length {
            var val = float3.random(in: 0..<1.0);
            while (simd_length(val) > 1.0) {
                val = float3.random(in: 0..<1.0);
            }
            float3s[i] = val;
        }
        return device?.makeBuffer(bytes: float3s, length: MemoryLayout<float3>.stride * float3s.count, options: .storageModeShared)
    }
}

extension MainView {
    override func draw(_ dirtyRect: NSRect) {
        guard let drawable = self.currentDrawable else { return }
        
        // calculate uniforms
        let focal_distance: Float = 2.0;
        let aspect_ratio = Float(drawable.texture.width) / Float(drawable.texture.height)
        let viewport_height: Float = 2.0;
        let viewport_width: Float = aspect_ratio * viewport_height;
        
        let spheres = [
            Sphere(center: float3(x: sin(Float(frameCount) / 60) * 2.0, y: cos(Float(frameCount) / 60) * 2.0, z: 5.0), radius: 1.0),
            Sphere(center: float3(x: 0.0, y: -51.0, z: 5.0), radius: 50.0)
        ];
        
        let uniforms = Uniforms(
            origin: float3.zero,
            sphere_count: UInt32(spheres.count),
            upper_left: simd_float3(x: -viewport_width / 2.0, y: viewport_height / 2.0, z: focal_distance),
            horizontal: simd_float3(x: viewport_width / Float(drawable.texture.width), y: 0.0, z: 0.0),
            vertical: simd_float3(x: 0.0, y: viewport_height / Float(drawable.texture.height), z: 0.0)
        )
        frameCount += 1
        
        let commandBuffer = commandQueue.makeCommandBuffer()
        let computeCommandEncoder = commandBuffer?.makeComputeCommandEncoder()
        computeCommandEncoder?.setBytes([uniforms], length: MemoryLayout<Uniforms>.size, index: 0)
        computeCommandEncoder?.setBytes(spheres, length: MemoryLayout<Sphere>.stride * spheres.count, index: 1)
        computeCommandEncoder?.setBuffer(randFloatBuf, offset: 0, index: 2)
        computeCommandEncoder?.setBuffer(randUnitSphere, offset: 0, index: 3)
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
