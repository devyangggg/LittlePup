// SpriteSheet.swift – slices a sprite-sheet PNG into individually cached per-frame NSImages

import AppKit // NSImage and CGImage are AppKit / CoreGraphics types

// Owns one loaded PNG and vends individual frame images on demand, caching every slice
final class SpriteSheet {

    // The full source image loaded from disk; held alive for the lifetime of this sheet
    private let sourceImage: NSImage

    // Side length of each square frame in pixels (width == height by spec)
    private let _frameSize: Int

    // Pixel dimensions of the full source image, read from its bitmap representation
    private let _pixelSize: CGSize

    // Maximum frames that fit in one row; used as the column stride for the cache key
    private let maxFramesPerRow: Int

    // Flat dictionary cache: key = row * maxFramesPerRow + index → sliced NSImage
    private var cache: [Int: NSImage] = [:]

    // Initialise with a pre-loaded image and the declared frame side length in pixels
    init(image: NSImage, frameSize: Int) {
        // Store the source image; do not load it again for each frame slice
        self.sourceImage = image
        // Record the frame size for all downstream slice calculations
        self._frameSize = frameSize
        // Read pixel counts from the first bitmap representation (not point-based image.size)
        if let rep = image.representations.first {
            self._pixelSize = CGSize(width: CGFloat(rep.pixelsWide),
                                     height: CGFloat(rep.pixelsHigh))
        } else {
            // Fall back to image.size if no bitmap representation is available
            self._pixelSize = image.size
        }
        // Precompute the column count so the cache key formula is stable across all calls
        self.maxFramesPerRow = frameSize > 0 ? Int(_pixelSize.width) / frameSize : 0
    }

    // Public read-only access to the declared frame side length
    var frameSize: Int { _frameSize }

    // Public read-only access to the full sheet's pixel dimensions
    var pixelSize: CGSize { _pixelSize }

    // Return the frame at (row, index), slicing from the source image on first access and caching it
    func frame(row: Int, index: Int) -> NSImage {
        // Compute how many full rows fit in the sheet height
        let sheetRows = _frameSize > 0 ? Int(_pixelSize.height) / _frameSize : 0
        // A negative or too-large row has no corresponding pixel data; crash loudly in all builds
        precondition(row >= 0 && row < sheetRows,
                     "SpriteSheet: row \(row) out of range — sheet has \(sheetRows) row(s)")
        // A negative or too-large column index is equally invalid
        precondition(index >= 0 && index < maxFramesPerRow,
                     "SpriteSheet: index \(index) out of range — sheet has \(maxFramesPerRow) column(s)")
        // Compute the flat cache key from row and column position
        let key = row * maxFramesPerRow + index
        // Return the cached image if this frame was already sliced
        if let cached = cache[key] {
            return cached
        }
        // CGImage uses top-left origin (same convention as the PNG file), so no Y-flip is needed
        let cropRect = CGRect(
            x: CGFloat(index * _frameSize),  // left edge of this column
            y: CGFloat(row   * _frameSize),  // top edge of this row (top-left origin)
            width:  CGFloat(_frameSize),
            height: CGFloat(_frameSize)
        )
        // Obtain a CGImage from the source NSImage; nil only if the image has no bitmap data
        guard let cg = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let cropped = cg.cropping(to: cropRect) else {
            // This can only happen with a corrupt or purely vector source; crash immediately
            preconditionFailure("SpriteSheet: could not crop frame at row \(row), index \(index)")
        }
        // Wrap the cropped CGImage in an NSImage declared at the frame's pixel size in points
        let result = NSImage(cgImage: cropped,
                             size: NSSize(width: _frameSize, height: _frameSize))
        // Store in the flat cache so this slice is never computed again
        cache[key] = result
        return result
    }

    // Return `count` consecutive frames from the given row, starting at index 0
    func frames(row: Int, count: Int) -> [NSImage] {
        // Map each column index to its cached or freshly-sliced frame image
        return (0..<count).map { frame(row: row, index: $0) }
    }

    // Pre-warm the cache for all animations in a profile so the first rendered frame is instant
    func preload(animations: [AnimationConfig]) {
        // Iterate every animation and touch each of its frames to force cache population
        for anim in animations {
            // Discard the return value; the side effect (cache fill) is what we want
            _ = frames(row: anim.row, count: anim.frameCount)
        }
    }
}
