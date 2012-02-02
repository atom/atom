/*
 * (C) 1999-2003 Lars Knoll (knoll@kde.org)
 * Copyright (C) 2004, 2005, 2006, 2007, 2008 Apple Inc. All rights reserved.
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

#ifndef CSSValue_h
#define CSSValue_h

#include "KURLHash.h"
#include <wtf/ListHashSet.h>
#include <wtf/RefCounted.h>
#include <wtf/RefPtr.h>

namespace WebCore {

class CSSStyleSheet;

typedef int ExceptionCode;

class CSSValue : public RefCounted<CSSValue> {
public:
    enum Type {
        CSS_INHERIT = 0,
        CSS_PRIMITIVE_VALUE = 1,
        CSS_VALUE_LIST = 2,
        CSS_CUSTOM = 3,
        CSS_INITIAL = 4

    };

    // Override RefCounted's deref() to ensure operator delete is called on
    // the appropriate subclass type.
    void deref()
    {
        if (derefBase())
            destroy();
    }

    Type cssValueType() const;

    String cssText() const;
    void setCssText(const String&, ExceptionCode&) { } // FIXME: Not implemented.

    bool isPrimitiveValue() const { return m_classType <= PrimitiveClass; }
    bool isValueList() const { return m_classType >= ValueListClass; }

    bool isAspectRatioValue() const { return m_classType == AspectRatioClass; }
    bool isBorderImageSliceValue() const { return m_classType == BorderImageSliceClass; }
    bool isCursorImageValue() const { return m_classType == CursorImageClass; }
    bool isFontFamilyValue() const { return m_classType == FontFamilyClass; }
    bool isFontFeatureValue() const { return m_classType == FontFeatureClass; }
    bool isFontValue() const { return m_classType == FontClass; }
    bool isImageGeneratorValue() const { return m_classType >= CanvasClass && m_classType <= RadialGradientClass; }
    bool isImageValue() const { return m_classType == ImageClass || m_classType == CursorImageClass; }
    bool isImplicitInitialValue() const;
    bool isInheritedValue() const { return m_classType == InheritedClass; }
    bool isInitialValue() const { return m_classType == InitialClass; }
    bool isReflectValue() const { return m_classType == ReflectClass; }
    bool isShadowValue() const { return m_classType == ShadowClass; }
    bool isTimingFunctionValue() const { return m_classType >= CubicBezierTimingFunctionClass && m_classType <= StepsTimingFunctionClass; }
    bool isWebKitCSSTransformValue() const { return m_classType == WebKitCSSTransformClass; }
    bool isCSSLineBoxContainValue() const { return m_classType == LineBoxContainClass; }
    bool isFlexValue() const { return m_classType == FlexClass; }
#if ENABLE(CSS_FILTERS)
    bool isWebKitCSSFilterValue() const { return m_classType == WebKitCSSFilterClass; }
#if ENABLE(CSS_SHADERS)
    bool isWebKitCSSShaderValue() const { return m_classType == WebKitCSSShaderClass; }
#endif
#endif // ENABLE(CSS_FILTERS)
#if ENABLE(SVG)
    bool isSVGColor() const { return m_classType == SVGColorClass || m_classType == SVGPaintClass; }
    bool isSVGPaint() const { return m_classType == SVGPaintClass; }
#endif

    void addSubresourceStyleURLs(ListHashSet<KURL>&, const CSSStyleSheet*);

protected:

    static const size_t ClassTypeBits = 5;
    enum ClassType {
        // Primitive class types must appear before PrimitiveClass.
        ImageClass,
        CursorImageClass,
        FontFamilyClass,
        PrimitiveClass,

        // Image generator classes.
        CanvasClass,
        CrossfadeClass,
        LinearGradientClass,
        RadialGradientClass,

        // Timing function classes.
        CubicBezierTimingFunctionClass,
        LinearTimingFunctionClass,
        StepsTimingFunctionClass,

        // Other class types.
        AspectRatioClass,
        BorderImageSliceClass,
        FontFeatureClass,
        FontClass,
        FontFaceSrcClass,
        FunctionClass,

        InheritedClass,
        InitialClass,

        ReflectClass,
        ShadowClass,
        UnicodeRangeClass,
        LineBoxContainClass,
        FlexClass,
#if ENABLE(CSS_FILTERS) && ENABLE(CSS_SHADERS)
        WebKitCSSShaderClass,
#endif
#if ENABLE(SVG)
        SVGColorClass,
        SVGPaintClass,
#endif

        // List class types must appear after ValueListClass.
        ValueListClass,
#if ENABLE(CSS_FILTERS)
        WebKitCSSFilterClass,
#endif
        WebKitCSSTransformClass,
        // Do not append non-list class types here.
    };

    static const size_t ValueListSeparatorBits = 2;
    enum ValueListSeparator {
        SpaceSeparator,
        CommaSeparator,
        SlashSeparator
    };

    ClassType classType() const { return static_cast<ClassType>(m_classType); }

    explicit CSSValue(ClassType classType)
        : m_primitiveUnitType(0)
        , m_hasCachedCSSText(false)
        , m_isQuirkValue(false)
        , m_valueListSeparator(SpaceSeparator)
        , m_classType(classType)
    {
    }

    // NOTE: This class is non-virtual for memory and performance reasons.
    // Don't go making it virtual again unless you know exactly what you're doing!

    ~CSSValue() { }

private:
    void destroy();

protected:
    // The bits in this section are only used by specific subclasses but kept here
    // to maximize struct packing.

    // CSSPrimitiveValue bits:
    unsigned char m_primitiveUnitType : 7; // CSSPrimitiveValue::UnitTypes
    mutable bool m_hasCachedCSSText : 1;
    bool m_isQuirkValue : 1;

    unsigned char m_valueListSeparator : ValueListSeparatorBits;

private:
    unsigned char m_classType : ClassTypeBits; // ClassType
};

} // namespace WebCore

#endif // CSSValue_h
