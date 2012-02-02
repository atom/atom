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

#ifndef ParserTokens_h
#define ParserTokens_h

namespace JSC {

class Identifier;

enum {
    UnaryOpTokenFlag = 64,
    KeywordTokenFlag = 128,
    BinaryOpTokenPrecedenceShift = 8,
    BinaryOpTokenAllowsInPrecedenceAdditionalShift = 4,
    BinaryOpTokenPrecedenceMask = 15 << BinaryOpTokenPrecedenceShift,
};

#define BINARY_OP_PRECEDENCE(prec) (((prec) << BinaryOpTokenPrecedenceShift) | ((prec) << (BinaryOpTokenPrecedenceShift + BinaryOpTokenAllowsInPrecedenceAdditionalShift)))
#define IN_OP_PRECEDENCE(prec) ((prec) << (BinaryOpTokenPrecedenceShift + BinaryOpTokenAllowsInPrecedenceAdditionalShift))

enum JSTokenType {
    NULLTOKEN = KeywordTokenFlag,
    TRUETOKEN,
    FALSETOKEN,
    BREAK,
    CASE,
    DEFAULT,
    FOR,
    NEW,
    VAR,
    CONSTTOKEN,
    CONTINUE,
    FUNCTION,
    RETURN,
    IF,
    THISTOKEN,
    DO,
    WHILE,
    SWITCH,
    WITH,
    RESERVED,
    RESERVED_IF_STRICT,
    THROW,
    TRY,
    CATCH,
    FINALLY,
    DEBUGGER,
    ELSE,
    OPENBRACE = 0,
    CLOSEBRACE,
    OPENPAREN,
    CLOSEPAREN,
    OPENBRACKET,
    CLOSEBRACKET,
    COMMA,
    QUESTION,
    NUMBER,
    IDENT,
    STRING,
    SEMICOLON,
    COLON,
    DOT,
    ERRORTOK,
    EOFTOK,
    EQUAL,
    PLUSEQUAL,
    MINUSEQUAL,
    MULTEQUAL,
    DIVEQUAL,
    LSHIFTEQUAL,
    RSHIFTEQUAL,
    URSHIFTEQUAL,
    ANDEQUAL,
    MODEQUAL,
    XOREQUAL,
    OREQUAL,
    LastUntaggedToken,

    // Begin tagged tokens
    PLUSPLUS = 0 | UnaryOpTokenFlag,
    MINUSMINUS = 1 | UnaryOpTokenFlag,
    EXCLAMATION = 2 | UnaryOpTokenFlag,
    TILDE = 3 | UnaryOpTokenFlag,
    AUTOPLUSPLUS = 4 | UnaryOpTokenFlag,
    AUTOMINUSMINUS = 5 | UnaryOpTokenFlag,
    TYPEOF = 6 | UnaryOpTokenFlag | KeywordTokenFlag,
    VOIDTOKEN = 7 | UnaryOpTokenFlag | KeywordTokenFlag,
    DELETETOKEN = 8 | UnaryOpTokenFlag | KeywordTokenFlag,
    OR = 0 | BINARY_OP_PRECEDENCE(1),
    AND = 1 | BINARY_OP_PRECEDENCE(2),
    BITOR = 2 | BINARY_OP_PRECEDENCE(3),
    BITXOR = 3 | BINARY_OP_PRECEDENCE(4),
    BITAND = 4 | BINARY_OP_PRECEDENCE(5),
    EQEQ = 5 | BINARY_OP_PRECEDENCE(6),
    NE = 6 | BINARY_OP_PRECEDENCE(6),
    STREQ = 7 | BINARY_OP_PRECEDENCE(6),
    STRNEQ = 8 | BINARY_OP_PRECEDENCE(6),
    LT = 9 | BINARY_OP_PRECEDENCE(7),
    GT = 10 | BINARY_OP_PRECEDENCE(7),
    LE = 11 | BINARY_OP_PRECEDENCE(7),
    GE = 12 | BINARY_OP_PRECEDENCE(7),
    INSTANCEOF = 13 | BINARY_OP_PRECEDENCE(7) | KeywordTokenFlag,
    INTOKEN = 14 | IN_OP_PRECEDENCE(7) | KeywordTokenFlag,
    LSHIFT = 15 | BINARY_OP_PRECEDENCE(8),
    RSHIFT = 16 | BINARY_OP_PRECEDENCE(8),
    URSHIFT = 17 | BINARY_OP_PRECEDENCE(8),
    PLUS = 18 | BINARY_OP_PRECEDENCE(9) | UnaryOpTokenFlag,
    MINUS = 19 | BINARY_OP_PRECEDENCE(9) | UnaryOpTokenFlag,
    TIMES = 20 | BINARY_OP_PRECEDENCE(10),
    DIVIDE = 21 | BINARY_OP_PRECEDENCE(10),
    MOD = 22 | BINARY_OP_PRECEDENCE(10)
};

union JSTokenData {
    int intValue;
    double doubleValue;
    const Identifier* ident;
};

struct JSTokenInfo {
    JSTokenInfo() : line(0) { }
    int line;
    int startOffset;
    int endOffset;
};

struct JSToken {
    JSTokenType m_type;
    JSTokenData m_data;
    JSTokenInfo m_info;
};

enum JSParserStrictness { JSParseNormal, JSParseStrict };
enum JSParserMode { JSParseProgramCode, JSParseFunctionCode };
    
}


#endif // ParserTokens_h
