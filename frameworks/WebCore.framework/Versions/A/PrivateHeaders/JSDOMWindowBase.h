/*
 *  Copyright (C) 2000 Harri Porten (porten@kde.org)
 *  Copyright (C) 2003, 2004, 2005, 2006, 2007, 2008 Apple Inc. All rights reseved.
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
 */

#ifndef JSDOMWindowBase_h
#define JSDOMWindowBase_h

#include "JSDOMBinding.h"
#include "JSDOMGlobalObject.h"
#include <wtf/Forward.h>

namespace WebCore {

    class DOMWindow;
    class Frame;
    class DOMWrapperWorld;
    class JSDOMWindow;
    class JSDOMWindowShell;

    class JSDOMWindowBasePrivate;

    class JSDOMWindowBase : public JSDOMGlobalObject {
        typedef JSDOMGlobalObject Base;
    protected:
        JSDOMWindowBase(JSC::JSGlobalData&, JSC::Structure*, PassRefPtr<DOMWindow>, JSDOMWindowShell*);
        void finishCreation(JSC::JSGlobalData&, JSDOMWindowShell*);

        static void destroy(JSCell*);

    public:
        void updateDocument();

        DOMWindow* impl() const { return m_impl.get(); }
        ScriptExecutionContext* scriptExecutionContext() const;

        // Called just before removing this window from the JSDOMWindowShell.
        void willRemoveFromWindowShell();

        static const JSC::ClassInfo s_info;

        static JSC::Structure* createStructure(JSC::JSGlobalData& globalData, JSC::JSValue prototype)
        {
            return JSC::Structure::create(globalData, 0, prototype, JSC::TypeInfo(JSC::GlobalObjectType, StructureFlags), &s_info);
        }

        static const JSC::GlobalObjectMethodTable s_globalObjectMethodTable;

        static bool supportsProfiling(const JSC::JSGlobalObject*);
        static bool supportsRichSourceInfo(const JSC::JSGlobalObject*);
        static bool shouldInterruptScript(const JSC::JSGlobalObject*);

        bool allowsAccessFrom(JSC::ExecState*) const;
        bool allowsAccessFromNoErrorMessage(JSC::ExecState*) const;
        bool allowsAccessFrom(JSC::ExecState*, String& message) const;
        void printErrorMessage(const String&) const;

        // Don't call this version of allowsAccessFrom -- it's a slightly incorrect implementation used only by WebScriptObject
        bool allowsAccessFrom(const JSC::JSGlobalObject*) const;
        
        static JSC::JSObject* toThisObject(JSC::JSCell*, JSC::ExecState*);
        JSDOMWindowShell* shell() const;

        static JSC::JSGlobalData* commonJSGlobalData();

    private:
        RefPtr<DOMWindow> m_impl;
        JSDOMWindowShell* m_shell;

        bool allowsAccessFromPrivate(const JSC::JSGlobalObject*) const;
        String crossDomainAccessErrorMessage(const JSC::JSGlobalObject*) const;
    };

    // Returns a JSDOMWindow or jsNull()
    // JSDOMGlobalObject* is ignored, accessing a window in any context will
    // use that DOMWindow's prototype chain.
    JSC::JSValue toJS(JSC::ExecState*, JSDOMGlobalObject*, DOMWindow*);
    JSC::JSValue toJS(JSC::ExecState*, DOMWindow*);

    // Returns JSDOMWindow or 0
    JSDOMWindow* toJSDOMWindow(Frame*, DOMWrapperWorld*);
    JSDOMWindow* toJSDOMWindow(JSC::JSValue);

} // namespace WebCore

#endif // JSDOMWindowBase_h
