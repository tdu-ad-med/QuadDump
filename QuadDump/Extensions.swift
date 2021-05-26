import UIKit

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

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1.0) {
        self.init(
            red  : CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8 ) & 0xFF) / 255.0,
            blue : CGFloat((hex >> 0 ) & 0xFF) / 255.0,
            alpha: alpha
        )
    }
}
