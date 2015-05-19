//
//  UIImage+SWPalette.swift
//  SWPalette
//
//  Copyright (c) 2015 cowbay.wtf. All rights reserved.
//

import UIKit

public extension UIImage {
    public func swp_generatePalette() -> SWPalette {
        return buildPaletteFrom(self.CGImage)
    }
    
    public func swp_generatePaletteAsync(callback: (SWPalette) -> ()) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            let palette = buildPaletteFrom(self.CGImage)
            
            dispatch_async(dispatch_get_main_queue()) {
                callback(palette)
            }
        }
    }
}
