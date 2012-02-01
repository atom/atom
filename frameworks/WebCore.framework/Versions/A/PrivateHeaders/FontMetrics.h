/*
 * Copyright (C) Research In Motion Limited 2010-2011. All rights reserved.
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

#ifndef FontMetrics_h
#define FontMetrics_h

#include <wtf/MathExtras.h>

namespace WebCore {

const unsigned gDefaultUnitsPerEm = 1000;

class FontMetrics {
public:
    FontMetrics()
        : m_unitsPerEm(gDefaultUnitsPerEm)
        , m_ascent(0)
        , m_descent(0)
        , m_lineGap(0)
        , m_lineSpacing(0)
        , m_xHeight(0)
    {
    }

    unsigned unitsPerEm() const { return m_unitsPerEm; }
    void setUnitsPerEm(unsigned unitsPerEm) { m_unitsPerEm = unitsPerEm; }

    float floatAscent(FontBaseline baselineType = AlphabeticBaseline) const
    {
        if (baselineType == AlphabeticBaseline)
            return m_ascent;
        return floatHeight() / 2;
    }

    void setAscent(float ascent) { m_ascent = ascent; }

    float floatDescent(FontBaseline baselineType = AlphabeticBaseline) const
    {
        if (baselineType == AlphabeticBaseline)
            return m_descent;
        return floatHeight() / 2;
    }

    void setDescent(float descent) { m_descent = descent; }

    float floatHeight(FontBaseline baselineType = AlphabeticBaseline) const
    {
        return floatAscent(baselineType) + floatDescent(baselineType);
    }

    float floatLineGap() const { return m_lineGap; }
    void setLineGap(float lineGap) { m_lineGap = lineGap; }

    float floatLineSpacing() const { return m_lineSpacing; }
    void setLineSpacing(float lineSpacing) { m_lineSpacing = lineSpacing; }

    float xHeight() const { return m_xHeight; }
    void setXHeight(float xHeight) { m_xHeight = xHeight; }

    // Integer variants of certain metrics, used for HTML rendering.
    int ascent(FontBaseline baselineType = AlphabeticBaseline) const
    {
        if (baselineType == AlphabeticBaseline)
            return lroundf(m_ascent);
        return height() - height() / 2;
    }

    int descent(FontBaseline baselineType = AlphabeticBaseline) const
    {
        if (baselineType == AlphabeticBaseline)
            return lroundf(m_descent);
        return height() / 2;
    }

    int height(FontBaseline baselineType = AlphabeticBaseline) const
    {
        return ascent(baselineType) + descent(baselineType);
    }

    int lineGap() const { return lroundf(m_lineGap); }
    int lineSpacing() const { return lroundf(m_lineSpacing); }

    bool hasIdenticalAscentDescentAndLineGap(const FontMetrics& other) const
    {
        return ascent() == other.ascent() && descent() == other.descent() && lineGap() == other.lineGap();
    }

private:
    friend class SimpleFontData;

    void reset()
    {
        m_unitsPerEm = gDefaultUnitsPerEm;
        m_ascent = 0;
        m_descent = 0;
        m_lineGap = 0;
        m_lineSpacing = 0;
        m_xHeight = 0;
    }

    unsigned m_unitsPerEm;
    float m_ascent;
    float m_descent;
    float m_lineGap;
    float m_lineSpacing;
    float m_xHeight;
};

static inline float scaleEmToUnits(float x, unsigned unitsPerEm)
{
    return unitsPerEm ? x / unitsPerEm : x;
}

} // namespace WebCore

#endif // FontMetrics_h
