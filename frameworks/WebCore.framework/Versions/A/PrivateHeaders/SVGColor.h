/*
 * Copyright (C) 2004, 2005 Nikolas Zimmermann <zimmermann@kde.org>
 * Copyright (C) 2004, 2005, 2006, 2007 Rob Buis <buis@kde.org>
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

#ifndef SVGColor_h
#define SVGColor_h

#if ENABLE(SVG)
#include "CSSValue.h"
#include "Color.h"
#include <wtf/PassRefPtr.h>

namespace WebCore {

class RGBColor;

class SVGColor : public CSSValue {
public:
    enum SVGColorType {
        SVG_COLORTYPE_UNKNOWN = 0,
        SVG_COLORTYPE_RGBCOLOR = 1,
        SVG_COLORTYPE_RGBCOLOR_ICCCOLOR = 2,
        SVG_COLORTYPE_CURRENTCOLOR = 3
    };

    static PassRefPtr<SVGColor> createFromString(const String& rgbColor)
    {
        RefPtr<SVGColor> color = adoptRef(new SVGColor(SVG_COLORTYPE_RGBCOLOR));
        color->setColor(colorFromRGBColorString(rgbColor));
        return color.release();
    }

    static PassRefPtr<SVGColor> createFromColor(const Color& rgbColor)
    {
        RefPtr<SVGColor> color = adoptRef(new SVGColor(SVG_COLORTYPE_RGBCOLOR));
        color->setColor(rgbColor);
        return color.release();
    }

    static PassRefPtr<SVGColor> createCurrentColor()
    {
        return adoptRef(new SVGColor(SVG_COLORTYPE_CURRENTCOLOR));
    }

    const Color& color() const { return m_color; }
    const SVGColorType& colorType() const { return m_colorType; }
    PassRefPtr<RGBColor> rgbColor() const;

    static Color colorFromRGBColorString(const String&);

    void setRGBColor(const String& rgbColor, ExceptionCode&);
    void setRGBColorICCColor(const String& rgbColor, const String& iccColor, ExceptionCode&);
    void setColor(unsigned short colorType, const String& rgbColor, const String& iccColor, ExceptionCode&);

    String customCssText() const;

    ~SVGColor() { }

protected:
    friend class CSSComputedStyleDeclaration;

    SVGColor(ClassType, const SVGColorType&);

    void setColor(const Color& color) { m_color = color; }
    void setColorType(const SVGColorType& type) { m_colorType = type; }

private:
    SVGColor(const SVGColorType&);

    Color m_color;
    SVGColorType m_colorType;
};

} // namespace WebCore

#endif // ENABLE(SVG)
#endif // SVGColor_h
