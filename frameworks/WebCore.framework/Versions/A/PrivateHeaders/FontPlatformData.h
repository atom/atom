/*
 * Copyright (C) 2006, 2007, 2008, 2010 Apple Inc.
 * Copyright (C) 2006 Michael Emmel mike.emmel@gmail.com
 * Copyright (C) 2007 Holger Hans Peter Freyther
 * Copyright (C) 2007 Pioneer Research Center USA, Inc.
 * Copyright (C) 2010, 2011 Brent Fulgham <bfulgham@webkit.org>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public License
 * along with this library; see the file COPYING.LIB.  If not, write to
 * the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 *
 */

// FIXME: This is temporary until all ports switch to using this file.
#if PLATFORM(CHROMIUM) && !OS(DARWIN)
#include "chromium/FontPlatformData.h"
#elif PLATFORM(QT)
#include "qt/FontPlatformData.h"
#elif PLATFORM(WIN) && OS(WINCE)
#include "wince/FontPlatformData.h"
#elif PLATFORM(WX)
#include "wx/FontPlatformData.h"
#elif (PLATFORM(EFL) || PLATFORM(GTK)) && USE(FREETYPE)
#include "freetype/FontPlatformData.h"
#elif (PLATFORM(EFL) || PLATFORM(GTK)) && USE(PANGO)
#include "pango/FontPlatformData.h"
#else

#ifndef FontPlatformData_h
#define FontPlatformData_h

#include "FontOrientation.h"
#include "FontWidthVariant.h"
#include "GlyphBuffer.h"
#include "TextOrientation.h"

#if PLATFORM(WIN)
#include "RefCountedGDIHandle.h"
#endif

#if USE(CAIRO)
#include "HashFunctions.h"
#include <cairo.h>
#endif

#if OS(DARWIN)
OBJC_CLASS NSFont;

typedef struct CGFont* CGFontRef;
typedef const struct __CTFont* CTFontRef;

#include <CoreFoundation/CFBase.h>
#include <objc/objc-auto.h>
#endif

#include <wtf/Forward.h>
#include <wtf/PassRefPtr.h>
#include <wtf/RefCounted.h>
#include <wtf/RetainPtr.h>
#include <wtf/text/StringImpl.h>

#if PLATFORM(CHROMIUM) && OS(DARWIN)
#include "CrossProcessFontLoading.h"  
#endif

#if PLATFORM(WIN)
typedef struct HFONT__* HFONT;
#endif

#if USE(CG) || USE(SKIA_ON_MAC_CHROMIUM)
typedef struct CGFont* CGFontRef;
#if OS(DARWIN)
typedef const struct __CTFont* CTFontRef;
typedef UInt32 FMFont;
typedef FMFont ATSUFontID;
typedef UInt32 ATSFontRef;
#endif
#endif

namespace WebCore {

class FontDescription;

#if OS(DARWIN)
inline CTFontRef toCTFontRef(NSFont *nsFont) { return reinterpret_cast<CTFontRef>(nsFont); }
#endif

class FontPlatformData {
public:
    FontPlatformData(WTF::HashTableDeletedValueType)
        : m_syntheticBold(false)
        , m_syntheticOblique(false)
        , m_orientation(Horizontal)
        , m_textOrientation(TextOrientationVerticalRight)
        , m_size(0)
        , m_widthVariant(RegularWidth)
#if PLATFORM(WIN)
        , m_font(WTF::HashTableDeletedValue)
#elif OS(DARWIN)
        , m_font(hashTableDeletedFontValue())
#endif
#if USE(CG) && PLATFORM(WIN)
        , m_cgFont(0)
#elif USE(CAIRO)
        , m_scaledFont(hashTableDeletedFontValue())
#endif
        , m_isColorBitmapFont(false)
#if PLATFORM(WIN)
        , m_useGDI(false)
#endif
        {
        }

    FontPlatformData()
        : m_syntheticBold(false)
        , m_syntheticOblique(false)
        , m_orientation(Horizontal)
        , m_textOrientation(TextOrientationVerticalRight)
        , m_size(0)
        , m_widthVariant(RegularWidth)
#if OS(DARWIN)
        , m_font(0)
#endif
#if USE(CG) && PLATFORM(WIN)
        , m_cgFont(0)
#elif USE(CAIRO)
        , m_scaledFont(0)
#endif
        , m_isColorBitmapFont(false)
#if PLATFORM(WIN)
        , m_useGDI(false)
#endif
    {
    }

    FontPlatformData(const FontPlatformData&);
    FontPlatformData(const FontDescription&, const AtomicString& family);
    FontPlatformData(float size, bool syntheticBold, bool syntheticOblique, FontOrientation orientation = Horizontal,
                     TextOrientation textOrientation = TextOrientationVerticalRight, FontWidthVariant widthVariant = RegularWidth)
        : m_syntheticBold(syntheticBold)
        , m_syntheticOblique(syntheticOblique)
        , m_orientation(orientation)
        , m_textOrientation(textOrientation)
        , m_size(size)
        , m_widthVariant(widthVariant)
#if OS(DARWIN)
        , m_font(0)
#endif
#if USE(CG) && PLATFORM(WIN)
        , m_cgFont(0)
#elif USE(CAIRO)
        , m_scaledFont(0)
#endif
        , m_isColorBitmapFont(false)
#if PLATFORM(WIN)
        , m_useGDI(false)
#endif
    {
    }

#if OS(DARWIN)
    FontPlatformData(NSFont*, float size, bool syntheticBold = false, bool syntheticOblique = false, FontOrientation = Horizontal,
                     TextOrientation = TextOrientationVerticalRight, FontWidthVariant = RegularWidth);
#if USE(CG) || USE(SKIA_ON_MAC_CHROMIUM)
    FontPlatformData(CGFontRef cgFont, float size, bool syntheticBold, bool syntheticOblique, FontOrientation orientation,
                     TextOrientation textOrientation, FontWidthVariant widthVariant)
        : m_syntheticBold(syntheticBold)
        , m_syntheticOblique(syntheticOblique)
        , m_orientation(orientation)
        , m_textOrientation(textOrientation)
        , m_size(size)
        , m_widthVariant(widthVariant)
        , m_font(0)
        , m_cgFont(cgFont)
        , m_isColorBitmapFont(false)
    {
    }
#endif
#endif
#if PLATFORM(WIN)
    FontPlatformData(HFONT, float size, bool syntheticBold, bool syntheticOblique, bool useGDI);
#if USE(CG)
    FontPlatformData(HFONT, CGFontRef, float size, bool syntheticBold, bool syntheticOblique, bool useGDI);
#endif
#endif
#if USE(CAIRO)
    FontPlatformData(cairo_font_face_t*, float size, bool bold, bool italic);
#endif

    ~FontPlatformData();

#if PLATFORM(WIN)
    HFONT hfont() const { return m_font ? m_font->handle() : 0; }
    bool useGDI() const { return m_useGDI; }
#elif OS(DARWIN)
    NSFont* font() const { return m_font; }
    void setFont(NSFont*);
#endif

#if USE(CG) || USE(SKIA_ON_MAC_CHROMIUM)
#if OS(DARWIN)
    CGFontRef cgFont() const { return m_cgFont.get(); }
    CTFontRef ctFont() const;

    bool roundsGlyphAdvances() const;
    bool allowsLigatures() const;
#else
    CGFontRef cgFont() const { return m_cgFont.get(); }
#endif
#endif

    bool isFixedPitch() const;
    float size() const { return m_size; }
    void setSize(float size) { m_size = size; }
    bool syntheticBold() const { return m_syntheticBold; }
    bool syntheticOblique() const { return m_syntheticOblique; }
    bool isColorBitmapFont() const { return m_isColorBitmapFont; }
    FontOrientation orientation() const { return m_orientation; }
    TextOrientation textOrientation() const { return m_textOrientation; }
    FontWidthVariant widthVariant() const { return m_widthVariant; }

    void setOrientation(FontOrientation orientation) { m_orientation = orientation; }

#if USE(CAIRO)
    cairo_scaled_font_t* scaledFont() const { return m_scaledFont; }
#endif

    unsigned hash() const
    {
#if PLATFORM(WIN) && !USE(CAIRO)
        return m_font ? m_font->hash() : 0;
#elif OS(DARWIN)
#if USE(CG) || USE(SKIA_ON_MAC_CHROMIUM)
        ASSERT(m_font || !m_cgFont);
#endif
        uintptr_t hashCodes[3] = { (uintptr_t)m_font, m_widthVariant, m_textOrientation << 3 | m_orientation << 2 | m_syntheticBold << 1 | m_syntheticOblique };
        return StringHasher::hashMemory<sizeof(hashCodes)>(hashCodes);
#elif USE(CAIRO)
        return PtrHash<cairo_scaled_font_t*>::hash(m_scaledFont);
#endif
    }

    const FontPlatformData& operator=(const FontPlatformData&);

    bool operator==(const FontPlatformData& other) const
    {
        return platformIsEqual(other)
            && m_size == other.m_size
            && m_syntheticBold == other.m_syntheticBold
            && m_syntheticOblique == other.m_syntheticOblique
            && m_isColorBitmapFont == other.m_isColorBitmapFont
            && m_orientation == other.m_orientation
            && m_textOrientation == other.m_textOrientation
            && m_widthVariant == other.m_widthVariant;
    }

    bool isHashTableDeletedValue() const
    {
#if PLATFORM(WIN) && !USE(CAIRO)
        return m_font.isHashTableDeletedValue();
#elif OS(DARWIN)
        return m_font == hashTableDeletedFontValue();
#elif USE(CAIRO)
        return m_scaledFont == hashTableDeletedFontValue();
#endif
    }


#ifndef NDEBUG
    String description() const;
#endif

private:
    bool platformIsEqual(const FontPlatformData&) const;
    void platformDataInit(const FontPlatformData&);
    const FontPlatformData& platformDataAssign(const FontPlatformData&);
#if OS(DARWIN)
    // Load various data about the font specified by |nsFont| with the size fontSize into the following output paramters:
    // Note: Callers should always take into account that for the Chromium port, |outNSFont| isn't necessarily the same
    // font as |nsFont|. This because the sandbox may block loading of the original font.
    // * outNSFont - The font that was actually loaded, for the Chromium port this may be different than nsFont.
    // The caller is responsible for calling CFRelease() on this parameter when done with it.
    // * cgFont - CGFontRef representing the input font at the specified point size.
    void loadFont(NSFont*, float fontSize, NSFont*& outNSFont, CGFontRef&);
    static NSFont* hashTableDeletedFontValue() { return reinterpret_cast<NSFont *>(-1); }
#elif PLATFORM(WIN)
    void platformDataInit(HFONT, float size, HDC, WCHAR* faceName);
#endif

#if USE(CAIRO)
    static cairo_scaled_font_t* hashTableDeletedFontValue() { return reinterpret_cast<cairo_scaled_font_t*>(-1); }
#endif

public:
    bool m_syntheticBold;
    bool m_syntheticOblique;
    FontOrientation m_orientation;
    TextOrientation m_textOrientation;
    float m_size;
    FontWidthVariant m_widthVariant;

private:
#if OS(DARWIN)
    NSFont* m_font;
#elif PLATFORM(WIN)
    RefPtr<RefCountedGDIHandle<HFONT> > m_font;
#endif

#if USE(CG) || USE(SKIA_ON_MAC_CHROMIUM)
#if PLATFORM(WIN)
    RetainPtr<CGFontRef> m_cgFont;
#else
    RetainPtr<CGFontRef> m_cgFont;
    mutable RetainPtr<CTFontRef> m_CTFont;
#endif
#endif

#if USE(CAIRO)
    cairo_scaled_font_t* m_scaledFont;
#endif

#if PLATFORM(CHROMIUM) && OS(DARWIN)
    RefPtr<MemoryActivatedFont> m_inMemoryFont;
#endif

    bool m_isColorBitmapFont;

#if PLATFORM(WIN)
    bool m_useGDI;
#endif
};

} // namespace WebCore

#endif // FontPlatformData_h

#endif
