/*
 *  Copyright (C) 1999-2000 Harri Porten (porten@kde.org)
 *  Copyright (C) 2003, 2007, 2008 Apple Inc. All Rights Reserved.
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

#ifndef RegExpObject_h
#define RegExpObject_h

#include "JSObject.h"
#include "RegExp.h"

namespace JSC {
    
    class RegExpObject : public JSNonFinalObject {
    public:
        typedef JSNonFinalObject Base;

        static RegExpObject* create(ExecState* exec, JSGlobalObject* globalObject, Structure* structure, RegExp* regExp)
        {
            RegExpObject* object = new (NotNull, allocateCell<RegExpObject>(*exec->heap())) RegExpObject(globalObject, structure, regExp);
            object->finishCreation(globalObject);
            return object;
        }
        
        static RegExpObject* create(JSGlobalData& globalData, JSGlobalObject* globalObject, Structure* structure, RegExp* regExp)
        {
            RegExpObject* object = new (NotNull, allocateCell<RegExpObject>(globalData.heap)) RegExpObject(globalObject, structure, regExp);
            object->finishCreation(globalObject);
            return object;
        }

        void setRegExp(JSGlobalData& globalData, RegExp* r) { d->regExp.set(globalData, this, r); }
        RegExp* regExp() const { return d->regExp.get(); }

        void setLastIndex(size_t lastIndex)
        {
            d->lastIndex.setWithoutWriteBarrier(jsNumber(lastIndex));
        }
        void setLastIndex(JSGlobalData& globalData, JSValue lastIndex)
        {
            d->lastIndex.set(globalData, this, lastIndex);
        }
        JSValue getLastIndex() const
        {
            return d->lastIndex.get();
        }

        JSValue test(ExecState*);
        JSValue exec(ExecState*);

        static bool getOwnPropertySlot(JSCell*, ExecState*, const Identifier& propertyName, PropertySlot&);
        static bool getOwnPropertyDescriptor(JSObject*, ExecState*, const Identifier&, PropertyDescriptor&);
        static void put(JSCell*, ExecState*, const Identifier& propertyName, JSValue, PutPropertySlot&);

        static JS_EXPORTDATA const ClassInfo s_info;

        static Structure* createStructure(JSGlobalData& globalData, JSGlobalObject* globalObject, JSValue prototype)
        {
            return Structure::create(globalData, globalObject, prototype, TypeInfo(ObjectType, StructureFlags), &s_info);
        }

    protected:
        JS_EXPORT_PRIVATE RegExpObject(JSGlobalObject*, Structure*, RegExp*);
        JS_EXPORT_PRIVATE void finishCreation(JSGlobalObject*);
        static void destroy(JSCell*);

        static const unsigned StructureFlags = OverridesVisitChildren | OverridesGetOwnPropertySlot | Base::StructureFlags;

        static void visitChildren(JSCell*, SlotVisitor&);

    private:
        bool match(ExecState*);

        struct RegExpObjectData {
            WTF_MAKE_FAST_ALLOCATED;
        public:
            RegExpObjectData(JSGlobalData& globalData, RegExpObject* owner, RegExp* regExp)
                : regExp(globalData, owner, regExp)
            {
                lastIndex.setWithoutWriteBarrier(jsNumber(0));
            }

            WriteBarrier<RegExp> regExp;
            WriteBarrier<Unknown> lastIndex;
        };
#if COMPILER(MSVC)
        friend void WTF::deleteOwnedPtr<RegExpObjectData>(RegExpObjectData*);
#endif
        OwnPtr<RegExpObjectData> d;
    };

    RegExpObject* asRegExpObject(JSValue);

    inline RegExpObject* asRegExpObject(JSValue value)
    {
        ASSERT(asObject(value)->inherits(&RegExpObject::s_info));
        return static_cast<RegExpObject*>(asObject(value));
    }

} // namespace JSC

#endif // RegExpObject_h
