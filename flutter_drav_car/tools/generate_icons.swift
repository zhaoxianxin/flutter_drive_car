import AppKit
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
func icon(_ size: Int, _ path: String) {
 let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
   bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(),
   bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
 let scale = CGFloat(size) / 1024
 context.scaleBy(x: scale, y: scale)
 func rect(_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ h:CGFloat,_ r:CGFloat,_ hex:Int) {
  context.setFillColor(NSColor(srgbRed:CGFloat((hex>>16)&255)/255,green:CGFloat((hex>>8)&255)/255,blue:CGFloat(hex&255)/255,alpha:1).cgColor)
  context.addPath(CGPath(roundedRect:CGRect(x:x,y:y,width:w,height:h),cornerWidth:r,cornerHeight:r,transform:nil));context.fillPath()
 }
 rect(0,0,1024,1024,0,0xC9E7BB)
 rect(230,0,564,1024,0,0xF9F3DE);rect(250,0,524,1024,0,0x8FA7A0)
 for y in stride(from:40,through:1000,by:200) {rect(500,CGFloat(y),24,90,12,0xE2E9DC)}
 rect(326,200,48,150,20,0x36514F);rect(650,200,48,150,20,0x36514F)
 rect(326,590,48,150,20,0x36514F);rect(650,590,48,150,20,0x36514F)
 rect(356,150,312,650,100,0xD76540);rect(356,178,312,650,100,0xFF9765)
 rect(382,215,260,560,72,0xFFB47B);rect(400,400,224,245,50,0x527E7C)
 rect(420,545,184,75,24,0xB5E1D8);rect(396,380,232,140,38,0xFFA46D)
 rect(405,710,48,60,20,0xFFF2C6);rect(571,710,48,60,20,0xFFF2C6)
 rect(424,250,176,40,20,0xBEE1D1)
 let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
 let data = bitmap.representation(using:.png,properties:[:])!
 try! data.write(to:root.appendingPathComponent(path))
}
let json = try! Data(contentsOf:root.appendingPathComponent("ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json"))
let content = try! JSONSerialization.jsonObject(with:json) as! [String:Any]
for entry in content["images"] as! [[String:String]] {
 if let file=entry["filename"],let dimensions=entry["size"],let scale=entry["scale"] {
 let points=Double(dimensions.components(separatedBy:"x")[0])!;let factor=Double(scale.replacingOccurrences(of:"x",with:""))!
 icon(Int(points*factor),"ios/Runner/Assets.xcassets/AppIcon.appiconset/"+file)
 }
}
for (density,size) in [("mdpi",48),("hdpi",72),("xhdpi",96),("xxhdpi",144),("xxxhdpi",192)] { icon(size,"android/app/src/main/res/mipmap-\(density)/ic_launcher.png") }
