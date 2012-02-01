/*
 * Copyright (C) 2009 Apple Inc. All rights reserved.
 * Copyright (C) 2010 Peter Varga (pvarga@inf.u-szeged.hu), University of Szeged
 * All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY UNIVERSITY OF SZEGED ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL UNIVERSITY OF SZEGED OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef Yarr_h
#define Yarr_h

#include "YarrInterpreter.h"
#include "YarrPattern.h"

namespace JSC { namespace Yarr {

#define YarrStackSpaceForBackTrackInfoPatternCharacter 1 // Only for !fixed quantifiers.
#define YarrStackSpaceForBackTrackInfoCharacterClass 1 // Only for !fixed quantifiers.
#define YarrStackSpaceForBackTrackInfoBackReference 2
#define YarrStackSpaceForBackTrackInfoAlternative 1 // One per alternative.
#define YarrStackSpaceForBackTrackInfoParentheticalAssertion 1
#define YarrStackSpaceForBackTrackInfoParenthesesOnce 1 // Only for !fixed quantifiers.
#define YarrStackSpaceForBackTrackInfoParenthesesTerminal 1
#define YarrStackSpaceForBackTrackInfoParentheses 2

static const unsigned quantifyInfinite = UINT_MAX;

// The below limit restricts the number of "recursive" match calls in order to
// avoid spending exponential time on complex regular expressions.
static const unsigned matchLimit = 1000000;

enum JSRegExpResult {
    JSRegExpMatch = 1,
    JSRegExpNoMatch = 0,
    JSRegExpErrorNoMatch = -1,
    JSRegExpErrorHitLimit = -2,
    JSRegExpErrorNoMemory = -3,
    JSRegExpErrorInternal = -4
};

enum YarrCharSize {
    Char8,
    Char16
};

JS_EXPORT_PRIVATE PassOwnPtr<BytecodePattern> byteCompile(YarrPattern&, BumpPointerAllocator*);
JS_EXPORT_PRIVATE int interpret(BytecodePattern*, const UString& input, unsigned start, unsigned length, int* output);

} } // namespace JSC::Yarr

#endif // Yarr_h

