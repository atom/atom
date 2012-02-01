/*
 * Copyright (C) 2004 Apple Computer, Inc.  All rights reserved.
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

#import <WebCore/DOMCore.h>
#import <WebCore/DOMDocument.h>
#import <WebCore/DOMElement.h>
#import <WebCore/DOMObject.h>
#import <WebCore/DOMStylesheets.h>

#import <WebCore/DOMCSSCharsetRule.h>
#import <WebCore/DOMCSSFontFaceRule.h>
#import <WebCore/DOMCSSImportRule.h>
#import <WebCore/DOMCSSMediaRule.h>
#import <WebCore/DOMCSSPageRule.h>
#import <WebCore/DOMCSSPrimitiveValue.h>
#import <WebCore/DOMCSSRule.h>
#import <WebCore/DOMCSSRuleList.h>
#import <WebCore/DOMCSSStyleDeclaration.h>
#import <WebCore/DOMCSSStyleRule.h>
#import <WebCore/DOMCSSStyleSheet.h>
#import <WebCore/DOMCSSUnknownRule.h>
#import <WebCore/DOMCSSValue.h>
#import <WebCore/DOMCSSValueList.h>
#import <WebCore/DOMCounter.h>
#import <WebCore/DOMRGBColor.h>
#import <WebCore/DOMRect.h>

#if WEBKIT_VERSION_MAX_ALLOWED >= WEBKIT_VERSION_1_3

@interface DOMCSSStyleDeclaration (DOMCSS2Properties)
- (NSString *)azimuth;
- (void)setAzimuth:(NSString *)azimuth;
- (NSString *)background;
- (void)setBackground:(NSString *)background;
- (NSString *)backgroundAttachment;
- (void)setBackgroundAttachment:(NSString *)backgroundAttachment;
- (NSString *)backgroundColor;
- (void)setBackgroundColor:(NSString *)backgroundColor;
- (NSString *)backgroundImage;
- (void)setBackgroundImage:(NSString *)backgroundImage;
- (NSString *)backgroundPosition;
- (void)setBackgroundPosition:(NSString *)backgroundPosition;
- (NSString *)backgroundRepeat;
- (void)setBackgroundRepeat:(NSString *)backgroundRepeat;
- (NSString *)border;
- (void)setBorder:(NSString *)border;
- (NSString *)borderCollapse;
- (void)setBorderCollapse:(NSString *)borderCollapse;
- (NSString *)borderColor;
- (void)setBorderColor:(NSString *)borderColor;
- (NSString *)borderSpacing;
- (void)setBorderSpacing:(NSString *)borderSpacing;
- (NSString *)borderStyle;
- (void)setBorderStyle:(NSString *)borderStyle;
- (NSString *)borderTop;
- (void)setBorderTop:(NSString *)borderTop;
- (NSString *)borderRight;
- (void)setBorderRight:(NSString *)borderRight;
- (NSString *)borderBottom;
- (void)setBorderBottom:(NSString *)borderBottom;
- (NSString *)borderLeft;
- (void)setBorderLeft:(NSString *)borderLeft;
- (NSString *)borderTopColor;
- (void)setBorderTopColor:(NSString *)borderTopColor;
- (NSString *)borderRightColor;
- (void)setBorderRightColor:(NSString *)borderRightColor;
- (NSString *)borderBottomColor;
- (void)setBorderBottomColor:(NSString *)borderBottomColor;
- (NSString *)borderLeftColor;
- (void)setBorderLeftColor:(NSString *)borderLeftColor;
- (NSString *)borderTopStyle;
- (void)setBorderTopStyle:(NSString *)borderTopStyle;
- (NSString *)borderRightStyle;
- (void)setBorderRightStyle:(NSString *)borderRightStyle;
- (NSString *)borderBottomStyle;
- (void)setBorderBottomStyle:(NSString *)borderBottomStyle;
- (NSString *)borderLeftStyle;
- (void)setBorderLeftStyle:(NSString *)borderLeftStyle;
- (NSString *)borderTopWidth;
- (void)setBorderTopWidth:(NSString *)borderTopWidth;
- (NSString *)borderRightWidth;
- (void)setBorderRightWidth:(NSString *)borderRightWidth;
- (NSString *)borderBottomWidth;
- (void)setBorderBottomWidth:(NSString *)borderBottomWidth;
- (NSString *)borderLeftWidth;
- (void)setBorderLeftWidth:(NSString *)borderLeftWidth;
- (NSString *)borderWidth;
- (void)setBorderWidth:(NSString *)borderWidth;
- (NSString *)bottom;
- (void)setBottom:(NSString *)bottom;
- (NSString *)captionSide;
- (void)setCaptionSide:(NSString *)captionSide;
- (NSString *)clear;
- (void)setClear:(NSString *)clear;
- (NSString *)clip;
- (void)setClip:(NSString *)clip;
- (NSString *)color;
- (void)setColor:(NSString *)color;
- (NSString *)content;
- (void)setContent:(NSString *)content;
- (NSString *)counterIncrement;
- (void)setCounterIncrement:(NSString *)counterIncrement;
- (NSString *)counterReset;
- (void)setCounterReset:(NSString *)counterReset;
- (NSString *)cue;
- (void)setCue:(NSString *)cue;
- (NSString *)cueAfter;
- (void)setCueAfter:(NSString *)cueAfter;
- (NSString *)cueBefore;
- (void)setCueBefore:(NSString *)cueBefore;
- (NSString *)cursor;
- (void)setCursor:(NSString *)cursor;
- (NSString *)direction;
- (void)setDirection:(NSString *)direction;
- (NSString *)display;
- (void)setDisplay:(NSString *)display;
- (NSString *)elevation;
- (void)setElevation:(NSString *)elevation;
- (NSString *)emptyCells;
- (void)setEmptyCells:(NSString *)emptyCells;
- (NSString *)cssFloat;
- (void)setCssFloat:(NSString *)cssFloat;
- (NSString *)font;
- (void)setFont:(NSString *)font;
- (NSString *)fontFamily;
- (void)setFontFamily:(NSString *)fontFamily;
- (NSString *)fontSize;
- (void)setFontSize:(NSString *)fontSize;
- (NSString *)fontSizeAdjust;
- (void)setFontSizeAdjust:(NSString *)fontSizeAdjust;
- (NSString *)fontStretch;
- (void)setFontStretch:(NSString *)fontStretch;
- (NSString *)fontStyle;
- (void)setFontStyle:(NSString *)fontStyle;
- (NSString *)fontVariant;
- (void)setFontVariant:(NSString *)fontVariant;
- (NSString *)fontWeight;
- (void)setFontWeight:(NSString *)fontWeight;
- (NSString *)height;
- (void)setHeight:(NSString *)height;
- (NSString *)left;
- (void)setLeft:(NSString *)left;
- (NSString *)letterSpacing;
- (void)setLetterSpacing:(NSString *)letterSpacing;
- (NSString *)lineHeight;
- (void)setLineHeight:(NSString *)lineHeight;
- (NSString *)listStyle;
- (void)setListStyle:(NSString *)listStyle;
- (NSString *)listStyleImage;
- (void)setListStyleImage:(NSString *)listStyleImage;
- (NSString *)listStylePosition;
- (void)setListStylePosition:(NSString *)listStylePosition;
- (NSString *)listStyleType;
- (void)setListStyleType:(NSString *)listStyleType;
- (NSString *)margin;
- (void)setMargin:(NSString *)margin;
- (NSString *)marginTop;
- (void)setMarginTop:(NSString *)marginTop;
- (NSString *)marginRight;
- (void)setMarginRight:(NSString *)marginRight;
- (NSString *)marginBottom;
- (void)setMarginBottom:(NSString *)marginBottom;
- (NSString *)marginLeft;
- (void)setMarginLeft:(NSString *)marginLeft;
- (NSString *)markerOffset;
- (void)setMarkerOffset:(NSString *)markerOffset;
- (NSString *)marks;
- (void)setMarks:(NSString *)marks;
- (NSString *)maxHeight;
- (void)setMaxHeight:(NSString *)maxHeight;
- (NSString *)maxWidth;
- (void)setMaxWidth:(NSString *)maxWidth;
- (NSString *)minHeight;
- (void)setMinHeight:(NSString *)minHeight;
- (NSString *)minWidth;
- (void)setMinWidth:(NSString *)minWidth;
- (NSString *)orphans;
- (void)setOrphans:(NSString *)orphans;
- (NSString *)outline;
- (void)setOutline:(NSString *)outline;
- (NSString *)outlineColor;
- (void)setOutlineColor:(NSString *)outlineColor;
- (NSString *)outlineStyle;
- (void)setOutlineStyle:(NSString *)outlineStyle;
- (NSString *)outlineWidth;
- (void)setOutlineWidth:(NSString *)outlineWidth;
- (NSString *)overflow;
- (void)setOverflow:(NSString *)overflow;
- (NSString *)padding;
- (void)setPadding:(NSString *)padding;
- (NSString *)paddingTop;
- (void)setPaddingTop:(NSString *)paddingTop;
- (NSString *)paddingRight;
- (void)setPaddingRight:(NSString *)paddingRight;
- (NSString *)paddingBottom;
- (void)setPaddingBottom:(NSString *)paddingBottom;
- (NSString *)paddingLeft;
- (void)setPaddingLeft:(NSString *)paddingLeft;
- (NSString *)page;
- (void)setPage:(NSString *)page;
- (NSString *)pageBreakAfter;
- (void)setPageBreakAfter:(NSString *)pageBreakAfter;
- (NSString *)pageBreakBefore;
- (void)setPageBreakBefore:(NSString *)pageBreakBefore;
- (NSString *)pageBreakInside;
- (void)setPageBreakInside:(NSString *)pageBreakInside;
- (NSString *)pause;
- (void)setPause:(NSString *)pause;
- (NSString *)pauseAfter;
- (void)setPauseAfter:(NSString *)pauseAfter;
- (NSString *)pauseBefore;
- (void)setPauseBefore:(NSString *)pauseBefore;
- (NSString *)pitch;
- (void)setPitch:(NSString *)pitch;
- (NSString *)pitchRange;
- (void)setPitchRange:(NSString *)pitchRange;
- (NSString *)playDuring;
- (void)setPlayDuring:(NSString *)playDuring;
- (NSString *)position;
- (void)setPosition:(NSString *)position;
- (NSString *)quotes;
- (void)setQuotes:(NSString *)quotes;
- (NSString *)richness;
- (void)setRichness:(NSString *)richness;
- (NSString *)right;
- (void)setRight:(NSString *)right;
- (NSString *)size;
- (void)setSize:(NSString *)size;
- (NSString *)speak;
- (void)setSpeak:(NSString *)speak;
- (NSString *)speakHeader;
- (void)setSpeakHeader:(NSString *)speakHeader;
- (NSString *)speakNumeral;
- (void)setSpeakNumeral:(NSString *)speakNumeral;
- (NSString *)speakPunctuation;
- (void)setSpeakPunctuation:(NSString *)speakPunctuation;
- (NSString *)speechRate;
- (void)setSpeechRate:(NSString *)speechRate;
- (NSString *)stress;
- (void)setStress:(NSString *)stress;
- (NSString *)tableLayout;
- (void)setTableLayout:(NSString *)tableLayout;
- (NSString *)textAlign;
- (void)setTextAlign:(NSString *)textAlign;
- (NSString *)textDecoration;
- (void)setTextDecoration:(NSString *)textDecoration;
- (NSString *)textIndent;
- (void)setTextIndent:(NSString *)textIndent;
- (NSString *)textShadow;
- (void)setTextShadow:(NSString *)textShadow;
- (NSString *)textTransform;
- (void)setTextTransform:(NSString *)textTransform;
- (NSString *)top;
- (void)setTop:(NSString *)top;
- (NSString *)unicodeBidi;
- (void)setUnicodeBidi:(NSString *)unicodeBidi;
- (NSString *)verticalAlign;
- (void)setVerticalAlign:(NSString *)verticalAlign;
- (NSString *)visibility;
- (void)setVisibility:(NSString *)visibility;
- (NSString *)voiceFamily;
- (void)setVoiceFamily:(NSString *)voiceFamily;
- (NSString *)volume;
- (void)setVolume:(NSString *)volume;
- (NSString *)whiteSpace;
- (void)setWhiteSpace:(NSString *)whiteSpace;
- (NSString *)widows;
- (void)setWidows:(NSString *)widows;
- (NSString *)width;
- (void)setWidth:(NSString *)width;
- (NSString *)wordSpacing;
- (void)setWordSpacing:(NSString *)wordSpacing;
- (NSString *)zIndex;
- (void)setZIndex:(NSString *)zIndex;
@end

#endif
