/*
 * Copyright (C) 2007 Eric Seidel <eric@webkit.org>
 * Copyright (C) 2007 Nikolas Zimmermann <zimmermann@kde.org>
 * Copyright (C) 2008 Rob Buis <buis@kde.org>
 * Copyright (C) Research In Motion Limited 2011. All rights reserved.
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
 */

#ifndef SVGGlyph_h
#define SVGGlyph_h

#if ENABLE(SVG_FONTS)
#include "Glyph.h"
#include "Path.h"

#include <limits>
#include <wtf/Vector.h>
#include <wtf/text/WTFString.h>

namespace WebCore {

// Describe a glyph from a SVG Font.
struct SVGGlyph {
    enum Orientation {
        Vertical,
        Horizontal,
        Both
    };

    // SVG Font depends on exactly this order.
    enum ArabicForm {
        None = 0,
        Isolated,
        Terminal,
        Initial,
        Medial
    };

    SVGGlyph()
        : isPartOfLigature(false)
        , orientation(Both)
        , arabicForm(None)
        , priority(0)
        , tableEntry(0)
        , unicodeStringLength(0)
        , horizontalAdvanceX(0)
        , verticalOriginX(0)
        , verticalOriginY(0)
        , verticalAdvanceY(0)
    {
    }

    // Used to mark our float properties as "to be inherited from SVGFontData"
    static float inheritedValue()
    {
        static float s_inheritedValue = std::numeric_limits<float>::infinity();
        return s_inheritedValue;
    }

    bool operator==(const SVGGlyph& other) const
    {
        return isPartOfLigature == other.isPartOfLigature
            && orientation == other.orientation
            && arabicForm == other.arabicForm
            && tableEntry == other.tableEntry
            && unicodeStringLength == other.unicodeStringLength
            && glyphName == other.glyphName
            && horizontalAdvanceX == other.horizontalAdvanceX
            && verticalOriginX == other.verticalOriginX
            && verticalOriginY == other.verticalOriginY
            && verticalAdvanceY == other.verticalAdvanceY
            && languages == other.languages;
    }

    bool isPartOfLigature : 1;

    unsigned orientation : 2; // Orientation
    unsigned arabicForm : 3; // ArabicForm
    int priority;
    Glyph tableEntry;
    size_t unicodeStringLength;
    String glyphName;

    float horizontalAdvanceX;
    float verticalOriginX;
    float verticalOriginY;
    float verticalAdvanceY;

    Path pathData;
    Vector<String> languages;
};

Vector<SVGGlyph::ArabicForm> charactersWithArabicForm(const String& input, bool rtl);
bool isCompatibleGlyph(const SVGGlyph&, bool isVerticalText, const String& language, const Vector<SVGGlyph::ArabicForm>&, unsigned startPosition, unsigned endPosition);

} // namespace WebCore

#endif // ENABLE(SVG_FONTS)
#endif
