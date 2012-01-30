/*
 * Copyright (C) 2009 Google Inc. All rights reserved.
 * Copyright (C) 2011 Apple Inc. All rights reserved.
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

#ifndef NotificationPresenter_h
#define NotificationPresenter_h

#include <wtf/PassRefPtr.h>
#include "VoidCallback.h"

namespace WebCore {

class Document;
class Notification;
class KURL;
class ScriptExecutionContext;

class NotificationPresenter {

public:
    enum Permission {
        PermissionAllowed, // User has allowed notifications
        PermissionNotAllowed, // User has not yet allowed
        PermissionDenied // User has explicitly denied permission
    };

    // Requests that a notification be shown.
    virtual bool show(Notification*) = 0;

    // Requests that a notification that has already been shown be canceled.
    virtual void cancel(Notification*) = 0;

    // Informs the presenter that a Notification object has been destroyed
    // (such as by a page transition). The presenter may continue showing
    // the notification, but must not attempt to call the event handlers.
    virtual void notificationObjectDestroyed(Notification*) = 0;

    // Informs the presenter the controller attached to the page has been destroyed.
    virtual void notificationControllerDestroyed() = 0;

    // Requests user permission to show desktop notifications from a particular
    // script context. The callback parameter should be run when the user has
    // made a decision.
    virtual void requestPermission(ScriptExecutionContext*, PassRefPtr<VoidCallback>) = 0;

    // Cancel all outstanding requests for the ScriptExecutionContext
    virtual void cancelRequestsForPermission(ScriptExecutionContext*) = 0;

    // Checks the current level of permission.
    virtual Permission checkPermission(ScriptExecutionContext*) = 0;

protected:
    virtual ~NotificationPresenter() { }
};

} // namespace WebCore

#endif // NotificationPresenter_h
