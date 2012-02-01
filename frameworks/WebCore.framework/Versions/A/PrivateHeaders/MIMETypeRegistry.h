/*
 * Copyright (C) 2006 Apple Computer, Inc.  All rights reserved.
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

#ifndef MIMETypeRegistry_h
#define MIMETypeRegistry_h

#include "PlatformString.h"
#include <wtf/HashSet.h>
#include <wtf/Vector.h>
#include <wtf/text/StringHash.h>

namespace WebCore {

class MIMETypeRegistry {
public:
    static String getMIMETypeForExtension(const String& extension);
#if ENABLE(FILE_SYSTEM)
    static String getWellKnownMIMETypeForExtension(const String& extension);
#endif

    static Vector<String> getExtensionsForMIMEType(const String& type);
    static String getPreferredExtensionForMIMEType(const String& type);
    static String getMediaMIMETypeForExtension(const String& extension);
    static Vector<String> getMediaMIMETypesForExtension(const String& extension);

    static String getMIMETypeForPath(const String& path);

    // Check to see if a mime type is suitable for being loaded inline as an
    // image (e.g., <img> tags).
    static bool isSupportedImageMIMEType(const String& mimeType);

    // Check to see if a mime type is suitable for being loaded as an image
    // document in a frame.
    static bool isSupportedImageResourceMIMEType(const String& mimeType);

    // Check to see if a mime type is suitable for being encoded.
    static bool isSupportedImageMIMETypeForEncoding(const String& mimeType);

    // Check to see if a mime type is suitable for being loaded as a JavaScript
    // resource.
    static bool isSupportedJavaScriptMIMEType(const String& mimeType);    

    // Check to see if a non-image mime type is suitable for being loaded as a
    // document in a frame.  Includes supported JavaScript MIME types.
    static bool isSupportedNonImageMIMEType(const String& mimeType);

    // Check to see if a mime type is suitable for being loaded using <video> and <audio>
    static bool isSupportedMediaMIMEType(const String& mimeType); 

    // Check to see if the mime type is not suitable for being loaded as a text
    // document in a frame. Only valid for mime types begining with "text/".
    static bool isUnsupportedTextMIMEType(const String& mimeType);

    // Check to see if a mime type is a valid Java applet mime type
    static bool isJavaAppletMIMEType(const String& mimeType);

    // Check to see if a mime type is a plugin implemented by the
    // browser (e.g. a Qt Plugin).
    static bool isApplicationPluginMIMEType(const String& mimeType);

    static HashSet<String>& getSupportedImageMIMETypes();
    static HashSet<String>& getSupportedImageResourceMIMETypes();
    static HashSet<String>& getSupportedImageMIMETypesForEncoding();
    static HashSet<String>& getSupportedNonImageMIMETypes();
    static HashSet<String>& getSupportedMediaMIMETypes();
    static HashSet<String>& getUnsupportedTextMIMETypes();
};

const String& defaultMIMEType();

} // namespace WebCore

#endif // MIMETypeRegistry_h
