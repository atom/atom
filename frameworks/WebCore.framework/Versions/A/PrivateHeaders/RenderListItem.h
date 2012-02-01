/*
 * Copyright (C) 1999 Lars Knoll (knoll@kde.org)
 *           (C) 1999 Antti Koivisto (koivisto@kde.org)
 * Copyright (C) 2003, 2004, 2005, 2006, 2007, 2009 Apple Inc. All rights reserved.
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

#ifndef RenderListItem_h
#define RenderListItem_h

#include "RenderBlock.h"

namespace WebCore {

class RenderListMarker;

class RenderListItem : public RenderBlock {
public:
    explicit RenderListItem(Node*);

    int value() const { if (!m_isValueUpToDate) updateValueNow(); return m_value; }
    void updateValue();

    bool hasExplicitValue() const { return m_hasExplicitValue; }
    int explicitValue() const { return m_explicitValue; }
    void setExplicitValue(int value);
    void clearExplicitValue();

    void setNotInList(bool notInList) { m_notInList = notInList; }
    bool notInList() const { return m_notInList; }

    const String& markerText() const;
    String markerTextWithSuffix() const;

    void updateListMarkerNumbers();

    static RenderListItem* nextListItem(RenderObject* listRenderer, const RenderListItem* = 0);

private:
    virtual const char* renderName() const { return "RenderListItem"; }

    virtual bool isListItem() const { return true; }
    
    virtual void willBeDestroyed();

    virtual bool isEmpty() const;
    virtual void paint(PaintInfo&, const LayoutPoint&);

    virtual void layout();
    virtual void computePreferredLogicalWidths();

    void positionListMarker();

    virtual void styleDidChange(StyleDifference, const RenderStyle* oldStyle);

    virtual bool requiresForcedStyleRecalcPropagation() const { return true; }

    virtual void addOverflowFromChildren();

    void updateMarkerLocation();
    inline int calcValue() const;
    void updateValueNow() const;
    void explicitValueChanged();

    int m_explicitValue;
    RenderListMarker* m_marker;
    mutable int m_value;

    bool m_hasExplicitValue : 1;
    mutable bool m_isValueUpToDate : 1;
    bool m_notInList : 1;
};

inline RenderListItem* toRenderListItem(RenderObject* object)
{
    ASSERT(!object || object->isListItem());
    return static_cast<RenderListItem*>(object);
}

// This will catch anyone doing an unnecessary cast.
void toRenderListItem(const RenderListItem*);

} // namespace WebCore

#endif // RenderListItem_h
