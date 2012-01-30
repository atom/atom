/*
 * Copyright (C) 2004 Apple Computer, Inc.  All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY APPLE COMPUTER, INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE COMPUTER, INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 */

#ifndef _NP_RUNTIME_IMPL_H_
#define _NP_RUNTIME_IMPL_H_

#if ENABLE(NETSCAPE_PLUGIN_API)

#include "npruntime_internal.h"

#ifdef __cplusplus
extern "C" {
#endif

extern void _NPN_ReleaseVariantValue(NPVariant*);
extern NPIdentifier _NPN_GetStringIdentifier(const NPUTF8*);
extern void _NPN_GetStringIdentifiers(const NPUTF8** names, int32_t nameCount, NPIdentifier* identifiers);
extern NPIdentifier _NPN_GetIntIdentifier(int32_t);
extern bool _NPN_IdentifierIsString(NPIdentifier);
extern NPUTF8* _NPN_UTF8FromIdentifier(NPIdentifier);
extern int32_t _NPN_IntFromIdentifier(NPIdentifier);    
extern NPObject* _NPN_CreateObject(NPP, NPClass*);
extern NPObject* _NPN_RetainObject(NPObject*);
extern void _NPN_ReleaseObject(NPObject*);
extern void _NPN_DeallocateObject(NPObject*);
extern bool _NPN_Invoke(NPP, NPObject*, NPIdentifier methodName, const NPVariant* args, uint32_t argCount, NPVariant* result);
extern bool _NPN_InvokeDefault(NPP, NPObject*, const NPVariant* args, uint32_t argCount, NPVariant* result);
extern bool _NPN_Evaluate(NPP, NPObject*, NPString*, NPVariant* result);
extern bool _NPN_GetProperty(NPP, NPObject*, NPIdentifier, NPVariant* result);
extern bool _NPN_SetProperty(NPP, NPObject*, NPIdentifier, const NPVariant*);
extern bool _NPN_RemoveProperty(NPP, NPObject*, NPIdentifier);
extern bool _NPN_HasProperty(NPP, NPObject*, NPIdentifier);
extern bool _NPN_HasMethod(NPP, NPObject*, NPIdentifier);
extern void _NPN_SetException(NPObject*, const NPUTF8*);
extern bool _NPN_Enumerate(NPP, NPObject*, NPIdentifier**, uint32_t* count);
extern bool _NPN_Construct(NPP, NPObject*, const NPVariant* args, uint32_t argCount, NPVariant *result);

#ifdef __cplusplus
}  /* end extern "C" */
#endif

#endif // ENABLE(NETSCAPE_PLUGIN_API)

#endif
