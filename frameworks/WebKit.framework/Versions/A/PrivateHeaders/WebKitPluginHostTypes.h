/*
 * Copyright (C) 2008 Apple Inc. All Rights Reserved.
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

#ifndef WebKitPluginHostTypes_h
#define WebKitPluginHostTypes_h

typedef uint8_t* plist_bytes_t;
typedef uint8_t* application_name_t;

typedef char* data_t;

#ifndef __MigTypeCheck
#define __MigTypeCheck 1
#endif

enum LoadURLFlags {
    IsPost = 1 << 0,
    PostDataIsFile = 1 << 1, 
    AllowHeadersInPostData = 1 << 2,
    AllowPopups = 1 << 3,
};
 
enum InvokeType {
    Invoke,
    InvokeDefault,
    Construct
};

enum ValueType {
    VoidValueType,
    NullValueType,
    BoolValueType,
    DoubleValueType,
    StringValueType,
    JSObjectValueType,
    NPObjectValueType
};

enum RendererType {
    UseAcceleratedCompositing,
    UseSoftwareRenderer,
    UseLayerBackedView
};

#endif // WebKitPluginHostTypes_h
