/*
    Copyright (C) 2010 Nokia Corporation and/or its subsidiary(-ies)

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Library General Public
    License as published by the Free Software Foundation; either
    version 2 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Library General Public License for more details.

    You should have received a copy of the GNU Library General Public License
    along with this library; see the file COPYING.LIB.  If not, write to
    the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
    Boston, MA 02110-1301, USA.
*/

#ifndef NetworkingContext_h
#define NetworkingContext_h

#include <wtf/RefCounted.h>

#if PLATFORM(MAC)
#include "SchedulePair.h"
#endif

#if PLATFORM(QT)
#include <qglobal.h>
QT_BEGIN_NAMESPACE
class QObject;
class QNetworkAccessManager;
class QUrl;
QT_END_NAMESPACE
#endif

namespace WebCore {

class ResourceError;
class ResourceRequest;

class NetworkingContext : public RefCounted<NetworkingContext> {
public:
    virtual ~NetworkingContext() { }

    virtual bool isValid() const { return true; }

#if PLATFORM(MAC)
    virtual bool needsSiteSpecificQuirks() const = 0;
    virtual bool localFileContentSniffingEnabled() const = 0;
    virtual SchedulePairHashSet* scheduledRunLoopPairs() const = 0;
    virtual ResourceError blockedError(const ResourceRequest&) const = 0;
#endif

#if PLATFORM(QT)
    virtual QObject* originatingObject() const = 0;
    virtual QNetworkAccessManager* networkAccessManager() const = 0;
    virtual bool mimeSniffingEnabled() const = 0;
    virtual bool thirdPartyCookiePolicyPermission(const QUrl&) const = 0;
#endif

#if PLATFORM(WIN)
    virtual String userAgent() const = 0;
    virtual String referrer() const = 0;
    virtual ResourceError blockedError(const ResourceRequest&) const = 0;
#endif

protected:
    NetworkingContext() { }
};

}

#endif // NetworkingContext_h
