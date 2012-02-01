/*
 * Copyright (C) 2006, 2009, 2011 Apple Inc. All rights reserved.
 * Copyright (C) 2007-2008 Torch Mobile Inc.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1.  Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer. 
 * 2.  Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution. 
 * 3.  Neither the name of Apple Computer, Inc. ("Apple") nor the names of
 *     its contributors may be used to endorse or promote products derived
 *     from this software without specific prior written permission. 
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE AND ITS CONTRIBUTORS "AS IS" AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL APPLE OR ITS CONTRIBUTORS BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef GlyphBuffer_h
#define GlyphBuffer_h

#include "FloatSize.h"
#include "Glyph.h"
#include <wtf/UnusedParam.h>
#include <wtf/Vector.h>

#if USE(CG) || USE(SKIA_ON_MAC_CHROMIUM)
#include <CoreGraphics/CGGeometry.h>
#endif

#if PLATFORM(WX) && OS(DARWIN)
#include <ApplicationServices/ApplicationServices.h>
#endif

#if USE(CAIRO) || (PLATFORM(WX) && defined(wxUSE_CAIRO) && wxUSE_CAIRO)
#include <cairo.h>
#endif

namespace WebCore {

class SimpleFontData;

#if USE(CAIRO) || (PLATFORM(WX) && defined(wxUSE_CAIRO) && wxUSE_CAIRO)
// FIXME: Why does Cairo use such a huge struct instead of just an offset into an array?
typedef cairo_glyph_t GlyphBufferGlyph;
#elif OS(WINCE)
typedef wchar_t GlyphBufferGlyph;
#else
typedef Glyph GlyphBufferGlyph;
#endif

// CG uses CGSize instead of FloatSize so that the result of advances()
// can be passed directly to CGContextShowGlyphsWithAdvances in FontMac.mm
#if USE(CG) || (PLATFORM(WX) && OS(DARWIN)) || USE(SKIA_ON_MAC_CHROMIUM)
typedef CGSize GlyphBufferAdvance;
#elif OS(WINCE)
// There is no cross-platform code that uses the height of GlyphBufferAdvance,
// so we can save memory space on embedded devices by storing only the width
typedef float GlyphBufferAdvance;
#else
typedef FloatSize GlyphBufferAdvance;
#endif

class GlyphBuffer {
public:
    bool isEmpty() const { return m_fontData.isEmpty(); }
    int size() const { return m_fontData.size(); }
    
    void clear()
    {
        m_fontData.clear();
        m_glyphs.clear();
        m_advances.clear();
#if PLATFORM(WIN)
        m_offsets.clear();
#endif
    }

    GlyphBufferGlyph* glyphs(int from) { return m_glyphs.data() + from; }
    GlyphBufferAdvance* advances(int from) { return m_advances.data() + from; }
    const GlyphBufferGlyph* glyphs(int from) const { return m_glyphs.data() + from; }
    const GlyphBufferAdvance* advances(int from) const { return m_advances.data() + from; }

    const SimpleFontData* fontDataAt(int index) const { return m_fontData[index]; }
    
    void swap(int index1, int index2)
    {
        const SimpleFontData* f = m_fontData[index1];
        m_fontData[index1] = m_fontData[index2];
        m_fontData[index2] = f;

        GlyphBufferGlyph g = m_glyphs[index1];
        m_glyphs[index1] = m_glyphs[index2];
        m_glyphs[index2] = g;

        GlyphBufferAdvance s = m_advances[index1];
        m_advances[index1] = m_advances[index2];
        m_advances[index2] = s;

#if PLATFORM(WIN)
        FloatSize offset = m_offsets[index1];
        m_offsets[index1] = m_offsets[index2];
        m_offsets[index2] = offset;
#endif
    }

    Glyph glyphAt(int index) const
    {
#if USE(CAIRO) || (PLATFORM(WX) && defined(wxUSE_CAIRO) && wxUSE_CAIRO)
        return m_glyphs[index].index;
#else
        return m_glyphs[index];
#endif
    }

    float advanceAt(int index) const
    {
#if USE(CG) || (PLATFORM(WX) && OS(DARWIN)) || USE(SKIA_ON_MAC_CHROMIUM)
        return m_advances[index].width;
#elif OS(WINCE)
        return m_advances[index];
#else
        return m_advances[index].width();
#endif
    }

    FloatSize offsetAt(int index) const
    {
#if PLATFORM(WIN)
        return m_offsets[index];
#else
        UNUSED_PARAM(index);
        return FloatSize();
#endif
    }

    void add(Glyph glyph, const SimpleFontData* font, float width, const FloatSize* offset = 0)
    {
        m_fontData.append(font);

#if USE(CAIRO) || (PLATFORM(WX) && defined(wxUSE_CAIRO) && wxUSE_CAIRO)
        cairo_glyph_t cairoGlyph;
        cairoGlyph.index = glyph;
        m_glyphs.append(cairoGlyph);
#else
        m_glyphs.append(glyph);
#endif

#if USE(CG) || (PLATFORM(WX) && OS(DARWIN)) || USE(SKIA_ON_MAC_CHROMIUM)
        CGSize advance = { width, 0 };
        m_advances.append(advance);
#elif OS(WINCE)
        m_advances.append(width);
#else
        m_advances.append(FloatSize(width, 0));
#endif

#if PLATFORM(WIN)
        if (offset)
            m_offsets.append(*offset);
        else
            m_offsets.append(FloatSize());
#else
        UNUSED_PARAM(offset);
#endif
    }
    
#if !OS(WINCE)
    void add(Glyph glyph, const SimpleFontData* font, GlyphBufferAdvance advance)
    {
        m_fontData.append(font);
#if USE(CAIRO) || (PLATFORM(WX) && defined(wxUSE_CAIRO) && wxUSE_CAIRO)
        cairo_glyph_t cairoGlyph;
        cairoGlyph.index = glyph;
        m_glyphs.append(cairoGlyph);
#else
        m_glyphs.append(glyph);
#endif

        m_advances.append(advance);
    }
#endif

    void expandLastAdvance(float width)
    {
        ASSERT(!isEmpty());
        GlyphBufferAdvance& lastAdvance = m_advances.last();
#if USE(CG) || (PLATFORM(WX) && OS(DARWIN)) || USE(SKIA_ON_MAC_CHROMIUM)
        lastAdvance.width += width;
#elif OS(WINCE)
        lastAdvance += width;
#else
        lastAdvance += FloatSize(width, 0);
#endif
    }

private:
    Vector<const SimpleFontData*, 2048> m_fontData;
    Vector<GlyphBufferGlyph, 2048> m_glyphs;
    Vector<GlyphBufferAdvance, 2048> m_advances;
#if PLATFORM(WIN)
    Vector<FloatSize, 2048> m_offsets;
#endif
};

}
#endif
