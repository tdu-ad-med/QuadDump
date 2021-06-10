import SwiftUI
import MetalKit

struct CameraView: UIViewRepresentable {
    let quadRecorder: QuadRecorder
    init(quadRecorder: QuadRecorder) { self.quadRecorder = quadRecorder }
    func makeUIView(context: Context) -> some UIView {
        let view = BaseCameraView()
        view.setQuadRecorder(quadRecorder: quadRecorder)
        return view
    }
    func updateUIView(_ uiView: UIViewType, context: Context) {}
}

class BaseCameraView: UIView {
    func setQuadRecorder(quadRecorder: QuadRecorder) {
        quadRecorder.preview { [weak self] camPreview in
            self?.updateImage(camPreview: camPreview)
        }
    }

    let metalLayer = CAMetalLayer()
    let device = MTLCreateSystemDefaultDevice()!
    lazy var commandQueue = device.makeCommandQueue()
    let renderPassDescriptor = MTLRenderPassDescriptor()
    lazy var renderPipelineState: MTLRenderPipelineState! = {
        guard let library = device.makeDefaultLibrary() else { return nil }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "vertexShader")
        descriptor.fragmentFunction = library.makeFunction(name: "fragmentShader")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        return try? device.makeRenderPipelineState(descriptor: descriptor)
    }()

    override func layoutSubviews() {
        super.layoutSubviews()
        _ = initMetalAndCaptureSession
        metalLayer.frame = layer.frame
    }

    lazy var initMetalAndCaptureSession: Void = {
        metalLayer.device = device
        metalLayer.isOpaque = false
        layer.addSublayer(metalLayer)

        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
    }()

    func updateImage(camPreview: CamRecorder.CamPreview) {
        let buffer = camPreview.colorImage
        CVPixelBufferLockBaseAddress(buffer, .readOnly)

        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)

        var textureCache: CVMetalTextureCache!
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
        var texture: CVMetalTexture!
        _ = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, buffer, nil, .bgra8Unorm, width, height, 0, &texture)

        guard let drawable = metalLayer.nextDrawable(),
              let commandBuffer = commandQueue?.makeCommandBuffer() else { return }

        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
        encoder.setRenderPipelineState(renderPipelineState)

        let aspect = Float(frame.width / frame.height) * Float(height) / Float(width)
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
                0, 1,
                0, 0,
                1, 1,
                1, 0,
            ],
        ]

        vertexData.enumerated().forEach { i, array in
            let size = array.count * MemoryLayout.size(ofValue: array[0])
            let buffer = device.makeBuffer(bytes: array, length: size)
            encoder.setVertexBuffer(buffer, offset: 0, index: i)
        }

        encoder.setFragmentTexture(CVMetalTextureGetTexture(texture), index: 0)
        encoder.drawPrimitives(type: .triangleStrip,
                               vertexStart: 0,
                               vertexCount: vertexData[0].count / 4)

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()

        CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
    }
}
