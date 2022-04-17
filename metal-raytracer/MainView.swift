//
//  MainView.swift
//  metal-raytracer
//
//  Created by Arpan Dhatt on 4/17/22.
//

import Foundation
import MetalKit

class MainView : MTKView {
    var commandQueue: MTLCommandQueue!
    var clearPass: MTLComputePipelineState!
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        
        self.framebufferOnly = false
        
        self.device = MTLCreateSystemDefaultDevice()
        
        self.commandQueue = device?.makeCommandQueue()
        
        let library = device?.makeDefaultLibrary()
        let clearFunc = library?.makeFunction(name: "clear_pass")
        
        do {
            clearPass = try device?.makeComputePipelineState(function: clearFunc!)
        } catch let error as NSError {
            print(error)
        }
    }
}

extension MainView {
    override func draw(_ dirtyRect: NSRect) {
        guard let drawable = self.currentDrawable else { return }
        
        let commandBuffer = commandQueue.makeCommandBuffer()
        let computeCommandEncoder = commandBuffer?.makeComputeCommandEncoder()
        computeCommandEncoder?.setTexture(drawable.texture, index: 0)
        
        let w = clearPass.threadExecutionWidth
        let h = clearPass.maxTotalThreadsPerThreadgroup / w
        
        let threadsPerGrid = MTLSizeMake(drawable.texture.width, drawable.texture.height, 1)
        let threadsPerThreadgroup = MTLSize(width: w, height: h, depth: 1)
        
        computeCommandEncoder?.setComputePipelineState(clearPass)
        computeCommandEncoder?.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        
        computeCommandEncoder?.endEncoding()
        commandBuffer?.present(drawable)
        commandBuffer?.commit()
    }
}
