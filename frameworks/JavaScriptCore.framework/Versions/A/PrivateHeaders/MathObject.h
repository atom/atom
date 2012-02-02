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

#ifndef MathObject_h
#define MathObject_h

#include "JSObject.h"

namespace JSC {

    class MathObject : public JSNonFinalObject {
    private:
        MathObject(JSGlobalObject*, Structure*);

    public:
        typedef JSNonFinalObject Base;

        static MathObject* create(ExecState* exec, JSGlobalObject* globalObject, Structure* structure)
        {
            MathObject* object = new (NotNull, allocateCell<MathObject>(*exec->heap())) MathObject(globalObject, structure);
            object->finishCreation(exec, globalObject);
            return object;
        }
        static bool getOwnPropertySlot(JSCell*, ExecState*, const Identifier&, PropertySlot&);
        static bool getOwnPropertyDescriptor(JSObject*, ExecState*, const Identifier&, PropertyDescriptor&);

        static const ClassInfo s_info;

        static Structure* createStructure(JSGlobalData& globalData, JSGlobalObject* globalObject, JSValue prototype)
        {
            return Structure::create(globalData, globalObject, prototype, TypeInfo(ObjectType, StructureFlags), &s_info);
        }

    protected:
        void finishCreation(ExecState*, JSGlobalObject*);
        static const unsigned StructureFlags = OverridesGetOwnPropertySlot | JSObject::StructureFlags;
    };

} // namespace JSC

#endif // MathObject_h
