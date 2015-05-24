# SWPalette

This a Swift port from [Android Palette](https://developer.android.com/reference/android/support/v7/graphics/Palette.html).

The purpose of SWPalette is to extract prominent colors from a image:
* Vibrant
* Vibrant Dark
* Vibrant Light
* Muted
* Muted Dark
* Muted Light

You can use these colors to style your view components to match colors from your image. It can be applied to both text and background colors

## Usage

Unlike Android version (which requires a Builder to generate colors), this works as an extension to UIImage. All you have to do is to call `swp_generatePalette`.

Here is an example:

```swift
    UIImage image
    let palette = image.swpalette_generate()

    if let swatch = palette.lightMutedSwatch {
      self.textView?.textColor = swatch.bodyTextColor
      self.textView?.backgroundColor = swatch.color
    }
```

There are two kinds of colors you could use to apply to text. One is `titleTextColor` which is for title text. And another is `bodyTextColor`

Extracting colors is a time consuming task. You can also use the async version `swpalette_generateAsync` instead.

**Note** This does not guarantee to generate all colors. Some colors might not be generated (depends on what kind of image you use). So you must check before you use it.  

## Installation

### Carthage

Add this to your carthage file:
`github julianshen/SWPalette`



