/*
 * Copyright (C) 2008 Apple Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1.  Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 * 2.  Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 * 3.  Neither the name of Apple Computer, Inc. ("Apple") nor the names of
 *     its contributors may be used to endorse or promote products derived
 *     from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE AND ITS CONTRIBUTORS "AS IS" AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL APPLE OR ITS CONTRIBUTORS BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef JSDOMWindowShell_h
#define JSDOMWindowShell_h

#include "JSDOMWindow.h"
#include <runtime/JSGlobalThis.h>

namespace WebCore {

    class DOMWindow;
    class Frame;

    class JSDOMWindowShell : public JSC::JSGlobalThis {
        typedef JSC::JSGlobalThis Base;
    public:
        JSDOMWindowShell(PassRefPtr<DOMWindow>, JSC::Structure*, DOMWrapperWorld*);
        static void destroy(JSCell*);

        JSDOMWindow* window() const { return static_cast<JSDOMWindow*>(m_unwrappedObject.get()); }
        void setWindow(JSC::JSGlobalData& globalData, JSDOMWindow* window)
        {
            ASSERT_ARG(window, window);
            m_unwrappedObject.set(globalData, this, window);
            setPrototype(globalData, window->prototype());
        }
        void setWindow(PassRefPtr<DOMWindow>);

        static const JSC::ClassInfo s_info;

        DOMWindow* impl() const;

        static JSDOMWindowShell* create(PassRefPtr<DOMWindow> window, JSC::Structure* structure, DOMWrapperWorld* world) 
        {
            JSDOMWindowShell* shell = new JSDOMWindowShell(structure, world);
            shell->finishCreation(*world->globalData(), window);
            return shell; 
        }

        static JSC::Structure* createStructure(JSC::JSGlobalData& globalData, JSC::JSValue prototype) 
        {
            return JSC::Structure::create(globalData, 0, prototype, JSC::TypeInfo(JSC::GlobalThisType, StructureFlags), &s_info); 
        }

        DOMWrapperWorld* world() { return m_world.get(); }

    protected:
        JSDOMWindowShell(JSC::Structure*, DOMWrapperWorld*);
        void finishCreation(JSC::JSGlobalData&, PassRefPtr<DOMWindow>);

    private:
        void* operator new(size_t);
        static const unsigned StructureFlags = JSC::OverridesGetOwnPropertySlot | JSC::OverridesGetPropertyNames | Base::StructureFlags;

        static JSC::UString className(const JSC::JSObject*);
        static bool getOwnPropertySlot(JSC::JSCell*, JSC::ExecState*, const JSC::Identifier& propertyName, JSC::PropertySlot&);
        static bool getOwnPropertyDescriptor(JSC::JSObject*, JSC::ExecState*, const JSC::Identifier& propertyName, JSC::PropertyDescriptor&);
        static void put(JSC::JSCell*, JSC::ExecState*, const JSC::Identifier& propertyName, JSC::JSValue, JSC::PutPropertySlot&);
        static void putDirectVirtual(JSC::JSObject*, JSC::ExecState*, const JSC::Identifier& propertyName, JSC::JSValue, unsigned attributes);
        static bool deleteProperty(JSC::JSCell*, JSC::ExecState*, const JSC::Identifier& propertyName);
        static void getOwnPropertyNames(JSC::JSObject*, JSC::ExecState*, JSC::PropertyNameArray&, JSC::EnumerationMode);
        static void getPropertyNames(JSC::JSObject*, JSC::ExecState*, JSC::PropertyNameArray&, JSC::EnumerationMode);
        static void defineGetter(JSC::JSObject*, JSC::ExecState*, const JSC::Identifier& propertyName, JSC::JSObject* getterFunction, unsigned attributes);
        static void defineSetter(JSC::JSObject*, JSC::ExecState*, const JSC::Identifier& propertyName, JSC::JSObject* setterFunction, unsigned attributes);
        static bool defineOwnProperty(JSC::JSObject*, JSC::ExecState*, const JSC::Identifier& propertyName, JSC::PropertyDescriptor&, bool shouldThrow);

        RefPtr<DOMWrapperWorld> m_world;
    };

    JSC::JSValue toJS(JSC::ExecState*, Frame*);
    JSDOMWindowShell* toJSDOMWindowShell(Frame*, DOMWrapperWorld*);

} // namespace WebCore

#endif // JSDOMWindowShell_h
