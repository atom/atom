/*
 * Copyright (C) 2004, 2005, 2006 Apple Computer, Inc.  All rights reserved.
 * Copyright (C) 2007-2008 Torch Mobile, Inc.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE COMPUTER, INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE COMPUTER, INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 */

#ifndef ImageSource_h
#define ImageSource_h

#include <wtf/Forward.h>
#include <wtf/Noncopyable.h>
#include <wtf/Vector.h>

#if PLATFORM(WX)
class wxBitmap;
class wxGraphicsBitmap;
#elif USE(CG)
typedef struct CGImageSource* CGImageSourceRef;
typedef struct CGImage* CGImageRef;
typedef const struct __CFData* CFDataRef;
#elif PLATFORM(QT)
#include <qglobal.h>
QT_BEGIN_NAMESPACE
class QPixmap;
QT_END_NAMESPACE
#elif USE(CAIRO)
struct _cairo_surface;
typedef struct _cairo_surface cairo_surface_t;
#elif USE(SKIA)
namespace WebCore {
class NativeImageSkia;
}
#elif OS(WINCE)
#include "SharedBitmap.h"
#endif

namespace WebCore {

class IntPoint;
class IntSize;
class SharedBuffer;

#if USE(CG)
#if USE(WEBKIT_IMAGE_DECODERS)
class ImageDecoder;
typedef ImageDecoder* NativeImageSourcePtr;
#else
typedef CGImageSourceRef NativeImageSourcePtr;
#endif
typedef CGImageRef NativeImagePtr;
#elif PLATFORM(OPENVG)
class ImageDecoder;
class TiledImageOpenVG;
typedef ImageDecoder* NativeImageSourcePtr;
typedef TiledImageOpenVG* NativeImagePtr;
#elif PLATFORM(QT)
class ImageDecoderQt;
typedef ImageDecoderQt* NativeImageSourcePtr;
typedef QPixmap* NativeImagePtr;
#else
class ImageDecoder;
typedef ImageDecoder* NativeImageSourcePtr;
#if PLATFORM(WX)
#if USE(WXGC)
typedef wxGraphicsBitmap* NativeImagePtr;
#else
typedef wxBitmap* NativeImagePtr;
#endif
#elif USE(CAIRO)
typedef cairo_surface_t* NativeImagePtr;
#elif USE(SKIA)
typedef WebCore::NativeImageSkia* NativeImagePtr;
#elif OS(WINCE)
typedef RefPtr<SharedBitmap> NativeImagePtr;
#endif
#endif

// Right now GIFs are the only recognized image format that supports animation.
// The animation system and the constants below are designed with this in mind.
// GIFs have an optional 16-bit unsigned loop count that describes how an
// animated GIF should be cycled.  If the loop count is absent, the animation
// cycles once; if it is 0, the animation cycles infinitely; otherwise the
// animation plays n + 1 cycles (where n is the specified loop count).  If the
// GIF decoder defaults to cAnimationLoopOnce in the absence of any loop count
// and translates an explicit "0" loop count to cAnimationLoopInfinite, then we
// get a couple of nice side effects:
//   * By making cAnimationLoopOnce be 0, we allow the animation cycling code in
//     BitmapImage.cpp to avoid special-casing it, and simply treat all
//     non-negative loop counts identically.
//   * By making the other two constants negative, we avoid conflicts with any
//     real loop count values.
const int cAnimationLoopOnce = 0;
const int cAnimationLoopInfinite = -1;
const int cAnimationNone = -2;

class ImageSource {
    WTF_MAKE_NONCOPYABLE(ImageSource);
public:
    enum AlphaOption {
        AlphaPremultiplied,
        AlphaNotPremultiplied
    };

    enum GammaAndColorProfileOption {
        GammaAndColorProfileApplied,
        GammaAndColorProfileIgnored
    };

#if USE(CG)
    enum ShouldSkipMetaData {
        DoNotSkipMetaData,
        SkipMetaData
    };
#endif

    ImageSource(AlphaOption alphaOption = AlphaPremultiplied, GammaAndColorProfileOption gammaAndColorProfileOption = GammaAndColorProfileApplied);
    ~ImageSource();

    // Tells the ImageSource that the Image no longer cares about decoded frame
    // data -- at all (if |destroyAll| is true), or before frame
    // |clearBeforeFrame| (if |destroyAll| is false).  The ImageSource should
    // delete cached decoded data for these frames where possible to keep memory
    // usage low.  When |destroyAll| is true, the ImageSource should also reset
    // any local state so that decoding can begin again.
    //
    // Implementations that delete less than what's specified above waste
    // memory.  Implementations that delete more may burn CPU re-decoding frames
    // that could otherwise have been cached, or encounter errors if they're
    // asked to decode frames they can't decode due to the loss of previous
    // decoded frames.
    //
    // Callers should not call clear(false, n) and subsequently call
    // createFrameAtIndex(m) with m < n, unless they first call clear(true).
    // This ensures that stateful ImageSources/decoders will work properly.
    //
    // The |data| and |allDataReceived| parameters should be supplied by callers
    // who set |destroyAll| to true if they wish to be able to continue using
    // the ImageSource.  This way implementations which choose to destroy their
    // decoders in some cases can reconstruct them correctly.
    void clear(bool destroyAll,
               size_t clearBeforeFrame = 0,
               SharedBuffer* data = NULL,
               bool allDataReceived = false);

    bool initialized() const;

    void setData(SharedBuffer* data, bool allDataReceived);
    String filenameExtension() const;

    bool isSizeAvailable();
    IntSize size() const;
    IntSize frameSizeAtIndex(size_t) const;
    bool getHotSpot(IntPoint&) const;

    size_t bytesDecodedToDetermineProperties() const;

    int repetitionCount();

    size_t frameCount() const;

    // Callers should not call this after calling clear() with a higher index;
    // see comments on clear() above.
    NativeImagePtr createFrameAtIndex(size_t);

    float frameDurationAtIndex(size_t);
    bool frameHasAlphaAtIndex(size_t); // Whether or not the frame actually used any alpha.
    bool frameIsCompleteAtIndex(size_t); // Whether or not the frame is completely decoded.

#if ENABLE(IMAGE_DECODER_DOWN_SAMPLING)
    static unsigned maxPixelsPerDecodedImage() { return s_maxPixelsPerDecodedImage; }
    static void setMaxPixelsPerDecodedImage(unsigned maxPixels) { s_maxPixelsPerDecodedImage = maxPixels; }
#endif

private:
    NativeImageSourcePtr m_decoder;
    AlphaOption m_alphaOption;
    GammaAndColorProfileOption m_gammaAndColorProfileOption;
#if ENABLE(IMAGE_DECODER_DOWN_SAMPLING)
    static unsigned s_maxPixelsPerDecodedImage;
#endif
};

}

#endif
