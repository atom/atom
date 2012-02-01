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

#ifndef GeolocationController_h
#define GeolocationController_h

#if ENABLE(CLIENT_BASED_GEOLOCATION)

#include "Geolocation.h"
#include <wtf/HashSet.h>
#include <wtf/Noncopyable.h>
#include <wtf/RefPtr.h>

namespace WebCore {

class GeolocationClient;
class GeolocationError;
class GeolocationPosition;
class Page;

class GeolocationController {
    WTF_MAKE_NONCOPYABLE(GeolocationController);
public:
    ~GeolocationController();

    static PassOwnPtr<GeolocationController> create(Page*, GeolocationClient*);

    void addObserver(Geolocation*, bool enableHighAccuracy);
    void removeObserver(Geolocation*);

    void requestPermission(Geolocation*);
    void cancelPermissionRequest(Geolocation*);

    void positionChanged(GeolocationPosition*);
    void errorOccurred(GeolocationError*);

    GeolocationPosition* lastPosition();

    GeolocationClient* client() { return m_client; }

private:
    GeolocationController(Page*, GeolocationClient*);

    Page* m_page;
    GeolocationClient* m_client;

    RefPtr<GeolocationPosition> m_lastPosition;
    typedef HashSet<RefPtr<Geolocation> > ObserversSet;
    // All observers; both those requesting high accuracy and those not.
    ObserversSet m_observers;
    ObserversSet m_highAccuracyObservers;
};

} // namespace WebCore

#endif // ENABLE(CLIENT_BASED_GEOLOCATION)

#endif // GeolocationController_h
