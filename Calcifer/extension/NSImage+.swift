//
//  NSImage+.swift
//  Calcifer
//
//  (c) 2021 Fumio Saruki (github.com/famio)
//

import AppKit

extension NSImage {
    
    var cgImage: CGImage? {
        var proposedRect = CGRect(origin: .zero, size: size)
        
        return cgImage(forProposedRect: &proposedRect,
                       context: nil,
                       hints: nil)
    }
    
    func resized(maxLength: CGFloat) -> NSImage? {
        let width, height: CGFloat
        if self.size.width < self.size.height {
            width = maxLength / self.size.height * self.size.width
            height = maxLength
        }
        else if self.size.width > self.size.height {
            width = maxLength
            height = maxLength / self.size.width * self.size.height
        }
        else {
            width = maxLength
            height = maxLength
        }
        return resized(to: .init(width: width, height: height))
    }
    
    func resized(to newSize: NSSize) -> NSImage? {
        if let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(newSize.width), pixelsHigh: Int(newSize.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) {
            bitmapRep.size = newSize
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
            draw(in: NSRect(x: 0, y: 0, width: newSize.width, height: newSize.height), from: .zero, operation: .copy, fraction: 1.0)
            NSGraphicsContext.restoreGraphicsState()

            let resizedImage = NSImage(size: newSize)
            resizedImage.addRepresentation(bitmapRep)
            return resizedImage
        }

        return nil
    }
}
