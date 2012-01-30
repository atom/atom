/*
 * Copyright (C) 1999-2000 Harri Porten (porten@kde.org)
 * Copyright (C) 2006, 2007 Apple Inc. All rights reserved.
 * Copyright (C) 2009 Google Inc. All rights reserved.
 * Copyright (C) 2010 Research In Motion Limited. All rights reserved.
 *
 * Version: MPL 1.1/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is Mozilla Communicator client code, released
 * March 31, 1998.
 *
 * The Initial Developer of the Original Code is
 * Netscape Communications Corporation.
 * Portions created by the Initial Developer are Copyright (C) 1998
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either of the GNU General Public License Version 2 or later (the "GPL"),
 * or the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the MPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL, the GPL or the LGPL.
 *
 */

#ifndef JSDateMath_h
#define JSDateMath_h

#include <wtf/DateMath.h>

namespace JSC {

class ExecState;
struct GregorianDateTime;

void msToGregorianDateTime(ExecState*, double, bool outputIsUTC, GregorianDateTime&);
double gregorianDateTimeToMS(ExecState*, const GregorianDateTime&, double, bool inputIsUTC);
double getUTCOffset(ExecState*);
double parseDateFromNullTerminatedCharacters(ExecState*, const char* dateString);

// Intentionally overridding the default tm of the system.
// The members of tm differ on various operating systems.
struct GregorianDateTime {
    WTF_MAKE_NONCOPYABLE(GregorianDateTime);
public:
    GregorianDateTime()
        : second(0)
        , minute(0)
        , hour(0)
        , weekDay(0)
        , monthDay(0)
        , yearDay(0)
        , month(0)
        , year(0)
        , isDST(0)
        , utcOffset(0)
    {
    }

    GregorianDateTime(ExecState* exec, const tm& inTm)
        : second(inTm.tm_sec)
        , minute(inTm.tm_min)
        , hour(inTm.tm_hour)
        , weekDay(inTm.tm_wday)
        , monthDay(inTm.tm_mday)
        , yearDay(inTm.tm_yday)
        , month(inTm.tm_mon)
        , year(inTm.tm_year)
        , isDST(inTm.tm_isdst)
    {
        UNUSED_PARAM(exec);
#if HAVE(TM_GMTOFF)
        utcOffset = static_cast<int>(inTm.tm_gmtoff);
#else
        utcOffset = static_cast<int>(getUTCOffset(exec) / WTF::msPerSecond + (isDST ? WTF::secondsPerHour : 0));
#endif

#if HAVE(TM_ZONE)
        int inZoneSize = strlen(inTm.tm_zone) + 1;
        timeZone = adoptArrayPtr(new char[inZoneSize]);
        strncpy(timeZone.get(), inTm.tm_zone, inZoneSize);
#else
        timeZone = nullptr;
#endif
    }

    operator tm() const
    {
        tm ret;
        memset(&ret, 0, sizeof(ret));

        ret.tm_sec   =  second;
        ret.tm_min   =  minute;
        ret.tm_hour  =  hour;
        ret.tm_wday  =  weekDay;
        ret.tm_mday  =  monthDay;
        ret.tm_yday  =  yearDay;
        ret.tm_mon   =  month;
        ret.tm_year  =  year;
        ret.tm_isdst =  isDST;

#if HAVE(TM_GMTOFF)
        ret.tm_gmtoff = static_cast<long>(utcOffset);
#endif
#if HAVE(TM_ZONE)
        ret.tm_zone = timeZone.get();
#endif

        return ret;
    }

    void copyFrom(const GregorianDateTime& rhs)
    {
        second = rhs.second;
        minute = rhs.minute;
        hour = rhs.hour;
        weekDay = rhs.weekDay;
        monthDay = rhs.monthDay;
        yearDay = rhs.yearDay;
        month = rhs.month;
        year = rhs.year;
        isDST = rhs.isDST;
        utcOffset = rhs.utcOffset;
        if (rhs.timeZone) {
            int inZoneSize = strlen(rhs.timeZone.get()) + 1;
            timeZone = adoptArrayPtr(new char[inZoneSize]);
            strncpy(timeZone.get(), rhs.timeZone.get(), inZoneSize);
        } else
            timeZone = nullptr;
    }

    int second;
    int minute;
    int hour;
    int weekDay;
    int monthDay;
    int yearDay;
    int month;
    int year;
    int isDST;
    int utcOffset;
    OwnArrayPtr<char> timeZone;
};

static inline int gmtoffset(const GregorianDateTime& t)
{
    return t.utcOffset;
}

} // namespace JSC

#endif // JSDateMath_h
