/*
 * Copyright (C) 2007, 2008 Apple Inc. All rights reserved.
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

#ifndef JSVariableObject_h
#define JSVariableObject_h

#include "JSObject.h"
#include "Register.h"
#include "SymbolTable.h"
#include "UnusedParam.h"
#include <wtf/OwnArrayPtr.h>
#include <wtf/UnusedParam.h>

namespace JSC {

    class Register;

    class JSVariableObject : public JSNonFinalObject {
        friend class JIT;

    public:
        typedef JSNonFinalObject Base;

        SymbolTable& symbolTable() const { return *m_symbolTable; }

        JS_EXPORT_PRIVATE static void destroy(JSCell*);

        static NO_RETURN_DUE_TO_ASSERT void putDirectVirtual(JSObject*, ExecState*, const Identifier&, JSValue, unsigned attributes);

        JS_EXPORT_PRIVATE static bool deleteProperty(JSCell*, ExecState*, const Identifier&);
        JS_EXPORT_PRIVATE static void getOwnPropertyNames(JSObject*, ExecState*, PropertyNameArray&, EnumerationMode);
        
        bool isDynamicScope(bool& requiresDynamicChecks) const;

        WriteBarrier<Unknown>& registerAt(int index) const { return m_registers[index]; }

        WriteBarrier<Unknown>* const * addressOfRegisters() const { return &m_registers; }
        static size_t offsetOfRegisters() { return OBJECT_OFFSETOF(JSVariableObject, m_registers); }

        static Structure* createStructure(JSGlobalData& globalData, JSGlobalObject* globalObject, JSValue prototype)
        {
            return Structure::create(globalData, globalObject, prototype, TypeInfo(VariableObjectType, StructureFlags), &s_info);
        }
        
    protected:
        static const unsigned StructureFlags = OverridesGetPropertyNames | JSNonFinalObject::StructureFlags;

        JSVariableObject(JSGlobalData& globalData, Structure* structure, SymbolTable* symbolTable, Register* registers)
            : JSNonFinalObject(globalData, structure)
            , m_symbolTable(symbolTable)
            , m_registers(reinterpret_cast<WriteBarrier<Unknown>*>(registers))
        {
        }

        void finishCreation(JSGlobalData& globalData)
        {
            Base::finishCreation(globalData);
            ASSERT(m_symbolTable);
            COMPILE_ASSERT(sizeof(WriteBarrier<Unknown>) == sizeof(Register), Register_should_be_same_size_as_WriteBarrier);
        }

        PassOwnArrayPtr<WriteBarrier<Unknown> > copyRegisterArray(JSGlobalData&, WriteBarrier<Unknown>* src, size_t count, size_t callframeStarts);
        void setRegisters(WriteBarrier<Unknown>* registers, PassOwnArrayPtr<WriteBarrier<Unknown> > registerArray);

        bool symbolTableGet(const Identifier&, PropertySlot&);
        JS_EXPORT_PRIVATE bool symbolTableGet(const Identifier&, PropertyDescriptor&);
        bool symbolTableGet(const Identifier&, PropertySlot&, bool& slotIsWriteable);
        bool symbolTablePut(ExecState*, const Identifier&, JSValue, bool shouldThrow);
        bool symbolTablePutWithAttributes(JSGlobalData&, const Identifier&, JSValue, unsigned attributes);

        SymbolTable* m_symbolTable; // Maps name -> offset from "r" in register file.
        WriteBarrier<Unknown>* m_registers; // "r" in the register file.
        OwnArrayPtr<WriteBarrier<Unknown> > m_registerArray; // Independent copy of registers, used when a variable object copies its registers out of the register file.
    };

    inline bool JSVariableObject::symbolTableGet(const Identifier& propertyName, PropertySlot& slot)
    {
        SymbolTableEntry entry = symbolTable().inlineGet(propertyName.impl());
        if (!entry.isNull()) {
            slot.setValue(registerAt(entry.getIndex()).get());
            return true;
        }
        return false;
    }

    inline bool JSVariableObject::symbolTableGet(const Identifier& propertyName, PropertySlot& slot, bool& slotIsWriteable)
    {
        SymbolTableEntry entry = symbolTable().inlineGet(propertyName.impl());
        if (!entry.isNull()) {
            slot.setValue(registerAt(entry.getIndex()).get());
            slotIsWriteable = !entry.isReadOnly();
            return true;
        }
        return false;
    }

    inline bool JSVariableObject::symbolTablePut(ExecState* exec, const Identifier& propertyName, JSValue value, bool shouldThrow)
    {
        JSGlobalData& globalData = exec->globalData();
        ASSERT(!Heap::heap(value) || Heap::heap(value) == Heap::heap(this));

        SymbolTableEntry entry = symbolTable().inlineGet(propertyName.impl());
        if (entry.isNull())
            return false;
        if (entry.isReadOnly()) {
            if (shouldThrow)
                throwTypeError(exec, StrictModeReadonlyPropertyWriteError);
            return true;
        }
        registerAt(entry.getIndex()).set(globalData, this, value);
        return true;
    }

    inline bool JSVariableObject::symbolTablePutWithAttributes(JSGlobalData& globalData, const Identifier& propertyName, JSValue value, unsigned attributes)
    {
        ASSERT(!Heap::heap(value) || Heap::heap(value) == Heap::heap(this));

        SymbolTable::iterator iter = symbolTable().find(propertyName.impl());
        if (iter == symbolTable().end())
            return false;
        SymbolTableEntry& entry = iter->second;
        ASSERT(!entry.isNull());
        entry.setAttributes(attributes);
        registerAt(entry.getIndex()).set(globalData, this, value);
        return true;
    }

    inline PassOwnArrayPtr<WriteBarrier<Unknown> > JSVariableObject::copyRegisterArray(JSGlobalData& globalData, WriteBarrier<Unknown>* src, size_t count, size_t callframeStarts)
    {
        OwnArrayPtr<WriteBarrier<Unknown> > registerArray = adoptArrayPtr(new WriteBarrier<Unknown>[count]);
        for (size_t i = 0; i < callframeStarts; i++)
            registerArray[i].set(globalData, this, src[i].get());
        for (size_t i = callframeStarts + RegisterFile::CallFrameHeaderSize; i < count; i++)
            registerArray[i].set(globalData, this, src[i].get());

        return registerArray.release();
    }

    inline void JSVariableObject::setRegisters(WriteBarrier<Unknown>* registers, PassOwnArrayPtr<WriteBarrier<Unknown> > registerArray)
    {
        ASSERT(registerArray != m_registerArray);
        m_registerArray = registerArray;
        m_registers = registers;
    }

} // namespace JSC

#endif // JSVariableObject_h
