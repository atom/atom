/*
 *  Copyright (C) 2005, 2007, 2008 Apple Inc. All rights reserved.
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Library General Public
 *  License as published by the Free Software Foundation; either
 *  version 2 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Library General Public License for more details.
 *
 *  You should have received a copy of the GNU Library General Public License
 *  along with this library; see the file COPYING.LIB.  If not, write to
 *  the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 *  Boston, MA 02110-1301, USA.
 *
 */

#ifndef PropertySlot_h
#define PropertySlot_h

#include "Identifier.h"
#include "JSValue.h"
#include "Register.h"
#include <wtf/Assertions.h>
#include <wtf/NotFound.h>

namespace JSC {

    class ExecState;
    class JSObject;

#define JSC_VALUE_MARKER 0
#define INDEX_GETTER_MARKER reinterpret_cast<GetValueFunc>(2)
#define GETTER_FUNCTION_MARKER reinterpret_cast<GetValueFunc>(3)

    class PropertySlot {
    public:
        enum CachedPropertyType {
            Uncacheable,
            Getter,
            Custom,
            Value
        };

        PropertySlot()
            : m_cachedPropertyType(Uncacheable)
        {
            clearBase();
            clearOffset();
            clearValue();
        }

        explicit PropertySlot(const JSValue base)
            : m_slotBase(base)
            , m_cachedPropertyType(Uncacheable)
        {
            clearOffset();
            clearValue();
        }

        typedef JSValue (*GetValueFunc)(ExecState*, JSValue slotBase, const Identifier&);
        typedef JSValue (*GetIndexValueFunc)(ExecState*, JSValue slotBase, unsigned);

        JSValue getValue(ExecState* exec, const Identifier& propertyName) const
        {
            if (m_getValue == JSC_VALUE_MARKER)
                return m_value;
            if (m_getValue == INDEX_GETTER_MARKER)
                return m_getIndexValue(exec, slotBase(), index());
            if (m_getValue == GETTER_FUNCTION_MARKER)
                return functionGetter(exec);
            return m_getValue(exec, slotBase(), propertyName);
        }

        JSValue getValue(ExecState* exec, unsigned propertyName) const
        {
            if (m_getValue == JSC_VALUE_MARKER)
                return m_value;
            if (m_getValue == INDEX_GETTER_MARKER)
                return m_getIndexValue(exec, m_slotBase, m_data.index);
            if (m_getValue == GETTER_FUNCTION_MARKER)
                return functionGetter(exec);
            return m_getValue(exec, slotBase(), Identifier::from(exec, propertyName));
        }

        CachedPropertyType cachedPropertyType() const { return m_cachedPropertyType; }
        bool isCacheable() const { return m_cachedPropertyType != Uncacheable; }
        bool isCacheableValue() const { return m_cachedPropertyType == Value; }
        size_t cachedOffset() const
        {
            ASSERT(isCacheable());
            return m_offset;
        }

        void setValue(JSValue slotBase, JSValue value)
        {
            ASSERT(value);
            clearOffset();
            m_getValue = JSC_VALUE_MARKER;
            m_slotBase = slotBase;
            m_value = value;
        }
        
        void setValue(JSValue slotBase, JSValue value, size_t offset)
        {
            ASSERT(value);
            m_getValue = JSC_VALUE_MARKER;
            m_slotBase = slotBase;
            m_value = value;
            m_offset = offset;
            m_cachedPropertyType = Value;
        }

        void setValue(JSValue value)
        {
            ASSERT(value);
            clearBase();
            clearOffset();
            m_getValue = JSC_VALUE_MARKER;
            m_value = value;
        }

        void setCustom(JSValue slotBase, GetValueFunc getValue)
        {
            ASSERT(slotBase);
            ASSERT(getValue);
            m_getValue = getValue;
            m_getIndexValue = 0;
            m_slotBase = slotBase;
        }
        
        void setCacheableCustom(JSValue slotBase, GetValueFunc getValue)
        {
            ASSERT(slotBase);
            ASSERT(getValue);
            m_getValue = getValue;
            m_getIndexValue = 0;
            m_slotBase = slotBase;
            m_cachedPropertyType = Custom;
        }

        void setCustomIndex(JSValue slotBase, unsigned index, GetIndexValueFunc getIndexValue)
        {
            ASSERT(slotBase);
            ASSERT(getIndexValue);
            m_getValue = INDEX_GETTER_MARKER;
            m_getIndexValue = getIndexValue;
            m_slotBase = slotBase;
            m_data.index = index;
        }

        void setGetterSlot(JSObject* getterFunc)
        {
            ASSERT(getterFunc);
            m_thisValue = m_slotBase;
            m_getValue = GETTER_FUNCTION_MARKER;
            m_data.getterFunc = getterFunc;
        }

        void setCacheableGetterSlot(JSValue slotBase, JSObject* getterFunc, unsigned offset)
        {
            ASSERT(getterFunc);
            m_getValue = GETTER_FUNCTION_MARKER;
            m_thisValue = m_slotBase;
            m_slotBase = slotBase;
            m_data.getterFunc = getterFunc;
            m_offset = offset;
            m_cachedPropertyType = Getter;
        }

        void setUndefined()
        {
            setValue(jsUndefined());
        }

        JSValue slotBase() const
        {
            return m_slotBase;
        }

        void setBase(JSValue base)
        {
            ASSERT(m_slotBase);
            ASSERT(base);
            m_slotBase = base;
        }

        void clearBase()
        {
#ifndef NDEBUG
            m_slotBase = JSValue();
#endif
        }

        void clearValue()
        {
#ifndef NDEBUG
            m_value = JSValue();
#endif
        }

        void clearOffset()
        {
            // Clear offset even in release builds, in case this PropertySlot has been used before.
            // (For other data members, we don't need to clear anything because reuse would meaningfully overwrite them.)
            m_offset = 0;
            m_cachedPropertyType = Uncacheable;
        }

        unsigned index() const { return m_data.index; }

        GetValueFunc customGetter() const
        {
            ASSERT(m_cachedPropertyType == Custom);
            return m_getValue;
        }
    private:
        JS_EXPORT_PRIVATE JSValue functionGetter(ExecState*) const;

        GetValueFunc m_getValue;
        GetIndexValueFunc m_getIndexValue;
        
        JSValue m_slotBase;
        union {
            JSObject* getterFunc;
            unsigned index;
        } m_data;

        JSValue m_value;
        JSValue m_thisValue;

        size_t m_offset;
        CachedPropertyType m_cachedPropertyType;
    };

} // namespace JSC

#endif // PropertySlot_h
