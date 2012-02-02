/*
 * Copyright (C) 2009 Apple Inc. All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. AND ITS CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef GeolocationClient_h
#define GeolocationClient_h

namespace WebCore {

class Geolocation;
class GeolocationPosition;

class GeolocationClient {
public:
    virtual void geolocationDestroyed() = 0;

    virtual void startUpdating() = 0;
    virtual void stopUpdating() = 0;
    // FIXME: The V2 Geolocation specification proposes that this property is
    // renamed. See http://www.w3.org/2008/geolocation/track/issues/6
    // We should update WebKit to reflect this if and when the V2 specification
    // is published.
    virtual void setEnableHighAccuracy(bool) = 0;
    virtual GeolocationPosition* lastPosition() = 0;

    virtual void requestPermission(Geolocation*) = 0;
    virtual void cancelPermissionRequest(Geolocation*) = 0;

protected:
    virtual ~GeolocationClient() { }
};

} // namespace WebCore

#endif // GeolocationClient_h
