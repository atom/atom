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

@class DOMDocument;
@class DOMRange;

namespace WebCore {
    class DocumentLoader;
    class Range;
}

@interface WebHTMLConverter : NSObject {
    NSMutableAttributedString *_attrStr;
    NSURL *_baseURL;
    DOMDocument *_document;
    DOMRange *_domRange;
    NSMutableArray *_domStartAncestors;
    WebCore::DocumentLoader *_dataSource;
    NSString *_standardFontFamily;
    CGFloat _textSizeMultiplier;
    CGFloat _webViewTextSizeMultiplier;
    CGFloat _defaultTabInterval;
    CGFloat _defaultFontSize;
    CGFloat _minimumFontSize;
    NSMutableArray *_textLists;
    NSMutableArray *_textBlocks;
    NSMutableArray *_textTables;
    NSMutableDictionary *_textTableFooters;
    NSMutableArray *_textTableSpacings;
    NSMutableArray *_textTablePaddings;
    NSMutableArray *_textTableRows;
    NSMutableArray *_textTableRowArrays;
    NSMutableArray *_textTableRowBackgroundColors;
    NSMutableDictionary *_computedStylesForElements;
    NSMutableDictionary *_specifiedStylesForElements;
    NSMutableDictionary *_stringsForNodes;
    NSMutableDictionary *_floatsForNodes;
    NSMutableDictionary *_colorsForNodes;
    NSMutableDictionary *_attributesForElements;
    NSMutableDictionary *_elementIsBlockLevel;
    NSMutableDictionary *_fontCache;
    NSMutableArray *_writingDirectionArray;
    NSUInteger _domRangeStartIndex;
    NSInteger _indexingLimit;
    NSUInteger _thumbnailLimit;
    NSInteger _errorCode;
    NSInteger _quoteLevel;

    struct {
        unsigned int isSoft:1;
        unsigned int reachedStart:1;
        unsigned int reachedEnd:1;
        unsigned int isIndexing:1;
        unsigned int isTesting:1;
        unsigned int hasTrailingNewline:1;
        unsigned int pad:26;
    } _flags;
}

#if !defined(BUILDING_ON_LEOPARD)
- (id)init;
- (id)initWithDOMRange:(DOMRange *)domRange;

- (NSAttributedString *)attributedString;
#endif

+ (NSAttributedString *)editingAttributedStringFromRange:(WebCore::Range*)range;
@end

