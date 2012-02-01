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

#ifndef FunctionConstructor_h
#define FunctionConstructor_h

#include "InternalFunction.h"

namespace WTF {
class TextPosition;
}

namespace JSC {

    class FunctionPrototype;

    class FunctionConstructor : public InternalFunction {
    public:
        typedef InternalFunction Base;

        static FunctionConstructor* create(ExecState* exec, JSGlobalObject* globalObject, Structure* structure, FunctionPrototype* functionPrototype)
        {
            FunctionConstructor* constructor = new (NotNull, allocateCell<FunctionConstructor>(*exec->heap())) FunctionConstructor(globalObject, structure);
            constructor->finishCreation(exec, functionPrototype);
            return constructor;
        }

        static const ClassInfo s_info;

        static Structure* createStructure(JSGlobalData& globalData, JSGlobalObject* globalObject, JSValue prototype) 
        { 
            return Structure::create(globalData, globalObject, prototype, TypeInfo(ObjectType, StructureFlags), &s_info); 
        }

    private:
        FunctionConstructor(JSGlobalObject*, Structure*);
        void finishCreation(ExecState*, FunctionPrototype*);
        static ConstructType getConstructData(JSCell*, ConstructData&);
        static CallType getCallData(JSCell*, CallData&);
    };

    JSObject* constructFunction(ExecState*, JSGlobalObject*, const ArgList&, const Identifier& functionName, const UString& sourceURL, const WTF::TextPosition&);
    JSObject* constructFunction(ExecState*, JSGlobalObject*, const ArgList&);

    JS_EXPORT_PRIVATE JSObject* constructFunctionSkippingEvalEnabledCheck(ExecState*, JSGlobalObject*, const ArgList&, const Identifier&, const UString&, const WTF::TextPosition&);

} // namespace JSC

#endif // FunctionConstructor_h
