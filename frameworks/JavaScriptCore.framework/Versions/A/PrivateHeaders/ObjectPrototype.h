/*
 *  Copyright (C) 1999-2000 Harri Porten (porten@kde.org)
 *  Copyright (C) 2008, 2011 Apple Inc. All rights reserved.
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

#ifndef ObjectPrototype_h
#define ObjectPrototype_h

#include "JSObject.h"

namespace JSC {

    class ObjectPrototype : public JSNonFinalObject {
    public:
        typedef JSNonFinalObject Base;

        static ObjectPrototype* create(ExecState* exec, JSGlobalObject* globalObject, Structure* structure)
        {
            ObjectPrototype* prototype = new (NotNull, allocateCell<ObjectPrototype>(*exec->heap())) ObjectPrototype(exec, structure);
            prototype->finishCreation(exec->globalData(), globalObject);
            return prototype;
        }

        static const ClassInfo s_info;

        static Structure* createStructure(JSGlobalData& globalData, JSGlobalObject* globalObject, JSValue prototype)
        {
            return Structure::create(globalData, globalObject, prototype, TypeInfo(ObjectType, StructureFlags), &s_info);
        }

    protected:
        static const unsigned StructureFlags = OverridesGetOwnPropertySlot | JSNonFinalObject::StructureFlags;

        void finishCreation(JSGlobalData&, JSGlobalObject*);

    private:
        ObjectPrototype(ExecState*, Structure*);
        static void put(JSCell*, ExecState*, const Identifier&, JSValue, PutPropertySlot&);

        static bool getOwnPropertySlot(JSCell*, ExecState*, const Identifier&, PropertySlot&);
        static bool getOwnPropertySlotByIndex(JSCell*, ExecState*, unsigned propertyName, PropertySlot&);
        static bool getOwnPropertyDescriptor(JSObject*, ExecState*, const Identifier&, PropertyDescriptor&);

        bool m_hasNoPropertiesWithUInt32Names;
    };

    JS_EXPORT_PRIVATE EncodedJSValue JSC_HOST_CALL objectProtoFuncToString(ExecState*);

} // namespace JSC

#endif // ObjectPrototype_h
