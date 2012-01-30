/*
 *  Copyright (C) 1999-2001 Harri Porten (porten@kde.org)
 *  Copyright (C) 2001 Peter Kelly (pmk@post.com)
 *  Copyright (C) 2003, 2004, 2005, 2007, 2008 Apple Inc. All rights reserved.
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

#ifndef JSAPIValueWrapper_h
#define JSAPIValueWrapper_h

#include "JSCell.h"
#include "JSValue.h"
#include "CallFrame.h"
#include "Structure.h"

namespace JSC {

    class JSAPIValueWrapper : public JSCell {
        friend JSValue jsAPIValueWrapper(ExecState*, JSValue);
    public:
        typedef JSCell Base;

        JSValue value() const { return m_value.get(); }

        static Structure* createStructure(JSGlobalData& globalData, JSGlobalObject* globalObject, JSValue prototype)
        {
            return Structure::create(globalData, globalObject, prototype, TypeInfo(APIValueWrapperType, OverridesVisitChildren | OverridesGetPropertyNames), &s_info);
        }
        
        static JS_EXPORTDATA const ClassInfo s_info;
        
        static JSAPIValueWrapper* create(ExecState* exec, JSValue value) 
        {
            JSAPIValueWrapper* wrapper = new (NotNull, allocateCell<JSAPIValueWrapper>(*exec->heap())) JSAPIValueWrapper(exec);
            wrapper->finishCreation(exec, value);
            return wrapper;
        }

    protected:
        void finishCreation(ExecState* exec, JSValue value)
        {
            Base::finishCreation(exec->globalData());
            m_value.set(exec->globalData(), this, value);
            ASSERT(!value.isCell());
        }

    private:
        JSAPIValueWrapper(ExecState* exec)
            : JSCell(exec->globalData(), exec->globalData().apiWrapperStructure.get())
        {
        }

        WriteBarrier<Unknown> m_value;
    };

    inline JSValue jsAPIValueWrapper(ExecState* exec, JSValue value)
    {
        return JSAPIValueWrapper::create(exec, value);
    }

} // namespace JSC

#endif // JSAPIValueWrapper_h
