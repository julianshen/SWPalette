//
//  ColorCutQuantizer.swift
//  SWPalette
//
//  Copyright (c) 2015 cowbay.wtf. All rights reserved.
//

import Foundation
import CoreGraphics

enum ColorComponent:Int {
    case COMPONENT_RED = -3
    case COMPONENT_GREEN = -2
    case COMPONENT_BLUE = -1
}

func createColorCutQuantizerFromImage(image: CGImageRef, maxColors: Int) -> ColorCutQuantizer {
    let data = getARGBBitmapPixels(image)
    
    return ColorCutQuantizer(colorHistorgram: ColorHistorgram(pixels: data), maxColors: maxColors)
}

class ColorHistorgram {
    private var mColors: [UInt32]
    private var mColorCounts: [Int]
    private var mNumberColors: Int = 0
    
    var numColors: Int {
        return mNumberColors
    }
    
    var colors: [UInt32] {
        return mColors
    }
    
    var colorCounts: [Int] {
        return mColorCounts
    }
    
    init(var pixels: [UInt32]) {
        // Create arrays
        mColors = [UInt32]()
        mColorCounts = [Int]()
        
        countFrequencies(pixels)
        
        // Count number of distinct colors
        mNumberColors = mColors.count
    }
    
    private func countFrequencies(let pixels: [UInt32]) {
        if pixels.count == 0 {
            return;
        }
        
        // Now iterate from the second pixel to the end, population distinct colors
        var histogram:[UInt32: Int] = [UInt32: Int]()
        for pixel in pixels {
            if let count = histogram[pixel] {
                histogram[pixel] = count + 1
            } else {
                histogram[pixel] = 1
            }
        }
        
        mColors.extend(sorted(histogram.keys))
        mColorCounts.extend(mColors.map {
            return histogram[$0] ?? 0
        })
    }
}


class ColorCutQuantizer {
    private var mColorPopulations: [UInt32:Int] =  [UInt32:Int]()
    private var mColors: [UInt32]
    private var mQuantizedColors:[Swatch] = [Swatch]()
    
    var quantizedColors:[Swatch] {
        return mQuantizedColors
    }
    
    private func quantizePixels(maxColorIndex: Int, maxColors: Int) -> [Swatch] {
        var pq = PriorityQueue<VBox>(>)
        pq.offer(VBox(quantizer: self, lowerIndex: 0, upperIndex: maxColorIndex))
        splitBoxes(&pq, maxSize: maxColors)
        return generateAverageColors(pq.data);
    }
    
    private func splitBoxes(inout queue: PriorityQueue<VBox>, let maxSize: Int) {
        while queue.size < maxSize {
            if let vbox = queue.poll() {
                if vbox.canSplit {
                    queue.offer(vbox.splitBox())
                    queue.offer(vbox)
                } else {
                    return
                }
            } else {
                return
            }
            
        }
    }
    
    private func generateAverageColors(vboxes:[VBox]) -> [Swatch] {
        var colors: [Swatch] = [Swatch]()
        
        for vbox in vboxes {
            let color = vbox.averageColor
            if !shouldIgnoreColor(color) {
                colors.append(color)
            }
        }
        
        return colors
    }
    
    private init(colorHistorgram: ColorHistorgram, maxColors: Int) {
        let rawColorCount = colorHistorgram.numColors
        let rawColors = colorHistorgram.colors
        let rawColorCounts = colorHistorgram.colorCounts
        
        // First, lets pack the populations into a SparseIntArray so that they can be easily
        // retrieved without knowing a color's index
        for (var i = 0; i < rawColors.count; i++) {
            mColorPopulations[rawColors[i]] = rawColorCounts[i]
        }
        
        mColors = [UInt32]()
        
        var validColorCount = 0
        
        for color in rawColors {
            if !shouldIgnoreColor(color) {
                self.mColors.append(color)
            }
        }
        
        validColorCount = self.mColors.count
        
        if validColorCount <= maxColors {
            for color in mColors {
                mQuantizedColors.append(Swatch(rgb: color, population: mColorPopulations[color] ?? 0))
            }
        } else {
            mQuantizedColors.extend(self.quantizePixels(validColorCount - 1, maxColors: maxColors))
        }
    }
    
    private class VBox: Comparable {
        private var mLowerIndex:Int
        private var mUpperIndex:Int
        private var mMinRed:UInt32 = 0x0
        private var mMaxRed:UInt32 = 0x0
        private var mMinGreen:UInt32 = 0x0
        private var mMaxGreen:UInt32 = 0x0
        private var mMinBlue:UInt32 = 0x0
        private var mMaxBlue:UInt32 = 0x0
        
        private var mCCQ:ColorCutQuantizer
        
        var vloume:Int {
            return (Int(mMaxRed) - Int(mMinRed) + 1) * (Int(mMaxGreen) - Int(mMinGreen) + 1) * (Int(mMaxBlue) - Int(mMinBlue) + 1)
        }
        
        var canSplit:Bool {
            return colorCount > 1
        }
        
        var colorCount:Int {
            return mUpperIndex - mLowerIndex + 1
        }
        
        var longestColorDimension:Int {
            let redLength = mMaxRed - mMinRed;
            let greenLength = mMaxGreen - mMinGreen;
            let blueLength = mMaxBlue - mMinBlue;
            if redLength >= greenLength && redLength >= blueLength {
                return ColorComponent.COMPONENT_RED.rawValue;
            } else if greenLength >= redLength && greenLength >= blueLength {
                return ColorComponent.COMPONENT_GREEN.rawValue;
            } else {
                return ColorComponent.COMPONENT_BLUE.rawValue;
            }
        }
        
        var averageColor:Swatch {
            var redSum = 0
            var greenSum = 0
            var blueSum = 0
            var totalPopulation = 0
            
            for i in mLowerIndex...mUpperIndex {
                let color = mCCQ.mColors[i]
                let colorPopulation = mCCQ.mColorPopulations[color] ?? 0
                
                totalPopulation += colorPopulation
                redSum += colorPopulation * Int(red(color))
                greenSum += colorPopulation * Int(green(color))
                blueSum += colorPopulation * Int(blue(color))
            }
            
            let redAverage = round(Float(redSum) / Float(totalPopulation))
            let greenAverage = round(Float(greenSum) / Float(totalPopulation))
            let blueAverage = round(Float(blueSum) / Float(totalPopulation))
            
            return Swatch(red: UInt32(redAverage), green: UInt32(greenAverage), blue: UInt32(blueAverage), population: totalPopulation)
        }
        
        init(quantizer:ColorCutQuantizer, lowerIndex: Int, upperIndex: Int) {
            mLowerIndex = lowerIndex
            mUpperIndex = upperIndex
            mCCQ = quantizer
            
            self.fitBox()
        }
        
        private func fitBox() {
            (mMinRed, mMinBlue, mMinGreen) = (0xFF, 0xFF, 0xFF)
            (mMaxRed, mMaxBlue, mMaxGreen) = (0x0, 0x0, 0x0)
            let calls = NSThread.callStackSymbols()
            assert(mLowerIndex <= mUpperIndex, "\(mLowerIndex) > \(mUpperIndex): \(calls)")
            
            for i in mLowerIndex...mUpperIndex {
                let color = mCCQ.mColors[i]
                
                let r = red(color)
                let g = green(color)
                let b = blue(color)
                
                if r > mMaxRed {
                    mMaxRed = r
                }
                
                if r < mMinRed {
                    mMinRed = r
                }
                
                if g > mMaxGreen {
                    mMaxGreen = g
                }
                
                if g < mMinGreen {
                    mMinGreen = g
                }
                
                if b > mMaxBlue {
                    mMaxBlue = b
                }
                
                if b < mMinBlue {
                    mMinBlue = b
                }
            }
        }
        
        func modifySignificantOctet(var colors: [UInt32], dimension:Int) -> [UInt32] {
            let d:ColorComponent = ColorComponent(rawValue: dimension)!
            switch d {
                case .COMPONENT_RED:
                    // Already in RGB, no need to do anything
                    break
                case .COMPONENT_GREEN:
                    // We need to do a RGB to GRB swap, or vice-versa
                    colors = colors.map {
                        return toArgb(alpha($0), green($0), red($0), blue($0))
                    }
                case .COMPONENT_BLUE:
                    // We need to do a RGB to BGR swap, or vice-versa
                    colors = colors.map {
                        return toArgb(alpha($0), blue($0), green($0), red($0))
                    }
                default:
                    //Do nothing
                    break
            }
            
            return colors
        }
        
        func midPoint(dimension:Int) -> UInt32 {
            let d:ColorComponent = ColorComponent(rawValue: dimension)!
            switch d {
                case .COMPONENT_RED:
                    return (mMinRed + mMaxRed) / 2
                case .COMPONENT_GREEN:
                    return (mMinGreen + mMaxGreen) / 2
                case .COMPONENT_BLUE:
                    return (mMinBlue + mMaxBlue) / 2
                default:
                    return (mMinRed + mMaxRed) / 2
            }
        }
        
        func findSplitPoint() -> Int {
            let l = longestColorDimension
            
            var sub = Array(mCCQ.mColors[mLowerIndex ... mUpperIndex])
            
            sub = modifySignificantOctet(sub, dimension: l)
            sort(&sub)
            sub = modifySignificantOctet(sub, dimension: l)
            
            mCCQ.mColors.replaceRange(mLowerIndex ... mUpperIndex, with: sub)
            
            let dimensionMidPoint = midPoint(l)
            
            for i in mLowerIndex...mUpperIndex {
                let color = mCCQ.mColors[i]
                
                let d:ColorComponent = ColorComponent(rawValue: l)!
                switch d {
                    case .COMPONENT_RED:
                        if red(color) >= dimensionMidPoint {
                            return i
                        }
                    case .COMPONENT_GREEN:
                        if green(color) >= dimensionMidPoint {
                            return i
                        }
                    case .COMPONENT_BLUE:
                        if blue(color) >= dimensionMidPoint {
                            return i
                        }
                }
            }
            
            return mLowerIndex
        }
        
        func splitBox() -> VBox {
            assert(canSplit, "Can not split a box with only 1 color")
            
            let splitPoint = findSplitPoint()
            let newBox = VBox(quantizer: self.mCCQ, lowerIndex: splitPoint + 1, upperIndex: mUpperIndex)
            mUpperIndex = splitPoint
            fitBox()
            
            return newBox
        }
    }
    
    
}

private func <(l:ColorCutQuantizer.VBox, r:ColorCutQuantizer.VBox) -> Bool {
    return l.vloume < r.vloume
}

private func ==(l:ColorCutQuantizer.VBox, r:ColorCutQuantizer.VBox) -> Bool {
    return l.vloume == r.vloume
}

