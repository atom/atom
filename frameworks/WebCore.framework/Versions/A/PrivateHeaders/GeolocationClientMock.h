/*
 * Copyright (C) 2010 Google Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 *     * Redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above
 * copyright notice, this list of conditions and the following disclaimer
 * in the documentation and/or other materials provided with the
 * distribution.
 *     * Neither the name of Google Inc. nor the names of its
 * contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef GeolocationClientMock_h
#define GeolocationClientMock_h

#if ENABLE(CLIENT_BASED_GEOLOCATION)

#include "GeolocationClient.h"
#include "PlatformString.h"
#include "Timer.h"

#include <wtf/HashSet.h>
#include <wtf/PassRefPtr.h>
#include <wtf/RefPtr.h>

namespace WebCore {

class GeolocationController;
class GeolocationPosition;
class GeolocationError;

// Provides a mock object for the geolocation client
class GeolocationClientMock : public GeolocationClient {
public:
    GeolocationClientMock();
    virtual ~GeolocationClientMock();

    void reset();
    void setController(GeolocationController*);

    void setError(PassRefPtr<GeolocationError>);
    void setPosition(PassRefPtr<GeolocationPosition>);
    void setPermission(bool allowed);
    int numberOfPendingPermissionRequests() const;

    // GeolocationClient
    virtual void geolocationDestroyed();
    virtual void startUpdating();
    virtual void stopUpdating();
    virtual void setEnableHighAccuracy(bool);
    virtual GeolocationPosition* lastPosition();
    virtual void requestPermission(Geolocation*);
    virtual void cancelPermissionRequest(Geolocation*);

private:
    void asyncUpdateController();
    void controllerTimerFired(Timer<GeolocationClientMock>*);

    void asyncUpdatePermission();
    void permissionTimerFired(Timer<GeolocationClientMock>*);

    GeolocationController* m_controller;
    RefPtr<GeolocationPosition> m_lastPosition;
    RefPtr<GeolocationError> m_lastError;
    Timer<GeolocationClientMock> m_controllerTimer;
    Timer<GeolocationClientMock> m_permissionTimer;
    bool m_isActive;

    enum PermissionState {
        PermissionStateUnset,
        PermissionStateAllowed,
        PermissionStateDenied,
    } m_permissionState;
    typedef WTF::HashSet<RefPtr<Geolocation> > GeolocationSet;
    GeolocationSet m_pendingPermission;
};

}

#endif // ENABLE(CLIENT_BASED_GEOLOCATION)

#endif
