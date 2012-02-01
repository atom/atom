/*
 * Copyright (C) 2011 Apple Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 */

#ifndef ValueRecovery_h
#define ValueRecovery_h

#include "DataFormat.h"
#include "JSValue.h"
#include "MacroAssembler.h"
#include "VirtualRegister.h"
#include <wtf/Platform.h>

#ifndef NDEBUG
#include <stdio.h>
#endif

namespace JSC {

// Describes how to recover a given bytecode virtual register at a given
// code point.
enum ValueRecoveryTechnique {
    // It's already in the register file at the right location.
    AlreadyInRegisterFile,
    // It's already in the register file but unboxed.
    AlreadyInRegisterFileAsUnboxedInt32,
    AlreadyInRegisterFileAsUnboxedCell,
    AlreadyInRegisterFileAsUnboxedBoolean,
    AlreadyInRegisterFileAsUnboxedDouble,
    // It's in a register.
    InGPR,
    UnboxedInt32InGPR,
    UnboxedBooleanInGPR,
#if USE(JSVALUE32_64)
    InPair,
#endif
    InFPR,
    UInt32InGPR,
    // It's in the register file, but at a different location.
    DisplacedInRegisterFile,
    // It's in the register file, at a different location, and it's unboxed.
    Int32DisplacedInRegisterFile,
    DoubleDisplacedInRegisterFile,
    CellDisplacedInRegisterFile,
    BooleanDisplacedInRegisterFile,
    // It's a constant.
    Constant,
    // Don't know how to recover it.
    DontKnow
};

class ValueRecovery {
public:
    ValueRecovery()
        : m_technique(DontKnow)
    {
    }
    
    static ValueRecovery alreadyInRegisterFile()
    {
        ValueRecovery result;
        result.m_technique = AlreadyInRegisterFile;
        return result;
    }
    
    static ValueRecovery alreadyInRegisterFileAsUnboxedInt32()
    {
        ValueRecovery result;
        result.m_technique = AlreadyInRegisterFileAsUnboxedInt32;
        return result;
    }
    
    static ValueRecovery alreadyInRegisterFileAsUnboxedCell()
    {
        ValueRecovery result;
        result.m_technique = AlreadyInRegisterFileAsUnboxedCell;
        return result;
    }
    
    static ValueRecovery alreadyInRegisterFileAsUnboxedBoolean()
    {
        ValueRecovery result;
        result.m_technique = AlreadyInRegisterFileAsUnboxedBoolean;
        return result;
    }
    
    static ValueRecovery alreadyInRegisterFileAsUnboxedDouble()
    {
        ValueRecovery result;
        result.m_technique = AlreadyInRegisterFileAsUnboxedDouble;
        return result;
    }
    
    static ValueRecovery inGPR(MacroAssembler::RegisterID gpr, DataFormat dataFormat)
    {
        ASSERT(dataFormat != DataFormatNone);
#if USE(JSVALUE32_64)
        ASSERT(dataFormat == DataFormatInteger || dataFormat == DataFormatCell || dataFormat == DataFormatBoolean);
#endif
        ValueRecovery result;
        if (dataFormat == DataFormatInteger)
            result.m_technique = UnboxedInt32InGPR;
        else if (dataFormat == DataFormatBoolean)
            result.m_technique = UnboxedBooleanInGPR;
        else
            result.m_technique = InGPR;
        result.m_source.gpr = gpr;
        return result;
    }
    
    static ValueRecovery uint32InGPR(MacroAssembler::RegisterID gpr)
    {
        ValueRecovery result;
        result.m_technique = UInt32InGPR;
        result.m_source.gpr = gpr;
        return result;
    }
    
#if USE(JSVALUE32_64)
    static ValueRecovery inPair(MacroAssembler::RegisterID tagGPR, MacroAssembler::RegisterID payloadGPR)
    {
        ValueRecovery result;
        result.m_technique = InPair;
        result.m_source.pair.tagGPR = tagGPR;
        result.m_source.pair.payloadGPR = payloadGPR;
        return result;
    }
#endif

    static ValueRecovery inFPR(MacroAssembler::FPRegisterID fpr)
    {
        ValueRecovery result;
        result.m_technique = InFPR;
        result.m_source.fpr = fpr;
        return result;
    }
    
    static ValueRecovery displacedInRegisterFile(VirtualRegister virtualReg, DataFormat dataFormat)
    {
        ValueRecovery result;
        switch (dataFormat) {
        case DataFormatInteger:
            result.m_technique = Int32DisplacedInRegisterFile;
            break;
            
        case DataFormatDouble:
            result.m_technique = DoubleDisplacedInRegisterFile;
            break;

        case DataFormatCell:
            result.m_technique = CellDisplacedInRegisterFile;
            break;
            
        case DataFormatBoolean:
            result.m_technique = BooleanDisplacedInRegisterFile;
            break;
            
        default:
            ASSERT(dataFormat != DataFormatNone && dataFormat != DataFormatStorage);
            result.m_technique = DisplacedInRegisterFile;
            break;
        }
        result.m_source.virtualReg = virtualReg;
        return result;
    }
    
    static ValueRecovery constant(JSValue value)
    {
        ValueRecovery result;
        result.m_technique = Constant;
        result.m_source.constant = JSValue::encode(value);
        return result;
    }
    
    ValueRecoveryTechnique technique() const { return m_technique; }
    
    bool isInRegisters() const
    {
        switch (m_technique) {
        case InGPR:
        case UnboxedInt32InGPR:
        case UnboxedBooleanInGPR:
#if USE(JSVALUE32_64)
        case InPair:
#endif
        case InFPR:
            return true;
        default:
            return false;
        }
    }
    
    MacroAssembler::RegisterID gpr() const
    {
        ASSERT(m_technique == InGPR || m_technique == UnboxedInt32InGPR || m_technique == UnboxedBooleanInGPR || m_technique == UInt32InGPR);
        return m_source.gpr;
    }
    
#if USE(JSVALUE32_64)
    MacroAssembler::RegisterID tagGPR() const
    {
        ASSERT(m_technique == InPair);
        return m_source.pair.tagGPR;
    }
    
    MacroAssembler::RegisterID payloadGPR() const
    {
        ASSERT(m_technique == InPair);
        return m_source.pair.payloadGPR;
    }
#endif
    
    MacroAssembler::FPRegisterID fpr() const
    {
        ASSERT(m_technique == InFPR);
        return m_source.fpr;
    }
    
    VirtualRegister virtualRegister() const
    {
        ASSERT(m_technique == DisplacedInRegisterFile || m_technique == Int32DisplacedInRegisterFile || m_technique == DoubleDisplacedInRegisterFile || m_technique == CellDisplacedInRegisterFile || m_technique == BooleanDisplacedInRegisterFile);
        return m_source.virtualReg;
    }
    
    JSValue constant() const
    {
        ASSERT(m_technique == Constant);
        return JSValue::decode(m_source.constant);
    }
    
#ifndef NDEBUG
    void dump(FILE* out) const
    {
        switch (technique()) {
        case AlreadyInRegisterFile:
            fprintf(out, "-");
            break;
        case AlreadyInRegisterFileAsUnboxedInt32:
            fprintf(out, "(int32)");
            break;
        case AlreadyInRegisterFileAsUnboxedCell:
            fprintf(out, "(cell)");
            break;
        case AlreadyInRegisterFileAsUnboxedBoolean:
            fprintf(out, "(bool)");
            break;
        case AlreadyInRegisterFileAsUnboxedDouble:
            fprintf(out, "(double)");
            break;
        case InGPR:
            fprintf(out, "%%r%d", gpr());
            break;
        case UnboxedInt32InGPR:
            fprintf(out, "int32(%%r%d)", gpr());
            break;
        case UnboxedBooleanInGPR:
            fprintf(out, "bool(%%r%d)", gpr());
            break;
        case UInt32InGPR:
            fprintf(out, "uint32(%%r%d)", gpr());
            break;
        case InFPR:
            fprintf(out, "%%fr%d", fpr());
            break;
#if USE(JSVALUE32_64)
        case InPair:
            fprintf(out, "pair(%%r%d, %%r%d)", tagGPR(), payloadGPR());
            break;
#endif
        case DisplacedInRegisterFile:
            fprintf(out, "*%d", virtualRegister());
            break;
        case Int32DisplacedInRegisterFile:
            fprintf(out, "*int32(%d)", virtualRegister());
            break;
        case DoubleDisplacedInRegisterFile:
            fprintf(out, "*double(%d)", virtualRegister());
            break;
        case CellDisplacedInRegisterFile:
            fprintf(out, "*cell(%d)", virtualRegister());
            break;
        case BooleanDisplacedInRegisterFile:
            fprintf(out, "*bool(%d)", virtualRegister());
            break;
        case Constant:
            fprintf(out, "[%s]", constant().description());
            break;
        case DontKnow:
            fprintf(out, "!");
            break;
        default:
            fprintf(out, "?%d", technique());
            break;
        }
    }
#endif
    
private:
    ValueRecoveryTechnique m_technique;
    union {
        MacroAssembler::RegisterID gpr;
        MacroAssembler::FPRegisterID fpr;
#if USE(JSVALUE32_64)
        struct {
            MacroAssembler::RegisterID tagGPR;
            MacroAssembler::RegisterID payloadGPR;
        } pair;
#endif
        VirtualRegister virtualReg;
        EncodedJSValue constant;
    } m_source;
};

} // namespace JSC

#endif // ValueRecovery_h
