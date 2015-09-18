
//
//  Generator.swift
//  SWPalette
//
//  Copyright (c) 2015 cowbay.wtf. All rights reserved.
//

import Foundation

private let TARGET_DARK_LUMA:Float = 0.26
private let MAX_DARK_LUMA:Float = 0.45

private let MIN_LIGHT_LUMA:Float = 0.55
private let TARGET_LIGHT_LUMA:Float = 0.74

private let MIN_NORMAL_LUMA:Float = 0.3
private let TARGET_NORMAL_LUMA:Float = 0.5
private let MAX_NORMAL_LUMA:Float = 0.7

private let TARGET_MUTED_SATURATION:Float = 0.3
private let MAX_MUTED_SATURATION:Float = 0.4

private let TARGET_VIBRANT_SATURATION:Float = 1.0
private let MIN_VIBRANT_SATURATION:Float = 0.35

private let WEIGHT_SATURATION:Float = 3.0
private let WEIGHT_LUMA:Float = 6.0
private let WEIGHT_POPULATION:Float = 1.0


internal func invertDiff(value:Float, targetValue:Float) -> Float {
    return 1.0 - abs(value - targetValue)
}

internal func weightedMean(values:Float...) -> Float {
    let indexes = Array(0..<values.count)
    
    let sums = indexes.filter {
        $0 % 2 == 0
        }.reduce([0.0, 0.0]) {
            [$0[0] + values[$1] * values[$1 + 1] , $0[1] + values[$1 + 1]] //[sum, sumWeight]
    }
    
    return sums[0]/sums[1] //sum / sumWeight
}

internal func copyHslValues(color: Swatch) -> [Float] {
    var newHsl = [Float]()
    newHsl.appendContentsOf(color.hsl)
    return newHsl
}

internal func createComparisonValue(saturation:Float, targetSaturation: Float, saturationWeight: Float, luma: Float, targetLuma:Float, lumaWeight:Float, population:Int, maxPopulation: Int, populationWeight: Float) -> Float {
    return weightedMean(
        invertDiff(saturation, targetValue: targetSaturation), saturationWeight,
        invertDiff(luma, targetValue: targetLuma), lumaWeight,
        Float(population) / Float(maxPopulation), populationWeight
    )
}

internal func hack_less_equal_than(left:Float, right:Float) -> Bool {
    if left < right {
        return true
    }
    
    return hack_equal_than(left, right: right)
}

internal func hack_great_equal_than(left:Float, right:Float) -> Bool {
    if left > right {
        return true
    }
    
    return hack_equal_than(left, right: right)
}

internal func hack_equal_than(left:Float, right:Float) -> Bool {
    let epsilon:Float = 0.00001
    
    if left == right {
        return true
    }
    
    let diff = abs(left - right)
    
    return diff/(abs(left) + abs(right)) < epsilon
}

internal class PaletteGenerator {
    var mSwatches: [Swatch]?
    var mHighestPopulation: Int?
    var mVibrantSwatch: Swatch?
    var mMutedSwatch: Swatch?
    var mDarkVibrantSwatch: Swatch?
    var mDarkMutedSwatch: Swatch?
    var mLightVibrantSwatch: Swatch?
    var mLightMutedSwatch: Swatch?
    
    private func findMaxPopulation() -> Int {
        var popuplation = 0
        if let swatches = mSwatches {
            for swatch in swatches {
                popuplation = max(popuplation, swatch.population)
            }
        }
        
        return popuplation
    }
    
    private func isAlreadySelected(swatch:Swatch) -> Bool {
        return mVibrantSwatch == swatch || mDarkVibrantSwatch == swatch ||
            mLightVibrantSwatch == swatch || mMutedSwatch == swatch ||
            mDarkMutedSwatch == swatch || mLightMutedSwatch == swatch
    }
    
    private func findColorVariation(targetLuma: Float, minLuma:Float, maxLuma:Float, targetSaturation:Float, minSaturation:Float, maxSaturation:Float) -> Swatch! {
        var maxValue:Float = 0
        var max:Swatch! = nil
        
        if let swatches = mSwatches {
            for swatch in swatches {
                let sat = swatch.hsl[1]
                let luma = swatch.hsl[2]
                
                let ab = hack_great_equal_than(sat, right: minSaturation) && hack_less_equal_than(sat, right: maxSaturation) &&
                    hack_great_equal_than(luma, right: minLuma) && hack_less_equal_than(luma, right: maxLuma)
                let aa = hack_great_equal_than(sat, right: minSaturation) && hack_less_equal_than(sat, right: maxSaturation)
                let bb = hack_great_equal_than(luma, right: minLuma) && hack_less_equal_than(luma, right: maxLuma)
                
                let aaa = hack_great_equal_than(sat, right: minSaturation)
                let aa1 = hack_less_equal_than(sat, right: maxSaturation)
                
                if (hack_great_equal_than(sat, right: minSaturation) && hack_less_equal_than(sat, right: maxSaturation) &&
                    hack_great_equal_than(luma, right: minLuma) && hack_less_equal_than(luma, right: maxLuma) &&
                    !isAlreadySelected(swatch)) {
                        let value = createComparisonValue(sat, targetSaturation: targetSaturation, saturationWeight: WEIGHT_SATURATION, luma: luma, targetLuma: targetLuma, lumaWeight: WEIGHT_LUMA, population: swatch.population, maxPopulation: mHighestPopulation!, populationWeight: WEIGHT_POPULATION)
                        
                        if (max == nil || value > maxValue) {
                            max = swatch;
                            maxValue = value;
                        }
                }
            }
        }
        
        return max
    }
    
    private func generateVariationColors() {
        mVibrantSwatch = findColorVariation(TARGET_NORMAL_LUMA, minLuma: MIN_NORMAL_LUMA, maxLuma: MAX_NORMAL_LUMA,
            targetSaturation: TARGET_VIBRANT_SATURATION, minSaturation: MIN_VIBRANT_SATURATION, maxSaturation: 1.0)
        mLightVibrantSwatch = findColorVariation(TARGET_LIGHT_LUMA, minLuma: MIN_LIGHT_LUMA, maxLuma: 1.0,
            targetSaturation: TARGET_VIBRANT_SATURATION, minSaturation: MIN_VIBRANT_SATURATION, maxSaturation: 1.0)
        mDarkVibrantSwatch = findColorVariation(TARGET_DARK_LUMA, minLuma: 0.0, maxLuma: MAX_DARK_LUMA,
            targetSaturation: TARGET_VIBRANT_SATURATION, minSaturation: MIN_VIBRANT_SATURATION, maxSaturation: 1.0)
        mMutedSwatch = findColorVariation(TARGET_NORMAL_LUMA, minLuma: MIN_NORMAL_LUMA, maxLuma: MAX_NORMAL_LUMA,
            targetSaturation: TARGET_MUTED_SATURATION, minSaturation: 0.0, maxSaturation: MAX_MUTED_SATURATION)
        mLightMutedSwatch = findColorVariation(TARGET_LIGHT_LUMA, minLuma: MIN_LIGHT_LUMA, maxLuma: 1.0,
            targetSaturation: TARGET_MUTED_SATURATION, minSaturation: 0.0, maxSaturation: MAX_MUTED_SATURATION)
        mDarkMutedSwatch = findColorVariation(TARGET_DARK_LUMA, minLuma: 0.0, maxLuma: MAX_DARK_LUMA,
            targetSaturation: TARGET_MUTED_SATURATION, minSaturation: 0.0, maxSaturation: MAX_MUTED_SATURATION);
    }
    
    private func generateEmptySwatches() {
        if mVibrantSwatch == nil {
            // If we do not have a vibrant color...
            if let mDarkVibrantSwatch = mDarkVibrantSwatch {
                // ...but we do have a dark vibrant, generate the value by modifying the luma
                var newHsl = copyHslValues(mDarkVibrantSwatch);
                newHsl[2] = TARGET_NORMAL_LUMA;
                mVibrantSwatch = Swatch(rgb: HSLToColor(newHsl), population: 0);
            }
        }
        
        if mDarkVibrantSwatch == nil {
            // If we do not have a dark vibrant color...
            if let mVibrantSwatch = mVibrantSwatch {
                // ...but we do have a vibrant, generate the value by modifying the luma
                var newHsl = copyHslValues(mVibrantSwatch);
                newHsl[2] = TARGET_DARK_LUMA;
                mDarkVibrantSwatch = Swatch(rgb: HSLToColor(newHsl), population: 0);
            }
        }
        
        // Android version does not have this part. Add this just in case
        if mLightVibrantSwatch == nil {
            // If we do not have a light vibrant color...
            if let mVibrantSwatch = mVibrantSwatch {
                // ...but we do have a vibrant, generate the value by modifying the luma
                var newHsl = copyHslValues(mVibrantSwatch);
                newHsl[2] = TARGET_LIGHT_LUMA;
                mLightVibrantSwatch = Swatch(rgb: HSLToColor(newHsl), population: 0);
            }
        }
    }
    
    func generate(swatches:[Swatch]) {
        mSwatches = swatches
        mHighestPopulation = findMaxPopulation()
        
        generateVariationColors()
        
        // Now try and generate any missing colors
        generateEmptySwatches()
    }
}