/*
 *  Copyright (C) 1999-2001 Harri Porten (porten@kde.org)
 *  Copyright (C) 2001 Peter Kelly (pmk@post.com)
 *  Copyright (C) 2003, 2004, 2005, 2006, 2007, 2008 Apple Inc. All rights reserved.
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

#ifndef Error_h
#define Error_h

#include "InternalFunction.h"
#include "Interpreter.h"
#include "JSObject.h"
#include <stdint.h>

namespace JSC {

    class ExecState;
    class JSGlobalData;
    class JSGlobalObject;
    class JSObject;
    class SourceCode;
    class Structure;
    class UString;

    // Methods to create a range of internal errors.
    JSObject* createError(JSGlobalObject*, const UString&);
    JSObject* createEvalError(JSGlobalObject*, const UString&);
    JSObject* createRangeError(JSGlobalObject*, const UString&);
    JSObject* createReferenceError(JSGlobalObject*, const UString&);
    JSObject* createSyntaxError(JSGlobalObject*, const UString&);
    JSObject* createTypeError(JSGlobalObject*, const UString&);
    JSObject* createURIError(JSGlobalObject*, const UString&);
    // ExecState wrappers.
    JS_EXPORT_PRIVATE JSObject* createError(ExecState*, const UString&);
    JSObject* createEvalError(ExecState*, const UString&);
    JS_EXPORT_PRIVATE JSObject* createRangeError(ExecState*, const UString&);
    JS_EXPORT_PRIVATE JSObject* createReferenceError(ExecState*, const UString&);
    JS_EXPORT_PRIVATE JSObject* createSyntaxError(ExecState*, const UString&);
    JS_EXPORT_PRIVATE JSObject* createTypeError(ExecState*, const UString&);
    JSObject* createURIError(ExecState*, const UString&);

    // Methods to add 
    bool hasErrorInfo(ExecState*, JSObject* error);
    JSObject* addErrorInfo(JSGlobalData*, JSObject* error, int line, const SourceCode&, const Vector<StackFrame>&);
    // ExecState wrappers.
    JSObject* addErrorInfo(ExecState*, JSObject* error, int line, const SourceCode&, const Vector<StackFrame>&);

    // Methods to throw Errors.
    JS_EXPORT_PRIVATE JSValue throwError(ExecState*, JSValue);
    JS_EXPORT_PRIVATE JSObject* throwError(ExecState*, JSObject*);

    // Convenience wrappers, create an throw an exception with a default message.
    JS_EXPORT_PRIVATE JSObject* throwTypeError(ExecState*);
    JS_EXPORT_PRIVATE JSObject* throwSyntaxError(ExecState*);

    // Convenience wrappers, wrap result as an EncodedJSValue.
    inline EncodedJSValue throwVMError(ExecState* exec, JSValue error) { return JSValue::encode(throwError(exec, error)); }
    inline EncodedJSValue throwVMTypeError(ExecState* exec) { return JSValue::encode(throwTypeError(exec)); }

    class StrictModeTypeErrorFunction : public InternalFunction {
    private:
        StrictModeTypeErrorFunction(JSGlobalObject* globalObject, Structure* structure, const UString& message)
            : InternalFunction(globalObject, structure)
            , m_message(message)
        {
        }

        static void destroy(JSCell*);

    public:
        typedef InternalFunction Base;

        static StrictModeTypeErrorFunction* create(ExecState* exec, JSGlobalObject* globalObject, Structure* structure, const UString& message)
        {
            StrictModeTypeErrorFunction* function = new (NotNull, allocateCell<StrictModeTypeErrorFunction>(*exec->heap())) StrictModeTypeErrorFunction(globalObject, structure, message);
            function->finishCreation(exec->globalData(), exec->globalData().propertyNames->emptyIdentifier);
            return function;
        }
    
        static EncodedJSValue JSC_HOST_CALL constructThrowTypeError(ExecState* exec)
        {
            throwTypeError(exec, static_cast<StrictModeTypeErrorFunction*>(exec->callee())->m_message);
            return JSValue::encode(jsNull());
        }
    
        static ConstructType getConstructData(JSCell*, ConstructData& constructData)
        {
            constructData.native.function = constructThrowTypeError;
            return ConstructTypeHost;
        }
    
        static EncodedJSValue JSC_HOST_CALL callThrowTypeError(ExecState* exec)
        {
            throwTypeError(exec, static_cast<StrictModeTypeErrorFunction*>(exec->callee())->m_message);
            return JSValue::encode(jsNull());
        }

        static CallType getCallData(JSCell*, CallData& callData)
        {
            callData.native.function = callThrowTypeError;
            return CallTypeHost;
        }

        static const ClassInfo s_info;

        static Structure* createStructure(JSGlobalData& globalData, JSGlobalObject* globalObject, JSValue prototype) 
        { 
            return Structure::create(globalData, globalObject, prototype, TypeInfo(ObjectType, StructureFlags), &s_info); 
        }

    private:
        UString m_message;
    };

} // namespace JSC

#endif // Error_h
