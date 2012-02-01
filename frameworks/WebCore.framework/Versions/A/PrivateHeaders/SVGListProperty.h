/*
 * Copyright (C) Research In Motion Limited 2010. All rights reserved.
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

#ifndef SVGListProperty_h
#define SVGListProperty_h

#if ENABLE(SVG)
#include "SVGAnimatedProperty.h"
#include "SVGException.h"
#include "SVGPropertyTearOff.h"
#include "SVGPropertyTraits.h"

namespace WebCore {

template<typename PropertyType>
class SVGAnimatedListPropertyTearOff;

template<typename PropertyType>
class SVGListProperty : public SVGProperty {
public:
    typedef SVGListProperty<PropertyType> Self;

    typedef typename SVGPropertyTraits<PropertyType>::ListItemType ListItemType;
    typedef SVGPropertyTearOff<ListItemType> ListItemTearOff;
    typedef PassRefPtr<ListItemTearOff> PassListItemTearOff;
    typedef SVGAnimatedListPropertyTearOff<PropertyType> AnimatedListPropertyTearOff;
    typedef typename SVGAnimatedListPropertyTearOff<PropertyType>::ListWrapperCache ListWrapperCache;

    bool canAlterList(ExceptionCode& ec) const
    {
        if (m_role == AnimValRole) {
            ec = NO_MODIFICATION_ALLOWED_ERR;
            return false;
        }

        return true;
    }

    // SVGList::clear()
    void clearValues(PropertyType& values, ExceptionCode& ec)
    {
        if (!canAlterList(ec))
            return;

        values.clear();
        commitChange();
    }

    void clearValuesAndWrappers(AnimatedListPropertyTearOff* animatedList, ExceptionCode& ec)
    {
        ASSERT(animatedList);
        if (!canAlterList(ec))
            return;

        animatedList->detachListWrappers(0);
        animatedList->values().clear();
        commitChange();
    }

    // SVGList::numberOfItems()
    unsigned numberOfItemsValues(PropertyType& values) const
    {
        return values.size();
    }

    unsigned numberOfItemsValuesAndWrappers(AnimatedListPropertyTearOff* animatedList) const
    {
        ASSERT(animatedList);
        return animatedList->values().size();
    }

    // SVGList::initialize()
    ListItemType initializeValues(PropertyType& values, const ListItemType& newItem, ExceptionCode& ec)
    {
        if (!canAlterList(ec))
            return ListItemType();

        // Spec: If the inserted item is already in a list, it is removed from its previous list before it is inserted into this list.
        processIncomingListItemValue(newItem, 0);

        // Spec: Clears all existing current items from the list and re-initializes the list to hold the single item specified by the parameter.
        values.clear();
        values.append(newItem);

        commitChange();
        return newItem;
    }

    PassListItemTearOff initializeValuesAndWrappers(AnimatedListPropertyTearOff* animatedList, PassListItemTearOff passNewItem, ExceptionCode& ec)
    {
        ASSERT(animatedList);
        if (!canAlterList(ec))
            return 0;

        // Not specified, but FF/Opera do it this way, and it's just sane.
        if (!passNewItem) {
            ec = SVGException::SVG_WRONG_TYPE_ERR;
            return 0;
        }

        PropertyType& values = animatedList->values();
        ListWrapperCache& wrappers = animatedList->wrappers();

        RefPtr<ListItemTearOff> newItem = passNewItem;
        ASSERT(values.size() == wrappers.size());

        // Spec: If the inserted item is already in a list, it is removed from its previous list before it is inserted into this list.
        processIncomingListItemWrapper(newItem, 0);

        // Spec: Clears all existing current items from the list and re-initializes the list to hold the single item specified by the parameter.
        animatedList->detachListWrappers(0);
        values.clear();

        values.append(newItem->propertyReference());
        wrappers.append(newItem);

        commitChange();
        return newItem.release();
    }

    // SVGList::getItem()
    bool canGetItem(PropertyType& values, unsigned index, ExceptionCode& ec)
    {
        if (index >= values.size()) {
            ec = INDEX_SIZE_ERR;
            return false;
        }

        return true;
    }

    ListItemType getItemValues(PropertyType& values, unsigned index, ExceptionCode& ec)
    {
        if (!canGetItem(values, index, ec)) 
            return ListItemType();

        // Spec: Returns the specified item from the list. The returned item is the item itself and not a copy.
        return values.at(index);
    }

    PassListItemTearOff getItemValuesAndWrappers(AnimatedListPropertyTearOff* animatedList, unsigned index, ExceptionCode& ec)
    {
        ASSERT(animatedList);
        PropertyType& values = animatedList->values();
        if (!canGetItem(values, index, ec))
            return 0;

        ListWrapperCache& wrappers = animatedList->wrappers();

        // Spec: Returns the specified item from the list. The returned item is the item itself and not a copy.
        // Any changes made to the item are immediately reflected in the list.
        ASSERT(values.size() == wrappers.size());
        RefPtr<ListItemTearOff> wrapper = wrappers.at(index);
        if (!wrapper) {
            // Create new wrapper, which is allowed to directly modify the item in the list, w/o copying and cache the wrapper in our map.
            // It is also associated with our animated property, so it can notify the SVG Element which holds the SVGAnimated*List
            // that it has been modified (and thus can call svgAttributeChanged(associatedAttributeName)).
            wrapper = ListItemTearOff::create(animatedList, UndefinedRole, values.at(index));
            wrappers.at(index) = wrapper;
        }

        return wrapper.release();
    }

    // SVGList::insertItemBefore()
    ListItemType insertItemBeforeValues(PropertyType& values, const ListItemType& newItem, unsigned index, ExceptionCode& ec)
    {
        if (!canAlterList(ec))
            return ListItemType();

        // Spec: If the index is greater than or equal to numberOfItems, then the new item is appended to the end of the list.
        if (index > values.size())
            index = values.size();

        // Spec: If newItem is already in a list, it is removed from its previous list before it is inserted into this list.
        processIncomingListItemValue(newItem, &index);

        // Spec: Inserts a new item into the list at the specified position. The index of the item before which the new item is to be
        // inserted. The first item is number 0. If the index is equal to 0, then the new item is inserted at the front of the list.
        values.insert(index, newItem);

        commitChange();
        return newItem;
    }

    PassListItemTearOff insertItemBeforeValuesAndWrappers(AnimatedListPropertyTearOff* animatedList, PassListItemTearOff passNewItem, unsigned index, ExceptionCode& ec)
    {
        ASSERT(animatedList);
        if (!canAlterList(ec))
            return 0;

        // Not specified, but FF/Opera do it this way, and it's just sane.
        if (!passNewItem) {
            ec = SVGException::SVG_WRONG_TYPE_ERR;
            return 0;
        }

        PropertyType& values = animatedList->values();
        ListWrapperCache& wrappers = animatedList->wrappers();

        // Spec: If the index is greater than or equal to numberOfItems, then the new item is appended to the end of the list.
        if (index > values.size())
             index = values.size();

        RefPtr<ListItemTearOff> newItem = passNewItem;
        ASSERT(values.size() == wrappers.size());

        // Spec: If newItem is already in a list, it is removed from its previous list before it is inserted into this list.
        processIncomingListItemWrapper(newItem, &index);

        // Spec: Inserts a new item into the list at the specified position. The index of the item before which the new item is to be
        // inserted. The first item is number 0. If the index is equal to 0, then the new item is inserted at the front of the list.
        values.insert(index, newItem->propertyReference());

        // Store new wrapper at position 'index', change its underlying value, so mutations of newItem, directly affect the item in the list.
        wrappers.insert(index, newItem);

        commitChange();
        return newItem.release();
    }

    // SVGList::replaceItem()
    bool canReplaceItem(PropertyType& values, unsigned index, ExceptionCode& ec)
    {
        if (!canAlterList(ec))
            return false;

        if (index >= values.size()) {
            ec = INDEX_SIZE_ERR;
            return false;
        }

        return true;
    }

    ListItemType replaceItemValues(PropertyType& values, const ListItemType& newItem, unsigned index, ExceptionCode& ec)
    {
        if (!canReplaceItem(values, index, ec))
            return ListItemType();

        // Spec: If newItem is already in a list, it is removed from its previous list before it is inserted into this list.
        // Spec: If the item is already in this list, note that the index of the item to replace is before the removal of the item.
        processIncomingListItemValue(newItem, &index);

        if (values.isEmpty()) {
            // 'newItem' already lived in our list, we removed it, and now we're empty, which means there's nothing to replace.
            ec = INDEX_SIZE_ERR;
            return ListItemType();
        }

        // Update the value at the desired position 'index'. 
        values.at(index) = newItem;

        commitChange();
        return newItem;
    }

    PassListItemTearOff replaceItemValuesAndWrappers(AnimatedListPropertyTearOff* animatedList, PassListItemTearOff passNewItem, unsigned index, ExceptionCode& ec)
    {
        ASSERT(animatedList);
        PropertyType& values = animatedList->values();
        if (!canReplaceItem(values, index, ec))
            return 0;

        // Not specified, but FF/Opera do it this way, and it's just sane.
        if (!passNewItem) {
            ec = SVGException::SVG_WRONG_TYPE_ERR;
            return 0;
        }

        ListWrapperCache& wrappers = animatedList->wrappers();
        ASSERT(values.size() == wrappers.size());
        RefPtr<ListItemTearOff> newItem = passNewItem;

        // Spec: If newItem is already in a list, it is removed from its previous list before it is inserted into this list.
        // Spec: If the item is already in this list, note that the index of the item to replace is before the removal of the item.
        processIncomingListItemWrapper(newItem, &index);

        if (values.isEmpty()) {
            ASSERT(wrappers.isEmpty());
            // 'passNewItem' already lived in our list, we removed it, and now we're empty, which means there's nothing to replace.
            ec = INDEX_SIZE_ERR;
            return 0;
        }

        // Detach the existing wrapper.
        RefPtr<ListItemTearOff> oldItem = wrappers.at(index);
        if (oldItem)
            oldItem->detachWrapper();

        // Update the value and the wrapper at the desired position 'index'. 
        values.at(index) = newItem->propertyReference();
        wrappers.at(index) = newItem;

        commitChange();
        return newItem.release();
    }

    // SVGList::removeItem()
    bool canRemoveItem(PropertyType& values, unsigned index, ExceptionCode& ec)
    {
        if (!canAlterList(ec))
            return false;

        if (index >= values.size()) {
            ec = INDEX_SIZE_ERR;
            return false;
        }

        return true;
    }

    ListItemType removeItemValues(PropertyType& values, unsigned index, ExceptionCode& ec)
    {
        if (!canRemoveItem(values, index, ec))
            return ListItemType();

        ListItemType oldItem = values.at(index);
        values.remove(index);

        commitChange();
        return oldItem;
    }

    PassListItemTearOff removeItemValuesAndWrappers(AnimatedListPropertyTearOff* animatedList, unsigned index, ExceptionCode& ec)
    {
        ASSERT(animatedList);
        PropertyType& values = animatedList->values();
        if (!canRemoveItem(values, index, ec))
            return 0;

        ListWrapperCache& wrappers = animatedList->wrappers();
        ASSERT(values.size() == wrappers.size());

        // Detach the existing wrapper.
        RefPtr<ListItemTearOff> oldItem = wrappers.at(index);
        if (!oldItem)
            oldItem = ListItemTearOff::create(animatedList, UndefinedRole, values.at(index));

        oldItem->detachWrapper();
        wrappers.remove(index);
        values.remove(index);

        commitChange();
        return oldItem.release();
    }

    // SVGList::appendItem()
    ListItemType appendItemValues(PropertyType& values, const ListItemType& newItem, ExceptionCode& ec)
    {
        if (!canAlterList(ec))
            return ListItemType();

        // Spec: If newItem is already in a list, it is removed from its previous list before it is inserted into this list.
        processIncomingListItemValue(newItem, 0);

        // Append the value at the end of the list.
        values.append(newItem);

        commitChange();
        return newItem;
    }

    PassListItemTearOff appendItemValuesAndWrappers(AnimatedListPropertyTearOff* animatedList, PassListItemTearOff passNewItem, ExceptionCode& ec)
    {
        ASSERT(animatedList);
        if (!canAlterList(ec))
            return 0;

        // Not specified, but FF/Opera do it this way, and it's just sane.
        if (!passNewItem) {
            ec = SVGException::SVG_WRONG_TYPE_ERR;
            return 0;
        }

        PropertyType& values = animatedList->values();
        ListWrapperCache& wrappers = animatedList->wrappers();

        RefPtr<ListItemTearOff> newItem = passNewItem;
        ASSERT(values.size() == wrappers.size());

        // Spec: If newItem is already in a list, it is removed from its previous list before it is inserted into this list.
        processIncomingListItemWrapper(newItem, 0);

        // Append the value and wrapper at the end of the list.
        values.append(newItem->propertyReference());
        wrappers.append(newItem);

        commitChange();
        return newItem.release();
    }

    virtual SVGPropertyRole role() const { return m_role; }

protected:
    SVGListProperty(SVGPropertyRole role)
        : m_role(role)
    {
    }

    virtual void commitChange() = 0;
    virtual void processIncomingListItemValue(const ListItemType& newItem, unsigned* indexToModify) = 0;
    virtual void processIncomingListItemWrapper(RefPtr<ListItemTearOff>& newItem, unsigned* indexToModify) = 0;

private:
    SVGPropertyRole m_role;
};

}

#endif // ENABLE(SVG)
#endif // SVGListProperty_h
