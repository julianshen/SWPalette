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
    var histogram:[UInt32: Int] = [UInt32: Int]()
    private var mNumberColors: Int = 0
    
    var numColors: Int {
        return mNumberColors
    }
    
    var colors: [UInt32] {
        return Array(histogram.keys)
    }
    
    init(pixels: [UInt32]) {
        countFrequencies(pixels)
        
        // Count number of distinct colors
        mNumberColors = histogram.keys.count
        
        //check pixels
        /*let sumOfPixels = histogram.keys.array.reduce(0, combine: {
            sum, i in
            return sum + histogram[i]!
        })*/
    }
    
    private func countFrequencies(let pixels: [UInt32]) {
        if pixels.count == 0 {
            return;
        }
        
        // Now iterate from the second pixel to the end, population distinct colors
        
        for pixel in pixels {
            if let _ = histogram[pixel] {
                histogram[pixel]?++
            } else {
                histogram[pixel] = 1
            }
        }
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
        let rawColors = colorHistorgram.colors.sort()
        
        mColorPopulations = colorHistorgram.histogram
        
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
                mQuantizedColors.append(Swatch(rgb: color, population: mColorPopulations[color] ?? 1))
            }
        } else {
            mQuantizedColors.appendContentsOf(self.quantizePixels(validColorCount - 1, maxColors: maxColors))
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
        
        var longestColorDimension:ColorComponent {
            let redLength = mMaxRed - mMinRed;
            let greenLength = mMaxGreen - mMinGreen
            let blueLength = mMaxBlue - mMinBlue
            let maxLength = max(redLength, greenLength, blueLength)
            
            if redLength == maxLength {
                return ColorComponent.COMPONENT_RED;
            } else if greenLength == maxLength {
                return ColorComponent.COMPONENT_GREEN;
            } else {
                return ColorComponent.COMPONENT_BLUE;
            }
        }
        
        var averageColor:Swatch {
            var redSum:Int = 0
            var greenSum:Int = 0
            var blueSum:Int = 0
            var totalPopulation:Int = 0
            
            for i in mLowerIndex...mUpperIndex {
                let color = mCCQ.mColors[i]
                if let colorPopulation = mCCQ.mColorPopulations[color] {
                    totalPopulation += colorPopulation
                    redSum += colorPopulation * Int(red(color))
                    greenSum += colorPopulation * Int(green(color))
                    blueSum += colorPopulation * Int(blue(color))
                }
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
            
            assert(mLowerIndex <= mUpperIndex, "\(mLowerIndex) > \(mUpperIndex)")
            
            let reds = Array(Array(mCCQ.mColors[mLowerIndex...mUpperIndex].map() {
                return red($0)
                }))
            
            let greens = Array(Array(mCCQ.mColors[mLowerIndex...mUpperIndex].map() {
                return green($0)
                }))
            
            let blues = Array(Array(mCCQ.mColors[mLowerIndex...mUpperIndex].map() {
                return blue($0)
                }))
            
            mMaxRed = reds.reduce(0) {
                return $0 < $1 ? $1:$0
            }
            
            mMinRed = reds.reduce(0xFF) {
                return $0 < $1 ? $0:$1
            }
            
            mMaxBlue = blues.reduce(0) {
                return $0 < $1 ? $1:$0
            }
            
            mMinBlue = blues.reduce(0xFF) {
                return $0 < $1 ? $0:$1
            }
            
            mMaxGreen = greens.reduce(0) {
                return $0 < $1 ? $1:$0
            }
            
            mMinGreen = greens.reduce(0xFF) {
                return $0 < $1 ? $0:$1
            }
        }
        
        func modifySignificantOctet(var colors: [UInt32], dimension:ColorComponent) -> [UInt32] {
            switch dimension {
            case .COMPONENT_RED:
                // Already in RGB, no need to do anything
                break
            case .COMPONENT_GREEN:
                // We need to do a RGB to GRB swap, or vice-versa
                colors = colors.map {
                    return toArgb(alpha($0), red: green($0), green: red($0), blue: blue($0))
                }
            case .COMPONENT_BLUE:
                // We need to do a RGB to BGR swap, or vice-versa
                colors = colors.map {
                    return toArgb(alpha($0), red: blue($0), green: green($0), blue: red($0))
                }
            default:
                //Do nothing
                break
            }
            
            return colors
        }
        
        
        
        func midPoint(dimension:ColorComponent) -> UInt32 {
            switch dimension {
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
            
            mCCQ.mColors[mLowerIndex...mUpperIndex].sortInPlace {
                (var left:UInt32, var right:UInt32) -> Bool in
                switch l {
                case .COMPONENT_GREEN:
                    // We need to do a RGB to GRB swap, or vice-versa
                    left = toArgb(alpha(left), red: green(left), green: red(left), blue: blue(left))
                    right = toArgb(alpha(right), red: green(right), green: red(right), blue: blue(right))
                case .COMPONENT_BLUE:
                    // We need to do a RGB to BGR swap, or vice-versa
                    left = toArgb(alpha(left), red: blue(left), green: green(left), blue: red(left))
                    right = toArgb(alpha(right), red: blue(right), green: green(right), blue: red(right))
                default:
                    break
                }
                
                return left < right
            }
            
            let dimensionMidPoint = midPoint(l)
            
            let a = Array(mCCQ.mColors[mLowerIndex...mUpperIndex].map({ (color) -> UInt32 in
                switch l {
                case .COMPONENT_RED:
                    return red(color)
                case .COMPONENT_GREEN:
                    return green(color)
                case .COMPONENT_BLUE:
                    return blue(color)
                }
                return 0
            }))
            
            for (i, color) in mCCQ.mColors[mLowerIndex...mUpperIndex].enumerate() {
                switch l {
                case .COMPONENT_RED:
                    if red(color) >= dimensionMidPoint {
                        return i + mLowerIndex
                    }
                case .COMPONENT_GREEN:
                    if green(color) >= dimensionMidPoint {
                        return i + mLowerIndex
                    }
                case .COMPONENT_BLUE:
                    if blue(color) >= dimensionMidPoint {
                        return i + mLowerIndex
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


