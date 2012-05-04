/* -*- Mode: C; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- */
/* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is mozilla.org code.
 *
 * The Initial Developer of the Original Code is
 * Netscape Communications Corporation.
 * Portions created by the Initial Developer are Copyright (C) 1998
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either the GNU General Public License Version 2 or later (the "GPL"), or
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the MPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL, the GPL or the LGPL.
 *
 * ***** END LICENSE BLOCK ***** */

#ifndef npfunctions_h_
#define npfunctions_h_

#ifdef __OS2__
#pragma pack(1)
#define NP_LOADDS _System
#else
#define NP_LOADDS
#endif

#include "npapi.h"
#include "npruntime.h"

typedef NPError      (* NP_LOADDS NPP_NewProcPtr)(NPMIMEType pluginType, NPP instance, uint16_t mode, int16_t argc, char* argn[], char* argv[], NPSavedData* saved);
typedef NPError      (* NP_LOADDS NPP_DestroyProcPtr)(NPP instance, NPSavedData** save);
typedef NPError      (* NP_LOADDS NPP_SetWindowProcPtr)(NPP instance, NPWindow* window);
typedef NPError      (* NP_LOADDS NPP_NewStreamProcPtr)(NPP instance, NPMIMEType type, NPStream* stream, NPBool seekable, uint16_t* stype);
typedef NPError      (* NP_LOADDS NPP_DestroyStreamProcPtr)(NPP instance, NPStream* stream, NPReason reason);
typedef int32_t      (* NP_LOADDS NPP_WriteReadyProcPtr)(NPP instance, NPStream* stream);
typedef int32_t      (* NP_LOADDS NPP_WriteProcPtr)(NPP instance, NPStream* stream, int32_t offset, int32_t len, void* buffer);
typedef void         (* NP_LOADDS NPP_StreamAsFileProcPtr)(NPP instance, NPStream* stream, const char* fname);
typedef void         (* NP_LOADDS NPP_PrintProcPtr)(NPP instance, NPPrint* platformPrint);
typedef int16_t      (* NP_LOADDS NPP_HandleEventProcPtr)(NPP instance, void* event);
typedef void         (* NP_LOADDS NPP_URLNotifyProcPtr)(NPP instance, const char* url, NPReason reason, void* notifyData);
/* Any NPObjects returned to the browser via NPP_GetValue should be retained
   by the plugin on the way out. The browser is responsible for releasing. */
typedef NPError      (* NP_LOADDS NPP_GetValueProcPtr)(NPP instance, NPPVariable variable, void *ret_value);
typedef NPError      (* NP_LOADDS NPP_SetValueProcPtr)(NPP instance, NPNVariable variable, void *value);
typedef NPBool       (* NP_LOADDS NPP_GotFocusPtr)(NPP instance, NPFocusDirection direction);
typedef void         (* NP_LOADDS NPP_LostFocusPtr)(NPP instance);
typedef void         (* NP_LOADDS NPP_URLRedirectNotifyPtr)(NPP instance, const char* url, int32_t status, void* notifyData);
typedef NPError      (* NP_LOADDS NPP_ClearSiteDataPtr)(const char* site, uint64_t flags, uint64_t maxAge);
typedef char**       (* NP_LOADDS NPP_GetSitesWithDataPtr)(void);

typedef NPError      (*NPN_GetValueProcPtr)(NPP instance, NPNVariable variable, void *ret_value);
typedef NPError      (*NPN_SetValueProcPtr)(NPP instance, NPPVariable variable, void *value);
typedef NPError      (*NPN_GetURLNotifyProcPtr)(NPP instance, const char* url, const char* window, void* notifyData);
typedef NPError      (*NPN_PostURLNotifyProcPtr)(NPP instance, const char* url, const char* window, uint32_t len, const char* buf, NPBool file, void* notifyData);
typedef NPError      (*NPN_GetURLProcPtr)(NPP instance, const char* url, const char* window);
typedef NPError      (*NPN_PostURLProcPtr)(NPP instance, const char* url, const char* window, uint32_t len, const char* buf, NPBool file);
typedef NPError      (*NPN_RequestReadProcPtr)(NPStream* stream, NPByteRange* rangeList);
typedef NPError      (*NPN_NewStreamProcPtr)(NPP instance, NPMIMEType type, const char* window, NPStream** stream);
typedef int32_t      (*NPN_WriteProcPtr)(NPP instance, NPStream* stream, int32_t len, void* buffer);
typedef NPError      (*NPN_DestroyStreamProcPtr)(NPP instance, NPStream* stream, NPReason reason);
typedef void         (*NPN_StatusProcPtr)(NPP instance, const char* message);
/* Browser manages the lifetime of the buffer returned by NPN_UserAgent, don't
   depend on it sticking around and don't free it. */
typedef const char*  (*NPN_UserAgentProcPtr)(NPP instance);
typedef void*        (*NPN_MemAllocProcPtr)(uint32_t size);
typedef void         (*NPN_MemFreeProcPtr)(void* ptr);
typedef uint32_t     (*NPN_MemFlushProcPtr)(uint32_t size);
typedef void         (*NPN_ReloadPluginsProcPtr)(NPBool reloadPages);
typedef void*        (*NPN_GetJavaEnvProcPtr)(void);
typedef void*        (*NPN_GetJavaPeerProcPtr)(NPP instance);
typedef void         (*NPN_InvalidateRectProcPtr)(NPP instance, NPRect *rect);
typedef void         (*NPN_InvalidateRegionProcPtr)(NPP instance, NPRegion region);
typedef void         (*NPN_ForceRedrawProcPtr)(NPP instance);
typedef NPIdentifier (*NPN_GetStringIdentifierProcPtr)(const NPUTF8* name);
typedef void         (*NPN_GetStringIdentifiersProcPtr)(const NPUTF8** names, int32_t nameCount, NPIdentifier* identifiers);
typedef NPIdentifier (*NPN_GetIntIdentifierProcPtr)(int32_t intid);
typedef bool         (*NPN_IdentifierIsStringProcPtr)(NPIdentifier identifier);
typedef NPUTF8*      (*NPN_UTF8FromIdentifierProcPtr)(NPIdentifier identifier);
typedef int32_t      (*NPN_IntFromIdentifierProcPtr)(NPIdentifier identifier);
typedef NPObject*    (*NPN_CreateObjectProcPtr)(NPP npp, NPClass *aClass);
typedef NPObject*    (*NPN_RetainObjectProcPtr)(NPObject *obj);
typedef void         (*NPN_ReleaseObjectProcPtr)(NPObject *obj);
typedef bool         (*NPN_InvokeProcPtr)(NPP npp, NPObject* obj, NPIdentifier methodName, const NPVariant *args, uint32_t argCount, NPVariant *result);
typedef bool         (*NPN_InvokeDefaultProcPtr)(NPP npp, NPObject* obj, const NPVariant *args, uint32_t argCount, NPVariant *result);
typedef bool         (*NPN_EvaluateProcPtr)(NPP npp, NPObject *obj, NPString *script, NPVariant *result);
typedef bool         (*NPN_GetPropertyProcPtr)(NPP npp, NPObject *obj, NPIdentifier propertyName, NPVariant *result);
typedef bool         (*NPN_SetPropertyProcPtr)(NPP npp, NPObject *obj, NPIdentifier propertyName, const NPVariant *value);
typedef bool         (*NPN_RemovePropertyProcPtr)(NPP npp, NPObject *obj, NPIdentifier propertyName);
typedef bool         (*NPN_HasPropertyProcPtr)(NPP npp, NPObject *obj, NPIdentifier propertyName);
typedef bool         (*NPN_HasMethodProcPtr)(NPP npp, NPObject *obj, NPIdentifier propertyName);
typedef void         (*NPN_ReleaseVariantValueProcPtr)(NPVariant *variant);
typedef void         (*NPN_SetExceptionProcPtr)(NPObject *obj, const NPUTF8 *message);
typedef void         (*NPN_PushPopupsEnabledStateProcPtr)(NPP npp, NPBool enabled);
typedef void         (*NPN_PopPopupsEnabledStateProcPtr)(NPP npp);
typedef bool         (*NPN_EnumerateProcPtr)(NPP npp, NPObject *obj, NPIdentifier **identifier, uint32_t *count);
typedef void         (*NPN_PluginThreadAsyncCallProcPtr)(NPP instance, void (*func)(void *), void *userData);
typedef bool         (*NPN_ConstructProcPtr)(NPP npp, NPObject* obj, const NPVariant *args, uint32_t argCount, NPVariant *result);
typedef NPError      (*NPN_GetValueForURLPtr)(NPP npp, NPNURLVariable variable, const char *url, char **value, uint32_t *len);
typedef NPError      (*NPN_SetValueForURLPtr)(NPP npp, NPNURLVariable variable, const char *url, const char *value, uint32_t len);
typedef NPError      (*NPN_GetAuthenticationInfoPtr)(NPP npp, const char *protocol, const char *host, int32_t port, const char *scheme, const char *realm, char **username, uint32_t *ulen, char **password, uint32_t *plen);
typedef uint32_t     (*NPN_ScheduleTimerPtr)(NPP instance, uint32_t interval, NPBool repeat, void (*timerFunc)(NPP npp, uint32_t timerID));
typedef void         (*NPN_UnscheduleTimerPtr)(NPP instance, uint32_t timerID);
typedef NPError      (*NPN_PopUpContextMenuPtr)(NPP instance, NPMenu* menu);
typedef NPBool       (*NPN_ConvertPointPtr)(NPP instance, double sourceX, double sourceY, NPCoordinateSpace sourceSpace, double *destX, double *destY, NPCoordinateSpace destSpace);
typedef NPBool       (*NPN_HandleEventPtr)(NPP instance, void *event, NPBool handled);
typedef NPBool       (*NPN_UnfocusInstancePtr)(NPP instance, NPFocusDirection direction);
typedef void         (*NPN_URLRedirectResponsePtr)(NPP instance, void* notifyData, NPBool allow);

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
  void* javaClass;
  NPP_GetValueProcPtr getvalue;
  NPP_SetValueProcPtr setvalue;
  NPP_GotFocusPtr gotfocus;
  NPP_LostFocusPtr lostfocus;
  NPP_URLRedirectNotifyPtr urlredirectnotify;
  NPP_ClearSiteDataPtr clearsitedata;
  NPP_GetSitesWithDataPtr getsiteswithdata;
} NPPluginFuncs;

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
  NPN_GetValueForURLPtr getvalueforurl;
  NPN_SetValueForURLPtr setvalueforurl;
  NPN_GetAuthenticationInfoPtr getauthenticationinfo;
  NPN_ScheduleTimerPtr scheduletimer;
  NPN_UnscheduleTimerPtr unscheduletimer;
  NPN_PopUpContextMenuPtr popupcontextmenu;
  NPN_ConvertPointPtr convertpoint;
  NPN_HandleEventPtr handleevent;
  NPN_UnfocusInstancePtr unfocusinstance;
  NPN_URLRedirectResponsePtr urlredirectresponse;
} NPNetscapeFuncs;

#ifdef XP_MACOSX
/*
 * Mac OS X version(s) of NP_GetMIMEDescription(const char *)
 * These can be called to retreive MIME information from the plugin dynamically
 *
 * Note: For compatibility with Quicktime, BPSupportedMIMEtypes is another way
 *       to get mime info from the plugin only on OSX and may not be supported
 *       in furture version -- use NP_GetMIMEDescription instead
 */
enum
{
 kBPSupportedMIMETypesStructVers_1    = 1
};
typedef struct _BPSupportedMIMETypes
{
 SInt32    structVersion;      /* struct version */
 Handle    typeStrings;        /* STR# formated handle, allocated by plug-in */
 Handle    infoStrings;        /* STR# formated handle, allocated by plug-in */
} BPSupportedMIMETypes;
OSErr BP_GetSupportedMIMETypes(BPSupportedMIMETypes *mimeInfo, UInt32 flags);
#define NP_GETMIMEDESCRIPTION_NAME "NP_GetMIMEDescription"
typedef const char* (*NP_GetMIMEDescriptionProcPtr)(void);
typedef OSErr (*BP_GetSupportedMIMETypesProcPtr)(BPSupportedMIMETypes*, UInt32);
#endif

#endif /* npfunctions_h_ */
