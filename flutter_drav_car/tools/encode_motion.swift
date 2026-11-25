import Foundation
import ImageIO
import UniformTypeIdentifiers
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let target = root.appendingPathComponent("docs/qa/v12-motion.gif")
guard let output = CGImageDestinationCreateWithURL(target as CFURL, UTType.gif.identifier as CFString, 24, nil) else { fatalError("GIF output failed") }
CGImageDestinationSetProperties(output, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
for index in 0..<24 {
 let path = URL(fileURLWithPath: String(format: "/tmp/drive_v12_frames/frame-%02d.png", index))
 guard let source = CGImageSourceCreateWithURL(path as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fatalError("Missing frame") }
 CGImageDestinationAddImage(output,image,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:0.1]] as CFDictionary)
}
guard CGImageDestinationFinalize(output) else { fatalError("GIF encoding failed") }
print(target.path)
