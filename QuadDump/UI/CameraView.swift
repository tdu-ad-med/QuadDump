import SwiftUI
import MetalKit

struct CameraView: UIViewRepresentable {
    let quadRecorder: QuadRecorder
    @Binding var previewMode: Bool

    func makeUIView(context: Context) -> BaseCameraView {
        let view = BaseCameraView()
        view.setQuadRecorder(quadRecorder: quadRecorder)
        return view
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {
        uiView.mode = previewMode
    }
}

class BaseCameraView: UIView {
    func setQuadRecorder(quadRecorder: QuadRecorder) {
        quadRecorder.preview { [weak self] camPreview in
            self?.update(camPreview)
        }
    }

    private let metalLayer = CAMetalLayer()
    private let device = MTLCreateSystemDefaultDevice()!
    private lazy var commandQueue = device.makeCommandQueue()
    private let renderPassDescriptor = MTLRenderPassDescriptor()
    private lazy var normalRenderPipelineState: MTLRenderPipelineState! = {
        guard let library = device.makeDefaultLibrary() else { return nil }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "vertexShader")
        descriptor.fragmentFunction = library.makeFunction(name: "normalFragmentShader")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        return try? device.makeRenderPipelineState(descriptor: descriptor)
    }()
    private lazy var colorfulRenderPipelineState: MTLRenderPipelineState! = {
        guard let library = device.makeDefaultLibrary() else { return nil }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "vertexShader")
        descriptor.fragmentFunction = library.makeFunction(name: "colorfulFragmentShader")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        return try? device.makeRenderPipelineState(descriptor: descriptor)
    }()
    private lazy var textureCache: CVMetalTextureCache = {
        var cache: CVMetalTextureCache!
        CVMetalTextureCacheCreate(nil, nil, device, nil, &cache)
        return cache
    }()
    public var mode: Bool = false

    override func layoutSubviews() {
        super.layoutSubviews()
        _ = initMetalAndCaptureSession
        metalLayer.frame = layer.frame
    }

    private lazy var initMetalAndCaptureSession: Void = {
        metalLayer.device = device
        metalLayer.isOpaque = false
        layer.addSublayer(metalLayer)

        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
    }()

    func update(_ cam: CamRecorder.CamPreview) {
        guard
            CVPixelBufferGetPlaneCount(cam.color) >= 2,
            let colorTextureY = makeTexture(fromPixelBuffer: cam.color, pixelFormat: .r8Unorm, planeIndex: 0),
            let colorTextureCbCr = makeTexture(fromPixelBuffer: cam.color, pixelFormat: .rg8Unorm, planeIndex: 1)
            else { return }

        let depthTexture: CVMetalTexture? = {
            guard let depth = cam.depth else { return nil }
            return makeTexture(fromPixelBuffer: depth, pixelFormat: .r32Float, planeIndex: 0)
        }()

        let width = CVPixelBufferGetWidth(cam.color)
        let height = CVPixelBufferGetHeight(cam.color)

        guard let drawable = metalLayer.nextDrawable(),
              let commandBuffer = commandQueue?.makeCommandBuffer() else { return }

        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        if nil != depthTexture && mode {
            encoder.setRenderPipelineState(colorfulRenderPipelineState)
        }
        else {
            encoder.setRenderPipelineState(normalRenderPipelineState)
        }

        let aspect = Float(frame.width / frame.height) * Float(width) / Float(height)
        let vertexData: [[Float]] = [
            // 0: positions
            [
                -1, -aspect, 0, 1,
                -1, aspect, 0, 1,
                1, -aspect, 0, 1,
                1, aspect, 0, 1,
            ],
            // 1: texCoords
            [
                1, 1,
                0, 1,
                1, 0,
                0, 0,
            ],
        ]

        vertexData.enumerated().forEach { i, array in
            let size = array.count * MemoryLayout.size(ofValue: array[0])
            let buffer = device.makeBuffer(bytes: array, length: size)
            encoder.setVertexBuffer(buffer, offset: 0, index: i)
        }

        encoder.setFragmentTexture(CVMetalTextureGetTexture(colorTextureY), index: 0)
        encoder.setFragmentTexture(CVMetalTextureGetTexture(colorTextureCbCr), index: 1)
        if let depthTexture = depthTexture {
            encoder.setFragmentTexture(CVMetalTextureGetTexture(depthTexture), index: 2)
        }
        encoder.drawPrimitives(type: .triangleStrip,
                               vertexStart: 0,
                               vertexCount: vertexData[0].count / 4)

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func makeTexture(fromPixelBuffer pixelBuffer: CVPixelBuffer, pixelFormat: MTLPixelFormat, planeIndex: Int) -> CVMetalTexture? {
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)

        var texture: CVMetalTexture? = nil
        let status = CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, pixelBuffer, nil, pixelFormat, width, height, planeIndex, &texture)

        if status != kCVReturnSuccess {
            texture = nil
        }

        return texture
    }
}
