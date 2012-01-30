/*
 * Copyright (C) 2010 Apple Inc. All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE COMPUTER, INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 */

#ifndef PlatformCAAnimation_h
#define PlatformCAAnimation_h

#if USE(ACCELERATED_COMPOSITING)

#include "Color.h"
#include "FloatPoint3D.h"
#include "TransformationMatrix.h"
#include <wtf/RefCounted.h>
#include <wtf/RetainPtr.h>
#include <wtf/Vector.h>

#if PLATFORM(MAC)
OBJC_CLASS CAPropertyAnimation;
typedef CAPropertyAnimation* PlatformAnimationRef;
#elif PLATFORM(WIN)
typedef struct _CACFAnimation* CACFAnimationRef;
typedef CACFAnimationRef PlatformAnimationRef;
#endif

namespace WebCore {

class FloatRect;
class PlatformCAAnimation;
class TimingFunction;

class PlatformCAAnimation : public RefCounted<PlatformCAAnimation> {
public:
    friend class PlatformCALayer;
    
    enum AnimationType { Basic, Keyframe };
    enum FillModeType { NoFillMode, Forwards, Backwards, Both };
    enum ValueFunctionType { NoValueFunction, RotateX, RotateY, RotateZ, ScaleX, ScaleY, ScaleZ, Scale, TranslateX, TranslateY, TranslateZ, Translate };

    static PassRefPtr<PlatformCAAnimation> create(AnimationType, const String& keyPath);
    static PassRefPtr<PlatformCAAnimation> create(PlatformAnimationRef);

    ~PlatformCAAnimation();
    
    static bool supportsValueFunction();
    
    PassRefPtr<PlatformCAAnimation> copy() const;

    PlatformAnimationRef platformAnimation() const;
    
    AnimationType animationType() const { return m_type; }
    String keyPath() const;
    
    CFTimeInterval beginTime() const;
    void setBeginTime(CFTimeInterval);
    
    CFTimeInterval duration() const;
    void setDuration(CFTimeInterval);
    
    float speed() const;
    void setSpeed(float);

    CFTimeInterval timeOffset() const;
    void setTimeOffset(CFTimeInterval);

    float repeatCount() const;
    void setRepeatCount(float);

    bool autoreverses() const;
    void setAutoreverses(bool);

    FillModeType fillMode() const;
    void setFillMode(FillModeType);
    
    void setTimingFunction(const TimingFunction*);
    void copyTimingFunctionFrom(const PlatformCAAnimation*);

    bool isRemovedOnCompletion() const;
    void setRemovedOnCompletion(bool);

    bool isAdditive() const;
    void setAdditive(bool);

    ValueFunctionType valueFunction() const;
    void setValueFunction(ValueFunctionType);

    // Basic-animation properties.
    void setFromValue(float);
    void setFromValue(const WebCore::TransformationMatrix&);
    void setFromValue(const FloatPoint3D&);
    void setFromValue(const WebCore::Color&);
    void copyFromValueFrom(const PlatformCAAnimation*);

    void setToValue(float);
    void setToValue(const WebCore::TransformationMatrix&);
    void setToValue(const FloatPoint3D&);
    void setToValue(const WebCore::Color&);
    void copyToValueFrom(const PlatformCAAnimation*);

    // Keyframe-animation properties.
    void setValues(const Vector<float>&);
    void setValues(const Vector<WebCore::TransformationMatrix>&);
    void setValues(const Vector<FloatPoint3D>&);
    void setValues(const Vector<WebCore::Color>&);
    void copyValuesFrom(const PlatformCAAnimation*);

    void setKeyTimes(const Vector<float>&);
    void copyKeyTimesFrom(const PlatformCAAnimation*);

    void setTimingFunctions(const Vector<const TimingFunction*>&);
    void copyTimingFunctionsFrom(const PlatformCAAnimation*);
    
protected:
    PlatformCAAnimation(AnimationType, const String& keyPath);
    PlatformCAAnimation(PlatformAnimationRef);

    void setActualStartTimeIfNeeded(CFTimeInterval t)
    {
        if (beginTime() <= 0)
            setBeginTime(t);
    }
    
private:
    AnimationType m_type;
    
#if PLATFORM(MAC)
    RetainPtr<CAPropertyAnimation> m_animation;
#elif PLATFORM(WIN)
    RetainPtr<CACFAnimationRef> m_animation;
#endif
};

}

#endif // USE(ACCELERATED_COMPOSITING)

#endif // PlatformCAAnimation_h
