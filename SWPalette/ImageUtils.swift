//
//  ImageUtils.swift
//  SWPalette
//
//  Copyright (c) 2015 cowbay.wtf. All rights reserved.
//


import Foundation
import CoreGraphics

internal func scaleBitmapDown(image:CGImageRef, let targetMaxDimension:Int) -> CGImageRef {
    let maxDimension = max(CGImageGetWidth(image), CGImageGetHeight(image))
    
    if maxDimension <= targetMaxDimension {
        return image
    }
    
    let scaleRatio = Float(targetMaxDimension) / Float(maxDimension)
    
    var context:CGContextRef!
    var bitmapData:UnsafeMutablePointer<Void>
    var bitmapByteCount:Int
    var bytesPerRow:Int
    
    
    let width = Int(Float(CGImageGetWidth(image)) * scaleRatio)
    let height = Int(Float(CGImageGetHeight(image)) * scaleRatio)
    
    bytesPerRow = width * 4
    bitmapByteCount = bytesPerRow * height
    
    bitmapData = UnsafeMutablePointer<Void>.alloc(bitmapByteCount)
    
    assert(bitmapData != nil, "Memory not allocated!")
    
    var colorspace = CGImageGetColorSpace(image)
    
    context = CGBitmapContextCreate (bitmapData, width, height, 8, bytesPerRow, colorspace, CGBitmapInfo(CGImageAlphaInfo.NoneSkipFirst.rawValue))
    
    assert(context != nil)
    
    CGContextDrawImage(context, CGRectMake(CGFloat(0),CGFloat(0),CGFloat(width), CGFloat(height)), image)
    let newImgRef = CGBitmapContextCreateImage(context)
    
    return newImgRef
}

internal func getARGBBitmapPixels(image: CGImageRef) -> [UInt32] {
    //from : https://developer.apple.com/library/mac/qa/qa1509/_index.html
    var context: CGContextRef!
    var colorspace: CGColorSpaceRef
    var bitmapData: UnsafeMutablePointer<Void>
    var bitmapByteCount: Int
    var bytesPerRow: Int
    
    let width = CGImageGetWidth(image)
    let height = CGImageGetHeight(image)
    
    
    bytesPerRow = width * 4
    bitmapByteCount = bytesPerRow * height
    
    bitmapData = UnsafeMutablePointer<Void>.alloc(bitmapByteCount)
    colorspace = CGColorSpaceCreateDeviceRGB()
    
    bitmapData = UnsafeMutablePointer<Void>.alloc(bitmapByteCount)
    
    assert(bitmapData != nil, "Memory not allocated!")
    
    context = CGBitmapContextCreate (bitmapData, width, height, 8, bytesPerRow, colorspace, CGBitmapInfo(CGImageAlphaInfo.PremultipliedFirst.rawValue))
    
    assert(context != nil, "Context not created!")
    
    CGContextDrawImage(context, CGRectMake(CGFloat(0),CGFloat(0),CGFloat(width), CGFloat(height)), image)
    let data = CGBitmapContextGetData(context)
    
    let intData = UnsafeMutablePointer<UInt32>(data)
    let intArray = Array(UnsafeBufferPointer(start: intData, count: bitmapByteCount/4))
    
    return intArray
}