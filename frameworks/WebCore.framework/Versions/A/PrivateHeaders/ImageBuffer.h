/*
 * Copyright (C) 2006 Nikolas Zimmermann <zimmermann@kde.org>
 * Copyright (C) 2007, 2008, 2009 Apple Inc. All rights reserved.
 * Copyright (C) 2010 Torch Mobile (Beijing) Co. Ltd. All rights reserved.
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

#ifndef ImageBuffer_h
#define ImageBuffer_h

#include "AffineTransform.h"
#include "ColorSpace.h"
#include "FloatRect.h"
#if USE(ACCELERATED_COMPOSITING)
#include "GraphicsLayer.h"
#endif
#include "GraphicsTypes.h"
#include "IntSize.h"
#include "ImageBufferData.h"
#include <wtf/ByteArray.h>
#include <wtf/Forward.h>
#include <wtf/OwnPtr.h>
#include <wtf/PassOwnPtr.h>
#include <wtf/PassRefPtr.h>
#include <wtf/Vector.h>

namespace WebCore {

    class GraphicsContext;
    class Image;
    class ImageData;
    class IntPoint;
    class IntRect;

    enum Multiply {
        Premultiplied,
        Unmultiplied
    };

    enum RenderingMode {
        Unaccelerated,
        UnacceleratedNonPlatformBuffer, // Use plain memory allocation rather than platform API to allocate backing store.
        Accelerated
    };
    
    enum BackingStoreCopy {
        CopyBackingStore, // Guarantee subsequent draws don't affect the copy.
        DontCopyBackingStore // Subsequent draws may affect the copy.
    };

    class ImageBuffer {
        WTF_MAKE_NONCOPYABLE(ImageBuffer); WTF_MAKE_FAST_ALLOCATED;
    public:
        // Will return a null pointer on allocation failure.
        static PassOwnPtr<ImageBuffer> create(const IntSize& size, ColorSpace colorSpace = ColorSpaceDeviceRGB, RenderingMode renderingMode = Unaccelerated)
        {
            bool success = false;
            OwnPtr<ImageBuffer> buf = adoptPtr(new ImageBuffer(size, colorSpace, renderingMode, success));
            if (success)
                return buf.release();
            return nullptr;
        }

        ~ImageBuffer();

        const IntSize& size() const { return m_size; }
        int width() const { return m_size.width(); }
        int height() const { return m_size.height(); }
        
        size_t dataSize() const;
        
        GraphicsContext* context() const;

        PassRefPtr<Image> copyImage(BackingStoreCopy = CopyBackingStore) const;

        PassRefPtr<ByteArray> getUnmultipliedImageData(const IntRect&) const;
        PassRefPtr<ByteArray> getPremultipliedImageData(const IntRect&) const;

        void putUnmultipliedImageData(ByteArray*, const IntSize& sourceSize, const IntRect& sourceRect, const IntPoint& destPoint);
        void putPremultipliedImageData(ByteArray*, const IntSize& sourceSize, const IntRect& sourceRect, const IntPoint& destPoint);
        
        void convertToLuminanceMask();
        
        String toDataURL(const String& mimeType, const double* quality = 0) const;
#if !USE(CG)
        AffineTransform baseTransform() const { return AffineTransform(); }
        void transformColorSpace(ColorSpace srcColorSpace, ColorSpace dstColorSpace);
        void platformTransformColorSpace(const Vector<int>&);
#else
        AffineTransform baseTransform() const { return AffineTransform(1, 0, 0, -1, 0, m_size.height()); }
#endif
#if USE(ACCELERATED_COMPOSITING)
        PlatformLayer* platformLayer() const;
#endif

    private:
#if USE(CG)
        NativeImagePtr copyNativeImage(BackingStoreCopy = CopyBackingStore) const;
#endif

        void clip(GraphicsContext*, const FloatRect&) const;

        void draw(GraphicsContext*, ColorSpace, const FloatRect& destRect, const FloatRect& srcRect = FloatRect(0, 0, -1, -1), CompositeOperator = CompositeSourceOver, bool useLowQualityScale = false);
        void drawPattern(GraphicsContext*, const FloatRect& srcRect, const AffineTransform& patternTransform, const FloatPoint& phase, ColorSpace styleColorSpace, CompositeOperator, const FloatRect& destRect);

        inline void genericConvertToLuminanceMask();

        friend class GraphicsContext;
        friend class GeneratedImage;
        friend class CrossfadeGeneratedImage;
        friend class GeneratorGeneratedImage;

    private:
        ImageBufferData m_data;

        IntSize m_size;
        OwnPtr<GraphicsContext> m_context;

#if !USE(CG)
        Vector<int> m_linearRgbLUT;
        Vector<int> m_deviceRgbLUT;
#endif

        // This constructor will place its success into the given out-variable
        // so that create() knows when it should return failure.
        ImageBuffer(const IntSize&, ColorSpace, RenderingMode, bool& success);
    };

#if USE(CG) || USE(SKIA)
    String ImageDataToDataURL(const ImageData&, const String& mimeType, const double* quality);
#endif

} // namespace WebCore

#endif // ImageBuffer_h
