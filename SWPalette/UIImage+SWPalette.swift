//
//  UIImage+SWPalette.swift
//  SWPalette
//
//  Copyright (c) 2015 cowbay.wtf. All rights reserved.
//

import UIKit

public extension UIImage {
    public func swpalette_generate(maxColors:Int = DEFAULT_CALCULATE_NUMBER_COLORS) -> SWPalette {
        return buildPaletteFrom(self.CGImage, maxColors: maxColors)
    }
    
    public func swpalette_generateAsync(maxColors:Int = DEFAULT_CALCULATE_NUMBER_COLORS, callback: (SWPalette) -> ()) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            let palette = buildPaletteFrom(self.CGImage, maxColors: maxColors)
            
            dispatch_async(dispatch_get_main_queue()) {
                callback(palette)
            }
        }
    }
}
