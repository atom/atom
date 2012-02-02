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

#import <WebCore/DOMSVGAElement.h>
#import <WebCore/DOMSVGAltGlyphDefElement.h>
#import <WebCore/DOMSVGAltGlyphElement.h>
#import <WebCore/DOMSVGAltGlyphItemElement.h>
#import <WebCore/DOMSVGAngle.h>
#import <WebCore/DOMSVGAnimateColorElement.h>
#import <WebCore/DOMSVGAnimateElement.h>
#import <WebCore/DOMSVGAnimateTransformElement.h>
#import <WebCore/DOMSVGAnimatedAngle.h>
#import <WebCore/DOMSVGAnimatedBoolean.h>
#import <WebCore/DOMSVGAnimatedEnumeration.h>
#import <WebCore/DOMSVGAnimatedInteger.h>
#import <WebCore/DOMSVGAnimatedLength.h>
#import <WebCore/DOMSVGAnimatedLengthList.h>
#import <WebCore/DOMSVGAnimatedNumber.h>
#import <WebCore/DOMSVGAnimatedNumberList.h>
#import <WebCore/DOMSVGAnimatedPreserveAspectRatio.h>
#import <WebCore/DOMSVGAnimatedRect.h>
#import <WebCore/DOMSVGAnimatedString.h>
#import <WebCore/DOMSVGAnimatedTransformList.h>
#import <WebCore/DOMSVGAnimationElement.h>
#import <WebCore/DOMSVGCircleElement.h>
#import <WebCore/DOMSVGClipPathElement.h>
#import <WebCore/DOMSVGColor.h>
#import <WebCore/DOMSVGComponentTransferFunctionElement.h>
#import <WebCore/DOMSVGCursorElement.h>
#import <WebCore/DOMSVGDefsElement.h>
#import <WebCore/DOMSVGDescElement.h>
#import <WebCore/DOMSVGDocument.h>
#import <WebCore/DOMSVGElement.h>
#import <WebCore/DOMSVGElementInstance.h>
#import <WebCore/DOMSVGElementInstanceList.h>
#import <WebCore/DOMSVGEllipseElement.h>
#import <WebCore/DOMSVGException.h>
#import <WebCore/DOMSVGExternalResourcesRequired.h>
#import <WebCore/DOMSVGFEBlendElement.h>
#import <WebCore/DOMSVGFEColorMatrixElement.h>
#import <WebCore/DOMSVGFEComponentTransferElement.h>
#import <WebCore/DOMSVGFECompositeElement.h>
#import <WebCore/DOMSVGFEConvolveMatrixElement.h>
#import <WebCore/DOMSVGFEDiffuseLightingElement.h>
#import <WebCore/DOMSVGFEDisplacementMapElement.h>
#import <WebCore/DOMSVGFEDistantLightElement.h>
#import <WebCore/DOMSVGFEDropShadowElement.h>
#import <WebCore/DOMSVGFEFloodElement.h>
#import <WebCore/DOMSVGFEFuncAElement.h>
#import <WebCore/DOMSVGFEFuncBElement.h>
#import <WebCore/DOMSVGFEFuncGElement.h>
#import <WebCore/DOMSVGFEFuncRElement.h>
#import <WebCore/DOMSVGFEGaussianBlurElement.h>
#import <WebCore/DOMSVGFEImageElement.h>
#import <WebCore/DOMSVGFEMergeElement.h>
#import <WebCore/DOMSVGFEMergeNodeElement.h>
#import <WebCore/DOMSVGFEMorphologyElement.h>
#import <WebCore/DOMSVGFEOffsetElement.h>
#import <WebCore/DOMSVGFEPointLightElement.h>
#import <WebCore/DOMSVGFESpecularLightingElement.h>
#import <WebCore/DOMSVGFESpotLightElement.h>
#import <WebCore/DOMSVGFETileElement.h>
#import <WebCore/DOMSVGFETurbulenceElement.h>
#import <WebCore/DOMSVGFilterElement.h>
#import <WebCore/DOMSVGFilterPrimitiveStandardAttributes.h>
#import <WebCore/DOMSVGFitToViewBox.h>
#import <WebCore/DOMSVGFontElement.h>
#import <WebCore/DOMSVGFontFaceElement.h>
#import <WebCore/DOMSVGFontFaceFormatElement.h>
#import <WebCore/DOMSVGFontFaceNameElement.h>
#import <WebCore/DOMSVGFontFaceSrcElement.h>
#import <WebCore/DOMSVGFontFaceUriElement.h>
#import <WebCore/DOMSVGForeignObjectElement.h>
#import <WebCore/DOMSVGGElement.h>
#import <WebCore/DOMSVGGlyphElement.h>
#import <WebCore/DOMSVGGlyphRefElement.h>
#import <WebCore/DOMSVGGradientElement.h>
#import <WebCore/DOMSVGImageElement.h>
#import <WebCore/DOMSVGLangSpace.h>
#import <WebCore/DOMSVGLength.h>
#import <WebCore/DOMSVGLengthList.h>
#import <WebCore/DOMSVGLineElement.h>
#import <WebCore/DOMSVGLinearGradientElement.h>
#import <WebCore/DOMSVGLocatable.h>
#import <WebCore/DOMSVGMarkerElement.h>
#import <WebCore/DOMSVGMaskElement.h>
#import <WebCore/DOMSVGMatrix.h>
#import <WebCore/DOMSVGMetadataElement.h>
#import <WebCore/DOMSVGMissingGlyphElement.h>
#import <WebCore/DOMSVGNumber.h>
#import <WebCore/DOMSVGNumberList.h>
#import <WebCore/DOMSVGPaint.h>
#import <WebCore/DOMSVGPathElement.h>
#import <WebCore/DOMSVGPathSeg.h>
#import <WebCore/DOMSVGPathSegArcAbs.h>
#import <WebCore/DOMSVGPathSegArcRel.h>
#import <WebCore/DOMSVGPathSegClosePath.h>
#import <WebCore/DOMSVGPathSegCurvetoCubicAbs.h>
#import <WebCore/DOMSVGPathSegCurvetoCubicRel.h>
#import <WebCore/DOMSVGPathSegCurvetoCubicSmoothAbs.h>
#import <WebCore/DOMSVGPathSegCurvetoCubicSmoothRel.h>
#import <WebCore/DOMSVGPathSegCurvetoQuadraticAbs.h>
#import <WebCore/DOMSVGPathSegCurvetoQuadraticRel.h>
#import <WebCore/DOMSVGPathSegCurvetoQuadraticSmoothAbs.h>
#import <WebCore/DOMSVGPathSegCurvetoQuadraticSmoothRel.h>
#import <WebCore/DOMSVGPathSegLinetoAbs.h>
#import <WebCore/DOMSVGPathSegLinetoHorizontalAbs.h>
#import <WebCore/DOMSVGPathSegLinetoHorizontalRel.h>
#import <WebCore/DOMSVGPathSegLinetoRel.h>
#import <WebCore/DOMSVGPathSegLinetoVerticalAbs.h>
#import <WebCore/DOMSVGPathSegLinetoVerticalRel.h>
#import <WebCore/DOMSVGPathSegList.h>
#import <WebCore/DOMSVGPathSegMovetoAbs.h>
#import <WebCore/DOMSVGPathSegMovetoRel.h>
#import <WebCore/DOMSVGPatternElement.h>
#import <WebCore/DOMSVGPoint.h>
#import <WebCore/DOMSVGPointList.h>
#import <WebCore/DOMSVGPolygonElement.h>
#import <WebCore/DOMSVGPolylineElement.h>
#import <WebCore/DOMSVGPreserveAspectRatio.h>
#import <WebCore/DOMSVGRadialGradientElement.h>
#import <WebCore/DOMSVGRect.h>
#import <WebCore/DOMSVGRectElement.h>
#import <WebCore/DOMSVGRenderingIntent.h>
#import <WebCore/DOMSVGSVGElement.h>
#import <WebCore/DOMSVGScriptElement.h>
#import <WebCore/DOMSVGSetElement.h>
#import <WebCore/DOMSVGStopElement.h>
#import <WebCore/DOMSVGStringList.h>
#import <WebCore/DOMSVGStylable.h>
#import <WebCore/DOMSVGStyleElement.h>
#import <WebCore/DOMSVGSwitchElement.h>
#import <WebCore/DOMSVGSymbolElement.h>
#import <WebCore/DOMSVGTRefElement.h>
#import <WebCore/DOMSVGTSpanElement.h>
#import <WebCore/DOMSVGTests.h>
#import <WebCore/DOMSVGTextContentElement.h>
#import <WebCore/DOMSVGTextElement.h>
#import <WebCore/DOMSVGTextPathElement.h>
#import <WebCore/DOMSVGTextPositioningElement.h>
#import <WebCore/DOMSVGTitleElement.h>
#import <WebCore/DOMSVGTransform.h>
#import <WebCore/DOMSVGTransformList.h>
#import <WebCore/DOMSVGTransformable.h>
#import <WebCore/DOMSVGURIReference.h>
#import <WebCore/DOMSVGUnitTypes.h>
#import <WebCore/DOMSVGUseElement.h>
#import <WebCore/DOMSVGViewElement.h>
#import <WebCore/DOMSVGZoomAndPan.h>
#import <WebCore/DOMSVGZoomEvent.h>
