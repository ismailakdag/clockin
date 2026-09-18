#!/usr/bin/env swift
// Shared deterministic art engine. Entry points: make-mascot-anchors, make-wardrobe, make-home, make-wardrobe-preview.
// Coordinates use the top-left image origin. New strokes use detected art pixels.
import Foundation
import CoreGraphics
import ImageIO

struct Pixel: Equatable {
    var r: UInt8, g: UInt8, b: UInt8, a: UInt8
    static let clear = Pixel(r: 0, g: 0, b: 0, a: 0)
}

struct Bounds {
    var x0: Int, y0: Int, x1: Int, y1: Int
    var width: Int { x1 - x0 + 1 }
    var height: Int { y1 - y0 + 1 }
    var midX: Int { (x0 + x1) / 2 }
    var midY: Int { (y0 + y1) / 2 }
    func contains(_ x: Int, _ y: Int) -> Bool {
        x >= x0 && x <= x1 && y >= y0 && y <= y1
    }
    func padded(_ n: Int) -> Bounds {
        Bounds(x0: x0 - n, y0: y0 - n, x1: x1 + n, y1: y1 + n)
    }
}

struct Bitmap {
    let width: Int, height: Int
    var bytes: [UInt8]
    init(width: Int, height: Int, fill: Pixel = .clear) {
        self.width = width
        self.height = height
        bytes = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height { for x in 0..<width { self[x, y] = fill } }
    }
    init(url: URL) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            fatalError("Cannot read \(url.path)")
        }
        self.init(width: image.width, height: image.height)
        // Read straight RGBA directly. A drawing context would premultiply and
        // round translucent edge colors, changing pixels outside the edits.
        precondition(image.bitsPerComponent == 8 && image.bitsPerPixel == 32 &&
                     image.alphaInfo == .last && image.bitmapInfo.intersection(.byteOrderMask).isEmpty,
                     "Expected straight 8-bit RGBA PNG")
        let data = image.dataProvider!.data! as Data
        for y in 0..<height {
            bytes.replaceSubrange((y * width * 4)..<((y + 1) * width * 4),
                with: data[(y * image.bytesPerRow)..<(y * image.bytesPerRow + width * 4)])
        }
    }

    subscript(x: Int, y: Int) -> Pixel {
        get {
            let i = (y * width + x) * 4
            return Pixel(r: bytes[i], g: bytes[i+1], b: bytes[i+2], a: bytes[i+3])
        }
        set {
            let i = (y * width + x) * 4
            bytes[i] = newValue.r; bytes[i+1] = newValue.g
            bytes[i+2] = newValue.b; bytes[i+3] = newValue.a
        }
    }
    func write(_ url: URL) {
        let data = Data(bytes) as CFData
        let image = CGImage(width: width, height: height, bitsPerComponent: 8,
            bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: CGDataProvider(data: data)!, decode: nil,
            shouldInterpolate: false, intent: .defaultIntent)!
        let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        precondition(CGImageDestinationFinalize(destination), "PNG encoding failed")
    }
}

func isCyan(_ p: Pixel) -> Bool {
    p.a > 100 && p.g > 80 && p.b > 90 &&
        Int(p.g) - Int(p.r) > 30 && Int(p.b) - Int(p.r) > 30
}
func isDark(_ p: Pixel) -> Bool { p.a > 240 && max(p.r, p.g, p.b) < 80 }

func components(_ bitmap: Bitmap, matching predicate: (Pixel) -> Bool) -> [[Int]] {
    let w = bitmap.width, h = bitmap.height
    var seen = [Bool](repeating: false, count: w * h)
    var result = [[Int]]()
    for start in 0..<(w * h) where !seen[start] {
        seen[start] = true
        guard predicate(bitmap[start % w, start / w]) else { continue }
        var queue = [start], cursor = 0
        while cursor < queue.count {
            let i = queue[cursor]; cursor += 1
            for n in [i-1, i+1, i-w, i+w] where n >= 0 && n < w*h && abs(n % w - i % w) <= 1 {
                if !seen[n] && predicate(bitmap[n % w, n / w]) {
                    seen[n] = true; queue.append(n)
                }
            }
        }
        result.append(queue)
    }
    return result
}
func bounds(_ pixels: [Int], width: Int) -> Bounds {
    Bounds(x0: pixels.map { $0 % width }.min()!, y0: pixels.map { $0 / width }.min()!,
           x1: pixels.map { $0 % width }.max()!, y1: pixels.map { $0 / width }.max()!)
}

// Repeated short plateaus on the visor contour reveal the art's pixel unit.
// Ignore single-pixel resampling noise and long straight contour segments.
func pixelUnit(_ pixels: [Int], width: Int) -> Int {
    let box = bounds(pixels, width: width)
    var histogram = [Int: Int]()
    for rightSide in [false, true] {
        var contour = [Int: Int]()
        for i in pixels {
            let x = i % width, y = i / width
            contour[y] = rightSide ? max(contour[y] ?? 0, x) : min(contour[y] ?? width, x)
        }
        var previous = -1, length = 0
        for y in box.y0...(box.y1 + 1) {
            let x = contour[y] ?? -2
            if x == previous { length += 1 } else {
                if (2...8).contains(length) { histogram[length, default: 0] += 1 }
                previous = x; length = 1
            }
        }
    }
    guard let unit = histogram.keys.sorted(by: {
        histogram[$0]! == histogram[$1]! ? $0 < $1 : histogram[$0]! > histogram[$1]!
    }).first else { fatalError("Cannot detect art pixel unit") }
    return unit
}

func color(_ hex: String) -> Pixel {
    let n = UInt32(hex.replacingOccurrences(of: "#", with: ""), radix: 16)!
    return Pixel(r: UInt8((n >> 16) & 255), g: UInt8((n >> 8) & 255), b: UInt8(n & 255), a: 255)
}
func hex(_ p: Pixel) -> String { String(format: "#%02X%02X%02X", Int(p.r), Int(p.g), Int(p.b)) }
let ink = color("191D24"), paper = color("F7F6F5"), steel = color("414857")
let orange = color("FF771A"), gold = color("F2C458"), cyan = color("49EBFF")
let teal = color("459B93"), purple = color("7961A8"), coral = color("DE756B")
let wood = color("A96E48"), woodLight = color("D89C68"), woodDark = color("684739")
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let framesDir = root.appendingPathComponent("iOS/Shared/Mascot/Frames")
let wardrobeDir = root.appendingPathComponent("iOS/Shared/Mascot/Wardrobe")
let homeDir = root.appendingPathComponent("iOS/Shared/Mascot/Home")
let frameFiles = try FileManager.default.contentsOfDirectory(at: framesDir, includingPropertiesForKeys: nil)
    .filter { $0.lastPathComponent.range(of: "^[htceazp].*\\.png$", options: .regularExpression) != nil }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }
func saveJSON(_ value: Any, _ url: URL) throws {
    try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]).write(to: url)
}
func json(_ url: URL) throws -> [String: Any] { try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any] }
extension Bitmap {
    mutating func rect(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ p: Pixel) {
        guard w > 0 && h > 0 else { return }
        let x0=max(0,x), y0=max(0,y), x1=min(width,x+w), y1=min(height,y+h)
        guard x0<x1 && y0<y1 else { return }
        for yy in y0..<y1 { for xx in x0..<x1 { self[xx,yy] = p } }
    }
    mutating func blit(_ b: Bitmap, _ x: Int, _ y: Int, width dw: Int? = nil, height dh: Int? = nil) {
        let tw = dw ?? b.width, th = dh ?? b.height
        for dy in 0..<th { for dx in 0..<tw where x+dx >= 0 && x+dx < width && y+dy >= 0 && y+dy < height {
            let p = b[min(b.width-1,(2*dx+1)*b.width/(2*tw)),min(b.height-1,(2*dy+1)*b.height/(2*th))]
            if p.a == 0 { continue }
            let bg = self[x+dx,y+dy], a = Int(p.a), ba = Int(bg.a), oa = a + ba*(255-a)/255
            self[x+dx,y+dy] = Pixel(r: UInt8((Int(p.r)*a+Int(bg.r)*ba*(255-a)/255)/oa),
                g: UInt8((Int(p.g)*a+Int(bg.g)*ba*(255-a)/255)/oa),
                b: UInt8((Int(p.b)*a+Int(bg.b)*ba*(255-a)/255)/oa), a: UInt8(oa))
        } }
    }
}
// Tiny bitmap alphabet keeps labels dependency free and uses nearest neighbor too.
let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789- /."
let letterRows = ["01110/10001/11111/10001/10001","11110/10001/11110/10001/11110","01111/10000/10000/10000/01111","11110/10001/10001/10001/11110","11111/10000/11110/10000/11111","11111/10000/11110/10000/10000","01111/10000/10111/10001/01111","10001/10001/11111/10001/10001","111/010/010/010/111","00111/00010/00010/10010/01100","10001/10010/11100/10010/10001","10000/10000/10000/10000/11111","10001/11011/10101/10001/10001","10001/11001/10101/10011/10001","01110/10001/10001/10001/01110","11110/10001/11110/10000/10000","01110/10001/10101/10010/01101","11110/10001/11110/10010/10001","01111/10000/01110/00001/11110","11111/00100/00100/00100/00100","10001/10001/10001/10001/01110","10001/10001/10001/01010/00100","10001/10001/10101/11011/10001","10001/01010/00100/01010/10001","10001/01010/00100/00100/00100","11111/00010/00100/01000/11111","111/101/101/101/111","010/110/010/010/111","110/001/010/100/111","110/001/010/001/110","101/101/111/001/001","111/100/110/001/110","011/100/111/101/111","111/001/010/010/010","111/101/111/101/111","111/101/111/001/110","000/000/111/000/000","00/00/00/00/00","00001/00010/00100/01000/10000","0/0/0/0/1"]
let font = Dictionary(uniqueKeysWithValues: zip(alphabet, letterRows))
func label(_ text: String, _ b: inout Bitmap, _ x: Int, _ y: Int, _ s: Int = 2, _ p: Pixel = paper) {
    var cx = x
    for c in text.uppercased() {
        let rows = font[c, default: "0/0/0/0/0"].split(separator: "/")
        for (dy,row) in rows.enumerated() { for (dx,v) in row.enumerated() where v == "1" { b.rect(cx+dx*s,y+dy*s,s,s,p) } }
        cx += (rows[0].count+1)*s
    }
}
struct Anchors {
    var head: [Int], visor: [Int], neck: [Int], back: [Int], handL: [Int]?, handR: [Int]?, tilt: Double
    var object: [String: Any] { ["head":head,"visor":visor,"neck":neck,"back":back,"handL":handL as Any? ?? NSNull(),"handR":handR as Any? ?? NSNull(),"tilt":tilt] }
}
struct Geometry {
    let visor: Bounds, helmet: Bounds, torso: Bounds, unit: Int
    let anchors: Anchors
    init(_ b: Bitmap, id: String, diagnostics: Bool = false) {
        let w = b.width
        let darkParts = components(b, matching: isDark)
        
        let rawVisor = darkParts.filter {
            let r = bounds($0,width:w)
            return r.width >= 45 && r.width <= 125 && r.height >= 28 && r.height < 160 && r.y0 < 140
        }.max { $0.count < $1.count }!
        // A lifted mug can touch the visor outline. Keep the helmet-local portion
        // of that connected component; its lower part belongs to the held object.
        let rawBox = bounds(rawVisor,width:w)
        let vp = rawBox.height > 100 ? rawVisor.filter { $0/w < rawBox.y0+64 } : rawVisor
        let v = bounds(vp,width:w); visor = v
        unit = pixelUnit(vp,width:w)
        let shell = components(b, matching: { $0.a > 200 && min($0.r,$0.g,$0.b) > 165 && Int(max($0.r,$0.g,$0.b))-Int(min($0.r,$0.g,$0.b)) < 55 })
        let helmetParts = shell.filter {
            let r = bounds($0,width:w)
            return r.width > v.width/2 && r.midX >= v.x0 && r.midX <= v.x1 && r.y0 < v.y0 && r.y1 >= v.y0
        }
        let hp = helmetParts.max { $0.count < $1.count }!
        let hb = bounds(hp,width:w); helmet = hb
        // Fit the upper visor contour, ignoring its rounded outer corners. This also
        // detects the celebrating pose's tilted helmet without an id-specific angle.
        var contour = [(Double,Double)]()
        for x in (v.x0+v.width/4)...(v.x1-v.width/4) {
            if let y = vp.lazy.filter({ $0 % w == x }).map({ $0 / w }).min() { contour.append((Double(x),Double(y))) }
        }
        let mx = contour.map{$0.0}.reduce(0,+)/Double(contour.count), my = contour.map{$0.1}.reduce(0,+)/Double(contour.count)
        let slope = contour.map{($0.0-mx)*($0.1-my)}.reduce(0,+)/contour.map{pow($0.0-mx,2)}.reduce(0,+)
        let angle = abs(slope) < 0.045 ? 0 : atan(slope)*180/Double.pi
        // The topmost broad shell edge excludes the separate antenna and side ears.
        let topPixels = hp.filter { $0/w <= hb.y0+2 }
        let topCenter = bounds(topPixels,width:w).midX
        let bottomPixels = hp.filter { $0/w >= hb.y1-2 }
        let bottomCenter = bounds(bottomPixels,width:w).midX
        let bodyParts = shell.filter {
            let r = bounds($0,width:w)
            return r.y0 >= v.y1 && r.midY < v.y1+70 && r.x0 <= v.midX && r.x1 >= v.midX && r.width >= 28
        }
        let torsoBox = bodyParts.map{bounds($0,width:w)}.min { $0.y0 < $1.y0 }
            ?? Bounds(x0:hb.midX-22,y0:hb.y1+6,x1:hb.midX+22,y1:hb.y1+46)
        torso = torsoBox
        // Hands are the small pale lobes outside the helmet, separated by the dark
        // wrist joint. Select the outermost high lobe in raised poses. Working hands
        // remain visible above the keyboard; coffee hands already grip the cup/body.
        var hands = [[Int]]()
        if !id.hasPrefix("c") {
            let candidates = shell.filter {
                let r = bounds($0,width:w)
                if id.hasPrefix("t") {
                    return r.y0 > v.y1+44 && r.y1 < v.y1+82 && r.x0 >= v.x0-4 && r.x1 <= v.x1+2 && r.width >= 5 && r.width < 35 && r.height < 30
                }
                return (r.midX < hb.x0-12 || r.midX > hb.x1+12) && r.y0 < hb.y1+12 && r.y1 > hb.y0 && r.width >= 5 && r.width < 37 && r.height < 40
            }.map { bounds($0,width:w) }
            for left in [true,false] {
                let side = candidates.filter { left ? $0.midX < v.midX : $0.midX >= v.midX }
                if let first = side.min(by: { $0.y0 < $1.y0 }) {
                    // Include adjacent knuckle lobes, but not the forearm below.
                    let near = side.filter { abs($0.midY-first.midY) <= 10 && abs($0.midX-first.midX) <= 25 }
                    let x0 = near.map{$0.x0}.min()!, x1 = near.map{$0.x1}.max()!
                    let y0 = near.map{$0.y0}.min()!, y1 = near.map{$0.y1}.max()!
                    hands.append([(x0+x1)/2,(y0+y1)/2 + (id.hasPrefix("t") ? 0:4)])
                } else { hands.append([]) }
            }
        } else {
            // Coffee poses use dark gloves. Detect the mug's orange round emblem,
            // then exclude gloves already interacting with that object. Folded
            // gloves form one wide component, split at its two knuckle centers.
            let emblems=components(b,matching: { $0.a>200 && $0.r>180 && $0.g<175 && $0.b<100 }).filter {
                let r=bounds($0,width:w)
                return $0.count>60 && r.y0>v.y1-25 && r.height>10 && r.width<35 && r.width*10<=r.height*13
            }.map{bounds($0,width:w)}
            let gloves=components(b,matching: { $0.a>240 && min($0.r,$0.g,$0.b)>30 && max($0.r,$0.g,$0.b)<140 }).filter{$0.count>40}.map{bounds($0,width:w)}.filter {
                $0.width>=13 && $0.width<43 && $0.height>=13 && $0.height<33 && $0.y0>v.y1+24 && $0.y1<v.y1+85 && $0.x1<hb.x1
            }.filter { glove in
                !emblems.contains { abs($0.midX-glove.midX)<$0.width/2+35 && abs($0.midY-glove.midY)<48 }
            }
            hands=[[],[]]
            for glove in gloves {
                if glove.width>30 && abs(glove.midX-v.midX)<22 {
                    hands=[[glove.x0+9,glove.midY],[glove.x1-9,glove.midY]]
                } else {
                    hands[glove.midX<v.midX-20 ? 0:1]=[glove.midX,glove.midY]
                }
            }
        }
        let neckX = id.hasPrefix("c") ? v.midX+3 : (angle == 0 ? bottomCenter : Int(Double(v.midX)-sin(angle*Double.pi/180)*Double(v.height/2+8)))
        let neckY = id.hasPrefix("c") ? v.y1+12 : (angle == 0 ? hb.y1+3 : v.midY+v.height/2+8)
        anchors = Anchors(head:[topCenter,hb.y0-2],visor:[v.midX,v.midY],neck:[neckX,neckY],
            back:[id.hasPrefix("c") ? neckX+4 : torsoBox.midX,neckY+14],
            handL:hands[0].isEmpty ? nil : hands[0],handR:hands[1].isEmpty ? nil : hands[1],tilt:(angle*10).rounded()/10)
        if diagnostics { print("\(id): visor \(v), helmet \(hb), torso \(torsoBox), unit \(unit), hands \(hands), tilt \(anchors.tilt)") }
    }
}
func makeAnchors() throws {
    var all = [String:Any]()
    let cell = 330, columns = 7
    var sheet = Bitmap(width:columns*cell,height:70+((frameFiles.count+columns-1)/columns)*cell,fill:color("252C37"))
    label("HEAD RED / VISOR CYAN / NECK GOLD / BACK PURPLE / HAND L GREEN / HAND R PINK", &sheet, 16, 16)
    for (i,url) in frameFiles.enumerated() {
        let id = url.deletingPathExtension().lastPathComponent, b = Bitmap(url:url)
        // Legacy acc-* files also match the contract's a* prefix. Their existing
        // generator paints accessories onto h01 without moving the underlying
        // robot. Detect that source pose for landmarks hidden by the baked art.
        let detectionSource = id.hasPrefix("acc-") ? Bitmap(url:framesDir.appendingPathComponent("h01.png")) : b
        let f = Geometry(detectionSource,id:id,diagnostics:true)
        var anchor = f.anchors
        if id == "acc-mug" { anchor.handL = nil }
        all[id] = anchor.object
        let x = i%columns*cell+8, y = 70+i/columns*cell
        sheet.blit(b,x,y)
        for (key,p) in [("head",color("FF544C")),("visor",cyan),("neck",gold),("back",color("B78CFF")),("handL",color("49FF83")),("handR",color("FF77CE"))] {
            if let xy = anchor.object[key] as? [Int] {
                sheet.rect(x+xy[0]-5,y+xy[1]-1,11,3,ink); sheet.rect(x+xy[0]-1,y+xy[1]-5,3,11,ink)
                sheet.rect(x+xy[0]-4,y+xy[1],9,1,p); sheet.rect(x+xy[0],y+xy[1]-4,1,9,p)
            }
        }
        label(id,&sheet,x+10,y+304)
    }
    try saveJSON(all,framesDir.appendingPathComponent("mascot-anchors.json"))
    sheet.write(URL(fileURLWithPath:"/tmp/clockin-anchors.png"))
    for prefix in ["a","c","e","h","p","t","z"] {
        let selected=frameFiles.enumerated().filter{$0.element.lastPathComponent.hasPrefix(prefix)}
        var family=Bitmap(width:1320,height:40+((selected.count+3)/4)*330,fill:color("252C37"))
        label("HEAD RED / VISOR CYAN / NECK GOLD / BACK PURPLE / L GREEN / R PINK",&family,12,12)
        for (j,entry) in selected.enumerated() {
            let sx=entry.offset%columns*cell,sy=70+entry.offset/columns*cell
            for y in 0..<330 { for x in 0..<330 { family[j%4*330+x,40+j/4*330+y]=sheet[sx+x,sy+y] } }
        }
        family.write(URL(fileURLWithPath:"/tmp/clockin-anchors-"+prefix+".png"))
    }
    print("Anchors: \(all.count) frames. /tmp/clockin-anchors.png")
}
if CommandLine.arguments.last == "anchors" { try makeAnchors() }
// Draw in art cells, then expand each cell to exactly 2 image pixels. Polygon
// coverage is evaluated at cell centers; no antialiasing or fractional resampling.
struct Art {
    var b = Bitmap(width:180,height:140)
    mutating func rect(_ x:Int,_ y:Int,_ w:Int,_ h:Int,_ p:Pixel) { b.rect(x,y,w,h,p) }
    mutating func box(_ x:Int,_ y:Int,_ w:Int,_ h:Int,_ p:Pixel) { rect(x,y,w,h,ink); rect(x+1,y+1,w-2,h-2,p) }
    mutating func ellipse(_ x:Int,_ y:Int,_ w:Int,_ h:Int,_ p:Pixel) {
        for yy in y..<(y+h) { for xx in x..<(x+w) {
            if pow((Double(xx-x)+0.5)/Double(w)*2-1,2)+pow((Double(yy-y)+0.5)/Double(h)*2-1,2) <= 1 { rect(xx,yy,1,1,p) }
        } }
    }
    mutating func oval(_ x:Int,_ y:Int,_ w:Int,_ h:Int,_ p:Pixel) { ellipse(x,y,w,h,ink); ellipse(x+1,y+1,w-2,h-2,p) }
    mutating func poly(_ points:[(Int,Int)],_ p:Pixel) {
        let x0=points.map{$0.0}.min()!, x1=points.map{$0.0}.max()!, y0=points.map{$0.1}.min()!, y1=points.map{$0.1}.max()!
        for y in y0...y1 { for x in x0...x1 {
            var inside=false, j=points.count-1
            for i in points.indices {
                let a=points[i], c=points[j], py=Double(y)+0.5, px=Double(x)+0.5
                if (Double(a.1)>py) != (Double(c.1)>py) && px < Double(c.0-a.0)*(py-Double(a.1))/Double(c.1-a.1)+Double(a.0) { inside.toggle() }
                j=i
            }
            if inside { rect(x,y,1,1,p) }
        } }
    }
    mutating func line(_ x0:Int,_ y0:Int,_ x1:Int,_ y1:Int,_ p:Pixel,_ thick:Int=1) {
        let n=max(abs(x1-x0),abs(y1-y0))
        for i in 0...max(1,n) { rect(x0+(x1-x0)*i/max(1,n),y0+(y1-y0)*i/max(1,n),thick,thick,p) }
    }
    mutating func star(_ x:Int,_ y:Int,_ p:Pixel) { rect(x+2,y,1,5,p); rect(x,y+2,5,1,p); rect(x+1,y+1,3,3,p) }
    // A one-art-cell outline surrounds the union, including thin strings. This
    // does not fill transparent holes in glasses or handles.
    func sprite(pivot:[Int], outline:Bool=true) -> (Bitmap,[Int]) {
        var raster=b
        if outline {
            for y in 1..<(b.height-1) { for x in 1..<(b.width-1) where b[x,y].a==0 {
                if [(x-1,y),(x+1,y),(x,y-1),(x,y+1)].contains(where:{b[$0.0,$0.1].a>0 && b[$0.0,$0.1] != ink}) { raster[x,y]=ink }
            } }
        }
        let pixels=(0..<(raster.width*raster.height)).filter{raster[$0%raster.width,$0/raster.width].a>0}
        let r=bounds(pixels,width:raster.width)
        precondition(r.contains(pivot[0],pivot[1]),"Pivot outside content bounds")
        var out=Bitmap(width:r.width*2,height:r.height*2)
        for y in 0..<r.height { for x in 0..<r.width { out.rect(x*2,y*2,2,2,raster[x+r.x0,y+r.y0]) } }
        return (out,[(pivot[0]-r.x0)*2,(pivot[1]-r.y0)*2])
    }
}
func makeWardrobe() throws {
    try FileManager.default.createDirectory(at:wardrobeDir,withIntermediateDirectories:true)
    // Sizes follow the measured hello helmet and visor in art cells. The fixed
    // contract has no scale per pose, so use a modest overhang on hello that also
    // fits the wider three-quarter typing helmet.
    let g=Geometry(Bitmap(url:framesDir.appendingPathComponent("h01.png")),id:"h01")
    precondition(g.unit==2)
    var catalog=[String:Any]()
    func item(_ id:String,_ slot:String,_ pivot:[Int],_ draw:(inout Art)->Void) {
        var a=Art(); draw(&a)
        var fittedPivot=pivot
        // A fixed-size overlay must fit the smallest upright visor and raised fist.
        let factor = slot == "face" ? 0.8 : (slot == "hand" ? 0.7 : 1.0)
        let scaleX = ["wings","backpack","jetpack"].contains(id) ? 1.25 : factor
        let scaleY = id == "cape" ? 0.85 : factor
        if scaleX != 1 || scaleY != 1 {
            let original=a.b
            a.b=Bitmap(width:180,height:140)
            a.b.blit(original,0,0,width:Int(180*scaleX),height:Int(140*scaleY))
            fittedPivot=[Int(Double(pivot[0])*scaleX),Int(Double(pivot[1])*scaleY)]
        }
        let (sprite,p)=a.sprite(pivot:fittedPivot)
        sprite.write(wardrobeDir.appendingPathComponent(id+".png"))
        let anchor=id == "headphones" ? "visor" : ["head":"head","face":"visor","neck":"neck","back":"back","hand":"handR"][slot]!
        catalog[id]=["slot":slot,"anchorPoint":anchor,"pivot":p,"layer":slot=="back" ? "back":"front"]
    }
    item("baseball-cap","head",[40,34]) { a in
        a.ellipse(16,20,48,34,teal); a.rect(12,37,58,4,teal); a.rect(49,39,24,3,teal)
        a.line(40,21,40,35,color("2A706D")); a.rect(39,19,4,2,gold); a.rect(23,34,35,3,color("2A706D"))
        a.star(32,26,paper); a.rect(16,42,52,14,.clear)
    }
    item("beanie","head",[40,34]) { a in
        a.ellipse(17,16,46,44,purple); a.rect(15,35,50,7,color("55436F")); a.rect(16,42,50,24,.clear)
        for x in stride(from:21,through:60,by:6) { a.line(x,27,x,34,color("A18ABF")); a.rect(x,37,2,3,purple) }
        a.oval(35,10,11,9,gold); a.box(45,36,8,5,woodLight)
    }
    item("party-hat","head",[40,37]) { a in
        a.poly([(17,43),(40,17),(64,43)],coral); a.line(29,31,51,31,gold,3); a.line(34,25,47,25,paper,2)
        a.oval(36,14,8,8,gold); a.rect(17,41,47,3,gold); a.rect(36,34,4,4,teal)
    }
    item("crown","head",[40,27]) { a in
        a.poly([(15,14),(27,22),(40,9),(53,22),(66,14),(61,34),(20,34)],gold)
        a.rect(20,30,42,4,color("C18B35")); a.box(37,22,7,7,coral); a.rect(24,26,3,3,cyan); a.rect(54,26,3,3,cyan)
        for x in [14,38,64] { a.ellipse(x,10-(x==38 ? 4:0),4,4,paper) }
    }
    item("wizard-hat","head",[40,38]) { a in
        a.poly([(20,42),(34,22),(51,15),(48,25),(61,42)],purple); a.ellipse(11,39,59,7,purple)
        a.rect(24,36,33,4,color("55436F")); a.star(38,23,gold); a.rect(45,20,2,2,paper); a.rect(49,31,2,2,gold)
    }
    item("chef-hat","head",[40,33]) { a in
        a.oval(14,13,23,23,paper); a.oval(27,10,26,26,paper); a.oval(44,13,23,23,paper)
        a.rect(22,25,38,14,paper); a.rect(24,35,34,4,color("B8BDCA")); a.line(32,27,32,34,color("D4D7DF")); a.line(50,25,50,34,color("D4D7DF"))
    }
    item("cowboy-hat","head",[40,30]) { a in
        a.poly([(22,34),(26,13),(38,17),(48,13),(58,34)],woodLight)
        a.poly([(8,29),(22,34),(60,34),(74,27),(68,38),(19,40)],woodLight)
        a.rect(24,29,35,5,woodDark); a.box(39,29,6,5,gold); a.line(30,16,30,27,color("E9B984"))
    }
    item("headphones","head",[40,32]) { a in
        a.ellipse(12,10,56,52,steel); a.ellipse(16,14,48,47,.clear); a.rect(20,40,42,28,.clear)
        a.box(11,22,10,21,steel); a.box(60,22,10,21,steel)
        a.rect(13,26,3,12,orange); a.rect(65,26,3,12,orange); a.rect(29,11,22,2,purple); a.rect(0,43,80,30,.clear)
    }
    item("round-glasses","face",[40,25]) { a in
        a.ellipse(20,17,17,17,gold); a.ellipse(22,19,13,13,.clear)
        a.ellipse(44,17,17,17,gold); a.ellipse(46,19,13,13,.clear)
        a.line(36,24,44,24,gold); a.line(15,22,20,23,gold); a.line(60,23,66,22,gold)
        a.rect(24,20,2,3,paper); a.rect(48,20,2,3,paper)
    }
    item("sunglasses","face",[40,25]) { a in
        a.poly([(17,19),(37,20),(34,32),(23,32)],steel); a.poly([(43,20),(63,19),(57,32),(46,32)],steel)
        a.line(16,19,64,19,ink,2); a.rect(37,22,7,2,ink); a.line(22,22,27,22,cyan,2); a.line(48,22,53,22,cyan,2)
    }
    item("pixel-shades","face",[40,25]) { a in
        a.rect(17,19,46,4,ink); a.rect(20,23,17,7,ink); a.rect(43,23,17,7,ink)
        for x in [22,28,45,51] { a.rect(x,23,3,2,paper); a.rect(x+3,25,3,2,paper) }
    }
    item("monocle","face",[39,25]) { a in
        a.ellipse(44,17,18,18,gold); a.ellipse(46,19,14,14,.clear); a.line(38,24,44,24,gold)
        a.line(60,30,63,42,gold,2); a.line(63,42,60,50,gold,2); a.rect(49,20,2,4,paper)
    }
    item("scarf","neck",[40,12]) { a in
        a.poly([(24,9),(38,12),(56,8),(56,15),(39,19),(24,15)],coral)
        a.poly([(48,15),(58,13),(63,34),(54,32)],coral); a.line(53,20,59,20,gold,2)
        a.rect(54,29,2,6,gold); a.rect(58,30,2,5,gold)
    }
    item("bow-tie","neck",[40,14]) { a in
        a.poly([(25,8),(40,13),(56,8),(56,21),(40,16),(25,21)],purple)
        a.box(37,11,7,7,gold); a.line(28,12,34,14,color("A18ABF")); a.line(48,14,53,12,color("A18ABF"))
    }
    item("gold-medal","neck",[40,8]) { a in
        a.line(26,7,39,25,coral,3); a.line(54,7,41,25,coral,3)
        a.oval(33,23,17,17,gold); a.ellipse(36,26,11,11,color("C18B35")); a.star(39,29,gold)
    }
    item("necktie","neck",[40,10]) { a in
        a.poly([(36,7),(45,7),(43,13),(46,32),(40,37),(35,32),(38,13)],teal)
        a.line(37,21,44,18,paper,2); a.line(36,29,45,25,color("78C8B6"),2)
    }
    item("cape","back",[40,12]) { a in
        a.poly([(24,9),(56,9),(76,70),(60,74),(42,70),(22,74),(6,70)],coral)
        a.line(24,17,17,65,color("A24C54"),2); a.line(55,17,65,65,color("A24C54"),2)
        a.line(40,20,40,66,color("EF9E7E"),2); a.rect(27,9,27,3,gold)
    }
    item("backpack","back",[40,16]) { a in
        a.box(13,15,51,40,teal); a.box(18,18,41,32,color("317871")); a.box(15,37,16,15,teal)
        a.box(10,25,6,18,gold); a.box(60,26,8,17,gold); a.box(29,11,19,7,woodLight)
        a.rect(23,20,3,29,woodLight); a.rect(51,20,3,29,woodLight); a.rect(19,41,9,2,gold)
    }
    item("jetpack","back",[40,17]) { a in
        a.box(12,14,16,38,steel); a.box(52,14,16,38,steel); a.box(26,21,29,22,color("8993A4"))
        for x in [16,56] { a.rect(x,19,8,17,paper); a.rect(x,37,8,5,orange); a.poly([(x,53),(x+8,53),(x+4,67)],orange); a.poly([(x+2,53),(x+6,53),(x+4,61)],gold) }
    }
    item("wings","back",[40,22]) { a in
        for right in [false,true] {
            func x(_ v:Int)->Int { right ? 80-v:v }
            a.poly([(x(37),27),(x(11),6),(x(5),9),(x(9),31),(x(17),39),(x(36),42)],paper)
            for i in 0..<4 { a.line(x(11+i*5),16+i*3,x(20+i*4),35+i,color("B8BDCA")) }
        }
        a.rect(35,21,11,19,paper)
    }
    item("coffee-mug","hand",[39,32]) { a in
        a.oval(32,22,12,15,paper); a.ellipse(35,25,6,8,.clear)
        a.box(15,20,21,22,paper); a.rect(17,21,17,3,woodDark); a.rect(18,25,3,12,color("D4D7DF")); a.star(24,28,orange)
    }
    item("trophy","hand",[40,42]) { a in
        a.oval(22,9,37,20,gold); a.ellipse(25,12,31,13,.clear)
        a.poly([(29,8),(52,8),(49,25),(42,29),(34,25)],gold); a.rect(38,27,5,10,gold)
        a.box(31,37,20,7,woodDark); a.rect(36,39,10,3,gold); a.rect(33,11,3,10,paper)
    }
    item("balloon","hand",[40,67]) { a in
        a.line(72,29,55,45,paper,2); a.line(55,45,40,67,paper,2)
        a.oval(60,4,28,30,coral); a.poly([(73,32),(70,37),(77,37)],coral); a.rect(65,11,3,9,paper)
    }
    item("small-flag","hand",[40,48]) { a in
        a.line(40,7,40,49,woodLight,2); a.poly([(42,8),(64,11),(59,19),(64,27),(42,24)],teal)
        a.star(49,15,gold); a.oval(38,4,6,6,gold)
    }
    try saveJSON(catalog,wardrobeDir.appendingPathComponent("wardrobe-sprites.json"))
    try makeColorways()
    print("Wardrobe: \(catalog.count) cropped 2-pixel sprites")
}
func makeColorways() throws {
    // Count exact opaque RGB values across ALL contract frames. Resampled source
    // art has many fringe shades, so map every observed color, not only the top six.
    var counts=[String:Int]()
    for url in frameFiles {
        let b=Bitmap(url:url)
        for y in 0..<b.height { for x in 0..<b.width where b[x,y].a==255 { counts[hex(b[x,y]),default:0]+=1 } }
    }
    let ranked=counts.keys.sorted { counts[$0]==counts[$1] ? $0<$1:counts[$0]!>counts[$1]! }
    print("Most common opaque colors: "+ranked.prefix(18).map{"\($0):\(counts[$0]!)"}.joined(separator:", "))
    // Ordered shell ramps: dark joints, mid shadow, pale shadow, shell, highlight.
    let ramps:[(String,String,[String],String,String)] = [
        ("classic","Classic",[],"FF771A","49EBFF"),
        ("midnight","Midnight",["19253D","2A3C5B","3F577C","567196","718BA9"],"F2C458","74E7FF"),
        ("mint","Mint",["294C49","488378","7CB8A4","B4E3CC","E7FFF0"],"E69F63","79E9FA"),
        ("sunset","Sunset",["58384B","97556A","D8898E","FFC0A2","FFE6CB"],"F58B45","80E4ED"),
        ("gold","Gold",["58482D","947341","C8A15C","EDC879","FFF0BB"],"E08B40","A2EEEC"),
        ("stealth","Stealth",["222329","36383F","4B4E58","626670","81858F"],"D85450","FF534F")]
    func mix(_ a:Pixel,_ b:Pixel,_ t:Double)->Pixel {
        Pixel(r:UInt8((Double(a.r)*(1-t)+Double(b.r)*t).rounded()),g:UInt8((Double(a.g)*(1-t)+Double(b.g)*t).rounded()),b:UInt8((Double(a.b)*(1-t)+Double(b.b)*t).rounded()),a:255)
    }
    var output=[String:Any]()
    for (id,name,ramp,warm,glow) in ramps {
        var map=[String:String]()
        for source in ranked {
            let p=color(source), hi=Int(max(p.r,p.g,p.b)), lo=Int(min(p.r,p.g,p.b))
            var target=p
            if id != "classic" && hi>=80 {
                if Int(p.g)-Int(p.r)>22 && Int(p.b)-Int(p.r)>22 {
                    target=mix(ink,color(glow),Double(hi)/255)
                } else if Int(p.r)-Int(p.b)>35 && Int(p.r)-Int(p.g)>25 {
                    target=mix(ink,color(warm),Double(hi)/255)
                } else {
                    let lum=Double(Int(p.r)+Int(p.g)+Int(p.b))/3
                    let stops:[Double]=[80,120,175,232,255]
                    let colors=ramp.map{color($0)}
                    var index=0
                    while index<3 && lum>stops[index+1] { index+=1 }
                    let t=max(0,min(1,(lum-stops[index])/(stops[index+1]-stops[index])))
                    target=mix(colors[index],colors[index+1],t)
                    // Very saturated mood marks retain their established identity.
                    if hi-lo>150 && Int(p.r)>220 && Int(p.g)<80 { target = id=="stealth" ? color(glow):p }
                }
            }
            // Every original black visor/joint value is identity, including fringes
            // below 80. This keeps visor black under all six global color maps.
            map[source]=hex(target)
        }
        output[id]=["name":name,"map":map]
    }
    try saveJSON(output,framesDir.appendingPathComponent("colorways.json"))
    print("Colorways: \(output.count), \(counts.count) exact source colors each")
}
if CommandLine.arguments.last == "wardrobe" { try makeWardrobe() }
func makeHome() throws {
    try FileManager.default.createDirectory(at:homeDir,withIntermediateDirectories:true)
    var rooms=[String:Any](), items=[String:Any]()
    for id in ["cozy","studio","night"] {
        let night=id=="night", modern=id=="studio"
        var a=Art()
        let wall=night ? color("293850"):(modern ? color("D7DDD7"):color("C99B73"))
        a.rect(0,0,180,120,wall)
        if modern {
            a.rect(0,0,180,6,color("B7C6BE")); a.rect(8,8,2,79,color("C1CEC4"))
            a.rect(168,8,2,79,color("C1CEC4")); a.rect(9,80,160,2,color("B7C6BE"))
        } else {
            for y in stride(from:5,to:89,by:12) {
                a.rect(0,y,180,1,night ? color("202E45"):color("AD7C58"))
                for x in stride(from:(y/12)%2*28+7,to:180,by:55) {
                    a.rect(x,y+1,1,10,night ? color("31435B"):color("DCB18A"))
                    a.rect(x+16,y+5,8,1,night ? color("304058"):color("B88861"))
                }
            }
            a.rect(0,0,7,91,night ? color("182A3E"):woodDark)
            a.rect(173,0,7,91,night ? color("182A3E"):woodDark)
            a.rect(0,0,180,5,night ? color("182A3E"):woodDark)
        }
        a.rect(0,90,180,30,night ? color("3E3F51"):color("AA7D5D"))
        a.rect(0,86,180,4,night ? color("1C2A3E"):woodDark)
        for y in stride(from:98,to:120,by:10) {
            a.rect(0,y,180,1,night ? color("2D3347"):color("875F4A"))
            for x in stride(from:(y/10)%2*23,to:180,by:43) { a.rect(x,y-8,1,8,night ? color("34394C"):color("966D52")) }
        }
        // Fixed architectural round window, with a separate window-slot sill.
        a.oval(119,15,45,45,night ? color("17273D"):woodDark)
        a.ellipse(122,18,39,39,night ? color("111D39"):color("9CD4D9"))
        if night {
            for (x,y) in [(131,25),(150,24),(139,41),(153,39),(128,43)] { a.star(x,y,color("CFDAD4")) }
            a.ellipse(137,25,10,10,gold); a.ellipse(141,23,9,10,color("111D39"))
        } else {
            a.ellipse(144,23,8,8,color("FFF0BE")); a.rect(129,36,15,3,paper)
            a.poly([(124,47),(134,38),(144,48),(151,39),(158,48),(151,54),(132,54)],color("68AAA8"))
        }
        a.rect(140,18,2,39,night ? color("3F5365"):woodLight)
        a.rect(122,36,39,2,night ? color("3F5365"):woodLight)
        a.box(117,59,49,4,night ? color("455166"):woodLight)
        // Hanging practical light and restrained stepped light pool.
        a.line(88,5,88,14,night ? color("6F7480"):woodDark)
        a.poly([(82,13),(94,13),(99,20),(77,20)],night ? color("A58655"):gold)
        a.rect(81,20,14,2,night ? color("D5AF71"):color("FFE3A0"))
        if !modern { a.rect(29,7,1,77,night ? color("3A4559"):color("D7AC84")) }
        var room=Bitmap(width:360,height:240)
        for y in 0..<120 { for x in 0..<180 { room.rect(x*2,y*2,2,2,a.b[x,y]) } }
        room.write(homeDir.appendingPathComponent("room-"+id+".png"))
        rooms[id]=["name":["cozy":"Cozy hut","studio":"Studio","night":"Night hut"][id]!,"file":"room-"+id+".png","floorY":180,
            "slots":["floorLeft":[64,218],"floorRight":[300,218],"wallLeft":[95,45],"wallRight":[210,91],"window":[282,120],"rug":[184,208],"desk":[94,154],"shelf":[60,150]],"mascotSpot":[214,218]]
    }
    func item(_ id:String,_ name:String,_ slot:String,_ pivot:[Int],_ draw:(inout Art)->Void) {
        var a=Art(); draw(&a)
        let (sprite,p)=a.sprite(pivot:pivot)
        sprite.write(homeDir.appendingPathComponent(id+".png"))
        items[id]=["name":name,"file":id+".png","slot":slot,"pivot":p]
    }
    item("desk-monitor","Desk and monitor","desk",[40,36]) { a in
        a.box(8,36,65,6,woodLight); a.box(13,42,5,23,wood); a.box(64,42,5,23,wood)
        a.box(27,12,35,23,steel); a.rect(30,15,29,16,color("284C63")); a.rect(32,18,13,2,cyan)
        for y in [23,27] { a.rect(33,y,19-(y-23)*2,1,color("73A6B4")) }
        a.rect(43,35,4,2,steel); a.rect(38,37,14,1,steel); a.box(33,39,23,2,color("8993A4"))
        a.box(20,44,39,8,wood); a.rect(36,47,8,1,gold); a.rect(10,37,12,1,color("F1C796"))
    }
    item("desk-lamp","Desk lamp","desk",[39,39]) { a in
        a.oval(29,35,21,5,steel); a.line(39,34,45,24,steel,2); a.line(45,24,39,15,steel,2)
        a.oval(41,23,5,5,gold); a.poly([(30,11),(43,11),(47,19),(26,19)],teal); a.rect(29,19,15,2,gold)
    }
    item("potted-plant","Potted plant","window",[39,42]) { a in
        a.line(39,31,39,13,woodDark,2); a.oval(28,16,11,7,teal); a.oval(40,12,12,8,color("79B88F"))
        a.oval(30,25,10,6,color("79B88F")); a.poly([(29,30),(50,30),(47,43),(32,43)],coral)
        a.rect(29,30,21,3,woodLight); a.rect(34,35,2,6,color("EDAA8E"))
    }
    item("big-plant","Big plant","floorRight",[40,72]) { a in
        a.line(40,55,40,15,woodDark,2)
        for (x,y,w,h) in [(22,16,18,11),(41,9,19,13),(18,33,22,11),(41,27,23,13),(27,4,13,18)] { a.oval(x,y,w,h,teal); a.line(x+3,y+h/2,x+w-3,y+h/2,color("79B88F")) }
        a.poly([(26,51),(55,51),(50,73),(31,73)],color("D1AA82")); a.rect(27,52,27,3,woodDark)
        a.rect(34,58,2,11,color("E8CCAA")); a.rect(47,58,2,11,woodLight)
    }
    item("round-rug","Round rug","rug",[42,19]) { a in
        a.oval(5,5,75,29,teal); a.ellipse(8,8,69,23,color("92C3AE")); a.ellipse(12,11,61,17,teal)
        a.poly([(22,19),(42,12),(62,19),(42,26)],color("B9D6BF")); a.poly([(32,19),(42,15),(52,19),(42,23)],woodLight)
    }
    item("bookshelf","Bookshelf","shelf",[35,62]) { a in
        a.box(11,8,48,55,woodDark); a.rect(15,12,40,47,wood)
        for y in [27,44,59] { a.rect(13,y,44,3,woodLight) }
        for (x,h,p) in [(17,12,teal),(23,15,coral),(29,11,gold),(35,14,purple),(43,13,steel)] {
            a.box(x,27-h,5,h,p); a.rect(x+1,26-h+3,3,1,paper)
        }
        a.box(17,34,12,9,color("D4C2A2")); a.rect(20,37,6,2,woodDark)
        for i in 0..<3 { a.box(35,39-i*3,16-i*2,3,[coral,teal,paper][i]) }
        a.oval(22,48,11,9,teal); a.box(40,49,11,10,coral); a.rect(43,52,5,1,gold)
    }
    item("poster","Mountain poster","wallLeft",[27,24]) { a in
        a.box(10,5,35,39,woodDark); a.rect(12,7,31,35,color("E3CEAD")); a.rect(15,10,25,24,color("8CAEB1"))
        a.ellipse(29,12,7,7,gold); a.poly([(16,33),(26,18),(38,33)],teal); a.poly([(22,24),(26,18),(31,24)],paper)
        a.rect(18,37,20,1,woodDark); a.rect(22,39,12,1,wood)
    }
    item("wall-clock","Wall clock","wallRight",[26,23]) { a in
        a.oval(10,7,33,33,woodDark); a.ellipse(13,10,27,27,paper)
        for (x,y) in [(26,12),(26,32),(15,22),(36,22)] { a.rect(x,y,2,3,woodDark) }
        a.line(26,23,26,16,steel,2); a.line(26,23,32,26,steel,2); a.rect(25,22,3,3,orange)
    }
    item("floor-lamp","Floor lamp","floorLeft",[27,76]) { a in
        a.oval(14,71,27,6,woodDark); a.rect(26,28,3,46,woodLight)
        a.poly([(16,9),(38,9),(46,30),(8,30)],gold); a.rect(12,28,30,3,color("FFE3A0")); a.line(34,31,34,40,woodDark)
        for x in [20,27,34] { a.line(x,12,x,25,color("E2AB58")) }
    }
    item("bean-bag","Bean bag","floorRight",[35,43]) { a in
        a.poly([(7,34),(10,22),(23,11),(42,8),(56,20),(63,36),(53,45),(18,45)],purple)
        a.ellipse(20,14,29,23,color("9A82B7")); a.line(14,35,27,41,color("55436F")); a.line(48,19,55,37,color("55436F"))
    }
    item("coffee-machine","Coffee machine on stool","floorLeft",[31,61]) { a in
        a.box(10,35,42,5,woodLight); a.box(14,40,4,22,wood); a.box(44,40,4,22,wood); a.rect(17,51,28,3,woodDark)
        a.box(17,10,30,25,steel); a.rect(20,13,24,6,teal); a.rect(21,21,21,10,ink)
        a.rect(32,19,3,5,woodLight); a.box(28,26,10,6,paper); a.rect(26,32,16,2,color("8993A4")); a.rect(38,14,3,3,orange)
    }
    item("cat-bed","Sleeping cat bed","floorLeft",[33,30]) { a in
        a.oval(5,17,57,20,woodDark); a.ellipse(9,19,49,14,coral)
        a.oval(18,11,32,19,woodLight); a.oval(13,13,19,14,color("E8BA83"))
        a.poly([(14,16),(14,8),(21,14),(27,8),(29,18)],color("E8BA83")); a.line(17,21,20,22,woodDark); a.line(24,22,27,21,woodDark)
        a.line(43,15,48,21,woodDark,2); a.line(47,23,36,25,woodDark,2); a.line(32,13,33,18,woodDark,2)
    }
    item("guitar","Guitar on stand","floorRight",[28,64]) { a in
        a.line(28,43,28,62,steel,2); a.line(28,57,15,64,steel,2); a.line(28,57,42,64,steel,2)
        a.oval(14,37,28,24,woodLight); a.oval(19,28,20,21,woodLight); a.box(26,9,7,29,woodDark)
        a.box(24,5,11,9,woodLight); a.oval(24,38,10,10,woodDark); a.rect(25,53,9,3,woodDark)
        a.line(28,11,28,54,gold); a.line(31,11,31,54,gold); a.rect(23,7,2,2,steel); a.rect(35,10,2,2,steel)
    }
    item("record-player","Record player","desk",[32,26]) { a in
        a.box(9,12,48,15,wood); a.rect(11,14,44,10,woodLight); a.oval(15,13,25,11,ink)
        a.ellipse(23,16,9,5,coral); a.rect(26,18,2,1,gold); a.line(49,15,49,19,steel,2); a.line(49,19,36,22,steel)
        a.rect(12,25,4,3,ink); a.rect(49,25,4,3,ink); a.rect(50,22,3,2,teal)
    }
    item("certificate","Framed certificate","wallRight",[30,22]) { a in
        a.box(7,7,47,31,woodDark); a.box(9,9,43,27,gold); a.rect(12,12,37,21,paper)
        a.rect(19,15,23,2,steel); a.rect(16,20,29,1,color("8993A4")); a.rect(19,23,23,1,color("8993A4")); a.oval(26,26,8,7,gold)
    }
    item("string-lights","String lights","wallLeft",[42,14]) { a in
        a.line(3,7,23,14,woodDark); a.line(23,14,61,14,woodDark); a.line(61,14,82,7,woodDark)
        for (i,x) in [9,21,34,47,60,73].enumerated() {
            let y = (x<20 || x>65) ? 12:17
            a.line(x,y-4,x,y,woodDark); a.oval(x-2,y,5,6,i%2==0 ? gold:coral); a.rect(x,y+1,1,2,paper)
        }
    }
    try saveJSON(["rooms":rooms,"items":items],homeDir.appendingPathComponent("home-items.json"))
    print("Home: \(rooms.count) rooms, \(items.count) furniture sprites")
}
if CommandLine.arguments.last == "home" { try makeHome() }
func makePreview() throws {
    let anchors=try json(framesDir.appendingPathComponent("mascot-anchors.json"))
    let wardrobe=try json(wardrobeDir.appendingPathComponent("wardrobe-sprites.json"))
    let colorways=try json(framesDir.appendingPathComponent("colorways.json"))
    let home=try json(homeDir.appendingPathComponent("home-items.json"))
    let rooms=home["rooms"] as! [String:[String:Any]], furniture=home["items"] as! [String:[String:Any]]
    let clips=try json(framesDir.appendingPathComponent("mascot-clips.json"))
    let hello=(clips["hello"] as! [String:Any])["rest"] as! String
    let typing=(clips["working"] as! [String:Any])["rest"] as! String
    func recolored(_ b:Bitmap,_ id:String)->Bitmap {
        let map=(colorways[id] as! [String:Any])["map"] as! [String:String]
        var out=b
        for y in 0..<b.height { for x in 0..<b.width where b[x,y].a>0 {
            let p=b[x,y]
            if let target=map[hex(p)] { var c=color(target); c.a=p.a; out[x,y]=c }
        } }
        return out
    }
    func dressed(_ frame:String,_ ids:[String],_ way:String="classic")->Bitmap {
        let anchor=anchors[frame] as! [String:Any]
        let original=recolored(Bitmap(url:framesDir.appendingPathComponent(frame+".png")),way)
        var out=Bitmap(width:314,height:314)
        func overlay(_ id:String) {
            let entry=wardrobe[id] as! [String:Any], key=entry["anchorPoint"] as! String
            guard let point=anchor[key] as? [Int] else { return }
            let sprite=Bitmap(url:wardrobeDir.appendingPathComponent(id+".png")), pivot=entry["pivot"] as! [Int]
            let slot=entry["slot"] as! String
            let theta=(slot=="head" || slot=="face") ? (anchor["tilt"] as! Double)*Double.pi/180:0
            if theta==0 { out.blit(sprite,point[0]-pivot[0],point[1]-pivot[1]); return }
            var layer=Bitmap(width:314,height:314)
            for y in 0..<314 { for x in 0..<314 {
                let dx=Double(x-point[0]),dy=Double(y-point[1])
                let sx=Int((cos(theta)*dx+sin(theta)*dy+Double(pivot[0])).rounded())
                let sy=Int((-sin(theta)*dx+cos(theta)*dy+Double(pivot[1])).rounded())
                if sx>=0 && sy>=0 && sx<sprite.width && sy<sprite.height { layer[x,y]=sprite[sx,sy] }
            } }
            out.blit(layer,0,0)
        }
        for id in ids where (wardrobe[id] as! [String:Any])["layer"] as! String=="back" { overlay(id) }
        out.blit(original,0,0)
        for id in ids where (wardrobe[id] as! [String:Any])["layer"] as! String=="front" { overlay(id) }
        return out
    }
    var sheet=Bitmap(width:1440,height:2400,fill:color("252C37"))
    label("COMPANION / WARDROBE AND HOME",&sheet,28,24,3)
    label("PIVOT ON ANCHOR / BACK THEN ROBOT THEN FRONT / NEAREST NEIGHBOR",&sheet,28,51)
    let outfit=["beanie","round-glasses","scarf","wings","coffee-mug"]
    for (i,id) in [hello,typing,"e01"].enumerated() {
        let x=28+i*466, b=dressed(id,outfit)
        label(id+" / FIVE SLOTS",&sheet,x,85)
        sheet.blit(b,x+4,105)
        sheet.blit(b,x+314,136,width:124,height:124)
        label("62 PT 2X",&sheet,x+314,270,1)
        sheet.blit(b,x+343,297,width:62,height:62)
        label("62 PX",&sheet,x+328,371,1)
    }
    label("24 WARDROBE SPRITES / NATIVE IMAGE PIXELS",&sheet,28,438)
    let order=["baseball-cap","beanie","party-hat","crown","wizard-hat","chef-hat","cowboy-hat","headphones","round-glasses","sunglasses","pixel-shades","monocle","scarf","bow-tie","gold-medal","necktie","cape","backpack","jetpack","wings","coffee-mug","trophy","balloon","small-flag"]
    for (i,id) in order.enumerated() {
        let x=24+i%6*236,y=468+i/6*176
        sheet.rect(x,y,220,160,color("303A47"))
        let b=Bitmap(url:wardrobeDir.appendingPathComponent(id+".png"))
        sheet.blit(b,x+(220-b.width)/2,y+6+(132-b.height)/2)
        label(id,&sheet,x+10,y+145,1)
    }
    label("SIX COLORWAYS / EXACT SOURCE COLOR MAP",&sheet,28,1196)
    for (i,id) in ["classic","midnight","mint","sunset","gold","stealth"].enumerated() {
        let x=24+i*236,b=recolored(Bitmap(url:framesDir.appendingPathComponent(hello+".png")),id)
        sheet.blit(b,x+10,1230,width:206,height:206)
        label(id,&sheet,x+15,1450)
    }
    label("HOME / 340 PX WIDE / FEET ON MASCOT SPOT",&sheet,28,1490)
    let sets=[
        ["round-rug","wall-clock","bookshelf","desk-monitor","potted-plant","big-plant","cat-bed"],
        ["round-rug","certificate","poster","desk-monitor","potted-plant","guitar"],
        ["round-rug","string-lights","certificate","bookshelf","potted-plant","bean-bag","floor-lamp"]]
    for (i,id) in ["cozy","studio","night"].enumerated() {
        let room=rooms[id]!, slots=room["slots"] as! [String:[Int]], spot=room["mascotSpot"] as! [Int]
        var scene=Bitmap(url:homeDir.appendingPathComponent(room["file"] as! String))
        for itemID in sets[i] {
            let item=furniture[itemID]!,p=item["pivot"] as! [Int], xy=slots[item["slot"] as! String]!
            scene.blit(Bitmap(url:homeDir.appendingPathComponent(item["file"] as! String)),xy[0]-p[0],xy[1]-p[1])
        }
        let b=dressed(hello,["beanie","scarf"],i==2 ? "midnight":"classic")
        // Feet derive from opaque pixels in the lower half, excluding floaty mood
        // marks and the antenna. Canvas scaling is 0.46, identical in both axes.
        let footPixels=(0..<(b.width*b.height)).filter{$0/b.width>190 && b[$0%b.width,$0/b.width].a>200}
        let feet=bounds(footPixels,width:b.width), scale=0.46, size=Int(314*scale)
        scene.blit(b,spot[0]-Int(Double(feet.midX)*scale),spot[1]-Int(Double(feet.y1)*scale),width:size,height:size)
        let x=60+i*466
        label(id,&sheet,x,1530)
        sheet.blit(scene,x,1555,width:340,height:227)
        scene.write(URL(fileURLWithPath:"/tmp/clockin-home-"+id+".png"))
    }
    label("16 FURNITURE SPRITES / NATIVE IMAGE PIXELS",&sheet,28,1830)
    for (i,id) in furniture.keys.sorted().enumerated() {
        let x=24+i%8*177,y=1864+i/8*225,b=Bitmap(url:homeDir.appendingPathComponent(id+".png"))
        sheet.rect(x,y,165,208,color("303A47")); sheet.blit(b,x+(165-b.width)/2,y+18+(160-b.height)/2)
        label(id,&sheet,x+5,y+192,1)
    }
    label("SOURCE CANVAS 314 X 314 / ART CELL 2 X 2 / ROOMS 360 X 240",&sheet,28,2340)
    sheet.write(URL(fileURLWithPath:"/tmp/clockin-wardrobe-preview.png"))
    // Every sprite is additionally tried on both required poses, avoiding a
    // showcase outfit that hides a poorly fitting individual item.
    var fit=Bitmap(width:1440,height:24*174,fill:color("252C37"))
    for (i,id) in order.enumerated() {
        label(id,&fit,12,i*174+12)
        for (j,frame) in [hello,typing,"c07","e01"].enumerated() {
            let b=dressed(frame,[id])
            fit.blit(b,250+j*290,i*174,width:174,height:174)
            fit.blit(b,430+j*290,i*174+50,width:62,height:62)
        }
    }
    fit.write(URL(fileURLWithPath:"/tmp/clockin-wardrobe-fit.png"))
    for page in 0..<4 {
        var detail=Bitmap(width:1440,height:1044)
        for y in 0..<1044 { for x in 0..<1440 { detail[x,y]=fit[x,page*1044+y] } }
        detail.write(URL(fileURLWithPath:"/tmp/clockin-wardrobe-fit-\(page+1).png"))
    }
    print("Preview: /tmp/clockin-wardrobe-preview.png; all-item pose checks: /tmp/clockin-wardrobe-fit.png")
}
if CommandLine.arguments.last == "preview" { try makePreview() }
