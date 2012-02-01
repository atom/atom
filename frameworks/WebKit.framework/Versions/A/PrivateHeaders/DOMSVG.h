/*
 * Copyright (C) 2006 Apple Computer, Inc.  All rights reserved.
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

#import <WebKit/DOMSVGAElement.h>
#import <WebKit/DOMSVGAltGlyphDefElement.h>
#import <WebKit/DOMSVGAltGlyphElement.h>
#import <WebKit/DOMSVGAltGlyphItemElement.h>
#import <WebKit/DOMSVGAngle.h>
#import <WebKit/DOMSVGAnimateColorElement.h>
#import <WebKit/DOMSVGAnimateElement.h>
#import <WebKit/DOMSVGAnimateTransformElement.h>
#import <WebKit/DOMSVGAnimatedAngle.h>
#import <WebKit/DOMSVGAnimatedBoolean.h>
#import <WebKit/DOMSVGAnimatedEnumeration.h>
#import <WebKit/DOMSVGAnimatedInteger.h>
#import <WebKit/DOMSVGAnimatedLength.h>
#import <WebKit/DOMSVGAnimatedLengthList.h>
#import <WebKit/DOMSVGAnimatedNumber.h>
#import <WebKit/DOMSVGAnimatedNumberList.h>
#import <WebKit/DOMSVGAnimatedPreserveAspectRatio.h>
#import <WebKit/DOMSVGAnimatedRect.h>
#import <WebKit/DOMSVGAnimatedString.h>
#import <WebKit/DOMSVGAnimatedTransformList.h>
#import <WebKit/DOMSVGAnimationElement.h>
#import <WebKit/DOMSVGCircleElement.h>
#import <WebKit/DOMSVGClipPathElement.h>
#import <WebKit/DOMSVGColor.h>
#import <WebKit/DOMSVGComponentTransferFunctionElement.h>
#import <WebKit/DOMSVGCursorElement.h>
#import <WebKit/DOMSVGDefsElement.h>
#import <WebKit/DOMSVGDescElement.h>
#import <WebKit/DOMSVGDocument.h>
#import <WebKit/DOMSVGElement.h>
#import <WebKit/DOMSVGElementInstance.h>
#import <WebKit/DOMSVGElementInstanceList.h>
#import <WebKit/DOMSVGEllipseElement.h>
#import <WebKit/DOMSVGException.h>
#import <WebKit/DOMSVGExternalResourcesRequired.h>
#import <WebKit/DOMSVGFEBlendElement.h>
#import <WebKit/DOMSVGFEColorMatrixElement.h>
#import <WebKit/DOMSVGFEComponentTransferElement.h>
#import <WebKit/DOMSVGFECompositeElement.h>
#import <WebKit/DOMSVGFEConvolveMatrixElement.h>
#import <WebKit/DOMSVGFEDiffuseLightingElement.h>
#import <WebKit/DOMSVGFEDisplacementMapElement.h>
#import <WebKit/DOMSVGFEDistantLightElement.h>
#import <WebKit/DOMSVGFEDropShadowElement.h>
#import <WebKit/DOMSVGFEFloodElement.h>
#import <WebKit/DOMSVGFEFuncAElement.h>
#import <WebKit/DOMSVGFEFuncBElement.h>
#import <WebKit/DOMSVGFEFuncGElement.h>
#import <WebKit/DOMSVGFEFuncRElement.h>
#import <WebKit/DOMSVGFEGaussianBlurElement.h>
#import <WebKit/DOMSVGFEImageElement.h>
#import <WebKit/DOMSVGFEMergeElement.h>
#import <WebKit/DOMSVGFEMergeNodeElement.h>
#import <WebKit/DOMSVGFEMorphologyElement.h>
#import <WebKit/DOMSVGFEOffsetElement.h>
#import <WebKit/DOMSVGFEPointLightElement.h>
#import <WebKit/DOMSVGFESpecularLightingElement.h>
#import <WebKit/DOMSVGFESpotLightElement.h>
#import <WebKit/DOMSVGFETileElement.h>
#import <WebKit/DOMSVGFETurbulenceElement.h>
#import <WebKit/DOMSVGFilterElement.h>
#import <WebKit/DOMSVGFilterPrimitiveStandardAttributes.h>
#import <WebKit/DOMSVGFitToViewBox.h>
#import <WebKit/DOMSVGFontElement.h>
#import <WebKit/DOMSVGFontFaceElement.h>
#import <WebKit/DOMSVGFontFaceFormatElement.h>
#import <WebKit/DOMSVGFontFaceNameElement.h>
#import <WebKit/DOMSVGFontFaceSrcElement.h>
#import <WebKit/DOMSVGFontFaceUriElement.h>
#import <WebKit/DOMSVGForeignObjectElement.h>
#import <WebKit/DOMSVGGElement.h>
#import <WebKit/DOMSVGGlyphElement.h>
#import <WebKit/DOMSVGGlyphRefElement.h>
#import <WebKit/DOMSVGGradientElement.h>
#import <WebKit/DOMSVGImageElement.h>
#import <WebKit/DOMSVGLangSpace.h>
#import <WebKit/DOMSVGLength.h>
#import <WebKit/DOMSVGLengthList.h>
#import <WebKit/DOMSVGLineElement.h>
#import <WebKit/DOMSVGLinearGradientElement.h>
#import <WebKit/DOMSVGLocatable.h>
#import <WebKit/DOMSVGMarkerElement.h>
#import <WebKit/DOMSVGMaskElement.h>
#import <WebKit/DOMSVGMatrix.h>
#import <WebKit/DOMSVGMetadataElement.h>
#import <WebKit/DOMSVGMissingGlyphElement.h>
#import <WebKit/DOMSVGNumber.h>
#import <WebKit/DOMSVGNumberList.h>
#import <WebKit/DOMSVGPaint.h>
#import <WebKit/DOMSVGPathElement.h>
#import <WebKit/DOMSVGPathSeg.h>
#import <WebKit/DOMSVGPathSegArcAbs.h>
#import <WebKit/DOMSVGPathSegArcRel.h>
#import <WebKit/DOMSVGPathSegClosePath.h>
#import <WebKit/DOMSVGPathSegCurvetoCubicAbs.h>
#import <WebKit/DOMSVGPathSegCurvetoCubicRel.h>
#import <WebKit/DOMSVGPathSegCurvetoCubicSmoothAbs.h>
#import <WebKit/DOMSVGPathSegCurvetoCubicSmoothRel.h>
#import <WebKit/DOMSVGPathSegCurvetoQuadraticAbs.h>
#import <WebKit/DOMSVGPathSegCurvetoQuadraticRel.h>
#import <WebKit/DOMSVGPathSegCurvetoQuadraticSmoothAbs.h>
#import <WebKit/DOMSVGPathSegCurvetoQuadraticSmoothRel.h>
#import <WebKit/DOMSVGPathSegLinetoAbs.h>
#import <WebKit/DOMSVGPathSegLinetoHorizontalAbs.h>
#import <WebKit/DOMSVGPathSegLinetoHorizontalRel.h>
#import <WebKit/DOMSVGPathSegLinetoRel.h>
#import <WebKit/DOMSVGPathSegLinetoVerticalAbs.h>
#import <WebKit/DOMSVGPathSegLinetoVerticalRel.h>
#import <WebKit/DOMSVGPathSegList.h>
#import <WebKit/DOMSVGPathSegMovetoAbs.h>
#import <WebKit/DOMSVGPathSegMovetoRel.h>
#import <WebKit/DOMSVGPatternElement.h>
#import <WebKit/DOMSVGPoint.h>
#import <WebKit/DOMSVGPointList.h>
#import <WebKit/DOMSVGPolygonElement.h>
#import <WebKit/DOMSVGPolylineElement.h>
#import <WebKit/DOMSVGPreserveAspectRatio.h>
#import <WebKit/DOMSVGRadialGradientElement.h>
#import <WebKit/DOMSVGRect.h>
#import <WebKit/DOMSVGRectElement.h>
#import <WebKit/DOMSVGRenderingIntent.h>
#import <WebKit/DOMSVGSVGElement.h>
#import <WebKit/DOMSVGScriptElement.h>
#import <WebKit/DOMSVGSetElement.h>
#import <WebKit/DOMSVGStopElement.h>
#import <WebKit/DOMSVGStringList.h>
#import <WebKit/DOMSVGStylable.h>
#import <WebKit/DOMSVGStyleElement.h>
#import <WebKit/DOMSVGSwitchElement.h>
#import <WebKit/DOMSVGSymbolElement.h>
#import <WebKit/DOMSVGTRefElement.h>
#import <WebKit/DOMSVGTSpanElement.h>
#import <WebKit/DOMSVGTests.h>
#import <WebKit/DOMSVGTextContentElement.h>
#import <WebKit/DOMSVGTextElement.h>
#import <WebKit/DOMSVGTextPathElement.h>
#import <WebKit/DOMSVGTextPositioningElement.h>
#import <WebKit/DOMSVGTitleElement.h>
#import <WebKit/DOMSVGTransform.h>
#import <WebKit/DOMSVGTransformList.h>
#import <WebKit/DOMSVGTransformable.h>
#import <WebKit/DOMSVGURIReference.h>
#import <WebKit/DOMSVGUnitTypes.h>
#import <WebKit/DOMSVGUseElement.h>
#import <WebKit/DOMSVGViewElement.h>
#import <WebKit/DOMSVGZoomAndPan.h>
#import <WebKit/DOMSVGZoomEvent.h>
