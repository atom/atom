/*
 * Copyright (C) 2009 Apple Inc.  All rights reserved.
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

#ifndef WebNetscapeContainerCheckPrivate_h
#define WebNetscapeContainerCheckPrivate_h

#include <WebKit/npapi.h>

#ifdef __cplusplus
extern "C" {
#endif
    
#define WKNVBrowserContainerCheckFuncs 1701
#define WKNVBrowserContainerCheckFuncsVersion 2

#define WKNVBrowserContainerCheckFuncsVersionHasGetLocation 2

typedef uint32_t (*WKN_CheckIfAllowedToLoadURLProcPtr)(NPP npp, const char* url, const char* frame, void (*callbackFunc)(NPP npp, uint32_t, NPBool allowed, void* context), void* context);
typedef void  (*WKN_CancelCheckIfAllowedToLoadURLProcPtr)(NPP npp, uint32_t);
typedef char* (*WKN_ResolveURLProcPtr)(NPP npp, const char* url, const char* target);

uint32_t WKN_CheckIfAllowedToLoadURL(NPP npp, const char* url, const char* frame, void (*callbackFunc)(NPP npp, uint32_t, NPBool allowed, void* context), void* context);
void WKN_CancelCheckIfAllowedToLoadURL(NPP npp, uint32_t);
char* WKN_ResolveURL(NPP npp, const char* url, const char* target);

typedef struct _WKNBrowserContainerCheckFuncs {
    uint16_t size;
    uint16_t version;
    
    WKN_CheckIfAllowedToLoadURLProcPtr checkIfAllowedToLoadURL;
    WKN_CancelCheckIfAllowedToLoadURLProcPtr cancelCheckIfAllowedToLoadURL;
    WKN_ResolveURLProcPtr resolveURL;
} WKNBrowserContainerCheckFuncs;

#ifdef __cplusplus
}
#endif

#endif // WebNetscapeContainerCheckPrivate_h
