/*
 * Copyright (C) 2006, 2007, 2008, 2009, 2011 Apple Inc. All rights reserved.
 * Copyright (C) 2008, 2009 Torch Mobile Inc. All rights reserved. (http://www.torchmobile.com/)
 * Copyright (C) Research In Motion Limited 2009. All rights reserved.
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

#ifndef SubframeLoader_h
#define SubframeLoader_h

#include "FrameLoaderTypes.h"
#include "PlatformString.h"
#include <wtf/Forward.h>
#include <wtf/HashMap.h>
#include <wtf/Noncopyable.h>
#include <wtf/Vector.h>

namespace WebCore {

class Document;
class Frame;
class FrameLoaderClient;
class HTMLAppletElement;
class HTMLFrameOwnerElement;
class HTMLPlugInImageElement;
class IntSize;
class KURL;
#if ENABLE(PLUGIN_PROXY_FOR_VIDEO)
class Node;
#endif
class Widget;

// This is a slight misnomer. It handles the higher level logic of loading both subframes and plugins.
class SubframeLoader {
    WTF_MAKE_NONCOPYABLE(SubframeLoader);
public:
    SubframeLoader(Frame*);

    void clear();

    bool requestFrame(HTMLFrameOwnerElement*, const String& url, const AtomicString& frameName, bool lockHistory = true, bool lockBackForwardList = true);    
    bool requestObject(HTMLPlugInImageElement*, const String& url, const AtomicString& frameName,
        const String& serviceType, const Vector<String>& paramNames, const Vector<String>& paramValues);

#if ENABLE(PLUGIN_PROXY_FOR_VIDEO)
    // FIXME: This should take Element* instead of Node*, or better yet the
    // specific type of Element which this code depends on.
    PassRefPtr<Widget> loadMediaPlayerProxyPlugin(Node*, const KURL&, const Vector<String>& paramNames, const Vector<String>& paramValues);
#endif

    PassRefPtr<Widget> createJavaAppletWidget(const IntSize&, HTMLAppletElement*, const HashMap<String, String>& args);

    bool allowPlugins(ReasonForCallingAllowPlugins);

    bool containsPlugins() const { return m_containsPlugins; }
    
    bool resourceWillUsePlugin(const String& url, const String& mimeType, bool shouldPreferPlugInsForImages);

private:
    bool requestPlugin(HTMLPlugInImageElement*, const KURL&, const String& serviceType, const Vector<String>& paramNames, const Vector<String>& paramValues, bool useFallback);
    Frame* loadOrRedirectSubframe(HTMLFrameOwnerElement*, const KURL&, const AtomicString& frameName, bool lockHistory, bool lockBackForwardList);
    Frame* loadSubframe(HTMLFrameOwnerElement*, const KURL&, const String& name, const String& referrer);
    bool loadPlugin(HTMLPlugInImageElement*, const KURL&, const String& mimeType,
        const Vector<String>& paramNames, const Vector<String>& paramValues, bool useFallback);

    bool shouldUsePlugin(const KURL&, const String& mimeType, bool shouldPreferPlugInsForImages, bool hasFallback, bool& useFallback);

    Document* document() const;

    bool m_containsPlugins;
    Frame* m_frame;

    KURL completeURL(const String&) const;
};

} // namespace WebCore

#endif // SubframeLoader_h
