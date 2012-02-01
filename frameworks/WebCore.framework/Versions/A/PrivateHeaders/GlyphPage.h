/*
 * Copyright (C) 2006, 2007, 2008 Apple Inc. All rights reserved.
 * Copyright (C) Research In Motion Limited 2011. All rights reserved.
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

#ifndef GlyphPage_h
#define GlyphPage_h

#include "Glyph.h"
#include <wtf/PassRefPtr.h>
#include <wtf/RefCounted.h>
#include <wtf/unicode/Unicode.h>

namespace WebCore {

class SimpleFontData;
class GlyphPageTreeNode;

// Holds the glyph index and the corresponding SimpleFontData information for a given
// character.
struct GlyphData {
    GlyphData(Glyph g = 0, const SimpleFontData* f = 0)
        : glyph(g)
        , fontData(f)
    {
    }
    Glyph glyph;
    const SimpleFontData* fontData;
};

// A GlyphPage contains a fixed-size set of GlyphData mappings for a contiguous
// range of characters in the Unicode code space. GlyphPages are indexed
// starting from 0 and incrementing for each 256 glyphs.
//
// One page may actually include glyphs from other fonts if the characters are
// missing in the primary font. It is owned by exactly one GlyphPageTreeNode,
// although multiple nodes may reference it as their "page" if they are supposed
// to be overriding the parent's node, but provide no additional information.
class GlyphPage : public RefCounted<GlyphPage> {
public:
    static PassRefPtr<GlyphPage> create(GlyphPageTreeNode* owner)
    {
        return adoptRef(new GlyphPage(owner));
    }

    static const size_t size = 256; // Covers Latin-1 in a single page.

    unsigned indexForCharacter(UChar32 c) const { return c % size; }
    GlyphData glyphDataForCharacter(UChar32 c) const
    {
        unsigned index = indexForCharacter(c);
        return GlyphData(m_glyphs[index], m_glyphFontData[index]);
    }

    GlyphData glyphDataForIndex(unsigned index) const
    {
        ASSERT(index < size);
        return GlyphData(m_glyphs[index], m_glyphFontData[index]);
    }

    Glyph glyphAt(unsigned index) const
    {
        ASSERT(index < size);
        return m_glyphs[index];
    }

    const SimpleFontData* fontDataForCharacter(UChar32 c) const
    {
        return m_glyphFontData[indexForCharacter(c)];
    }

    void setGlyphDataForCharacter(UChar32 c, Glyph g, const SimpleFontData* f)
    {
        setGlyphDataForIndex(indexForCharacter(c), g, f);
    }

    void setGlyphDataForIndex(unsigned index, Glyph g, const SimpleFontData* f)
    {
        ASSERT(index < size);
        m_glyphs[index] = g;
        m_glyphFontData[index] = f;
    }

    void setGlyphDataForIndex(unsigned index, const GlyphData& glyphData)
    {
        setGlyphDataForIndex(index, glyphData.glyph, glyphData.fontData);
    }
    
    void copyFrom(const GlyphPage& other)
    {
        memcpy(m_glyphs, other.m_glyphs, sizeof(m_glyphs));
        memcpy(m_glyphFontData, other.m_glyphFontData, sizeof(m_glyphFontData));
    }

    void clear()
    {
        memset(m_glyphs, 0, sizeof(m_glyphs));
        memset(m_glyphFontData, 0, sizeof(m_glyphFontData));
    }

    void clearForFontData(const SimpleFontData* fontData)
    {
        for (size_t i = 0; i < size; ++i) {
            if (m_glyphFontData[i] == fontData) {
                m_glyphs[i] = 0;
                m_glyphFontData[i] = 0;
            }
        }
    }

    GlyphPageTreeNode* owner() const { return m_owner; }

    // Implemented by the platform.
    bool fill(unsigned offset, unsigned length, UChar* characterBuffer, unsigned bufferLength, const SimpleFontData*);

private:
    GlyphPage(GlyphPageTreeNode* owner)
        : m_owner(owner)
    {
    }

    // Separate arrays, rather than array of GlyphData, to save space.
    Glyph m_glyphs[size];
    const SimpleFontData* m_glyphFontData[size];

    GlyphPageTreeNode* m_owner;
};

} // namespace WebCore

#endif // GlyphPageTreeNode_h
