/*
 * Copyright (C) 2007 Apple Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1.  Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer. 
 * 2.  Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution. 
 * 3.  Neither the name of Apple Computer, Inc. ("Apple") nor the names of
 *     its contributors may be used to endorse or promote products derived
 *     from this software without specific prior written permission. 
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE AND ITS CONTRIBUTORS "AS IS" AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL APPLE OR ITS CONTRIBUTORS BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef AnimationController_h
#define AnimationController_h

#include "CSSPropertyNames.h"
#include <wtf/Forward.h>
#include <wtf/OwnPtr.h>

namespace WebCore {

class AnimationBase;
class AnimationControllerPrivate;
class Document;
class Element;
class Frame;
class Node;
class RenderObject;
class RenderStyle;
class WebKitAnimationList;

class AnimationController {
public:
    AnimationController(Frame*);
    ~AnimationController();

    void cancelAnimations(RenderObject*);
    PassRefPtr<RenderStyle> updateAnimations(RenderObject*, RenderStyle* newStyle);
    PassRefPtr<RenderStyle> getAnimatedStyleForRenderer(RenderObject*);

    // This is called when an accelerated animation or transition has actually started to animate.
    void notifyAnimationStarted(RenderObject*, double startTime);

    bool pauseAnimationAtTime(RenderObject*, const String& name, double t); // To be used only for testing
    bool pauseTransitionAtTime(RenderObject*, const String& property, double t); // To be used only for testing
    unsigned numberOfActiveAnimations(Document*) const; // To be used only for testing
    
    bool isRunningAnimationOnRenderer(RenderObject*, CSSPropertyID, bool isRunningNow = true) const;
    bool isRunningAcceleratedAnimationOnRenderer(RenderObject*, CSSPropertyID, bool isRunningNow = true) const;

    void suspendAnimations();
    void resumeAnimations();

    void suspendAnimationsForDocument(Document*);
    void resumeAnimationsForDocument(Document*);

    void beginAnimationUpdate();
    void endAnimationUpdate();
    
    static bool supportsAcceleratedAnimationOfProperty(CSSPropertyID);

    PassRefPtr<WebKitAnimationList> animationsForRenderer(RenderObject*) const;

private:
    OwnPtr<AnimationControllerPrivate> m_data;
};

} // namespace WebCore

#endif // AnimationController_h
