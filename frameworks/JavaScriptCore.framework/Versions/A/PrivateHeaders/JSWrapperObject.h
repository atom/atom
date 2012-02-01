/*
 *  Copyright (C) 2006 Maks Orlovich
 *  Copyright (C) 2006, 2007, 2008, 2009 Apple Inc. All rights reserved.
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

#ifndef JSWrapperObject_h
#define JSWrapperObject_h

#include "JSObject.h"

namespace JSC {

    // This class is used as a base for classes such as String,
    // Number, Boolean and Date which are wrappers for primitive types.
    class JSWrapperObject : public JSNonFinalObject {
    public:
        typedef JSNonFinalObject Base;

        JSValue internalValue() const;
        void setInternalValue(JSGlobalData&, JSValue);

        static Structure* createStructure(JSGlobalData& globalData, JSGlobalObject* globalObject, JSValue prototype) 
        { 
            return Structure::create(globalData, globalObject, prototype, TypeInfo(ObjectType, StructureFlags), &s_info);
        }

    protected:
        explicit JSWrapperObject(JSGlobalData&, Structure*);
        static const unsigned StructureFlags = OverridesVisitChildren | JSNonFinalObject::StructureFlags;

        static void visitChildren(JSCell*, SlotVisitor&);

    private:
        WriteBarrier<Unknown> m_internalValue;
    };

    inline JSWrapperObject::JSWrapperObject(JSGlobalData& globalData, Structure* structure)
        : JSNonFinalObject(globalData, structure)
    {
    }

    inline JSValue JSWrapperObject::internalValue() const
    {
        return m_internalValue.get();
    }

    inline void JSWrapperObject::setInternalValue(JSGlobalData& globalData, JSValue value)
    {
        ASSERT(value);
        ASSERT(!value.isObject());
        m_internalValue.set(globalData, this, value);
    }

} // namespace JSC

#endif // JSWrapperObject_h
