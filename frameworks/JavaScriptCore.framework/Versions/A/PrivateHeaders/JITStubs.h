/*
 * Copyright (C) 2008 Apple Inc. All rights reserved.
 * Copyright (C) Research In Motion Limited 2010. All rights reserved.
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

#ifndef JITStubs_h
#define JITStubs_h

#include "CallData.h"
#include "Intrinsic.h"
#include "MacroAssemblerCodeRef.h"
#include "Register.h"
#include "ThunkGenerators.h"
#include <wtf/HashMap.h>

#if ENABLE(JIT)

namespace JSC {

    struct StructureStubInfo;

    class CodeBlock;
    class ExecutablePool;
    class FunctionExecutable;
    class Identifier;
    class JSGlobalData;
    class JSGlobalObject;
    class JSObject;
    class JSPropertyNameIterator;
    class JSValue;
    class JSValueEncodedAsPointer;
    class NativeExecutable;
    class Profiler;
    class PropertySlot;
    class PutPropertySlot;
    class RegisterFile;
    class RegExp;

    template <typename T> class Weak;

    union JITStubArg {
        void* asPointer;
        EncodedJSValue asEncodedJSValue;
        int32_t asInt32;

        JSValue jsValue() { return JSValue::decode(asEncodedJSValue); }
        JSObject* jsObject() { return static_cast<JSObject*>(asPointer); }
        Register* reg() { return static_cast<Register*>(asPointer); }
        Identifier& identifier() { return *static_cast<Identifier*>(asPointer); }
        int32_t int32() { return asInt32; }
        CodeBlock* codeBlock() { return static_cast<CodeBlock*>(asPointer); }
        FunctionExecutable* function() { return static_cast<FunctionExecutable*>(asPointer); }
        RegExp* regExp() { return static_cast<RegExp*>(asPointer); }
        JSPropertyNameIterator* propertyNameIterator() { return static_cast<JSPropertyNameIterator*>(asPointer); }
        JSGlobalObject* globalObject() { return static_cast<JSGlobalObject*>(asPointer); }
        JSString* jsString() { return static_cast<JSString*>(asPointer); }
        ReturnAddressPtr returnAddress() { return ReturnAddressPtr(asPointer); }
    };
    
    struct TrampolineStructure {
        MacroAssemblerCodePtr ctiStringLengthTrampoline;
        MacroAssemblerCodePtr ctiVirtualCallLink;
        MacroAssemblerCodePtr ctiVirtualConstructLink;
        MacroAssemblerCodePtr ctiVirtualCall;
        MacroAssemblerCodePtr ctiVirtualConstruct;
        MacroAssemblerCodePtr ctiNativeCall;
        MacroAssemblerCodePtr ctiNativeConstruct;
        MacroAssemblerCodePtr ctiSoftModulo;
    };

#if CPU(X86_64)
    struct JITStackFrame {
        void* reserved; // Unused
        JITStubArg args[6];
        void* padding[2]; // Maintain 32-byte stack alignment (possibly overkill).

        void* code;
        RegisterFile* registerFile;
        CallFrame* callFrame;
        void* unused1;
        Profiler** enabledProfilerReference;
        JSGlobalData* globalData;

        void* savedRBX;
        void* savedR15;
        void* savedR14;
        void* savedR13;
        void* savedR12;
        void* savedRBP;
        void* savedRIP;

        // When JIT code makes a call, it pushes its return address just below the rest of the stack.
        ReturnAddressPtr* returnAddressSlot() { return reinterpret_cast<ReturnAddressPtr*>(this) - 1; }
    };
#elif CPU(X86)
#if COMPILER(MSVC) || (OS(WINDOWS) && COMPILER(GCC))
#pragma pack(push)
#pragma pack(4)
#endif // COMPILER(MSVC) || (OS(WINDOWS) && COMPILER(GCC))
    struct JITStackFrame {
        void* reserved; // Unused
        JITStubArg args[6];
#if USE(JSVALUE32_64)
        void* padding[2]; // Maintain 16-byte stack alignment.
#endif

        void* savedEBX;
        void* savedEDI;
        void* savedESI;
        void* savedEBP;
        void* savedEIP;

        void* code;
        RegisterFile* registerFile;
        CallFrame* callFrame;
        void* unused1;
        Profiler** enabledProfilerReference;
        JSGlobalData* globalData;
        
        // When JIT code makes a call, it pushes its return address just below the rest of the stack.
        ReturnAddressPtr* returnAddressSlot() { return reinterpret_cast<ReturnAddressPtr*>(this) - 1; }
    };
#if COMPILER(MSVC) || (OS(WINDOWS) && COMPILER(GCC))
#pragma pack(pop)
#endif // COMPILER(MSVC) || (OS(WINDOWS) && COMPILER(GCC))
#elif CPU(ARM_THUMB2)
    struct JITStackFrame {
        JITStubArg reserved; // Unused
        JITStubArg args[6];

        ReturnAddressPtr thunkReturnAddress;

        void* preservedReturnAddress;
        void* preservedR4;
        void* preservedR5;
        void* preservedR6;
        void* preservedR7;
        void* preservedR8;
        void* preservedR9;
        void* preservedR10;
        void* preservedR11;

        // These arguments passed in r1..r3 (r0 contained the entry code pointed, which is not preserved)
        RegisterFile* registerFile;
        CallFrame* callFrame;

        // These arguments passed on the stack.
        Profiler** enabledProfilerReference;
        JSGlobalData* globalData;
        
        ReturnAddressPtr* returnAddressSlot() { return &thunkReturnAddress; }
    };
#elif CPU(ARM_TRADITIONAL)
#if COMPILER(MSVC)
#pragma pack(push)
#pragma pack(4)
#endif // COMPILER(MSVC)
    struct JITStackFrame {
        JITStubArg padding; // Unused
        JITStubArg args[7];

        ReturnAddressPtr thunkReturnAddress;

        void* preservedR4;
        void* preservedR5;
        void* preservedR6;
        void* preservedR7;
        void* preservedR8;
        void* preservedLink;

        RegisterFile* registerFile;
        CallFrame* callFrame;
        void* unused1;

        // These arguments passed on the stack.
        Profiler** enabledProfilerReference;
        JSGlobalData* globalData;

        // When JIT code makes a call, it pushes its return address just below the rest of the stack.
        ReturnAddressPtr* returnAddressSlot() { return &thunkReturnAddress; }
    };
#if COMPILER(MSVC)
#pragma pack(pop)
#endif // COMPILER(MSVC)
#elif CPU(MIPS)
    struct JITStackFrame {
        JITStubArg reserved; // Unused
        JITStubArg args[6];

#if USE(JSVALUE32_64)
        void* padding; // Make the overall stack length 8-byte aligned.
#endif

        void* preservedGP; // store GP when using PIC code
        void* preservedS0;
        void* preservedS1;
        void* preservedS2;
        void* preservedReturnAddress;

        ReturnAddressPtr thunkReturnAddress;

        // These arguments passed in a1..a3 (a0 contained the entry code pointed, which is not preserved)
        RegisterFile* registerFile;
        CallFrame* callFrame;
        void* unused1;

        // These arguments passed on the stack.
        Profiler** enabledProfilerReference;
        JSGlobalData* globalData;

        ReturnAddressPtr* returnAddressSlot() { return &thunkReturnAddress; }
    };
#elif CPU(SH4)
    struct JITStackFrame {
        JITStubArg padding; // Unused
        JITStubArg args[6];

        ReturnAddressPtr thunkReturnAddress;
        void* savedR10;
        void* savedR11;
        void* savedR13;
        void* savedRPR;
        void* savedR14;
        void* savedTimeoutReg;

        RegisterFile* registerFile;
        CallFrame* callFrame;
        JSValue* exception;
        Profiler** enabledProfilerReference;
        JSGlobalData* globalData;

        ReturnAddressPtr* returnAddressSlot() { return &thunkReturnAddress; }
    };
#else
#error "JITStackFrame not defined for this platform."
#endif

#define JITSTACKFRAME_ARGS_INDEX (OBJECT_OFFSETOF(JITStackFrame, args) / sizeof(void*))

#define STUB_ARGS_DECLARATION void** args
#define STUB_ARGS (args)

#if CPU(X86)
    #if COMPILER(MSVC)
    #define JIT_STUB __fastcall
    #elif COMPILER(GCC)
    #define JIT_STUB  __attribute__ ((fastcall))
    #elif COMPILER(SUNCC)
    #define JIT_STUB
    #else
    #error "JIT_STUB function calls require fastcall conventions on x86, add appropriate directive/attribute here for your compiler!"
    #endif
#else
    #define JIT_STUB
#endif

    extern "C" void ctiVMThrowTrampoline();
    extern "C" void ctiOpThrowNotCaught();
    extern "C" EncodedJSValue ctiTrampoline(void* code, RegisterFile*, CallFrame*, void* /*unused1*/, Profiler**, JSGlobalData*);

    class JITThunks {
    public:
        JITThunks(JSGlobalData*);
        ~JITThunks();

        static void tryCacheGetByID(CallFrame*, CodeBlock*, ReturnAddressPtr returnAddress, JSValue baseValue, const Identifier& propertyName, const PropertySlot&, StructureStubInfo* stubInfo);
        static void tryCachePutByID(CallFrame*, CodeBlock*, ReturnAddressPtr returnAddress, JSValue baseValue, const PutPropertySlot&, StructureStubInfo* stubInfo, bool direct);

        MacroAssemblerCodePtr ctiStringLengthTrampoline() { return m_trampolineStructure.ctiStringLengthTrampoline; }
        MacroAssemblerCodePtr ctiVirtualCallLink() { return m_trampolineStructure.ctiVirtualCallLink; }
        MacroAssemblerCodePtr ctiVirtualConstructLink() { return m_trampolineStructure.ctiVirtualConstructLink; }
        MacroAssemblerCodePtr ctiVirtualCall() { return m_trampolineStructure.ctiVirtualCall; }
        MacroAssemblerCodePtr ctiVirtualConstruct() { return m_trampolineStructure.ctiVirtualConstruct; }
        MacroAssemblerCodePtr ctiNativeCall() { return m_trampolineStructure.ctiNativeCall; }
        MacroAssemblerCodePtr ctiNativeConstruct() { return m_trampolineStructure.ctiNativeConstruct; }
        MacroAssemblerCodePtr ctiSoftModulo() { return m_trampolineStructure.ctiSoftModulo; }

        MacroAssemblerCodeRef ctiStub(JSGlobalData*, ThunkGenerator);

        NativeExecutable* hostFunctionStub(JSGlobalData*, NativeFunction, NativeFunction constructor);
        NativeExecutable* hostFunctionStub(JSGlobalData*, NativeFunction, ThunkGenerator, Intrinsic);

        void clearHostFunctionStubs();

    private:
        typedef HashMap<ThunkGenerator, MacroAssemblerCodeRef> CTIStubMap;
        CTIStubMap m_ctiStubMap;
        typedef HashMap<NativeFunction, Weak<NativeExecutable> > HostFunctionStubMap;
        OwnPtr<HostFunctionStubMap> m_hostFunctionStubMap;
        RefPtr<ExecutableMemoryHandle> m_executableMemory;

        TrampolineStructure m_trampolineStructure;
    };

extern "C" {
    EncodedJSValue JIT_STUB cti_op_add(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_bitand(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_bitnot(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_bitor(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_bitxor(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_call_NotJSFunction(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_call_eval(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_construct_NotJSConstruct(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_create_this(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_convert_this(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_create_arguments(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_del_by_id(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_del_by_val(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_div(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_get_by_id(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_get_by_id_array_fail(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_get_by_id_custom_stub(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_get_by_id_generic(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_get_by_id_getter_stub(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_get_by_id_method_check(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_get_by_id_method_check_update(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_get_by_id_proto_fail(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_get_by_id_proto_list(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_get_by_id_proto_list_full(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_get_by_id_self_fail(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_get_by_id_string_fail(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_get_by_val(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_get_by_val_byte_array(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_get_by_val_string(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_in(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_instanceof(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_is_boolean(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_is_function(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_is_number(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_is_object(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_is_string(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_is_undefined(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_less(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_lesseq(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_greater(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_greatereq(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_lshift(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_mod(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_mul(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_negate(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_not(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_nstricteq(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_post_dec(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_post_inc(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_pre_dec(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_pre_inc(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_resolve(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_resolve_base(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_resolve_base_strict_put(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_ensure_property_exists(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_resolve_global(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_resolve_global_dynamic(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_resolve_skip(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_resolve_with_base(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_resolve_with_this(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_rshift(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_strcat(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_stricteq(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_sub(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_to_jsnumber(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_to_primitive(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_typeof(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_op_urshift(STUB_ARGS_DECLARATION);
    EncodedJSValue JIT_STUB cti_to_object(STUB_ARGS_DECLARATION);
    JSObject* JIT_STUB cti_op_new_array(STUB_ARGS_DECLARATION);
    JSObject* JIT_STUB cti_op_new_array_buffer(STUB_ARGS_DECLARATION);
    JSObject* JIT_STUB cti_op_new_func(STUB_ARGS_DECLARATION);
    JSObject* JIT_STUB cti_op_new_func_exp(STUB_ARGS_DECLARATION);
    JSObject* JIT_STUB cti_op_new_object(STUB_ARGS_DECLARATION);
    JSObject* JIT_STUB cti_op_new_regexp(STUB_ARGS_DECLARATION);
    JSObject* JIT_STUB cti_op_push_activation(STUB_ARGS_DECLARATION);
    JSObject* JIT_STUB cti_op_push_new_scope(STUB_ARGS_DECLARATION);
    JSObject* JIT_STUB cti_op_push_scope(STUB_ARGS_DECLARATION);
    JSObject* JIT_STUB cti_op_put_by_id_transition_realloc(STUB_ARGS_DECLARATION);
    JSPropertyNameIterator* JIT_STUB cti_op_get_pnames(STUB_ARGS_DECLARATION);
    int JIT_STUB cti_op_eq(STUB_ARGS_DECLARATION);
    int JIT_STUB cti_op_eq_strings(STUB_ARGS_DECLARATION);
    int JIT_STUB cti_op_jless(STUB_ARGS_DECLARATION);
    int JIT_STUB cti_op_jlesseq(STUB_ARGS_DECLARATION);
    int JIT_STUB cti_op_jgreater(STUB_ARGS_DECLARATION);
    int JIT_STUB cti_op_jgreatereq(STUB_ARGS_DECLARATION);
    int JIT_STUB cti_op_jtrue(STUB_ARGS_DECLARATION);
    void* JIT_STUB cti_op_load_varargs(STUB_ARGS_DECLARATION);
    int JIT_STUB cti_timeout_check(STUB_ARGS_DECLARATION);
    int JIT_STUB cti_has_property(STUB_ARGS_DECLARATION);
    void JIT_STUB cti_op_check_has_instance(STUB_ARGS_DECLARATION);
    void JIT_STUB cti_op_debug(STUB_ARGS_DECLARATION);
    void JIT_STUB cti_op_end(STUB_ARGS_DECLARATION);
    void JIT_STUB cti_op_jmp_scopes(STUB_ARGS_DECLARATION);
    void JIT_STUB cti_op_pop_scope(STUB_ARGS_DECLARATION);
    void JIT_STUB cti_op_profile_did_call(STUB_ARGS_DECLARATION);
    void JIT_STUB cti_op_profile_will_call(STUB_ARGS_DECLARATION);
    void JIT_STUB cti_op_put_by_id(STUB_ARGS_DECLARATION);
    void JIT_STUB cti_op_put_by_id_fail(STUB_ARGS_DECLARATION);
    void JIT_STUB cti_op_put_by_id_generic(STUB_ARGS_DECLARATION);
    void JIT_STUB cti_op_put_by_id_direct(STUB_ARGS_DECLARATION);
    void JIT_STUB cti_op_put_by_id_direct_fail(STUB_ARGS_DECLARATION);
    void JIT_STUB cti_op_put_by_id_direct_generic(STUB_ARGS_DECLARATION);
    void JIT_STUB cti_op_put_by_index(STUB_ARGS_DECLARATION);
    void JIT_STUB cti_op_put_by_val(STUB_ARGS_DECLARATION);
    void JIT_STUB cti_op_put_by_val_byte_array(STUB_ARGS_DECLARATION);
    void JIT_STUB cti_op_put_getter(STUB_ARGS_DECLARATION);
    void JIT_STUB cti_op_put_setter(STUB_ARGS_DECLARATION);
    void JIT_STUB cti_op_tear_off_activation(STUB_ARGS_DECLARATION);
    void JIT_STUB cti_op_tear_off_arguments(STUB_ARGS_DECLARATION);
    void JIT_STUB cti_op_throw_reference_error(STUB_ARGS_DECLARATION);
#if ENABLE(DFG_JIT)
    void JIT_STUB cti_optimize_from_loop(STUB_ARGS_DECLARATION);
    void JIT_STUB cti_optimize_from_ret(STUB_ARGS_DECLARATION);
#endif
    void* JIT_STUB cti_op_call_arityCheck(STUB_ARGS_DECLARATION);
    void* JIT_STUB cti_op_construct_arityCheck(STUB_ARGS_DECLARATION);
    void* JIT_STUB cti_op_call_jitCompile(STUB_ARGS_DECLARATION);
    void* JIT_STUB cti_op_construct_jitCompile(STUB_ARGS_DECLARATION);
    void* JIT_STUB cti_op_switch_char(STUB_ARGS_DECLARATION);
    void* JIT_STUB cti_op_switch_imm(STUB_ARGS_DECLARATION);
    void* JIT_STUB cti_op_switch_string(STUB_ARGS_DECLARATION);
    void* JIT_STUB cti_op_throw(STUB_ARGS_DECLARATION);
    void* JIT_STUB cti_register_file_check(STUB_ARGS_DECLARATION);
    void* JIT_STUB cti_vm_lazyLinkCall(STUB_ARGS_DECLARATION);
    void* JIT_STUB cti_vm_lazyLinkConstruct(STUB_ARGS_DECLARATION);
    void* JIT_STUB cti_vm_throw(STUB_ARGS_DECLARATION);
} // extern "C"

} // namespace JSC

#endif // ENABLE(JIT)

#endif // JITStubs_h
