/*
 * (C) 1999-2003 Lars Knoll (knoll@kde.org)
 * Copyright (C) 2004, 2005, 2006, 2008 Apple Inc. All rights reserved.
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

#ifndef CSSImageValue_h
#define CSSImageValue_h

#include "CSSPrimitiveValue.h"
#include <wtf/RefPtr.h>

namespace WebCore {

class CachedResourceLoader;
class StyleCachedImage;
class StyleImage;

class CSSImageValue : public CSSPrimitiveValue {
public:
    static PassRefPtr<CSSImageValue> create() { return adoptRef(new CSSImageValue); }
    static PassRefPtr<CSSImageValue> create(const String& url) { return adoptRef(new CSSImageValue(url)); }
    static PassRefPtr<CSSImageValue> create(const String& url, StyleImage* image) { return adoptRef(new CSSImageValue(url, image)); }
    ~CSSImageValue();

    StyleCachedImage* cachedImage(CachedResourceLoader*);
    // Returns a StyleCachedImage if the image is cached already, otherwise a StylePendingImage.
    StyleImage* cachedOrPendingImage();

protected:
    CSSImageValue(ClassType, const String& url);

    StyleCachedImage* cachedImage(CachedResourceLoader*, const String& url);
    String cachedImageURL();
    void clearCachedImage();

private:
    CSSImageValue();
    explicit CSSImageValue(const String& url);
    explicit CSSImageValue(const String& url, StyleImage*);

    RefPtr<StyleImage> m_image;
    bool m_accessedImage;
};

} // namespace WebCore

#endif // CSSImageValue_h
