//
//  ColorUtils.swift
//  SWPalette
//
//  Copyright (c) 2015 cowbay.wtf. All rights reserved.
//
import Foundation

private let BLACK_MAX_LIGHTNESS:Float = 0.05
private let WHITE_MIN_LIGHTNESS:Float = 0.95

/**
Return the alpha component of a color int.
- parameter color:
- returns: alpha component of the color
*/
internal func alpha(color:UInt32) -> UInt32 {
    return color & 0xFF
}

/**
Return the red component of a color int.
- parameter color:
- returns: red component of the color
*/
internal func red(color:UInt32) -> UInt32 {
    return (color >> 8) & 0xFF
}

/**
Return the green component of a color int.
- parameter color:
- returns: green component of the color
*/
internal func green(color:UInt32) -> UInt32 {
    return (color >> 16) & 0xFF
}

/**
Return the blue component of a color int.
- parameter color:
- returns: blue component of the color
*/
internal func blue(color:UInt32) -> UInt32 {
    return (color >> 24) & 0xFF
}

internal func toArgb(alpha: UInt32, red: UInt32, green: UInt32, blue: UInt32) -> UInt32 {
    return (blue << 24) | (green << 16) | (red << 8) | alpha
}

internal func toRGB(red:UInt32, green:UInt32, blue:UInt32) -> UInt32 {
    return toArgb(0xFF, red: red, green: green, blue: blue)
}

internal func RGBToHSL(r:UInt32, g:UInt32, b:UInt32, inout hsl:[Float]) {
    let rf = Float(r) / 255
    let gf = Float(g) / 255
    let bf = Float(b) / 255
    
    let mx = max(rf, gf, bf)
    let mn = min(rf, gf, bf)
    let deltaMaxMin = mx - mn
    
    var h:Float
    var s:Float
    
    let l = (mx + mn)/2
    
    if mx == mn {
        // Monochromatic
        (h, s) = (0, 0)
    } else {
        if (mx == rf) {
            h = ((gf - bf) / deltaMaxMin) % 6
        } else if (mx == gf) {
            h = ((bf - rf) / deltaMaxMin) + 2
        } else {
            h = ((rf - gf) / deltaMaxMin) + 4
        }
        s = deltaMaxMin / (1 - abs(2 * l - 1))
    }
    
    hsl[0] = (h * 60) % 360
    hsl[1] = s
    hsl[2] = l
}

internal func colorToHSL(color: UInt32, inout hsl: [Float]) {
    RGBToHSL(red(color), g: green(color), b: blue(color), hsl: &hsl)
}

internal func HSLToColor(hsl:[Float]) -> UInt32 {
    let h = hsl[0]
    let s = hsl[1]
    let l = hsl[2]
    
    let c = (1.0 - abs(2.0 * l - 1.0)) * s
    let m = l - 0.5 * c
    let x = c * (1.0 - abs((h / 60.0 % 2.0) - 1.0))
    
    let hueSegment:Int = Int(h)/60
    
    var r:UInt32 = 0
    var g:UInt32 = 0
    var b:UInt32 = 0
    
    switch(hueSegment) {
    case 0:
        r = UInt32(round(255 * (c + m)))
        g = UInt32(round(255 * (x + m)))
        b = UInt32(round(255 * m))
    case 1:
        r = UInt32(round(255 * (x + m)))
        g = UInt32(round(255 * (c + m)))
        b = UInt32(round(255 * m))
    case 2:
        r = UInt32(round(255 * m))
        g = UInt32(round(255 * (c + m)))
        b = UInt32(round(255 * (x + m)))
    case 3:
        r = UInt32(round(255 * m))
        g = UInt32(round(255 * (x + m)))
        b = UInt32(round(255 * (c + m)))
    case 4:
        r = UInt32(round(255 * (x + m)))
        g = UInt32(round(255 * m))
        b = UInt32(round(255 * (c + m)))
    case 5, 6:
        r = UInt32(round(255 * (c + m)))
        g = UInt32(round(255 * m))
        b = UInt32(round(255 * (x + m)))
    default:
        r = 0
        g = 0
        b = 0
    }
    
    r = max(0, min(255, r));
    g = max(0, min(255, g));
    b = max(0, min(255, b));
    
    return toRGB(r, green: g, blue: b)
}

internal func setAlphaComponent(color:UInt32, alpha:UInt32) -> UInt32 {
    assert((alpha >= 0) && (alpha <= 255), "alpha must be between 0 and 255.")
    return (color & 0xffffff00) | alpha
}

internal func compositeColors(foreground:UInt32, background:UInt32) -> UInt32 {
    let alpha1:Float = Float(alpha(foreground)) / 255.0
    let alpha2:Float = Float(alpha(background)) / 255.0
    
    let a = (alpha1 + alpha2) * (1.0 - alpha1);
    let r = (Float(red(foreground)) * alpha1) + (Float(red(background)) * alpha2 * (1.0 - alpha1))
    let g = (Float(green(foreground)) * alpha1) + (Float(green(background)) * alpha2 * (1.0 - alpha1))
    let b = (Float(blue(foreground)) * alpha1) + (Float(blue(background)) * alpha2 * (1.0 - alpha1))
    
    return toArgb(UInt32(a), red: UInt32(r), green: UInt32(g), blue: UInt32(b))
}

internal func calculateLuminance(color:UInt32) -> Double {
    var r = Double(red(color)) / 255.0
    r = r < 0.03928 ? r / 12.92 : pow((r + 0.055) / 1.055, 2.4)
    
    var g = Double(green(color)) / 255.0
    g = g < 0.03928 ? g / 12.92 : pow((g + 0.055) / 1.055, 2.4)
    
    var b = Double(blue(color)) / 255.0
    b = b < 0.03928 ? b / 12.92 : pow((b + 0.055) / 1.055, 2.4)
    
    return (0.2126 * r) + (0.7152 * g) + (0.0722 * b);
}

internal func calculateContrast(var foreground:UInt32, background:UInt32) -> Double {
    assert(alpha(background) == 255, "background can not be translucent")
    
    if alpha(foreground) < 255 {
        foreground = compositeColors(foreground, background: background);
    }
    
    let luminance1:Double = calculateLuminance(foreground) + 0.05
    let luminance2:Double = calculateLuminance(background) + 0.05
    
    return max(luminance1, luminance2)
}

internal func calculateMinimumAlpha(foreground:UInt32, background:UInt32, minContrastRatio:Double) -> (UInt32, Bool) {
    assert(alpha(background) == 255, "background can not be translucent")
    
    var testForeground = setAlphaComponent(foreground, alpha: 255)
    var testRatio = calculateContrast(testForeground, background: background)
    
    if testRatio < minContrastRatio {
        return (0, false)
    }
    
    var numIterations = 0
    var minAlpha:UInt32 = 0
    var maxAlpha:UInt32 = 255
    
    while numIterations <= MIN_ALPHA_SEARCH_MAX_ITERATIONS && Int(maxAlpha - minAlpha) > MIN_ALPHA_SEARCH_PRECISION {
        let testAlpha:UInt32 = (minAlpha + maxAlpha) / 2;
        testForeground = setAlphaComponent(foreground, alpha: testAlpha);
        testRatio = calculateContrast(testForeground, background: background);
        if testRatio < minContrastRatio {
            minAlpha = testAlpha;
        } else {
            maxAlpha = testAlpha;
        }
        numIterations++;
    }
    
    return (maxAlpha, true)
}

internal func isBlack(hslColor:[Float]) -> Bool {
    return hslColor[2] <= BLACK_MAX_LIGHTNESS
}

internal func isWhite(hslColor:[Float]) -> Bool {
    return hslColor[2] >= WHITE_MIN_LIGHTNESS
}

internal func isNearRedILine(hslColor:[Float]) -> Bool {
    return hack_great_equal_than(hslColor[0], right: 10) && hack_less_equal_than(hslColor[0], right: 37) && hack_less_equal_than(hslColor[1], right: 0.82)
}

internal func shouldIgnoreColor(hslColor: [Float]) -> Bool {
    return isWhite(hslColor) || isBlack(hslColor) || isNearRedILine(hslColor)
}

internal func shouldIgnoreColor(color: Swatch) -> Bool {
    return shouldIgnoreColor(color.hsl)
}

internal func shouldIgnoreColor(color: UInt32) -> Bool {
    var hsl:[Float] = [Float](count: 3, repeatedValue: 0.0)
    colorToHSL(color, hsl: &hsl)
    return shouldIgnoreColor(hsl)
}