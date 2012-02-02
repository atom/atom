/*
 * Copyright (C) 2008 Apple Inc. All Rights Reserved.
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
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 */

#ifndef FontTraitsMask_h
#define FontTraitsMask_h

namespace WebCore {

    enum {
        FontStyleNormalBit = 0,
        FontStyleItalicBit,
        FontVariantNormalBit,
        FontVariantSmallCapsBit,
        FontWeight100Bit,
        FontWeight200Bit,
        FontWeight300Bit,
        FontWeight400Bit,
        FontWeight500Bit,
        FontWeight600Bit,
        FontWeight700Bit,
        FontWeight800Bit,
        FontWeight900Bit,
        FontTraitsMaskWidth
    };

    enum FontTraitsMask {
        FontStyleNormalMask = 1 << FontStyleNormalBit,
        FontStyleItalicMask = 1 << FontStyleItalicBit,
        FontStyleMask = FontStyleNormalMask | FontStyleItalicMask,

        FontVariantNormalMask = 1 << FontVariantNormalBit,
        FontVariantSmallCapsMask = 1 << FontVariantSmallCapsBit,
        FontVariantMask = FontVariantNormalMask | FontVariantSmallCapsMask,

        FontWeight100Mask = 1 << FontWeight100Bit,
        FontWeight200Mask = 1 << FontWeight200Bit,
        FontWeight300Mask = 1 << FontWeight300Bit,
        FontWeight400Mask = 1 << FontWeight400Bit,
        FontWeight500Mask = 1 << FontWeight500Bit,
        FontWeight600Mask = 1 << FontWeight600Bit,
        FontWeight700Mask = 1 << FontWeight700Bit,
        FontWeight800Mask = 1 << FontWeight800Bit,
        FontWeight900Mask = 1 << FontWeight900Bit,
        FontWeightMask = FontWeight100Mask | FontWeight200Mask | FontWeight300Mask | FontWeight400Mask | FontWeight500Mask | FontWeight600Mask | FontWeight700Mask | FontWeight800Mask | FontWeight900Mask
    };

} // namespace WebCore
#endif // FontTraitsMask_h
