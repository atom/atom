/*
 * Copyright (C) 2004, 2005 Nikolas Zimmermann <zimmermann@kde.org>
 * Copyright (C) 2004, 2005, 2006, 2007 Rob Buis <buis@kde.org>
 * Copyright (C) 2006 Samuel Weinig <sam.weinig@gmial.com>
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

#ifndef SVGPaint_h
#define SVGPaint_h

#if ENABLE(SVG)
#include "SVGColor.h"
#include <wtf/text/WTFString.h>

namespace WebCore {

class SVGPaint : public SVGColor {
public:
    enum SVGPaintType {
        SVG_PAINTTYPE_UNKNOWN = 0,
        SVG_PAINTTYPE_RGBCOLOR = 1,
        SVG_PAINTTYPE_RGBCOLOR_ICCCOLOR = 2,
        SVG_PAINTTYPE_NONE = 101,
        SVG_PAINTTYPE_CURRENTCOLOR = 102,
        SVG_PAINTTYPE_URI_NONE = 103,
        SVG_PAINTTYPE_URI_CURRENTCOLOR = 104,
        SVG_PAINTTYPE_URI_RGBCOLOR = 105,
        SVG_PAINTTYPE_URI_RGBCOLOR_ICCCOLOR = 106,
        SVG_PAINTTYPE_URI = 107
    };

    static PassRefPtr<SVGPaint> createUnknown()
    {
        return adoptRef(new SVGPaint(SVG_PAINTTYPE_UNKNOWN));
    }

    static PassRefPtr<SVGPaint> createNone()
    {
        return adoptRef(new SVGPaint(SVG_PAINTTYPE_NONE));
    }

    static PassRefPtr<SVGPaint> createCurrentColor()
    {
        return adoptRef(new SVGPaint(SVG_PAINTTYPE_CURRENTCOLOR));
    }

    static PassRefPtr<SVGPaint> createColor(const Color& color)
    {
        RefPtr<SVGPaint> paint = adoptRef(new SVGPaint(SVG_PAINTTYPE_RGBCOLOR));
        paint->setColor(color);
        return paint.release();
    }

    static PassRefPtr<SVGPaint> createURI(const String& uri)
    {
        RefPtr<SVGPaint> paint = adoptRef(new SVGPaint(SVG_PAINTTYPE_URI, uri));
        return paint.release();
    }

    static PassRefPtr<SVGPaint> createURIAndColor(const String& uri, const Color& color)
    {
        RefPtr<SVGPaint> paint = adoptRef(new SVGPaint(SVG_PAINTTYPE_URI_RGBCOLOR, uri));
        paint->setColor(color);
        return paint.release();
    }

    static PassRefPtr<SVGPaint> createURIAndNone(const String& uri)
    {
        RefPtr<SVGPaint> paint = adoptRef(new SVGPaint(SVG_PAINTTYPE_URI_NONE, uri));
        return paint.release();
    }

    const SVGPaintType& paintType() const { return m_paintType; }
    String uri() const { return m_uri; }

    void setUri(const String&);
    void setPaint(unsigned short paintType, const String& uri, const String& rgbColor, const String& iccColor, ExceptionCode&);

    String customCssText() const;

private:
    friend class CSSComputedStyleDeclaration;

    static PassRefPtr<SVGPaint> create(const SVGPaintType& type, const String& uri, const Color& color)
    {
        RefPtr<SVGPaint> paint = adoptRef(new SVGPaint(type, uri));
        paint->setColor(color);
        return paint.release();
    }

private:
    SVGPaint(const SVGPaintType&, const String& uri = String());

    SVGPaintType m_paintType;
    String m_uri;
};

} // namespace WebCore

#endif // ENABLE(SVG)
#endif // SVGPaint_h
