/*
 * Copyright (C) 2007 Apple Inc.  All rights reserved.
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
#ifndef NPFUNCTIONS_H
#define NPFUNCTIONS_H


#include "npruntime.h"
#include "npapi.h"

#ifdef __cplusplus
extern "C" {
#endif

#if defined(XP_WIN)
#define EXPORTED_CALLBACK(_type, _name) _type (__stdcall * _name)
#else
#define EXPORTED_CALLBACK(_type, _name) _type (* _name)
#endif

typedef NPError (*NPN_GetURLNotifyProcPtr)(NPP instance, const char* URL, const char* window, void* notifyData);
typedef NPError (*NPN_PostURLNotifyProcPtr)(NPP instance, const char* URL, const char* window, uint32_t len, const char* buf, NPBool file, void* notifyData);
typedef NPError (*NPN_RequestReadProcPtr)(NPStream* stream, NPByteRange* rangeList);
typedef NPError (*NPN_NewStreamProcPtr)(NPP instance, NPMIMEType type, const char* window, NPStream** stream);
typedef int32_t (*NPN_WriteProcPtr)(NPP instance, NPStream* stream, int32_t len, void* buffer);
typedef NPError (*NPN_DestroyStreamProcPtr)(NPP instance, NPStream* stream, NPReason reason);
typedef void (*NPN_StatusProcPtr)(NPP instance, const char* message);
typedef const char*(*NPN_UserAgentProcPtr)(NPP instance);
typedef void* (*NPN_MemAllocProcPtr)(uint32_t size);
typedef void (*NPN_MemFreeProcPtr)(void* ptr);
typedef uint32_t (*NPN_MemFlushProcPtr)(uint32_t size);
typedef void (*NPN_ReloadPluginsProcPtr)(NPBool reloadPages);
typedef NPError (*NPN_GetValueProcPtr)(NPP instance, NPNVariable variable, void *ret_value);
typedef NPError (*NPN_SetValueProcPtr)(NPP instance, NPPVariable variable, void *value);
typedef void (*NPN_InvalidateRectProcPtr)(NPP instance, NPRect *rect);
typedef void (*NPN_InvalidateRegionProcPtr)(NPP instance, NPRegion region);
typedef void (*NPN_ForceRedrawProcPtr)(NPP instance);
typedef NPError (*NPN_GetURLProcPtr)(NPP instance, const char* URL, const char* window);
typedef NPError (*NPN_PostURLProcPtr)(NPP instance, const char* URL, const char* window, uint32_t len, const char* buf, NPBool file);
typedef void* (*NPN_GetJavaEnvProcPtr)(void);
typedef void* (*NPN_GetJavaPeerProcPtr)(NPP instance);
typedef void  (*NPN_PushPopupsEnabledStateProcPtr)(NPP instance, NPBool enabled);
typedef void  (*NPN_PopPopupsEnabledStateProcPtr)(NPP instance);
typedef void (*NPN_PluginThreadAsyncCallProcPtr)(NPP npp, void (*func)(void *), void *userData);
typedef NPError (*NPN_GetValueForURLProcPtr)(NPP npp, NPNURLVariable variable, const char* url, char** value, uint32_t* len);
typedef NPError (*NPN_SetValueForURLProcPtr)(NPP npp, NPNURLVariable variable, const char* url, const char* value, uint32_t len);
typedef NPError (*NPN_GetAuthenticationInfoProcPtr)(NPP npp, const char* protocol, const char* host, int32_t port, const char* scheme, const char *realm, char** username, uint32_t* ulen, char** password, uint32_t* plen);

typedef uint32_t (*NPN_ScheduleTimerProcPtr)(NPP npp, uint32_t interval, NPBool repeat, void (*timerFunc)(NPP npp, uint32_t timerID));
typedef void (*NPN_UnscheduleTimerProcPtr)(NPP npp, uint32_t timerID);
typedef NPError (*NPN_PopUpContextMenuProcPtr)(NPP instance, NPMenu* menu);
typedef NPBool (*NPN_ConvertPointProcPtr)(NPP npp, double sourceX, double sourceY, NPCoordinateSpace sourceSpace, double *destX, double *destY, NPCoordinateSpace destSpace);

typedef void (*NPN_ReleaseVariantValueProcPtr) (NPVariant *variant);

typedef NPIdentifier (*NPN_GetStringIdentifierProcPtr) (const NPUTF8 *name);
typedef void (*NPN_GetStringIdentifiersProcPtr) (const NPUTF8 **names, int32_t nameCount, NPIdentifier *identifiers);
typedef NPIdentifier (*NPN_GetIntIdentifierProcPtr) (int32_t intid);
typedef int32_t (*NPN_IntFromIdentifierProcPtr) (NPIdentifier identifier);
typedef bool (*NPN_IdentifierIsStringProcPtr) (NPIdentifier identifier);
typedef NPUTF8 *(*NPN_UTF8FromIdentifierProcPtr) (NPIdentifier identifier);

typedef NPObject* (*NPN_CreateObjectProcPtr) (NPP, NPClass *aClass);
typedef NPObject* (*NPN_RetainObjectProcPtr) (NPObject *obj);
typedef void (*NPN_ReleaseObjectProcPtr) (NPObject *obj);
typedef bool (*NPN_InvokeProcPtr) (NPP npp, NPObject *obj, NPIdentifier methodName, const NPVariant *args, unsigned argCount, NPVariant *result);
typedef bool (*NPN_InvokeDefaultProcPtr) (NPP npp, NPObject *obj, const NPVariant *args, unsigned argCount, NPVariant *result);
typedef bool (*NPN_EvaluateProcPtr) (NPP npp, NPObject *obj, NPString *script, NPVariant *result);
typedef bool (*NPN_GetPropertyProcPtr) (NPP npp, NPObject *obj, NPIdentifier  propertyName, NPVariant *result);
typedef bool (*NPN_SetPropertyProcPtr) (NPP npp, NPObject *obj, NPIdentifier  propertyName, const NPVariant *value);
typedef bool (*NPN_HasPropertyProcPtr) (NPP, NPObject *npobj, NPIdentifier propertyName);
typedef bool (*NPN_HasMethodProcPtr) (NPP npp, NPObject *npobj, NPIdentifier methodName);
typedef bool (*NPN_RemovePropertyProcPtr) (NPP npp, NPObject *obj, NPIdentifier propertyName);
typedef void (*NPN_SetExceptionProcPtr) (NPObject *obj, const NPUTF8 *message);
typedef bool (*NPN_EnumerateProcPtr) (NPP npp, NPObject *npobj, NPIdentifier **identifier, uint32_t *count);
typedef bool (*NPN_ConstructProcPtr)(NPP npp, NPObject* obj, const NPVariant *args, uint32_t argCount, NPVariant *result);    

typedef NPError (*NPP_NewProcPtr)(NPMIMEType pluginType, NPP instance, uint16_t mode, int16_t argc, char* argn[], char* argv[], NPSavedData* saved);
typedef NPError (*NPP_DestroyProcPtr)(NPP instance, NPSavedData** save);
typedef NPError (*NPP_SetWindowProcPtr)(NPP instance, NPWindow* window);
typedef NPError (*NPP_NewStreamProcPtr)(NPP instance, NPMIMEType type, NPStream* stream, NPBool seekable, uint16_t* stype);
typedef NPError (*NPP_DestroyStreamProcPtr)(NPP instance, NPStream* stream, NPReason reason);
typedef void (*NPP_StreamAsFileProcPtr)(NPP instance, NPStream* stream, const char* fname);
typedef int32_t (*NPP_WriteReadyProcPtr)(NPP instance, NPStream* stream);
typedef int32_t (*NPP_WriteProcPtr)(NPP instance, NPStream* stream, int32_t offset, int32_t len, void* buffer);
typedef void (*NPP_PrintProcPtr)(NPP instance, NPPrint* platformPrint);
typedef int16_t (*NPP_HandleEventProcPtr)(NPP instance, void* event);
typedef void (*NPP_URLNotifyProcPtr)(NPP instance, const char* URL, NPReason reason, void* notifyData);
typedef NPError (*NPP_GetValueProcPtr)(NPP instance, NPPVariable variable, void *ret_value);
typedef NPError (*NPP_SetValueProcPtr)(NPP instance, NPNVariable variable, void *value);
typedef NPBool (*NPP_GotFocusPtr)(NPP instance, NPFocusDirection direction);
typedef void (*NPP_LostFocusPtr)(NPP instance);
typedef void (*NPP_URLRedirectNotifyPtr)(NPP instance, const char* url, int32_t status, void* notifyData);
typedef NPError (*NPP_ClearSiteDataPtr)(const char* site, uint64_t flags, uint64_t maxAge);
typedef char** (*NPP_GetSitesWithDataPtr)(void);

typedef void *(*NPP_GetJavaClassProcPtr)(void);
typedef void* JRIGlobalRef; //not using this right now

typedef struct _NPNetscapeFuncs {
    uint16_t size;
    uint16_t version;
    
    NPN_GetURLProcPtr geturl;
    NPN_PostURLProcPtr posturl;
    NPN_RequestReadProcPtr requestread;
    NPN_NewStreamProcPtr newstream;
    NPN_WriteProcPtr write;
    NPN_DestroyStreamProcPtr destroystream;
    NPN_StatusProcPtr status;
    NPN_UserAgentProcPtr uagent;
    NPN_MemAllocProcPtr memalloc;
    NPN_MemFreeProcPtr memfree;
    NPN_MemFlushProcPtr memflush;
    NPN_ReloadPluginsProcPtr reloadplugins;
    NPN_GetJavaEnvProcPtr getJavaEnv;
    NPN_GetJavaPeerProcPtr getJavaPeer;
    NPN_GetURLNotifyProcPtr geturlnotify;
    NPN_PostURLNotifyProcPtr posturlnotify;
    NPN_GetValueProcPtr getvalue;
    NPN_SetValueProcPtr setvalue;
    NPN_InvalidateRectProcPtr invalidaterect;
    NPN_InvalidateRegionProcPtr invalidateregion;
    NPN_ForceRedrawProcPtr forceredraw;
    
    NPN_GetStringIdentifierProcPtr getstringidentifier;
    NPN_GetStringIdentifiersProcPtr getstringidentifiers;
    NPN_GetIntIdentifierProcPtr getintidentifier;
    NPN_IdentifierIsStringProcPtr identifierisstring;
    NPN_UTF8FromIdentifierProcPtr utf8fromidentifier;
    NPN_IntFromIdentifierProcPtr intfromidentifier;
    NPN_CreateObjectProcPtr createobject;
    NPN_RetainObjectProcPtr retainobject;
    NPN_ReleaseObjectProcPtr releaseobject;
    NPN_InvokeProcPtr invoke;
    NPN_InvokeDefaultProcPtr invokeDefault;
    NPN_EvaluateProcPtr evaluate;
    NPN_GetPropertyProcPtr getproperty;
    NPN_SetPropertyProcPtr setproperty;
    NPN_RemovePropertyProcPtr removeproperty;
    NPN_HasPropertyProcPtr hasproperty;
    NPN_HasMethodProcPtr hasmethod;
    NPN_ReleaseVariantValueProcPtr releasevariantvalue;
    NPN_SetExceptionProcPtr setexception;
    NPN_PushPopupsEnabledStateProcPtr pushpopupsenabledstate;
    NPN_PopPopupsEnabledStateProcPtr poppopupsenabledstate;
    NPN_EnumerateProcPtr enumerate;
    NPN_PluginThreadAsyncCallProcPtr pluginthreadasynccall;
    NPN_ConstructProcPtr construct;
    NPN_GetValueForURLProcPtr getvalueforurl;
    NPN_SetValueForURLProcPtr setvalueforurl;
    NPN_GetAuthenticationInfoProcPtr getauthenticationinfo;
    NPN_ScheduleTimerProcPtr scheduletimer;
    NPN_UnscheduleTimerProcPtr unscheduletimer;
    NPN_PopUpContextMenuProcPtr popupcontextmenu;
    NPN_ConvertPointProcPtr convertpoint;
} NPNetscapeFuncs;

typedef struct _NPPluginFuncs {
    uint16_t size;
    uint16_t version;
    NPP_NewProcPtr newp;
    NPP_DestroyProcPtr destroy;
    NPP_SetWindowProcPtr setwindow;
    NPP_NewStreamProcPtr newstream;
    NPP_DestroyStreamProcPtr destroystream;
    NPP_StreamAsFileProcPtr asfile;
    NPP_WriteReadyProcPtr writeready;
    NPP_WriteProcPtr write;
    NPP_PrintProcPtr print;
    NPP_HandleEventProcPtr event;
    NPP_URLNotifyProcPtr urlnotify;
    JRIGlobalRef javaClass;
    NPP_GetValueProcPtr getvalue;
    NPP_SetValueProcPtr setvalue;
    NPP_GotFocusPtr gotfocus;
    NPP_LostFocusPtr lostfocus;
    NPP_URLRedirectNotifyPtr urlredirectnotify;
    NPP_ClearSiteDataPtr clearsitedata;
    NPP_GetSitesWithDataPtr getsiteswithdata;
} NPPluginFuncs;

typedef EXPORTED_CALLBACK(NPError, NP_GetEntryPointsFuncPtr)(NPPluginFuncs*);
typedef EXPORTED_CALLBACK(void, NPP_ShutdownProcPtr)(void);    

#if defined(XP_MACOSX)
typedef void (*BP_CreatePluginMIMETypesPreferencesFuncPtr)(void);
typedef NPError (*MainFuncPtr)(NPNetscapeFuncs*, NPPluginFuncs*, NPP_ShutdownProcPtr*);
#endif

#if defined(XP_UNIX)
typedef EXPORTED_CALLBACK(NPError, NP_InitializeFuncPtr)(NPNetscapeFuncs*, NPPluginFuncs*);
typedef EXPORTED_CALLBACK(char*, NP_GetMIMEDescriptionFuncPtr)(void);
#else
typedef EXPORTED_CALLBACK(NPError, NP_InitializeFuncPtr)(NPNetscapeFuncs*);
#endif

#ifdef __cplusplus
}
#endif

#endif
