/*
 *  Copyright (C) 1999-2000 Harri Porten (porten@kde.org)
 *  Copyright (C) 2006, 2008 Apple Inc. All rights reserved.
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

#ifndef FunctionPrototype_h
#define FunctionPrototype_h

#include "InternalFunction.h"

namespace JSC {

    class FunctionPrototype : public InternalFunction {
    public:
        typedef InternalFunction Base;

        static FunctionPrototype* create(ExecState* exec, JSGlobalObject* globalObject, Structure* structure)
        {
            FunctionPrototype* prototype = new (NotNull, allocateCell<FunctionPrototype>(*exec->heap())) FunctionPrototype(globalObject, structure);
            prototype->finishCreation(exec, exec->propertyNames().nullIdentifier);
            return prototype;
        }
        
        void addFunctionProperties(ExecState*, JSGlobalObject*, JSFunction** callFunction, JSFunction** applyFunction);
        
        static Structure* createStructure(JSGlobalData& globalData, JSGlobalObject* globalObject, JSValue proto)
        {
            return Structure::create(globalData, globalObject, proto, TypeInfo(ObjectType, StructureFlags), &s_info);
        }

        static const ClassInfo s_info;

    protected:
        void finishCreation(ExecState*, const Identifier& name);

    private:
        FunctionPrototype(JSGlobalObject*, Structure*);
        static CallType getCallData(JSCell*, CallData&);
    };

} // namespace JSC

#endif // FunctionPrototype_h
