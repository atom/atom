/*
 *  Copyright (C) 1999-2000 Harri Porten (porten@kde.org)
 *  Copyright (C) 2008 Apple Inc. All rights reserved.
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 2 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 *
 */

#ifndef BooleanObject_h
#define BooleanObject_h

#include "JSWrapperObject.h"

namespace JSC {

    class BooleanObject : public JSWrapperObject {
    protected:
        BooleanObject(JSGlobalData&, Structure*);
        void finishCreation(JSGlobalData&);

    public:
        typedef JSWrapperObject Base;

        static BooleanObject* create(JSGlobalData& globalData, Structure* structure)
        {
            BooleanObject* boolean = new (NotNull, allocateCell<BooleanObject>(globalData.heap)) BooleanObject(globalData, structure);
            boolean->finishCreation(globalData);
            return boolean;
        }
        
        static const ClassInfo s_info;
        
        static Structure* createStructure(JSGlobalData& globalData, JSGlobalObject* globalObject, JSValue prototype)
        {
            return Structure::create(globalData, globalObject, prototype, TypeInfo(ObjectType, StructureFlags), &s_info);
        }
    };

    BooleanObject* asBooleanObject(JSValue);

    inline BooleanObject* asBooleanObject(JSValue value)
    {
        ASSERT(asObject(value)->inherits(&BooleanObject::s_info));
        return static_cast<BooleanObject*>(asObject(value));
    }

} // namespace JSC

#endif // BooleanObject_h
