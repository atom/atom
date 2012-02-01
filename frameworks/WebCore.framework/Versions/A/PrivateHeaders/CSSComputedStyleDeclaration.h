/*
 * Copyright (C) 2004 Zack Rusin <zack@kde.org>
 * Copyright (C) 2004, 2005, 2006, 2008 Apple Inc. All rights reserved.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
 * 02110-1301  USA
 */

#ifndef CSSComputedStyleDeclaration_h
#define CSSComputedStyleDeclaration_h

#include "CSSStyleDeclaration.h"
#include "RenderStyleConstants.h"
#include <wtf/RefPtr.h>
#include <wtf/text/WTFString.h>

namespace WebCore {

class Color;
class CSSMutableStyleDeclaration;
class CSSPrimitiveValue;
class CSSValueList;
class CSSValuePool;
class Node;
class RenderStyle;
class ShadowData;
class SVGPaint;

#if ENABLE(CSS_SHADERS)
class CustomFilterNumberParameter;
class CustomFilterParameter;
#endif

enum EUpdateLayout { DoNotUpdateLayout = false, UpdateLayout = true };

class CSSComputedStyleDeclaration : public CSSStyleDeclaration {
public:
    friend PassRefPtr<CSSComputedStyleDeclaration> computedStyle(PassRefPtr<Node>, bool allowVisitedStyle, const String& pseudoElementName);
    virtual ~CSSComputedStyleDeclaration();

    virtual String cssText() const;

    virtual unsigned virtualLength() const;
    virtual String item(unsigned index) const;

    virtual PassRefPtr<CSSValue> getPropertyCSSValue(int propertyID) const;
    virtual String getPropertyValue(int propertyID) const;
    virtual bool getPropertyPriority(int propertyID) const;
    virtual int getPropertyShorthand(int /*propertyID*/) const { return -1; }
    virtual bool isPropertyImplicit(int /*propertyID*/) const { return false; }

    virtual PassRefPtr<CSSMutableStyleDeclaration> copy() const;
    virtual PassRefPtr<CSSMutableStyleDeclaration> makeMutable();

    PassRefPtr<CSSValue> getPropertyCSSValue(int propertyID, EUpdateLayout) const;
    PassRefPtr<CSSValue> getFontSizeCSSValuePreferringKeyword() const;
    bool useFixedFontDefaultSize() const;
#if ENABLE(SVG)
    PassRefPtr<CSSValue> getSVGPropertyCSSValue(int propertyID, EUpdateLayout) const;
#endif

protected:
    virtual bool cssPropertyMatches(const CSSProperty*) const;

private:
    CSSComputedStyleDeclaration(PassRefPtr<Node>, bool allowVisitedStyle, const String&);

    virtual void setCssText(const String&, ExceptionCode&);

    virtual String removeProperty(int propertyID, ExceptionCode&);
    virtual void setProperty(int propertyId, const String& value, bool important, ExceptionCode&);

    PassRefPtr<CSSValue> valueForShadow(const ShadowData*, int, RenderStyle*) const;
    PassRefPtr<CSSPrimitiveValue> currentColorOrValidColor(RenderStyle*, const Color&) const;
#if ENABLE(SVG)
    PassRefPtr<SVGPaint> adjustSVGPaintForCurrentColor(PassRefPtr<SVGPaint>, RenderStyle*) const;
#endif

#if ENABLE(CSS_SHADERS)
    PassRefPtr<CSSValue> valueForCustomFilterNumberParameter(const CustomFilterNumberParameter*) const;
    PassRefPtr<CSSValue> valueForCustomFilterParameter(const CustomFilterParameter*) const;
#endif

#if ENABLE(CSS_FILTERS)
    PassRefPtr<CSSValue> valueForFilter(RenderStyle*) const;
#endif

    PassRefPtr<CSSValueList> getCSSPropertyValuesForShorthandProperties(const int* properties, size_t) const;
    PassRefPtr<CSSValueList> getCSSPropertyValuesForSidesShorthand(const int* properties) const;

    RefPtr<Node> m_node;
    PseudoId m_pseudoElementSpecifier;
    bool m_allowVisitedStyle;
};

inline PassRefPtr<CSSComputedStyleDeclaration> computedStyle(PassRefPtr<Node> node,  bool allowVisitedStyle = false, const String& pseudoElementName = String())
{
    return adoptRef(new CSSComputedStyleDeclaration(node, allowVisitedStyle, pseudoElementName));
}

} // namespace WebCore

#endif // CSSComputedStyleDeclaration_h
