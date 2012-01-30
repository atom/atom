/*
 * Copyright (C) 2006, 2007 Apple Inc. All rights reserved.
 * Copyright (C) 2008 Nokia Corporation and/or its subsidiary(-ies)
 * Copyright (C) 2010 Google Inc. All rights reserved.
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
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef TextCheckerClient_h
#define TextCheckerClient_h

#include "TextChecking.h"

#include <wtf/Forward.h>
#include <wtf/Vector.h>
#include <wtf/text/WTFString.h>

namespace WebCore {

class SpellChecker;

struct GrammarDetail {
    int location;
    int length;
    Vector<String> guesses;
    String userDescription;
};

struct TextCheckingResult {
    TextCheckingType type;
    int location;
    int length;
    Vector<GrammarDetail> details;
    String replacement;
};

class TextCheckerClient {
public:
    virtual ~TextCheckerClient() {}

    virtual void ignoreWordInSpellDocument(const String&) = 0;
    virtual void learnWord(const String&) = 0;
    virtual void checkSpellingOfString(const UChar*, int length, int* misspellingLocation, int* misspellingLength) = 0;
    virtual String getAutoCorrectSuggestionForMisspelledWord(const String& misspelledWord) = 0;
    virtual void checkGrammarOfString(const UChar*, int length, Vector<GrammarDetail>&, int* badGrammarLocation, int* badGrammarLength) = 0;

#if USE(UNIFIED_TEXT_CHECKING)
    virtual void checkTextOfParagraph(const UChar* text, int length, TextCheckingTypeMask checkingTypes, Vector<TextCheckingResult>& results) = 0;
#endif

    // For spellcheckers that support multiple languages, it's often important to be able to identify the language in order to
    // provide more accurate correction suggestions. Caller can pass in more text in "context" to aid such spellcheckers on language
    // identification. Noramlly it's the text surrounding the "word" for which we are getting correction suggestions.
    virtual void getGuessesForWord(const String& word, const String& context, Vector<String>& guesses) = 0;
    virtual void requestCheckingOfString(SpellChecker*, int, TextCheckingTypeMask, const String&) = 0;
};

}

#endif // TextCheckerClient_h
