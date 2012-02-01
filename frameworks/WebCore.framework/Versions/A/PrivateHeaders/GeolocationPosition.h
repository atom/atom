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

#ifndef GeolocationPosition_h
#define GeolocationPosition_h

#if ENABLE(CLIENT_BASED_GEOLOCATION)

#include <wtf/PassRefPtr.h>
#include <wtf/RefCounted.h>
#include <wtf/RefPtr.h>

namespace WebCore {

class GeolocationPosition : public RefCounted<GeolocationPosition> {
public:
    static PassRefPtr<GeolocationPosition> create(double timestamp, double latitude, double longitude, double accuracy) { return adoptRef(new GeolocationPosition(timestamp, latitude, longitude, accuracy)); }

    static PassRefPtr<GeolocationPosition> create(double timestamp, double latitude, double longitude, double accuracy, bool providesAltitude, double altitude, bool providesAltitudeAccuracy, double altitudeAccuracy, bool providesHeading, double heading, bool providesSpeed, double speed) { return adoptRef(new GeolocationPosition(timestamp, latitude, longitude, accuracy, providesAltitude, altitude, providesAltitudeAccuracy, altitudeAccuracy, providesHeading, heading, providesSpeed, speed)); }

    double timestamp() const { return m_timestamp; }

    double latitude() const { return m_latitude; }
    double longitude() const { return m_longitude; }
    double accuracy() const { return m_accuracy; }
    double altitude() const { return m_altitude; }
    double altitudeAccuracy() const { return m_altitudeAccuracy; }
    double heading() const { return m_heading; }
    double speed() const { return m_speed; }

    bool canProvideAltitude() const { return m_canProvideAltitude; }
    bool canProvideAltitudeAccuracy() const { return m_canProvideAltitudeAccuracy; }
    bool canProvideHeading() const { return m_canProvideHeading; }
    bool canProvideSpeed() const { return m_canProvideSpeed; }

private:
    GeolocationPosition(double timestamp, double latitude, double longitude, double accuracy)
        : m_timestamp(timestamp)
        , m_latitude(latitude)
        , m_longitude(longitude)
        , m_accuracy(accuracy)
        , m_altitude(0)
        , m_altitudeAccuracy(0)
        , m_heading(0)
        , m_speed(0)
        , m_canProvideAltitude(false)
        , m_canProvideAltitudeAccuracy(false)
        , m_canProvideHeading(false)
        , m_canProvideSpeed(false)
    {
    }

    GeolocationPosition(double timestamp, double latitude, double longitude, double accuracy, bool providesAltitude, double altitude, bool providesAltitudeAccuracy, double altitudeAccuracy, bool providesHeading, double heading, bool providesSpeed, double speed)
        : m_timestamp(timestamp)
        , m_latitude(latitude)
        , m_longitude(longitude)
        , m_accuracy(accuracy)
        , m_altitude(altitude)
        , m_altitudeAccuracy(altitudeAccuracy)
        , m_heading(heading)
        , m_speed(speed)
        , m_canProvideAltitude(providesAltitude)
        , m_canProvideAltitudeAccuracy(providesAltitudeAccuracy)
        , m_canProvideHeading(providesHeading)
        , m_canProvideSpeed(providesSpeed)
    {
    }

    double m_timestamp;

    double m_latitude;
    double m_longitude;
    double m_accuracy;
    double m_altitude;
    double m_altitudeAccuracy;
    double m_heading;
    double m_speed;

    bool m_canProvideAltitude;
    bool m_canProvideAltitudeAccuracy;
    bool m_canProvideHeading;
    bool m_canProvideSpeed;
};

} // namespace WebCore

#endif // ENABLE(CLIENT_BASED_GEOLOCATION)

#endif // GeolocationPosition_h
