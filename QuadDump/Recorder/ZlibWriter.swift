import Compression
import Foundation
import AVFoundation
import VideoToolbox

class ZlibWriter {
	private var dstBuffer: UnsafeMutableBufferPointer<UInt8>?

	private func reset() {
		if let buffer = dstBuffer {
			buffer.deallocate()
			dstBuffer = nil
		}
	}

	deinit {
		reset()
	}

	func convert(pixelBuffer: CVPixelBuffer) -> Data? {
		// zlibで圧縮後のデータサイズが圧縮前のデータサイズを上回ることがあるため
		// 圧縮後のデータサイズを格納するためのメモリを多めに確保しておく
		// There are cases where the size of zlib output data is lager than the size of input data.
		// Therefore, allocate twice the memory of the input data.
		let buffer_size = CVPixelBufferGetBytesPerRow(pixelBuffer) * CVPixelBufferGetHeight(pixelBuffer)
		let capacity = buffer_size * 2
		if (nil == dstBuffer) || (capacity > dstBuffer!.count) {
			reset()
			dstBuffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: capacity)
		}
		guard let dstBuffer = dstBuffer else { return nil }

		// 画像の圧縮
		CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
		let compressedSize = compression_encode_buffer(
			dstBuffer.baseAddress!, dstBuffer.count,
			CVPixelBufferGetBaseAddress(pixelBuffer)!.assumingMemoryBound(to: UInt8.self), buffer_size,
			nil,
			COMPRESSION_ZLIB
		)
		CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
		if 0 == compressedSize { return nil }

		// 圧縮データを返す
		return Data(bytes: dstBuffer.baseAddress!, count: compressedSize)
	}
}
