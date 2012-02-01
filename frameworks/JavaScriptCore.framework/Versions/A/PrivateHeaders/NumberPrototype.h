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

#ifndef NumberPrototype_h
#define NumberPrototype_h

#include "NumberObject.h"

namespace JSC {

    class NumberPrototype : public NumberObject {
    public:
        typedef NumberObject Base;

        static NumberPrototype* create(ExecState* exec, JSGlobalObject* globalObject, Structure* structure)
        {
            NumberPrototype* prototype = new (NotNull, allocateCell<NumberPrototype>(*exec->heap())) NumberPrototype(exec, structure);
            prototype->finishCreation(exec, globalObject);
            return prototype;
        }
        
        static const ClassInfo s_info;

        static Structure* createStructure(JSGlobalData& globalData, JSGlobalObject* globalObject, JSValue prototype)
        {
            return Structure::create(globalData, globalObject, prototype, TypeInfo(NumberObjectType, StructureFlags), &s_info);
        }

    protected:
        void finishCreation(ExecState*, JSGlobalObject*);
        static const unsigned StructureFlags = OverridesGetOwnPropertySlot | NumberObject::StructureFlags;

    private:
        NumberPrototype(ExecState*, Structure*);
        static bool getOwnPropertySlot(JSCell*, ExecState*, const Identifier&, PropertySlot&);
        static bool getOwnPropertyDescriptor(JSObject*, ExecState*, const Identifier&, PropertyDescriptor&);
    };

} // namespace JSC

#endif // NumberPrototype_h
