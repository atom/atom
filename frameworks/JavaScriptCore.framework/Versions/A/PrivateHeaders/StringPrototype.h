/*
 *  Copyright (C) 1999-2000 Harri Porten (porten@kde.org)
 *  Copyright (C) 2007, 2008 Apple Inc. All rights reserved.
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

#ifndef StringPrototype_h
#define StringPrototype_h

#include "StringObject.h"

namespace JSC {

    class ObjectPrototype;

    class StringPrototype : public StringObject {
    private:
        StringPrototype(ExecState*, Structure*);

    public:
        typedef StringObject Base;

        static StringPrototype* create(ExecState* exec, JSGlobalObject* globalObject, Structure* structure)
        {
            JSString* empty = jsEmptyString(exec);
            StringPrototype* prototype = new (NotNull, allocateCell<StringPrototype>(*exec->heap())) StringPrototype(exec, structure);
            prototype->finishCreation(exec, globalObject, empty);
            return prototype;
        }

        static bool getOwnPropertySlot(JSCell*, ExecState*, const Identifier& propertyName, PropertySlot&);
        static bool getOwnPropertyDescriptor(JSObject*, ExecState*, const Identifier&, PropertyDescriptor&);

        static Structure* createStructure(JSGlobalData& globalData, JSGlobalObject* globalObject, JSValue prototype)
        {
            return Structure::create(globalData, globalObject, prototype, TypeInfo(ObjectType, StructureFlags), &s_info);
        }

        static const ClassInfo s_info;
        
    protected:
        void finishCreation(ExecState*, JSGlobalObject*, JSString*);
        static const unsigned StructureFlags = OverridesGetOwnPropertySlot | StringObject::StructureFlags;

    };

} // namespace JSC

#endif // StringPrototype_h
