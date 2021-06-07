import SwiftUI

struct SimpleError: Error {
    let description: String
}
typealias SimpleResult = Result<(), SimpleError>
func Ok() -> SimpleResult {
    return .success(())
}
func Err(_ description: String) -> SimpleResult {
    return .failure(SimpleError(description: description))
}

extension URL {
    // DocumentsディレクトリへのURLを返す
    static var docs: URL? {
        return FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).last
    }

    func createDir(name: String, deleteIfExists: Bool = false) -> URL? {
        do {
            let result = self.appendingPathComponent(name, isDirectory: true)

            // パス先が存在するかを確認
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: result.path, isDirectory: &isDir) {
                // deleteIfExistsがTrueであればパス先を削除
                if deleteIfExists {
                    try FileManager.default.removeItem(at: result)
                }

                // 既に存在するパスがディレクトリであれば、そのURLを返す
                else if isDir.boolValue {
                    return result
                }

                // 既に存在するパスがファイルであればnilを返す
                else {
                    return nil
                }
            }

            // ディレクトリを作成
            try FileManager.default.createDirectory(
                atPath: result.path, withIntermediateDirectories: true, attributes: nil
            )

            return result
        }
        catch {
            return nil
        }
    }

    func createFile(name: String, contents: Data?, deleteIfExists: Bool = false) -> URL? {
        do {
            let result = self.appendingPathComponent(name, isDirectory: false)

            // パス先が存在するかを確認
            if FileManager.default.fileExists(atPath: result.path) {
                // deleteIfExistsがTrueであればパス先を削除
                if deleteIfExists {
                    try FileManager.default.removeItem(at: result)
                }
                else {
                    return nil
                }
            }

            // ファイルを作成
            guard FileManager.default.createFile(atPath: result.path, contents: contents)
            else { return nil }

            return result
        }
        catch {
            return nil
        }
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red    : Double((hex >> 16) & 0xFF) / 255.0,
            green  : Double((hex >> 8 ) & 0xFF) / 255.0,
            blue   : Double((hex >> 0 ) & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

extension CGPoint {
    static func + (left: CGPoint, right: CGPoint) -> CGPoint { return CGPoint(x: left.x + right.x, y: left.y + right.y) }
    static func - (left: CGPoint, right: CGPoint) -> CGPoint { return CGPoint(x: left.x - right.x, y: left.y - right.y) }
    var length: CGFloat { sqrt(self.x * self.x + self.y * self.y) }
}

extension TimeInterval {
    var hhmmss: String {
        let ss_ = abs(self)
        let mm_ = ss_ / 60
        let hh_ = mm_ / 60
        let ss = Int(ss_ - 60 * floor(ss_ / 60))
        let mm = Int(mm_ - 60 * floor(mm_ / 60))
        let hh = Int(hh_)
        let sign = (self < 0) ? "-" : ""
        return sign + String(format: "%02d:%02d:%02d", hh, mm, ss)
    }
}

extension Data {
    mutating func append(contentsOf: [UInt64]) { _append(contentsOf: contentsOf) }
    mutating func append(contentsOf: [Float]) { _append(contentsOf: contentsOf) }
    mutating func append(contentsOf: [Double]) { _append(contentsOf: contentsOf) }
    private mutating func _append<T>(contentsOf: [T]) {
        let buffer = contentsOf.withUnsafeBytes { body in body.bindMemory(to: UInt8.self) }
        append(buffer)
    }
}
