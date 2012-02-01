/*
 * Copyright (C) 2010 Google Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *  * Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *  * Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef DeviceOrientationClientMock_h
#define DeviceOrientationClientMock_h

#include "DeviceOrientation.h"
#include "DeviceOrientationClient.h"
#include "Timer.h"

#include <wtf/PassRefPtr.h>
#include <wtf/RefPtr.h>

namespace WebCore {

class DeviceOrientationController;

// A mock implementation of DeviceOrientationClient used to test the feature in
// DumpRenderTree. Embedders should should configure the Page object to use this
// client when running DumpRenderTree.
class DeviceOrientationClientMock : public DeviceOrientationClient {
public:
    DeviceOrientationClientMock();

    // DeviceOrientationClient
    virtual void setController(DeviceOrientationController*);
    virtual void startUpdating();
    virtual void stopUpdating();
    virtual DeviceOrientation* lastOrientation() const { return m_orientation.get(); }
    virtual void deviceOrientationControllerDestroyed() { }

    void setOrientation(PassRefPtr<DeviceOrientation>);

private:
    void timerFired(Timer<DeviceOrientationClientMock>*);

    RefPtr<DeviceOrientation> m_orientation;
    DeviceOrientationController* m_controller;
    Timer<DeviceOrientationClientMock> m_timer;
    bool m_isUpdating;
};

} // namespace WebCore

#endif // DeviceOrientationClientMock_h
