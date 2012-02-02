/*
 * Copyright (C) 2006, 2007, 2008 Apple Computer, Inc.  All rights reserved.
 * Copyright (C) 2008 Eric Seidel <eric@webkit.org>
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

#ifndef Pattern_h
#define Pattern_h

#include "AffineTransform.h"
#include "Image.h"

#include <wtf/PassRefPtr.h>
#include <wtf/RefCounted.h>
#include <wtf/RefPtr.h>

#if USE(CG)
typedef struct CGPattern* CGPatternRef;
typedef CGPatternRef PlatformPatternPtr;
#elif USE(CAIRO)
#include <cairo.h>
typedef cairo_pattern_t* PlatformPatternPtr;
#elif USE(SKIA)
class SkShader;
typedef SkShader* PlatformPatternPtr;
#elif PLATFORM(QT)
#include <QBrush>
typedef QBrush PlatformPatternPtr;
#elif PLATFORM(WX)
#if USE(WXGC)
class wxGraphicsBrush;
typedef wxGraphicsBrush* PlatformPatternPtr;
#else
class wxBrush;
typedef wxBrush* PlatformPatternPtr;
#endif // USE(WXGC)
#elif OS(WINCE)
typedef void* PlatformPatternPtr;
#endif

namespace WebCore {

class AffineTransform;

class Pattern : public RefCounted<Pattern> {
public:
    static PassRefPtr<Pattern> create(PassRefPtr<Image> tileImage, bool repeatX, bool repeatY)
    {
        return adoptRef(new Pattern(tileImage, repeatX, repeatY));
    }
    virtual ~Pattern();

    Image* tileImage() const { return m_tileImage.get(); }

    void platformDestroy();

    // Pattern space is an abstract space that maps to the default user space by the transformation 'userSpaceTransformation' 
#if USE(SKIA)
    PlatformPatternPtr platformPattern(const AffineTransform& userSpaceTransformation);
#else
    PlatformPatternPtr createPlatformPattern(const AffineTransform& userSpaceTransformation) const;
#endif
    void setPatternSpaceTransform(const AffineTransform& patternSpaceTransformation);
    void setPlatformPatternSpaceTransform();

    bool repeatX() const { return m_repeatX; }
    bool repeatY() const { return m_repeatY; }

private:
    Pattern(PassRefPtr<Image>, bool repeatX, bool repeatY);

    RefPtr<Image> m_tileImage;
    bool m_repeatX;
    bool m_repeatY;
    AffineTransform m_patternSpaceTransformation;
    PlatformPatternPtr m_pattern;
};

} //namespace

#endif
