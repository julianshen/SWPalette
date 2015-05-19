//
//  SWPalette.swift
//  SWPalette
//
//  Copyright (c) 2015 cowbay.wtf. All rights reserved.
//

import Foundation
import CoreGraphics
import UIKit

internal let MIN_ALPHA_SEARCH_MAX_ITERATIONS = 10
internal let MIN_ALPHA_SEARCH_PRECISION = 10

internal let MIN_CONTRAST_TITLE_TEXT = 3.0
internal let MIN_CONTRAST_BODY_TEXT = 4.5

internal let DEFAULT_RESIZE_BITMAP_MAX_DIMENSION = 192
internal let DEFAULT_CALCULATE_NUMBER_COLORS = 16

let COLOR_WHITE:UInt32 = 0xffffffff
let COLOR_BLACK:UInt32 = 0xff000000

public class SWPalette {
    private var mGenerator: PaletteGenerator
    private var mSwatches: [Swatch]
    
    public var swatches:[Swatch] {
        return mSwatches
    }
    
    public var vibrantSwatch:Swatch {
        return mGenerator.mVibrantSwatch!
    }
    
    public var lightVibrantSwatch:Swatch {
        return mGenerator.mLightVibrantSwatch!
    }
    
    public var darkVibrantSwatch: Swatch {
        return mGenerator.mDarkVibrantSwatch!
    }
    
    public var mutedSwatch: Swatch {
        return mGenerator.mMutedSwatch!
    }
    
    public var lightMutedSwatch: Swatch {
        return mGenerator.mLightMutedSwatch!
    }
    
    public var darkMutedSwatch: Swatch {
        return mGenerator.mDarkMutedSwatch!
    }
    
    public func getVibrantColor(defaultColor:UInt32) -> UInt32 {
        if let swatch = mGenerator.mVibrantSwatch {
            return swatch.rgb
        }
        return defaultColor
    }
    
    public func getDarkVibrantColor(defaultColor:UInt32) -> UInt32 {
        if let swatch = mGenerator.mDarkVibrantSwatch {
            return swatch.rgb
        }
        return defaultColor
    }
    
    public func getMutedColor(defaultColor:UInt32) -> UInt32 {
        if let swatch = mGenerator.mMutedSwatch {
            return swatch.rgb
        }
        return defaultColor
    }
    
    public func getLightMutedColor(defaultColor:UInt32) -> UInt32 {
        if let swatch = mGenerator.mLightMutedSwatch {
            return swatch.rgb
        }
        return defaultColor
    }
    
    public func getDarkMutedColor(defaultColor:UInt32) -> UInt32 {
        if let swatch = mGenerator.mDarkMutedSwatch {
            return swatch.rgb
        }
        return defaultColor
    }
    
    init(generator: PaletteGenerator, swatches: [Swatch]) {
        mGenerator = generator
        mSwatches = swatches
    }
}

public class Swatch: Hashable {
    private let mRed:UInt32
    private let mGreen:UInt32
    private let mBlue:UInt32
    
    private var mGeneratedTextColors:Bool = false
    
    private var mBodyTextColor:UInt32!
    private var mTitleTextColor:UInt32!
    
    private lazy var _hsl:[Float] = {
        var __hsl = [Float](count: 3, repeatedValue: 0.0)
        RGBToHSL(self.mRed, self.mGreen, self.mBlue, &__hsl)
        return __hsl
    }()

    
    let rgb:UInt32
    public let population:Int
    
    
    public var hsl:[Float] {
        get {
            return self._hsl // Make it read only
        }
    }
    
    public var titleTextColor:UIColor {
        get {
            ensureTextColorsGenerated()
            
            var hsl = [Float](count: 3, repeatedValue: 0.0)
            colorToHSL(self.mTitleTextColor, &hsl)
            return UIColor(hue: CGFloat(hsl[0]), saturation: CGFloat(hsl[1]), brightness: CGFloat(hsl[2]), alpha: 1.0)
        }
    }
    
    public var bodyTextColor:UIColor {
        get {
            ensureTextColorsGenerated()
            var hsl = [Float](count: 3, repeatedValue: 0.0)
            colorToHSL(self.mBodyTextColor, &hsl)
            return UIColor(hue: CGFloat(hsl[0]), saturation: CGFloat(hsl[1]), brightness: CGFloat(hsl[2]), alpha: 1.0)
        }
    }
    
    public var color:UIColor {
        let hsl = self.hsl
        return UIColor(hue: CGFloat(hsl[0]), saturation: CGFloat(hsl[1]), brightness: CGFloat(hsl[2]), alpha: 1.0)
    }
    
    public var hashValue: Int {
        get {
            return 31 * Int(rgb) + population
        }
    }
    
    init(rgb: UInt32, population: Int) {
        self.rgb = rgb
        mRed = red(rgb)
        mGreen = green(rgb)
        mBlue = blue(rgb)
        self.population = population
    }
    
    init(red:UInt32, green:UInt32, blue:UInt32, population:Int) {
        mRed = red
        mGreen = green
        mBlue = blue
        rgb = toRGB(red, green, blue)
        self.population = population
    }
    
    private func ensureTextColorsGenerated() {
        if !mGeneratedTextColors {
            // First check white, as most colors will be dark
            let (lightBodyAlpha, lightBodyAlphaCalculated) = calculateMinimumAlpha(COLOR_WHITE, rgb, MIN_CONTRAST_BODY_TEXT);
            let (lightTitleAlpha, lightTitleAlphaCaulated) = calculateMinimumAlpha(COLOR_WHITE, rgb, MIN_CONTRAST_TITLE_TEXT);
            
            if !lightBodyAlphaCalculated && !lightTitleAlphaCaulated {
                // If we found valid light values, use them and return
                mBodyTextColor = UInt32(setAlphaComponent(COLOR_WHITE, lightBodyAlpha));
                mTitleTextColor = UInt32(setAlphaComponent(COLOR_WHITE, lightTitleAlpha));
                mGeneratedTextColors = true;
                return
            }
            
            let (darkBodyAlpha, darkBodyAlphaCaculated) = calculateMinimumAlpha(COLOR_BLACK, rgb, MIN_CONTRAST_BODY_TEXT)
            let (darkTitleAlpha, darkTitleAlphaCaculated) = calculateMinimumAlpha(COLOR_BLACK, rgb, MIN_CONTRAST_TITLE_TEXT)
            
            if !darkBodyAlphaCaculated && !darkTitleAlphaCaculated {
                // If we found valid dark values, use them and return
                mBodyTextColor = UInt32(setAlphaComponent(COLOR_BLACK, UInt32(darkBodyAlpha)));
                mTitleTextColor = UInt32(setAlphaComponent(COLOR_BLACK, UInt32(darkTitleAlpha)));
                mGeneratedTextColors = true;
            }
            
            // If we reach here then we can not find title and body values which use the same
            // lightness, we need to use mismatched values
            mBodyTextColor = lightBodyAlphaCalculated
                ? UInt32(setAlphaComponent(COLOR_WHITE, lightBodyAlpha))
                : UInt32(setAlphaComponent(COLOR_BLACK, darkBodyAlpha))
            mTitleTextColor = lightTitleAlphaCaulated
                ? UInt32(setAlphaComponent(COLOR_WHITE, lightTitleAlpha))
                : UInt32(setAlphaComponent(COLOR_BLACK, darkTitleAlpha))
            mGeneratedTextColors = true;
        }
    }
}

public func == (left: Swatch, right: Swatch) -> Bool {
    return false
}

internal class Builder {
    private var mSwatches: [Swatch]?
    private var mBitmap: CGImageRef?
    private var mMaxColors = DEFAULT_CALCULATE_NUMBER_COLORS
    private var mResizeMaxDimension = DEFAULT_RESIZE_BITMAP_MAX_DIMENSION
    
    init(bitmap: CGImageRef) {
        mBitmap = bitmap
    }
    
    init(swatches:[Swatch]) {
        mSwatches = swatches
    }
    
    func generate() -> SWPalette {
        var swatches:[Swatch]
        
        if let bitmap = mBitmap {
            assert(mResizeMaxDimension > 0)
            let scaledBitmap = scaleBitmapDown(bitmap, mResizeMaxDimension)
            let quantizer:ColorCutQuantizer = createColorCutQuantizerFromImage(scaledBitmap, mMaxColors)
            
            swatches = quantizer.quantizedColors
        } else {
            // Else we're using the provided swatches
            swatches = mSwatches!
        }
        
        var mGenerator = PaletteGenerator()
        mGenerator.generate(swatches)
        
        return SWPalette(generator: mGenerator, swatches: swatches)
    }
}

func buildPaletteFrom(bitmap: CGImageRef) -> SWPalette {
    let builder = Builder(bitmap: bitmap)
    return builder.generate()
}