/*
 * Copyright (C) 2003, 2004, 2005, 2008, 2009, 2010 Apple Inc. All rights reserved.
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

#ifndef JavaType_h
#define JavaType_h

#if ENABLE(JAVA_BRIDGE)

namespace JSC {

namespace Bindings {

// The order of these items can not be modified as they are tightly
// bound with the JVM on Mac OSX. If new types need to be added, they
// should be added to the end. It is used in jni_obc.mm when calling
// through to the JVM. Newly added items need to be made compatible
// in that file.
//
// The type conversion logic used here needs improving and this enum will likely
// be changed at that time. See https://bugs.webkit.org/show_bug.cgi?id=38745
enum JavaType {
    JavaTypeInvalid = 0,
    JavaTypeVoid,
    JavaTypeObject,
    JavaTypeBoolean,
    JavaTypeByte,
    JavaTypeChar,
    JavaTypeShort,
    JavaTypeInt,
    JavaTypeLong,
    JavaTypeFloat,
    JavaTypeDouble,
    JavaTypeArray,
};

} // namespace Bindings

} // namespace JSC

#endif // ENABLE(JAVA_BRIDGE)

#endif // JavaType_h
