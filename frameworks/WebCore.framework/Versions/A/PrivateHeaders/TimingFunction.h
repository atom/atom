/*
 * Copyright (C) 2000 Lars Knoll (knoll@kde.org)
 *           (C) 2000 Antti Koivisto (koivisto@kde.org)
 *           (C) 2000 Dirk Mueller (mueller@kde.org)
 * Copyright (C) 2003, 2005, 2006, 2007, 2008 Apple Inc. All rights reserved.
 * Copyright (C) 2006 Graham Dennis (graham.dennis@gmail.com)
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public License
 * along with this library; see the file COPYING.LIB.  If not, write to
 * the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 *
 */

#ifndef TimingFunction_h
#define TimingFunction_h

#include <wtf/RefCounted.h>

namespace WebCore {

class TimingFunction : public RefCounted<TimingFunction> {
public:

    enum TimingFunctionType {
        LinearFunction, CubicBezierFunction, StepsFunction
    };
    
    virtual ~TimingFunction() { }

    TimingFunctionType type() const { return m_type; }
    
    bool isLinearTimingFunction() const { return m_type == LinearFunction; }
    bool isCubicBezierTimingFunction() const { return m_type == CubicBezierFunction; }
    bool isStepsTimingFunction() const { return m_type == StepsFunction; }
    
    virtual bool operator==(const TimingFunction& other) = 0;

protected:
    TimingFunction(TimingFunctionType type)
        : m_type(type)
    {
    }
    
    TimingFunctionType m_type;
};

class LinearTimingFunction : public TimingFunction {
public:
    static PassRefPtr<LinearTimingFunction> create()
    {
        return adoptRef(new LinearTimingFunction);
    }
    
    ~LinearTimingFunction() { }
    
    virtual bool operator==(const TimingFunction& other)
    {
        return other.isLinearTimingFunction();
    }
    
private:
    LinearTimingFunction()
        : TimingFunction(LinearFunction)
    {
    }
};
    
class CubicBezierTimingFunction : public TimingFunction {
public:
    static PassRefPtr<CubicBezierTimingFunction> create(double x1, double y1, double x2, double y2)
    {
        return adoptRef(new CubicBezierTimingFunction(x1, y1, x2, y2));
    }

    static PassRefPtr<CubicBezierTimingFunction> create()
    {
        return adoptRef(new CubicBezierTimingFunction());
    }

    ~CubicBezierTimingFunction() { }
    
    virtual bool operator==(const TimingFunction& other)
    {
        if (other.isCubicBezierTimingFunction()) {
            const CubicBezierTimingFunction* ctf = static_cast<const CubicBezierTimingFunction*>(&other);
            return m_x1 == ctf->m_x1 && m_y1 == ctf->m_y1 && m_x2 == ctf->m_x2 && m_y2 == ctf->m_y2;
        }
        return false;
    }

    double x1() const { return m_x1; }
    double y1() const { return m_y1; }
    double x2() const { return m_x2; }
    double y2() const { return m_y2; }
    
    static const CubicBezierTimingFunction* defaultTimingFunction()
    {
        static const CubicBezierTimingFunction* dtf = create().leakRef();
        return dtf;
    }
    
private:
    CubicBezierTimingFunction(double x1 = 0.25, double y1 = 0.1, double x2 = 0.25, double y2 = 1.0)
        : TimingFunction(CubicBezierFunction)
        , m_x1(x1)
        , m_y1(y1)
        , m_x2(x2)
        , m_y2(y2)
    {
    }

    double m_x1;
    double m_y1;
    double m_x2;
    double m_y2;
};

class StepsTimingFunction : public TimingFunction {
public:
    static PassRefPtr<StepsTimingFunction> create(int steps, bool stepAtStart)
    {
        return adoptRef(new StepsTimingFunction(steps, stepAtStart));
    }
    
    ~StepsTimingFunction() { }
    
    virtual bool operator==(const TimingFunction& other)
    {
        if (other.isStepsTimingFunction()) {
            const StepsTimingFunction* stf = static_cast<const StepsTimingFunction*>(&other);
            return m_steps == stf->m_steps && m_stepAtStart == stf->m_stepAtStart;
        }
        return false;
    }
    
    int numberOfSteps() const { return m_steps; }
    bool stepAtStart() const { return m_stepAtStart; }
    
private:
    StepsTimingFunction(int steps, bool stepAtStart)
        : TimingFunction(StepsFunction)
        , m_steps(steps)
        , m_stepAtStart(stepAtStart)
    {
    }
    
    int m_steps;
    bool m_stepAtStart;
};
    
} // namespace WebCore

#endif // TimingFunction_h
