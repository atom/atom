/*
 * Copyright (C) 2004, 2005, 2006, 2007, 2008, 2009 Apple Inc. All rights reserved.
 * Copyright (C) 2006 Samuel Weinig <sam.weinig@gmail.com>
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
 * THIS SOFTWARE IS PROVIDED BY APPLE COMPUTER, INC. ``AS IS'' AND ANY
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

#import <WebKit/DOMSVGElement.h>
#import <WebKit/DOMSVGTests.h>
#import <WebKit/DOMSVGLangSpace.h>
#import <WebKit/DOMSVGExternalResourcesRequired.h>
#import <WebKit/DOMSVGStylable.h>
#import <WebKit/DOMSVGLocatable.h>
#import <WebKit/DOMSVGFitToViewBox.h>
#import <WebKit/DOMSVGZoomAndPan.h>

#if WEBKIT_VERSION_MAX_ALLOWED >= WEBKIT_VERSION_LATEST

@class DOMElement;
@class DOMNodeList;
@class DOMSVGAngle;
@class DOMSVGAnimatedLength;
@class DOMSVGElement;
@class DOMSVGLength;
@class DOMSVGMatrix;
@class DOMSVGNumber;
@class DOMSVGPoint;
@class DOMSVGRect;
@class DOMSVGTransform;
@class NSString;

@interface DOMSVGSVGElement : DOMSVGElement <DOMSVGTests, DOMSVGLangSpace, DOMSVGExternalResourcesRequired, DOMSVGStylable, DOMSVGLocatable, DOMSVGFitToViewBox, DOMSVGZoomAndPan>
@property(readonly, retain) DOMSVGAnimatedLength *x;
@property(readonly, retain) DOMSVGAnimatedLength *y;
@property(readonly, retain) DOMSVGAnimatedLength *width;
@property(readonly, retain) DOMSVGAnimatedLength *height;
@property(copy) NSString *contentScriptType;
@property(copy) NSString *contentStyleType;
@property(readonly, retain) DOMSVGRect *viewport;
@property(readonly) float pixelUnitToMillimeterX;
@property(readonly) float pixelUnitToMillimeterY;
@property(readonly) float screenPixelToMillimeterX;
@property(readonly) float screenPixelToMillimeterY;
@property BOOL useCurrentView;
@property float currentScale;
@property(readonly, retain) DOMSVGPoint *currentTranslate;

- (unsigned)suspendRedraw:(unsigned)maxWaitMilliseconds;
- (void)unsuspendRedraw:(unsigned)suspendHandleId;
- (void)unsuspendRedrawAll;
- (void)forceRedraw;
- (void)pauseAnimations;
- (void)unpauseAnimations;
- (BOOL)animationsPaused;
- (float)getCurrentTime;
- (void)setCurrentTime:(float)seconds;
- (DOMNodeList *)getIntersectionList:(DOMSVGRect *)rect referenceElement:(DOMSVGElement *)referenceElement;
- (DOMNodeList *)getEnclosureList:(DOMSVGRect *)rect referenceElement:(DOMSVGElement *)referenceElement;
- (BOOL)checkIntersection:(DOMSVGElement *)element rect:(DOMSVGRect *)rect;
- (BOOL)checkEnclosure:(DOMSVGElement *)element rect:(DOMSVGRect *)rect;
- (void)deselectAll;
- (DOMSVGNumber *)createSVGNumber;
- (DOMSVGLength *)createSVGLength;
- (DOMSVGAngle *)createSVGAngle;
- (DOMSVGPoint *)createSVGPoint;
- (DOMSVGMatrix *)createSVGMatrix;
- (DOMSVGRect *)createSVGRect;
- (DOMSVGTransform *)createSVGTransform;
- (DOMSVGTransform *)createSVGTransformFromMatrix:(DOMSVGMatrix *)matrix;
- (DOMElement *)getElementById:(NSString *)elementId;
@end

#endif
