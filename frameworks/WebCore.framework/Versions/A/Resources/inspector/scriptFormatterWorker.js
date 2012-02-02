/*
 * Copyright (C) 2011 Google Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 *     * Redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above
 * copyright notice, this list of conditions and the following disclaimer
 * in the documentation and/or other materials provided with the
 * distribution.
 *     * Neither the name of Google Inc. nor the names of its
 * contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
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

onmessage = function(event) {
    if (!event.data.method)
        return;

    self[event.data.method](event.data.params);
};

function format(params)
{
    // Default to a 4-space indent.
    var indentString = params.indentString || "    ";
    var result = {};

    if (params.mimeType === "text/html") {
        var formatter = new HTMLScriptFormatter(indentString);
        result = formatter.format(params.content);
    } else {
        result.mapping = { original: [0], formatted: [0] };
        result.content = formatScript(params.content, result.mapping, 0, 0, indentString);
    }
    postMessage(result);
}

function getChunkCount(totalLength, chunkSize)
{
    if (totalLength <= chunkSize)
        return 1;

    var remainder = totalLength % chunkSize;
    var partialLength = totalLength - remainder;
    return (partialLength / chunkSize) + (remainder ? 1 : 0);
}

function outline(params)
{
    const chunkSize = 100000; // characters per data chunk
    const totalLength = params.content.length;
    const lines = params.content.split("\n");
    const chunkCount = getChunkCount(totalLength, chunkSize);
    var outlineChunk = [];
    var previousIdentifier = null;
    var previousToken = null;
    var previousTokenType = null;
    var currentChunk = 1;
    var processedChunkCharacters = 0;
    var addedFunction = false;
    var isReadingArguments = false;
    var argumentsText = "";
    var currentFunction = null;
    var scriptTokenizer = new WebInspector.SourceJavaScriptTokenizer();
    scriptTokenizer.condition = scriptTokenizer.createInitialCondition();

    for (var i = 0; i < lines.length; ++i) {
        var line = lines[i];
        var column = 0;
        scriptTokenizer.line = line;
        do {
            var newColumn = scriptTokenizer.nextToken(column);
            var tokenType = scriptTokenizer.tokenType;
            var tokenValue = line.substring(column, newColumn);
            if (tokenType === "javascript-ident") {
                previousIdentifier = tokenValue;
                if (tokenValue && previousToken === "function") {
                    // A named function: "function f...".
                    currentFunction = { line: i, name: tokenValue };
                    addedFunction = true;
                    previousIdentifier = null;
                }
            } else if (tokenType === "javascript-keyword") {
                if (tokenValue === "function") {
                    if (previousIdentifier && (previousToken === "=" || previousToken === ":")) {
                        // Anonymous function assigned to an identifier: "...f = function..."
                        // or "funcName: function...".
                        currentFunction = { line: i, name: previousIdentifier };
                        addedFunction = true;
                        previousIdentifier = null;
                    }
                }
            } else if (tokenValue === "." && previousTokenType === "javascript-ident")
                previousIdentifier += ".";
            else if (tokenValue === "(" && addedFunction)
                isReadingArguments = true;
            if (isReadingArguments && tokenValue)
                argumentsText += tokenValue;

            if (tokenValue === ")" && isReadingArguments) {
                addedFunction = false;
                isReadingArguments = false;
                currentFunction.arguments = argumentsText.replace(/,[\r\n\s]*/g, ", ").replace(/([^,])[\r\n\s]+/g, "$1");
                argumentsText = "";
                outlineChunk.push(currentFunction);
            }

            if (tokenValue.trim().length) {
                // Skip whitespace tokens.
                previousToken = tokenValue;
                previousTokenType = tokenType;
            }
            processedChunkCharacters += newColumn - column;
            column = newColumn;

            if (processedChunkCharacters >= chunkSize) {
                postMessage({ chunk: outlineChunk, id: params.id, total: chunkCount, index: currentChunk++ });
                outlineChunk = [];
                processedChunkCharacters = 0;
            }
        } while (column < line.length);
    }
    postMessage({ chunk: outlineChunk, id: params.id, total: chunkCount, index: chunkCount });
}

function formatScript(content, mapping, offset, formattedOffset, indentString)
{
    var formattedContent;
    try {
        var tokenizer = new Tokenizer(content);
        var builder = new FormattedContentBuilder(tokenizer.content(), mapping, offset, formattedOffset, indentString);
        var formatter = new JavaScriptFormatter(tokenizer, builder);
        formatter.format();
        formattedContent = builder.content();
    } catch (e) {
        formattedContent = content;
    }
    return formattedContent;
}

WebInspector = {};

Array.prototype.keySet = function()
{
    var keys = {};
    for (var i = 0; i < this.length; ++i)
        keys[this[i]] = true;
    return keys;
};

/* Generated by re2c 0.13.5 on Tue Jan 26 01:16:33 2010 */
/*
 * Copyright (C) 2009 Google Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 *     * Redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above
 * copyright notice, this list of conditions and the following disclaimer
 * in the documentation and/or other materials provided with the
 * distribution.
 *     * Neither the name of Google Inc. nor the names of its
 * contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
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

/**
 * @constructor
 */
WebInspector.SourceTokenizer = function()
{
}

WebInspector.SourceTokenizer.prototype = {
    set line(line) {
        this._line = line;
    },

    set condition(condition)
    {
        this._condition = condition;
    },

    get condition()
    {
        return this._condition;
    },

    getLexCondition: function()
    {
        return this.condition.lexCondition;
    },

    setLexCondition: function(lexCondition)
    {
        this.condition.lexCondition = lexCondition;
    },

    _charAt: function(cursor)
    {
        return cursor < this._line.length ? this._line.charAt(cursor) : "\n";
    },

    createInitialCondition: function()
    {
    },

    nextToken: function(cursor)
    {
    }
}

/**
 * @constructor
 */
WebInspector.SourceTokenizer.Registry = function() {
    this._tokenizers = {};
    this._tokenizerConstructors = {
        "text/css": "SourceCSSTokenizer",
        "text/html": "SourceHTMLTokenizer",
        "text/javascript": "SourceJavaScriptTokenizer"
    };
}

WebInspector.SourceTokenizer.Registry.getInstance = function()
{
    if (!WebInspector.SourceTokenizer.Registry._instance)
        WebInspector.SourceTokenizer.Registry._instance = new WebInspector.SourceTokenizer.Registry();
    return WebInspector.SourceTokenizer.Registry._instance;
}

WebInspector.SourceTokenizer.Registry.prototype = {
    getTokenizer: function(mimeType)
    {
        if (!this._tokenizerConstructors[mimeType])
            return null;
        var tokenizerClass = this._tokenizerConstructors[mimeType];
        var tokenizer = this._tokenizers[tokenizerClass];
        if (!tokenizer) {
            tokenizer = new WebInspector[tokenizerClass]();
            this._tokenizers[tokenizerClass] = tokenizer;
        }
        return tokenizer;
    }
}
;
/* Generated by re2c 0.13.5 on Fri May  6 13:47:06 2011 */
/*
 * Copyright (C) 2009 Google Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 *     * Redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above
 * copyright notice, this list of conditions and the following disclaimer
 * in the documentation and/or other materials provided with the
 * distribution.
 *     * Neither the name of Google Inc. nor the names of its
 * contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
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

// Generate js file as follows:
//
// re2c -isc WebCore/inspector/front-end/SourceHTMLTokenizer.re2js \
// | sed 's|^yy\([^:]*\)*\:|case \1:|' \
// | sed 's|[*]cursor[+][+]|this._charAt(cursor++)|' \
// | sed 's|[[*][+][+]cursor|this._charAt(++cursor)|' \
// | sed 's|[*]cursor|this._charAt(cursor)|' \
// | sed 's|yych = \*\([^;]*\)|yych = this._charAt\1|' \
// | sed 's|{ gotoCase = \([^; continue; };]*\)|{ gotoCase = \1; continue; }|' \
// | sed 's|unsigned\ int|var|' \
// | sed 's|var\ yych|case 1: case 1: var yych|'

/**
 * @constructor
 * @extends {WebInspector.SourceTokenizer}
 */
WebInspector.SourceHTMLTokenizer = function()
{
    WebInspector.SourceTokenizer.call(this);

    // The order is determined by the generated code.
    this._lexConditions = {
        INITIAL: 0,
        COMMENT: 1,
        DOCTYPE: 2,
        TAG: 3,
        DSTRING: 4,
        SSTRING: 5
    };
    this.case_INITIAL = 1000;
    this.case_COMMENT = 1001;
    this.case_DOCTYPE = 1002;
    this.case_TAG = 1003;
    this.case_DSTRING = 1004;
    this.case_SSTRING = 1005;

    this._parseConditions = {
        INITIAL: 0,
        ATTRIBUTE: 1,
        ATTRIBUTE_VALUE: 2,
        LINKIFY: 4,
        A_NODE: 8,
        SCRIPT: 16,
        STYLE: 32
    };

    this.condition = this.createInitialCondition();
}

WebInspector.SourceHTMLTokenizer.prototype = {
    createInitialCondition: function()
    {
        return { lexCondition: this._lexConditions.INITIAL, parseCondition: this._parseConditions.INITIAL };
    },

    set line(line) {
        if (this._condition.internalJavaScriptTokenizerCondition) {
            var match = /<\/script/i.exec(line);
            if (match) {
                this._internalJavaScriptTokenizer.line = line.substring(0, match.index);
            } else
                this._internalJavaScriptTokenizer.line = line;
        } else if (this._condition.internalCSSTokenizerCondition) {
            var match = /<\/style/i.exec(line);
            if (match) {
                this._internalCSSTokenizer.line = line.substring(0, match.index);
            } else
                this._internalCSSTokenizer.line = line;
        }
        this._line = line;
    },

    _isExpectingAttribute: function()
    {
        return this._condition.parseCondition & this._parseConditions.ATTRIBUTE;
    },

    _isExpectingAttributeValue: function()
    {
        return this._condition.parseCondition & this._parseConditions.ATTRIBUTE_VALUE;
    },

    _setExpectingAttribute: function()
    {
        if (this._isExpectingAttributeValue())
            this._condition.parseCondition ^= this._parseConditions.ATTRIBUTE_VALUE;
        this._condition.parseCondition |= this._parseConditions.ATTRIBUTE;
    },

    _setExpectingAttributeValue: function()
    {
        if (this._isExpectingAttribute())
            this._condition.parseCondition ^= this._parseConditions.ATTRIBUTE;
        this._condition.parseCondition |= this._parseConditions.ATTRIBUTE_VALUE;
    },

    /**
     * @param {boolean=} stringEnds
     */
    _stringToken: function(cursor, stringEnds)
    {
        if (!this._isExpectingAttributeValue()) {
            this.tokenType = null;
            return cursor;
        }
        this.tokenType = this._attrValueTokenType();
        if (stringEnds)
            this._setExpectingAttribute();
        return cursor;
    },

    _attrValueTokenType: function()
    {
        if (this._condition.parseCondition & this._parseConditions.LINKIFY) {
            if (this._condition.parseCondition & this._parseConditions.A_NODE)
                return "html-external-link";
            return "html-resource-link";
        }
        return "html-attribute-value";
    },

    get _internalJavaScriptTokenizer()
    {
        return WebInspector.SourceTokenizer.Registry.getInstance().getTokenizer("text/javascript");
    },

    get _internalCSSTokenizer()
    {
        return WebInspector.SourceTokenizer.Registry.getInstance().getTokenizer("text/css");
    },

    scriptStarted: function(cursor)
    {
        this._condition.internalJavaScriptTokenizerCondition = this._internalJavaScriptTokenizer.createInitialCondition();
    },

    scriptEnded: function(cursor)
    {
    },

    styleSheetStarted: function(cursor)
    {
        this._condition.internalCSSTokenizerCondition = this._internalCSSTokenizer.createInitialCondition();
    },

    styleSheetEnded: function(cursor)
    {
    },

    nextToken: function(cursor)
    {
        if (this._condition.internalJavaScriptTokenizerCondition) {
            // Re-set line to force </script> detection first.
            this.line = this._line;
            if (cursor !== this._internalJavaScriptTokenizer._line.length) {
                // Tokenizer is stateless, so restore its condition before tokenizing and save it after.
                this._internalJavaScriptTokenizer.condition = this._condition.internalJavaScriptTokenizerCondition;
                var result = this._internalJavaScriptTokenizer.nextToken(cursor);
                this.tokenType = this._internalJavaScriptTokenizer.tokenType;
                this._condition.internalJavaScriptTokenizerCondition = this._internalJavaScriptTokenizer.condition;
                return result;
            } else if (cursor !== this._line.length)
                delete this._condition.internalJavaScriptTokenizerCondition;
        } else if (this._condition.internalCSSTokenizerCondition) {
            // Re-set line to force </style> detection first.
            this.line = this._line;
            if (cursor !== this._internalCSSTokenizer._line.length) {
                // Tokenizer is stateless, so restore its condition before tokenizing and save it after.
                this._internalCSSTokenizer.condition = this._condition.internalCSSTokenizerCondition;
                var result = this._internalCSSTokenizer.nextToken(cursor);
                this.tokenType = this._internalCSSTokenizer.tokenType;
                this._condition.internalCSSTokenizerCondition = this._internalCSSTokenizer.condition;
                return result;
            } else if (cursor !== this._line.length)
                delete this._condition.internalCSSTokenizerCondition;
        }

        var cursorOnEnter = cursor;
        var gotoCase = 1;
        var YYMARKER;
        while (1) {
            switch (gotoCase)
            // Following comment is replaced with generated state machine.

        {
            case 1: var yych;
            var yyaccept = 0;
            if (this.getLexCondition() < 3) {
                if (this.getLexCondition() < 1) {
                    { gotoCase = this.case_INITIAL; continue; };
                } else {
                    if (this.getLexCondition() < 2) {
                        { gotoCase = this.case_COMMENT; continue; };
                    } else {
                        { gotoCase = this.case_DOCTYPE; continue; };
                    }
                }
            } else {
                if (this.getLexCondition() < 4) {
                    { gotoCase = this.case_TAG; continue; };
                } else {
                    if (this.getLexCondition() < 5) {
                        { gotoCase = this.case_DSTRING; continue; };
                    } else {
                        { gotoCase = this.case_SSTRING; continue; };
                    }
                }
            }
/* *********************************** */
case this.case_COMMENT:

            yych = this._charAt(cursor);
            if (yych <= '\f') {
                if (yych == '\n') { gotoCase = 4; continue; };
                { gotoCase = 3; continue; };
            } else {
                if (yych <= '\r') { gotoCase = 4; continue; };
                if (yych == '-') { gotoCase = 6; continue; };
                { gotoCase = 3; continue; };
            }
case 2:
            { this.tokenType = "html-comment"; return cursor; }
case 3:
            yyaccept = 0;
            yych = this._charAt(YYMARKER = ++cursor);
            { gotoCase = 9; continue; };
case 4:
            ++cursor;
case 5:
            { this.tokenType = null; return cursor; }
case 6:
            yyaccept = 1;
            yych = this._charAt(YYMARKER = ++cursor);
            if (yych != '-') { gotoCase = 5; continue; };
case 7:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych == '>') { gotoCase = 10; continue; };
case 8:
            yyaccept = 0;
            YYMARKER = ++cursor;
            yych = this._charAt(cursor);
case 9:
            if (yych <= '\f') {
                if (yych == '\n') { gotoCase = 2; continue; };
                { gotoCase = 8; continue; };
            } else {
                if (yych <= '\r') { gotoCase = 2; continue; };
                if (yych == '-') { gotoCase = 12; continue; };
                { gotoCase = 8; continue; };
            }
case 10:
            ++cursor;
            this.setLexCondition(this._lexConditions.INITIAL);
            { this.tokenType = "html-comment"; return cursor; }
case 12:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych == '-') { gotoCase = 7; continue; };
            cursor = YYMARKER;
            if (yyaccept <= 0) {
                { gotoCase = 2; continue; };
            } else {
                { gotoCase = 5; continue; };
            }
/* *********************************** */
case this.case_DOCTYPE:
            yych = this._charAt(cursor);
            if (yych <= '\f') {
                if (yych == '\n') { gotoCase = 18; continue; };
                { gotoCase = 17; continue; };
            } else {
                if (yych <= '\r') { gotoCase = 18; continue; };
                if (yych == '>') { gotoCase = 20; continue; };
                { gotoCase = 17; continue; };
            }
case 16:
            { this.tokenType = "html-doctype"; return cursor; }
case 17:
            yych = this._charAt(++cursor);
            { gotoCase = 23; continue; };
case 18:
            ++cursor;
            { this.tokenType = null; return cursor; }
case 20:
            ++cursor;
            this.setLexCondition(this._lexConditions.INITIAL);
            { this.tokenType = "html-doctype"; return cursor; }
case 22:
            ++cursor;
            yych = this._charAt(cursor);
case 23:
            if (yych <= '\f') {
                if (yych == '\n') { gotoCase = 16; continue; };
                { gotoCase = 22; continue; };
            } else {
                if (yych <= '\r') { gotoCase = 16; continue; };
                if (yych == '>') { gotoCase = 16; continue; };
                { gotoCase = 22; continue; };
            }
/* *********************************** */
case this.case_DSTRING:
            yych = this._charAt(cursor);
            if (yych <= '\f') {
                if (yych == '\n') { gotoCase = 28; continue; };
                { gotoCase = 27; continue; };
            } else {
                if (yych <= '\r') { gotoCase = 28; continue; };
                if (yych == '"') { gotoCase = 30; continue; };
                { gotoCase = 27; continue; };
            }
case 26:
            { return this._stringToken(cursor); }
case 27:
            yych = this._charAt(++cursor);
            { gotoCase = 34; continue; };
case 28:
            ++cursor;
            { this.tokenType = null; return cursor; }
case 30:
            ++cursor;
case 31:
            this.setLexCondition(this._lexConditions.TAG);
            { return this._stringToken(cursor, true); }
case 32:
            yych = this._charAt(++cursor);
            { gotoCase = 31; continue; };
case 33:
            ++cursor;
            yych = this._charAt(cursor);
case 34:
            if (yych <= '\f') {
                if (yych == '\n') { gotoCase = 26; continue; };
                { gotoCase = 33; continue; };
            } else {
                if (yych <= '\r') { gotoCase = 26; continue; };
                if (yych == '"') { gotoCase = 32; continue; };
                { gotoCase = 33; continue; };
            }
/* *********************************** */
case this.case_INITIAL:
            yych = this._charAt(cursor);
            if (yych == '<') { gotoCase = 39; continue; };
            ++cursor;
            { this.tokenType = null; return cursor; }
case 39:
            yyaccept = 0;
            yych = this._charAt(YYMARKER = ++cursor);
            if (yych <= '/') {
                if (yych == '!') { gotoCase = 44; continue; };
                if (yych >= '/') { gotoCase = 41; continue; };
            } else {
                if (yych <= 'S') {
                    if (yych >= 'S') { gotoCase = 42; continue; };
                } else {
                    if (yych == 's') { gotoCase = 42; continue; };
                }
            }
case 40:
            this.setLexCondition(this._lexConditions.TAG);
            {
                    if (this._condition.parseCondition & (this._parseConditions.SCRIPT | this._parseConditions.STYLE)) {
                        // Do not tokenize script and style tag contents, keep lexer state, even though processing "<".
                        this.setLexCondition(this._lexConditions.INITIAL);
                        this.tokenType = null;
                        return cursor;
                    }

                    this._condition.parseCondition = this._parseConditions.INITIAL;
                    this.tokenType = "html-tag";
                    return cursor;
                }
case 41:
            yyaccept = 0;
            yych = this._charAt(YYMARKER = ++cursor);
            if (yych == 'S') { gotoCase = 73; continue; };
            if (yych == 's') { gotoCase = 73; continue; };
            { gotoCase = 40; continue; };
case 42:
            yych = this._charAt(++cursor);
            if (yych <= 'T') {
                if (yych == 'C') { gotoCase = 62; continue; };
                if (yych >= 'T') { gotoCase = 63; continue; };
            } else {
                if (yych <= 'c') {
                    if (yych >= 'c') { gotoCase = 62; continue; };
                } else {
                    if (yych == 't') { gotoCase = 63; continue; };
                }
            }
case 43:
            cursor = YYMARKER;
            { gotoCase = 40; continue; };
case 44:
            yych = this._charAt(++cursor);
            if (yych <= 'C') {
                if (yych != '-') { gotoCase = 43; continue; };
            } else {
                if (yych <= 'D') { gotoCase = 46; continue; };
                if (yych == 'd') { gotoCase = 46; continue; };
                { gotoCase = 43; continue; };
            }
            yych = this._charAt(++cursor);
            if (yych == '-') { gotoCase = 54; continue; };
            { gotoCase = 43; continue; };
case 46:
            yych = this._charAt(++cursor);
            if (yych == 'O') { gotoCase = 47; continue; };
            if (yych != 'o') { gotoCase = 43; continue; };
case 47:
            yych = this._charAt(++cursor);
            if (yych == 'C') { gotoCase = 48; continue; };
            if (yych != 'c') { gotoCase = 43; continue; };
case 48:
            yych = this._charAt(++cursor);
            if (yych == 'T') { gotoCase = 49; continue; };
            if (yych != 't') { gotoCase = 43; continue; };
case 49:
            yych = this._charAt(++cursor);
            if (yych == 'Y') { gotoCase = 50; continue; };
            if (yych != 'y') { gotoCase = 43; continue; };
case 50:
            yych = this._charAt(++cursor);
            if (yych == 'P') { gotoCase = 51; continue; };
            if (yych != 'p') { gotoCase = 43; continue; };
case 51:
            yych = this._charAt(++cursor);
            if (yych == 'E') { gotoCase = 52; continue; };
            if (yych != 'e') { gotoCase = 43; continue; };
case 52:
            ++cursor;
            this.setLexCondition(this._lexConditions.DOCTYPE);
            { this.tokenType = "html-doctype"; return cursor; }
case 54:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '\f') {
                if (yych == '\n') { gotoCase = 57; continue; };
                { gotoCase = 54; continue; };
            } else {
                if (yych <= '\r') { gotoCase = 57; continue; };
                if (yych != '-') { gotoCase = 54; continue; };
            }
            ++cursor;
            yych = this._charAt(cursor);
            if (yych == '-') { gotoCase = 59; continue; };
            { gotoCase = 43; continue; };
case 57:
            ++cursor;
            this.setLexCondition(this._lexConditions.COMMENT);
            { this.tokenType = "html-comment"; return cursor; }
case 59:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych != '>') { gotoCase = 54; continue; };
            ++cursor;
            { this.tokenType = "html-comment"; return cursor; }
case 62:
            yych = this._charAt(++cursor);
            if (yych == 'R') { gotoCase = 68; continue; };
            if (yych == 'r') { gotoCase = 68; continue; };
            { gotoCase = 43; continue; };
case 63:
            yych = this._charAt(++cursor);
            if (yych == 'Y') { gotoCase = 64; continue; };
            if (yych != 'y') { gotoCase = 43; continue; };
case 64:
            yych = this._charAt(++cursor);
            if (yych == 'L') { gotoCase = 65; continue; };
            if (yych != 'l') { gotoCase = 43; continue; };
case 65:
            yych = this._charAt(++cursor);
            if (yych == 'E') { gotoCase = 66; continue; };
            if (yych != 'e') { gotoCase = 43; continue; };
case 66:
            ++cursor;
            this.setLexCondition(this._lexConditions.TAG);
            {
                    if (this._condition.parseCondition & this._parseConditions.STYLE) {
                        // Do not tokenize style tag contents, keep lexer state, even though processing "<".
                        this.setLexCondition(this._lexConditions.INITIAL);
                        this.tokenType = null;
                        return cursor;
                    }
                    this.tokenType = "html-tag";
                    this._condition.parseCondition = this._parseConditions.STYLE;
                    this._setExpectingAttribute();
                    return cursor;
                }
case 68:
            yych = this._charAt(++cursor);
            if (yych == 'I') { gotoCase = 69; continue; };
            if (yych != 'i') { gotoCase = 43; continue; };
case 69:
            yych = this._charAt(++cursor);
            if (yych == 'P') { gotoCase = 70; continue; };
            if (yych != 'p') { gotoCase = 43; continue; };
case 70:
            yych = this._charAt(++cursor);
            if (yych == 'T') { gotoCase = 71; continue; };
            if (yych != 't') { gotoCase = 43; continue; };
case 71:
            ++cursor;
            this.setLexCondition(this._lexConditions.TAG);
            {
                    if (this._condition.parseCondition & this._parseConditions.SCRIPT) {
                        // Do not tokenize script tag contents, keep lexer state, even though processing "<".
                        this.setLexCondition(this._lexConditions.INITIAL);
                        this.tokenType = null;
                        return cursor;
                    }
                    this.tokenType = "html-tag";
                    this._condition.parseCondition = this._parseConditions.SCRIPT;
                    this._setExpectingAttribute();
                    return cursor;
                }
case 73:
            yych = this._charAt(++cursor);
            if (yych <= 'T') {
                if (yych == 'C') { gotoCase = 75; continue; };
                if (yych <= 'S') { gotoCase = 43; continue; };
            } else {
                if (yych <= 'c') {
                    if (yych <= 'b') { gotoCase = 43; continue; };
                    { gotoCase = 75; continue; };
                } else {
                    if (yych != 't') { gotoCase = 43; continue; };
                }
            }
            yych = this._charAt(++cursor);
            if (yych == 'Y') { gotoCase = 81; continue; };
            if (yych == 'y') { gotoCase = 81; continue; };
            { gotoCase = 43; continue; };
case 75:
            yych = this._charAt(++cursor);
            if (yych == 'R') { gotoCase = 76; continue; };
            if (yych != 'r') { gotoCase = 43; continue; };
case 76:
            yych = this._charAt(++cursor);
            if (yych == 'I') { gotoCase = 77; continue; };
            if (yych != 'i') { gotoCase = 43; continue; };
case 77:
            yych = this._charAt(++cursor);
            if (yych == 'P') { gotoCase = 78; continue; };
            if (yych != 'p') { gotoCase = 43; continue; };
case 78:
            yych = this._charAt(++cursor);
            if (yych == 'T') { gotoCase = 79; continue; };
            if (yych != 't') { gotoCase = 43; continue; };
case 79:
            ++cursor;
            this.setLexCondition(this._lexConditions.TAG);
            {
                    this.tokenType = "html-tag";
                    this._condition.parseCondition = this._parseConditions.INITIAL;
                    this.scriptEnded(cursor - 8);
                    return cursor;
                }
case 81:
            yych = this._charAt(++cursor);
            if (yych == 'L') { gotoCase = 82; continue; };
            if (yych != 'l') { gotoCase = 43; continue; };
case 82:
            yych = this._charAt(++cursor);
            if (yych == 'E') { gotoCase = 83; continue; };
            if (yych != 'e') { gotoCase = 43; continue; };
case 83:
            ++cursor;
            this.setLexCondition(this._lexConditions.TAG);
            {
                    this.tokenType = "html-tag";
                    this._condition.parseCondition = this._parseConditions.INITIAL;
                    this.styleSheetEnded(cursor - 7);
                    return cursor;
                }
/* *********************************** */
case this.case_SSTRING:
            yych = this._charAt(cursor);
            if (yych <= '\f') {
                if (yych == '\n') { gotoCase = 89; continue; };
                { gotoCase = 88; continue; };
            } else {
                if (yych <= '\r') { gotoCase = 89; continue; };
                if (yych == '\'') { gotoCase = 91; continue; };
                { gotoCase = 88; continue; };
            }
case 87:
            { return this._stringToken(cursor); }
case 88:
            yych = this._charAt(++cursor);
            { gotoCase = 95; continue; };
case 89:
            ++cursor;
            { this.tokenType = null; return cursor; }
case 91:
            ++cursor;
case 92:
            this.setLexCondition(this._lexConditions.TAG);
            { return this._stringToken(cursor, true); }
case 93:
            yych = this._charAt(++cursor);
            { gotoCase = 92; continue; };
case 94:
            ++cursor;
            yych = this._charAt(cursor);
case 95:
            if (yych <= '\f') {
                if (yych == '\n') { gotoCase = 87; continue; };
                { gotoCase = 94; continue; };
            } else {
                if (yych <= '\r') { gotoCase = 87; continue; };
                if (yych == '\'') { gotoCase = 93; continue; };
                { gotoCase = 94; continue; };
            }
/* *********************************** */
case this.case_TAG:
            yych = this._charAt(cursor);
            if (yych <= '&') {
                if (yych <= '\r') {
                    if (yych == '\n') { gotoCase = 100; continue; };
                    if (yych >= '\r') { gotoCase = 100; continue; };
                } else {
                    if (yych <= ' ') {
                        if (yych >= ' ') { gotoCase = 100; continue; };
                    } else {
                        if (yych == '"') { gotoCase = 102; continue; };
                    }
                }
            } else {
                if (yych <= '>') {
                    if (yych <= ';') {
                        if (yych <= '\'') { gotoCase = 103; continue; };
                    } else {
                        if (yych <= '<') { gotoCase = 100; continue; };
                        if (yych <= '=') { gotoCase = 104; continue; };
                        { gotoCase = 106; continue; };
                    }
                } else {
                    if (yych <= '[') {
                        if (yych >= '[') { gotoCase = 100; continue; };
                    } else {
                        if (yych == ']') { gotoCase = 100; continue; };
                    }
                }
            }
            ++cursor;
            yych = this._charAt(cursor);
            { gotoCase = 119; continue; };
case 99:
            {
                    if (this._condition.parseCondition === this._parseConditions.SCRIPT || this._condition.parseCondition === this._parseConditions.STYLE) {
                        // Fall through if expecting attributes.
                        this.tokenType = null;
                        return cursor;
                    }

                    if (this._condition.parseCondition === this._parseConditions.INITIAL) {
                        this.tokenType = "html-tag";
                        this._setExpectingAttribute();
                        var token = this._line.substring(cursorOnEnter, cursor);
                        if (token === "a")
                            this._condition.parseCondition |= this._parseConditions.A_NODE;
                        else if (this._condition.parseCondition & this._parseConditions.A_NODE)
                            this._condition.parseCondition ^= this._parseConditions.A_NODE;
                    } else if (this._isExpectingAttribute()) {
                        var token = this._line.substring(cursorOnEnter, cursor);
                        if (token === "href" || token === "src")
                            this._condition.parseCondition |= this._parseConditions.LINKIFY;
                        else if (this._condition.parseCondition |= this._parseConditions.LINKIFY)
                            this._condition.parseCondition ^= this._parseConditions.LINKIFY;
                        this.tokenType = "html-attribute-name";
                    } else if (this._isExpectingAttributeValue())
                        this.tokenType = this._attrValueTokenType();
                    else
                        this.tokenType = null;
                    return cursor;
                }
case 100:
            ++cursor;
            { this.tokenType = null; return cursor; }
case 102:
            yyaccept = 0;
            yych = this._charAt(YYMARKER = ++cursor);
            { gotoCase = 115; continue; };
case 103:
            yyaccept = 0;
            yych = this._charAt(YYMARKER = ++cursor);
            { gotoCase = 109; continue; };
case 104:
            ++cursor;
            {
                    if (this._isExpectingAttribute())
                        this._setExpectingAttributeValue();
                    this.tokenType = null;
                    return cursor;
                }
case 106:
            ++cursor;
            this.setLexCondition(this._lexConditions.INITIAL);
            {
                    this.tokenType = "html-tag";
                    if (this._condition.parseCondition & this._parseConditions.SCRIPT) {
                        this.scriptStarted(cursor);
                        // Do not tokenize script tag contents.
                        return cursor;
                    }

                    if (this._condition.parseCondition & this._parseConditions.STYLE) {
                        this.styleSheetStarted(cursor);
                        // Do not tokenize style tag contents.
                        return cursor;
                    }

                    this._condition.parseCondition = this._parseConditions.INITIAL;
                    return cursor;
                }
case 108:
            ++cursor;
            yych = this._charAt(cursor);
case 109:
            if (yych <= '\f') {
                if (yych != '\n') { gotoCase = 108; continue; };
            } else {
                if (yych <= '\r') { gotoCase = 110; continue; };
                if (yych == '\'') { gotoCase = 112; continue; };
                { gotoCase = 108; continue; };
            }
case 110:
            ++cursor;
            this.setLexCondition(this._lexConditions.SSTRING);
            { return this._stringToken(cursor); }
case 112:
            ++cursor;
            { return this._stringToken(cursor, true); }
case 114:
            ++cursor;
            yych = this._charAt(cursor);
case 115:
            if (yych <= '\f') {
                if (yych != '\n') { gotoCase = 114; continue; };
            } else {
                if (yych <= '\r') { gotoCase = 116; continue; };
                if (yych == '"') { gotoCase = 112; continue; };
                { gotoCase = 114; continue; };
            }
case 116:
            ++cursor;
            this.setLexCondition(this._lexConditions.DSTRING);
            { return this._stringToken(cursor); }
case 118:
            ++cursor;
            yych = this._charAt(cursor);
case 119:
            if (yych <= '"') {
                if (yych <= '\r') {
                    if (yych == '\n') { gotoCase = 99; continue; };
                    if (yych <= '\f') { gotoCase = 118; continue; };
                    { gotoCase = 99; continue; };
                } else {
                    if (yych == ' ') { gotoCase = 99; continue; };
                    if (yych <= '!') { gotoCase = 118; continue; };
                    { gotoCase = 99; continue; };
                }
            } else {
                if (yych <= '>') {
                    if (yych == '\'') { gotoCase = 99; continue; };
                    if (yych <= ';') { gotoCase = 118; continue; };
                    { gotoCase = 99; continue; };
                } else {
                    if (yych <= '[') {
                        if (yych <= 'Z') { gotoCase = 118; continue; };
                        { gotoCase = 99; continue; };
                    } else {
                        if (yych == ']') { gotoCase = 99; continue; };
                        { gotoCase = 118; continue; };
                    }
                }
            }
        }

        }
    }
}

WebInspector.SourceHTMLTokenizer.prototype.__proto__ = WebInspector.SourceTokenizer.prototype;
;
/* Generated by re2c 0.13.5 on Fri May 13 20:01:13 2011 */
/*
 * Copyright (C) 2009 Google Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 *     * Redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above
 * copyright notice, this list of conditions and the following disclaimer
 * in the documentation and/or other materials provided with the
 * distribution.
 *     * Neither the name of Google Inc. nor the names of its
 * contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
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

// Generate js file as follows:
//
// re2c -isc WebCore/inspector/front-end/SourceJavaScriptTokenizer.re2js \
// | sed 's|^yy\([^:]*\)*\:|case \1:|' \
// | sed 's|[*]cursor[+][+]|this._charAt(cursor++)|' \
// | sed 's|[[*][+][+]cursor|this._charAt(++cursor)|' \
// | sed 's|[*]cursor|this._charAt(cursor)|' \
// | sed 's|yych = \*\([^;]*\)|yych = this._charAt\1|' \
// | sed 's|{ gotoCase = \([^; continue; };]*\)|{ gotoCase = \1; continue; }|' \
// | sed 's|yych <= \(0x[0-9a-fA-f]+\)|yych <= String.fromCharCode(\1)|' \
// | sed 's|unsigned\ int|var|' \
// | sed 's|var\ yych|case 1: case 1: var yych|'

/**
 * @constructor
 * @extends {WebInspector.SourceTokenizer}
 */
WebInspector.SourceJavaScriptTokenizer = function()
{
    WebInspector.SourceTokenizer.call(this);

    this._keywords = [
        "null", "true", "false", "break", "case", "catch", "const", "default", "finally", "for",
        "instanceof", "new", "var", "continue", "function", "return", "void", "delete", "if",
        "this", "do", "while", "else", "in", "switch", "throw", "try", "typeof", "debugger",
        "class", "enum", "export", "extends", "import", "super", "get", "set", "with"
    ].keySet();

    this._lexConditions = {
        DIV: 0,
        NODIV: 1,
        COMMENT: 2,
        DSTRING: 3,
        SSTRING: 4,
        REGEX: 5
    };

    this.case_DIV = 1000;
    this.case_NODIV = 1001;
    this.case_COMMENT = 1002;
    this.case_DSTRING = 1003;
    this.case_SSTRING = 1004;
    this.case_REGEX = 1005;

    this.condition = this.createInitialCondition();
}

WebInspector.SourceJavaScriptTokenizer.prototype = {
    createInitialCondition: function()
    {
        return { lexCondition: this._lexConditions.NODIV };
    },

    nextToken: function(cursor)
    {
        var cursorOnEnter = cursor;
        var gotoCase = 1;
        var YYMARKER;
        while (1) {
            switch (gotoCase)
            // Following comment is replaced with generated state machine.

        {
            case 1: var yych;
            var yyaccept = 0;
            if (this.getLexCondition() < 3) {
                if (this.getLexCondition() < 1) {
                    { gotoCase = this.case_DIV; continue; };
                } else {
                    if (this.getLexCondition() < 2) {
                        { gotoCase = this.case_NODIV; continue; };
                    } else {
                        { gotoCase = this.case_COMMENT; continue; };
                    }
                }
            } else {
                if (this.getLexCondition() < 4) {
                    { gotoCase = this.case_DSTRING; continue; };
                } else {
                    if (this.getLexCondition() < 5) {
                        { gotoCase = this.case_SSTRING; continue; };
                    } else {
                        { gotoCase = this.case_REGEX; continue; };
                    }
                }
            }
/* *********************************** */
case this.case_COMMENT:

            yych = this._charAt(cursor);
            if (yych <= '\f') {
                if (yych == '\n') { gotoCase = 4; continue; };
                { gotoCase = 3; continue; };
            } else {
                if (yych <= '\r') { gotoCase = 4; continue; };
                if (yych == '*') { gotoCase = 6; continue; };
                { gotoCase = 3; continue; };
            }
case 2:
            { this.tokenType = "javascript-comment"; return cursor; }
case 3:
            yyaccept = 0;
            yych = this._charAt(YYMARKER = ++cursor);
            { gotoCase = 12; continue; };
case 4:
            ++cursor;
            { this.tokenType = null; return cursor; }
case 6:
            yyaccept = 1;
            yych = this._charAt(YYMARKER = ++cursor);
            if (yych == '*') { gotoCase = 9; continue; };
            if (yych != '/') { gotoCase = 11; continue; };
case 7:
            ++cursor;
            this.setLexCondition(this._lexConditions.NODIV);
            { this.tokenType = "javascript-comment"; return cursor; }
case 9:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych == '*') { gotoCase = 9; continue; };
            if (yych == '/') { gotoCase = 7; continue; };
case 11:
            yyaccept = 0;
            YYMARKER = ++cursor;
            yych = this._charAt(cursor);
case 12:
            if (yych <= '\f') {
                if (yych == '\n') { gotoCase = 2; continue; };
                { gotoCase = 11; continue; };
            } else {
                if (yych <= '\r') { gotoCase = 2; continue; };
                if (yych == '*') { gotoCase = 9; continue; };
                { gotoCase = 11; continue; };
            }
/* *********************************** */
case this.case_DIV:
            yych = this._charAt(cursor);
            if (yych <= '9') {
                if (yych <= '(') {
                    if (yych <= '#') {
                        if (yych <= ' ') { gotoCase = 15; continue; };
                        if (yych <= '!') { gotoCase = 17; continue; };
                        if (yych <= '"') { gotoCase = 19; continue; };
                    } else {
                        if (yych <= '%') {
                            if (yych <= '$') { gotoCase = 20; continue; };
                            { gotoCase = 22; continue; };
                        } else {
                            if (yych <= '&') { gotoCase = 23; continue; };
                            if (yych <= '\'') { gotoCase = 24; continue; };
                            { gotoCase = 25; continue; };
                        }
                    }
                } else {
                    if (yych <= ',') {
                        if (yych <= ')') { gotoCase = 26; continue; };
                        if (yych <= '*') { gotoCase = 28; continue; };
                        if (yych <= '+') { gotoCase = 29; continue; };
                        { gotoCase = 25; continue; };
                    } else {
                        if (yych <= '.') {
                            if (yych <= '-') { gotoCase = 30; continue; };
                            { gotoCase = 31; continue; };
                        } else {
                            if (yych <= '/') { gotoCase = 32; continue; };
                            if (yych <= '0') { gotoCase = 34; continue; };
                            { gotoCase = 36; continue; };
                        }
                    }
                }
            } else {
                if (yych <= '\\') {
                    if (yych <= '>') {
                        if (yych <= ';') { gotoCase = 25; continue; };
                        if (yych <= '<') { gotoCase = 37; continue; };
                        if (yych <= '=') { gotoCase = 38; continue; };
                        { gotoCase = 39; continue; };
                    } else {
                        if (yych <= '@') {
                            if (yych <= '?') { gotoCase = 25; continue; };
                        } else {
                            if (yych <= 'Z') { gotoCase = 20; continue; };
                            if (yych <= '[') { gotoCase = 25; continue; };
                            { gotoCase = 40; continue; };
                        }
                    }
                } else {
                    if (yych <= 'z') {
                        if (yych <= '^') {
                            if (yych <= ']') { gotoCase = 25; continue; };
                            { gotoCase = 41; continue; };
                        } else {
                            if (yych != '`') { gotoCase = 20; continue; };
                        }
                    } else {
                        if (yych <= '|') {
                            if (yych <= '{') { gotoCase = 25; continue; };
                            { gotoCase = 42; continue; };
                        } else {
                            if (yych <= '~') { gotoCase = 25; continue; };
                            if (yych >= 0x80) { gotoCase = 20; continue; };
                        }
                    }
                }
            }
case 15:
            ++cursor;
case 16:
            { this.tokenType = null; return cursor; }
case 17:
            ++cursor;
            if ((yych = this._charAt(cursor)) == '=') { gotoCase = 115; continue; };
case 18:
            this.setLexCondition(this._lexConditions.NODIV);
            { this.tokenType = null; return cursor; }
case 19:
            yyaccept = 0;
            yych = this._charAt(YYMARKER = ++cursor);
            if (yych == '\n') { gotoCase = 16; continue; };
            if (yych == '\r') { gotoCase = 16; continue; };
            { gotoCase = 107; continue; };
case 20:
            yyaccept = 1;
            yych = this._charAt(YYMARKER = ++cursor);
            { gotoCase = 50; continue; };
case 21:
            {
                    var token = this._line.substring(cursorOnEnter, cursor);
                    if (this._keywords[token] === true && token !== "__proto__")
                        this.tokenType = "javascript-keyword";
                    else
                        this.tokenType = "javascript-ident";
                    return cursor;
                }
case 22:
            yych = this._charAt(++cursor);
            if (yych == '=') { gotoCase = 43; continue; };
            { gotoCase = 18; continue; };
case 23:
            yych = this._charAt(++cursor);
            if (yych == '&') { gotoCase = 43; continue; };
            if (yych == '=') { gotoCase = 43; continue; };
            { gotoCase = 18; continue; };
case 24:
            yyaccept = 0;
            yych = this._charAt(YYMARKER = ++cursor);
            if (yych == '\n') { gotoCase = 16; continue; };
            if (yych == '\r') { gotoCase = 16; continue; };
            { gotoCase = 96; continue; };
case 25:
            yych = this._charAt(++cursor);
            { gotoCase = 18; continue; };
case 26:
            ++cursor;
            { this.tokenType = null; return cursor; }
case 28:
            yych = this._charAt(++cursor);
            if (yych == '=') { gotoCase = 43; continue; };
            { gotoCase = 18; continue; };
case 29:
            yych = this._charAt(++cursor);
            if (yych == '+') { gotoCase = 43; continue; };
            if (yych == '=') { gotoCase = 43; continue; };
            { gotoCase = 18; continue; };
case 30:
            yych = this._charAt(++cursor);
            if (yych == '-') { gotoCase = 43; continue; };
            if (yych == '=') { gotoCase = 43; continue; };
            { gotoCase = 18; continue; };
case 31:
            yych = this._charAt(++cursor);
            if (yych <= '/') { gotoCase = 18; continue; };
            if (yych <= '9') { gotoCase = 89; continue; };
            { gotoCase = 18; continue; };
case 32:
            yyaccept = 2;
            yych = this._charAt(YYMARKER = ++cursor);
            if (yych <= '.') {
                if (yych == '*') { gotoCase = 78; continue; };
            } else {
                if (yych <= '/') { gotoCase = 80; continue; };
                if (yych == '=') { gotoCase = 77; continue; };
            }
case 33:
            this.setLexCondition(this._lexConditions.NODIV);
            { this.tokenType = null; return cursor; }
case 34:
            yyaccept = 3;
            yych = this._charAt(YYMARKER = ++cursor);
            if (yych <= 'E') {
                if (yych <= '/') {
                    if (yych == '.') { gotoCase = 63; continue; };
                } else {
                    if (yych <= '7') { gotoCase = 72; continue; };
                    if (yych >= 'E') { gotoCase = 62; continue; };
                }
            } else {
                if (yych <= 'd') {
                    if (yych == 'X') { gotoCase = 74; continue; };
                } else {
                    if (yych <= 'e') { gotoCase = 62; continue; };
                    if (yych == 'x') { gotoCase = 74; continue; };
                }
            }
case 35:
            { this.tokenType = "javascript-number"; return cursor; }
case 36:
            yyaccept = 3;
            yych = this._charAt(YYMARKER = ++cursor);
            if (yych <= '9') {
                if (yych == '.') { gotoCase = 63; continue; };
                if (yych <= '/') { gotoCase = 35; continue; };
                { gotoCase = 60; continue; };
            } else {
                if (yych <= 'E') {
                    if (yych <= 'D') { gotoCase = 35; continue; };
                    { gotoCase = 62; continue; };
                } else {
                    if (yych == 'e') { gotoCase = 62; continue; };
                    { gotoCase = 35; continue; };
                }
            }
case 37:
            yych = this._charAt(++cursor);
            if (yych <= ';') { gotoCase = 18; continue; };
            if (yych <= '<') { gotoCase = 59; continue; };
            if (yych <= '=') { gotoCase = 43; continue; };
            { gotoCase = 18; continue; };
case 38:
            yych = this._charAt(++cursor);
            if (yych == '=') { gotoCase = 58; continue; };
            { gotoCase = 18; continue; };
case 39:
            yych = this._charAt(++cursor);
            if (yych <= '<') { gotoCase = 18; continue; };
            if (yych <= '=') { gotoCase = 43; continue; };
            if (yych <= '>') { gotoCase = 56; continue; };
            { gotoCase = 18; continue; };
case 40:
            yyaccept = 0;
            yych = this._charAt(YYMARKER = ++cursor);
            if (yych == 'u') { gotoCase = 44; continue; };
            { gotoCase = 16; continue; };
case 41:
            yych = this._charAt(++cursor);
            if (yych == '=') { gotoCase = 43; continue; };
            { gotoCase = 18; continue; };
case 42:
            yych = this._charAt(++cursor);
            if (yych == '=') { gotoCase = 43; continue; };
            if (yych != '|') { gotoCase = 18; continue; };
case 43:
            yych = this._charAt(++cursor);
            { gotoCase = 18; continue; };
case 44:
            yych = this._charAt(++cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 45; continue; };
                if (yych <= '9') { gotoCase = 46; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 46; continue; };
                if (yych <= '`') { gotoCase = 45; continue; };
                if (yych <= 'f') { gotoCase = 46; continue; };
            }
case 45:
            cursor = YYMARKER;
            if (yyaccept <= 1) {
                if (yyaccept <= 0) {
                    { gotoCase = 16; continue; };
                } else {
                    { gotoCase = 21; continue; };
                }
            } else {
                if (yyaccept <= 2) {
                    { gotoCase = 33; continue; };
                } else {
                    { gotoCase = 35; continue; };
                }
            }
case 46:
            yych = this._charAt(++cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 45; continue; };
                if (yych >= ':') { gotoCase = 45; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 47; continue; };
                if (yych <= '`') { gotoCase = 45; continue; };
                if (yych >= 'g') { gotoCase = 45; continue; };
            }
case 47:
            yych = this._charAt(++cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 45; continue; };
                if (yych >= ':') { gotoCase = 45; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 48; continue; };
                if (yych <= '`') { gotoCase = 45; continue; };
                if (yych >= 'g') { gotoCase = 45; continue; };
            }
case 48:
            yych = this._charAt(++cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 45; continue; };
                if (yych >= ':') { gotoCase = 45; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 49; continue; };
                if (yych <= '`') { gotoCase = 45; continue; };
                if (yych >= 'g') { gotoCase = 45; continue; };
            }
case 49:
            yyaccept = 1;
            YYMARKER = ++cursor;
            yych = this._charAt(cursor);
case 50:
            if (yych <= '[') {
                if (yych <= '/') {
                    if (yych == '$') { gotoCase = 49; continue; };
                    { gotoCase = 21; continue; };
                } else {
                    if (yych <= '9') { gotoCase = 49; continue; };
                    if (yych <= '@') { gotoCase = 21; continue; };
                    if (yych <= 'Z') { gotoCase = 49; continue; };
                    { gotoCase = 21; continue; };
                }
            } else {
                if (yych <= '_') {
                    if (yych <= '\\') { gotoCase = 51; continue; };
                    if (yych <= '^') { gotoCase = 21; continue; };
                    { gotoCase = 49; continue; };
                } else {
                    if (yych <= '`') { gotoCase = 21; continue; };
                    if (yych <= 'z') { gotoCase = 49; continue; };
                    if (yych <= String.fromCharCode(0x7F)) { gotoCase = 21; continue; };
                    { gotoCase = 49; continue; };
                }
            }
case 51:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych != 'u') { gotoCase = 45; continue; };
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 45; continue; };
                if (yych >= ':') { gotoCase = 45; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 53; continue; };
                if (yych <= '`') { gotoCase = 45; continue; };
                if (yych >= 'g') { gotoCase = 45; continue; };
            }
case 53:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 45; continue; };
                if (yych >= ':') { gotoCase = 45; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 54; continue; };
                if (yych <= '`') { gotoCase = 45; continue; };
                if (yych >= 'g') { gotoCase = 45; continue; };
            }
case 54:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 45; continue; };
                if (yych >= ':') { gotoCase = 45; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 55; continue; };
                if (yych <= '`') { gotoCase = 45; continue; };
                if (yych >= 'g') { gotoCase = 45; continue; };
            }
case 55:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 45; continue; };
                if (yych <= '9') { gotoCase = 49; continue; };
                { gotoCase = 45; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 49; continue; };
                if (yych <= '`') { gotoCase = 45; continue; };
                if (yych <= 'f') { gotoCase = 49; continue; };
                { gotoCase = 45; continue; };
            }
case 56:
            yych = this._charAt(++cursor);
            if (yych <= '<') { gotoCase = 18; continue; };
            if (yych <= '=') { gotoCase = 43; continue; };
            if (yych >= '?') { gotoCase = 18; continue; };
            yych = this._charAt(++cursor);
            if (yych == '=') { gotoCase = 43; continue; };
            { gotoCase = 18; continue; };
case 58:
            yych = this._charAt(++cursor);
            if (yych == '=') { gotoCase = 43; continue; };
            { gotoCase = 18; continue; };
case 59:
            yych = this._charAt(++cursor);
            if (yych == '=') { gotoCase = 43; continue; };
            { gotoCase = 18; continue; };
case 60:
            yyaccept = 3;
            YYMARKER = ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '9') {
                if (yych == '.') { gotoCase = 63; continue; };
                if (yych <= '/') { gotoCase = 35; continue; };
                { gotoCase = 60; continue; };
            } else {
                if (yych <= 'E') {
                    if (yych <= 'D') { gotoCase = 35; continue; };
                } else {
                    if (yych != 'e') { gotoCase = 35; continue; };
                }
            }
case 62:
            yych = this._charAt(++cursor);
            if (yych <= ',') {
                if (yych == '+') { gotoCase = 69; continue; };
                { gotoCase = 45; continue; };
            } else {
                if (yych <= '-') { gotoCase = 69; continue; };
                if (yych <= '/') { gotoCase = 45; continue; };
                if (yych <= '9') { gotoCase = 70; continue; };
                { gotoCase = 45; continue; };
            }
case 63:
            yyaccept = 3;
            YYMARKER = ++cursor;
            yych = this._charAt(cursor);
            if (yych <= 'D') {
                if (yych <= '/') { gotoCase = 35; continue; };
                if (yych <= '9') { gotoCase = 63; continue; };
                { gotoCase = 35; continue; };
            } else {
                if (yych <= 'E') { gotoCase = 65; continue; };
                if (yych != 'e') { gotoCase = 35; continue; };
            }
case 65:
            yych = this._charAt(++cursor);
            if (yych <= ',') {
                if (yych != '+') { gotoCase = 45; continue; };
            } else {
                if (yych <= '-') { gotoCase = 66; continue; };
                if (yych <= '/') { gotoCase = 45; continue; };
                if (yych <= '9') { gotoCase = 67; continue; };
                { gotoCase = 45; continue; };
            }
case 66:
            yych = this._charAt(++cursor);
            if (yych <= '/') { gotoCase = 45; continue; };
            if (yych >= ':') { gotoCase = 45; continue; };
case 67:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '/') { gotoCase = 35; continue; };
            if (yych <= '9') { gotoCase = 67; continue; };
            { gotoCase = 35; continue; };
case 69:
            yych = this._charAt(++cursor);
            if (yych <= '/') { gotoCase = 45; continue; };
            if (yych >= ':') { gotoCase = 45; continue; };
case 70:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '/') { gotoCase = 35; continue; };
            if (yych <= '9') { gotoCase = 70; continue; };
            { gotoCase = 35; continue; };
case 72:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '/') { gotoCase = 35; continue; };
            if (yych <= '7') { gotoCase = 72; continue; };
            { gotoCase = 35; continue; };
case 74:
            yych = this._charAt(++cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 45; continue; };
                if (yych >= ':') { gotoCase = 45; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 75; continue; };
                if (yych <= '`') { gotoCase = 45; continue; };
                if (yych >= 'g') { gotoCase = 45; continue; };
            }
case 75:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 35; continue; };
                if (yych <= '9') { gotoCase = 75; continue; };
                { gotoCase = 35; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 75; continue; };
                if (yych <= '`') { gotoCase = 35; continue; };
                if (yych <= 'f') { gotoCase = 75; continue; };
                { gotoCase = 35; continue; };
            }
case 77:
            yych = this._charAt(++cursor);
            { gotoCase = 33; continue; };
case 78:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '\f') {
                if (yych == '\n') { gotoCase = 85; continue; };
                { gotoCase = 78; continue; };
            } else {
                if (yych <= '\r') { gotoCase = 85; continue; };
                if (yych == '*') { gotoCase = 83; continue; };
                { gotoCase = 78; continue; };
            }
case 80:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych == '\n') { gotoCase = 82; continue; };
            if (yych != '\r') { gotoCase = 80; continue; };
case 82:
            { this.tokenType = "javascript-comment"; return cursor; }
case 83:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych == '*') { gotoCase = 83; continue; };
            if (yych == '/') { gotoCase = 87; continue; };
            { gotoCase = 78; continue; };
case 85:
            ++cursor;
            this.setLexCondition(this._lexConditions.COMMENT);
            { this.tokenType = "javascript-comment"; return cursor; }
case 87:
            ++cursor;
            { this.tokenType = "javascript-comment"; return cursor; }
case 89:
            yyaccept = 3;
            YYMARKER = ++cursor;
            yych = this._charAt(cursor);
            if (yych <= 'D') {
                if (yych <= '/') { gotoCase = 35; continue; };
                if (yych <= '9') { gotoCase = 89; continue; };
                { gotoCase = 35; continue; };
            } else {
                if (yych <= 'E') { gotoCase = 91; continue; };
                if (yych != 'e') { gotoCase = 35; continue; };
            }
case 91:
            yych = this._charAt(++cursor);
            if (yych <= ',') {
                if (yych != '+') { gotoCase = 45; continue; };
            } else {
                if (yych <= '-') { gotoCase = 92; continue; };
                if (yych <= '/') { gotoCase = 45; continue; };
                if (yych <= '9') { gotoCase = 93; continue; };
                { gotoCase = 45; continue; };
            }
case 92:
            yych = this._charAt(++cursor);
            if (yych <= '/') { gotoCase = 45; continue; };
            if (yych >= ':') { gotoCase = 45; continue; };
case 93:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '/') { gotoCase = 35; continue; };
            if (yych <= '9') { gotoCase = 93; continue; };
            { gotoCase = 35; continue; };
case 95:
            ++cursor;
            yych = this._charAt(cursor);
case 96:
            if (yych <= '\r') {
                if (yych == '\n') { gotoCase = 45; continue; };
                if (yych <= '\f') { gotoCase = 95; continue; };
                { gotoCase = 45; continue; };
            } else {
                if (yych <= '\'') {
                    if (yych <= '&') { gotoCase = 95; continue; };
                    { gotoCase = 98; continue; };
                } else {
                    if (yych != '\\') { gotoCase = 95; continue; };
                }
            }
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= 'a') {
                if (yych <= '!') {
                    if (yych <= '\n') {
                        if (yych <= '\t') { gotoCase = 45; continue; };
                        { gotoCase = 101; continue; };
                    } else {
                        if (yych == '\r') { gotoCase = 101; continue; };
                        { gotoCase = 45; continue; };
                    }
                } else {
                    if (yych <= '\'') {
                        if (yych <= '"') { gotoCase = 95; continue; };
                        if (yych <= '&') { gotoCase = 45; continue; };
                        { gotoCase = 95; continue; };
                    } else {
                        if (yych == '\\') { gotoCase = 95; continue; };
                        { gotoCase = 45; continue; };
                    }
                }
            } else {
                if (yych <= 'q') {
                    if (yych <= 'f') {
                        if (yych <= 'b') { gotoCase = 95; continue; };
                        if (yych <= 'e') { gotoCase = 45; continue; };
                        { gotoCase = 95; continue; };
                    } else {
                        if (yych == 'n') { gotoCase = 95; continue; };
                        { gotoCase = 45; continue; };
                    }
                } else {
                    if (yych <= 't') {
                        if (yych == 's') { gotoCase = 45; continue; };
                        { gotoCase = 95; continue; };
                    } else {
                        if (yych <= 'u') { gotoCase = 100; continue; };
                        if (yych <= 'v') { gotoCase = 95; continue; };
                        { gotoCase = 45; continue; };
                    }
                }
            }
case 98:
            ++cursor;
            { this.tokenType = "javascript-string"; return cursor; }
case 100:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 45; continue; };
                if (yych <= '9') { gotoCase = 103; continue; };
                { gotoCase = 45; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 103; continue; };
                if (yych <= '`') { gotoCase = 45; continue; };
                if (yych <= 'f') { gotoCase = 103; continue; };
                { gotoCase = 45; continue; };
            }
case 101:
            ++cursor;
            this.setLexCondition(this._lexConditions.SSTRING);
            { this.tokenType = "javascript-string"; return cursor; }
case 103:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 45; continue; };
                if (yych >= ':') { gotoCase = 45; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 104; continue; };
                if (yych <= '`') { gotoCase = 45; continue; };
                if (yych >= 'g') { gotoCase = 45; continue; };
            }
case 104:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 45; continue; };
                if (yych >= ':') { gotoCase = 45; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 105; continue; };
                if (yych <= '`') { gotoCase = 45; continue; };
                if (yych >= 'g') { gotoCase = 45; continue; };
            }
case 105:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 45; continue; };
                if (yych <= '9') { gotoCase = 95; continue; };
                { gotoCase = 45; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 95; continue; };
                if (yych <= '`') { gotoCase = 45; continue; };
                if (yych <= 'f') { gotoCase = 95; continue; };
                { gotoCase = 45; continue; };
            }
case 106:
            ++cursor;
            yych = this._charAt(cursor);
case 107:
            if (yych <= '\r') {
                if (yych == '\n') { gotoCase = 45; continue; };
                if (yych <= '\f') { gotoCase = 106; continue; };
                { gotoCase = 45; continue; };
            } else {
                if (yych <= '"') {
                    if (yych <= '!') { gotoCase = 106; continue; };
                    { gotoCase = 98; continue; };
                } else {
                    if (yych != '\\') { gotoCase = 106; continue; };
                }
            }
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= 'a') {
                if (yych <= '!') {
                    if (yych <= '\n') {
                        if (yych <= '\t') { gotoCase = 45; continue; };
                        { gotoCase = 110; continue; };
                    } else {
                        if (yych == '\r') { gotoCase = 110; continue; };
                        { gotoCase = 45; continue; };
                    }
                } else {
                    if (yych <= '\'') {
                        if (yych <= '"') { gotoCase = 106; continue; };
                        if (yych <= '&') { gotoCase = 45; continue; };
                        { gotoCase = 106; continue; };
                    } else {
                        if (yych == '\\') { gotoCase = 106; continue; };
                        { gotoCase = 45; continue; };
                    }
                }
            } else {
                if (yych <= 'q') {
                    if (yych <= 'f') {
                        if (yych <= 'b') { gotoCase = 106; continue; };
                        if (yych <= 'e') { gotoCase = 45; continue; };
                        { gotoCase = 106; continue; };
                    } else {
                        if (yych == 'n') { gotoCase = 106; continue; };
                        { gotoCase = 45; continue; };
                    }
                } else {
                    if (yych <= 't') {
                        if (yych == 's') { gotoCase = 45; continue; };
                        { gotoCase = 106; continue; };
                    } else {
                        if (yych <= 'u') { gotoCase = 109; continue; };
                        if (yych <= 'v') { gotoCase = 106; continue; };
                        { gotoCase = 45; continue; };
                    }
                }
            }
case 109:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 45; continue; };
                if (yych <= '9') { gotoCase = 112; continue; };
                { gotoCase = 45; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 112; continue; };
                if (yych <= '`') { gotoCase = 45; continue; };
                if (yych <= 'f') { gotoCase = 112; continue; };
                { gotoCase = 45; continue; };
            }
case 110:
            ++cursor;
            this.setLexCondition(this._lexConditions.DSTRING);
            { this.tokenType = "javascript-string"; return cursor; }
case 112:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 45; continue; };
                if (yych >= ':') { gotoCase = 45; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 113; continue; };
                if (yych <= '`') { gotoCase = 45; continue; };
                if (yych >= 'g') { gotoCase = 45; continue; };
            }
case 113:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 45; continue; };
                if (yych >= ':') { gotoCase = 45; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 114; continue; };
                if (yych <= '`') { gotoCase = 45; continue; };
                if (yych >= 'g') { gotoCase = 45; continue; };
            }
case 114:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 45; continue; };
                if (yych <= '9') { gotoCase = 106; continue; };
                { gotoCase = 45; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 106; continue; };
                if (yych <= '`') { gotoCase = 45; continue; };
                if (yych <= 'f') { gotoCase = 106; continue; };
                { gotoCase = 45; continue; };
            }
case 115:
            ++cursor;
            if ((yych = this._charAt(cursor)) == '=') { gotoCase = 43; continue; };
            { gotoCase = 18; continue; };
/* *********************************** */
case this.case_DSTRING:
            yych = this._charAt(cursor);
            if (yych <= '\r') {
                if (yych == '\n') { gotoCase = 120; continue; };
                if (yych <= '\f') { gotoCase = 119; continue; };
                { gotoCase = 120; continue; };
            } else {
                if (yych <= '"') {
                    if (yych <= '!') { gotoCase = 119; continue; };
                    { gotoCase = 122; continue; };
                } else {
                    if (yych == '\\') { gotoCase = 124; continue; };
                    { gotoCase = 119; continue; };
                }
            }
case 118:
            { this.tokenType = "javascript-string"; return cursor; }
case 119:
            yyaccept = 0;
            yych = this._charAt(YYMARKER = ++cursor);
            { gotoCase = 126; continue; };
case 120:
            ++cursor;
case 121:
            { this.tokenType = null; return cursor; }
case 122:
            ++cursor;
case 123:
            this.setLexCondition(this._lexConditions.NODIV);
            { this.tokenType = "javascript-string"; return cursor; }
case 124:
            yyaccept = 1;
            yych = this._charAt(YYMARKER = ++cursor);
            if (yych <= 'e') {
                if (yych <= '\'') {
                    if (yych == '"') { gotoCase = 125; continue; };
                    if (yych <= '&') { gotoCase = 121; continue; };
                } else {
                    if (yych <= '\\') {
                        if (yych <= '[') { gotoCase = 121; continue; };
                    } else {
                        if (yych != 'b') { gotoCase = 121; continue; };
                    }
                }
            } else {
                if (yych <= 'r') {
                    if (yych <= 'm') {
                        if (yych >= 'g') { gotoCase = 121; continue; };
                    } else {
                        if (yych <= 'n') { gotoCase = 125; continue; };
                        if (yych <= 'q') { gotoCase = 121; continue; };
                    }
                } else {
                    if (yych <= 't') {
                        if (yych <= 's') { gotoCase = 121; continue; };
                    } else {
                        if (yych <= 'u') { gotoCase = 127; continue; };
                        if (yych >= 'w') { gotoCase = 121; continue; };
                    }
                }
            }
case 125:
            yyaccept = 0;
            YYMARKER = ++cursor;
            yych = this._charAt(cursor);
case 126:
            if (yych <= '\r') {
                if (yych == '\n') { gotoCase = 118; continue; };
                if (yych <= '\f') { gotoCase = 125; continue; };
                { gotoCase = 118; continue; };
            } else {
                if (yych <= '"') {
                    if (yych <= '!') { gotoCase = 125; continue; };
                    { gotoCase = 133; continue; };
                } else {
                    if (yych == '\\') { gotoCase = 132; continue; };
                    { gotoCase = 125; continue; };
                }
            }
case 127:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 128; continue; };
                if (yych <= '9') { gotoCase = 129; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 129; continue; };
                if (yych <= '`') { gotoCase = 128; continue; };
                if (yych <= 'f') { gotoCase = 129; continue; };
            }
case 128:
            cursor = YYMARKER;
            if (yyaccept <= 0) {
                { gotoCase = 118; continue; };
            } else {
                { gotoCase = 121; continue; };
            }
case 129:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 128; continue; };
                if (yych >= ':') { gotoCase = 128; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 130; continue; };
                if (yych <= '`') { gotoCase = 128; continue; };
                if (yych >= 'g') { gotoCase = 128; continue; };
            }
case 130:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 128; continue; };
                if (yych >= ':') { gotoCase = 128; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 131; continue; };
                if (yych <= '`') { gotoCase = 128; continue; };
                if (yych >= 'g') { gotoCase = 128; continue; };
            }
case 131:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 128; continue; };
                if (yych <= '9') { gotoCase = 125; continue; };
                { gotoCase = 128; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 125; continue; };
                if (yych <= '`') { gotoCase = 128; continue; };
                if (yych <= 'f') { gotoCase = 125; continue; };
                { gotoCase = 128; continue; };
            }
case 132:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= 'e') {
                if (yych <= '\'') {
                    if (yych == '"') { gotoCase = 125; continue; };
                    if (yych <= '&') { gotoCase = 128; continue; };
                    { gotoCase = 125; continue; };
                } else {
                    if (yych <= '\\') {
                        if (yych <= '[') { gotoCase = 128; continue; };
                        { gotoCase = 125; continue; };
                    } else {
                        if (yych == 'b') { gotoCase = 125; continue; };
                        { gotoCase = 128; continue; };
                    }
                }
            } else {
                if (yych <= 'r') {
                    if (yych <= 'm') {
                        if (yych <= 'f') { gotoCase = 125; continue; };
                        { gotoCase = 128; continue; };
                    } else {
                        if (yych <= 'n') { gotoCase = 125; continue; };
                        if (yych <= 'q') { gotoCase = 128; continue; };
                        { gotoCase = 125; continue; };
                    }
                } else {
                    if (yych <= 't') {
                        if (yych <= 's') { gotoCase = 128; continue; };
                        { gotoCase = 125; continue; };
                    } else {
                        if (yych <= 'u') { gotoCase = 127; continue; };
                        if (yych <= 'v') { gotoCase = 125; continue; };
                        { gotoCase = 128; continue; };
                    }
                }
            }
case 133:
            ++cursor;
            yych = this._charAt(cursor);
            { gotoCase = 123; continue; };
/* *********************************** */
case this.case_NODIV:
            yych = this._charAt(cursor);
            if (yych <= '9') {
                if (yych <= '(') {
                    if (yych <= '#') {
                        if (yych <= ' ') { gotoCase = 136; continue; };
                        if (yych <= '!') { gotoCase = 138; continue; };
                        if (yych <= '"') { gotoCase = 140; continue; };
                    } else {
                        if (yych <= '%') {
                            if (yych <= '$') { gotoCase = 141; continue; };
                            { gotoCase = 143; continue; };
                        } else {
                            if (yych <= '&') { gotoCase = 144; continue; };
                            if (yych <= '\'') { gotoCase = 145; continue; };
                            { gotoCase = 146; continue; };
                        }
                    }
                } else {
                    if (yych <= ',') {
                        if (yych <= ')') { gotoCase = 147; continue; };
                        if (yych <= '*') { gotoCase = 149; continue; };
                        if (yych <= '+') { gotoCase = 150; continue; };
                        { gotoCase = 146; continue; };
                    } else {
                        if (yych <= '.') {
                            if (yych <= '-') { gotoCase = 151; continue; };
                            { gotoCase = 152; continue; };
                        } else {
                            if (yych <= '/') { gotoCase = 153; continue; };
                            if (yych <= '0') { gotoCase = 154; continue; };
                            { gotoCase = 156; continue; };
                        }
                    }
                }
            } else {
                if (yych <= '\\') {
                    if (yych <= '>') {
                        if (yych <= ';') { gotoCase = 146; continue; };
                        if (yych <= '<') { gotoCase = 157; continue; };
                        if (yych <= '=') { gotoCase = 158; continue; };
                        { gotoCase = 159; continue; };
                    } else {
                        if (yych <= '@') {
                            if (yych <= '?') { gotoCase = 146; continue; };
                        } else {
                            if (yych <= 'Z') { gotoCase = 141; continue; };
                            if (yych <= '[') { gotoCase = 146; continue; };
                            { gotoCase = 160; continue; };
                        }
                    }
                } else {
                    if (yych <= 'z') {
                        if (yych <= '^') {
                            if (yych <= ']') { gotoCase = 146; continue; };
                            { gotoCase = 161; continue; };
                        } else {
                            if (yych != '`') { gotoCase = 141; continue; };
                        }
                    } else {
                        if (yych <= '|') {
                            if (yych <= '{') { gotoCase = 146; continue; };
                            { gotoCase = 162; continue; };
                        } else {
                            if (yych <= '~') { gotoCase = 146; continue; };
                            if (yych >= 0x80) { gotoCase = 141; continue; };
                        }
                    }
                }
            }
case 136:
            ++cursor;
case 137:
            { this.tokenType = null; return cursor; }
case 138:
            ++cursor;
            if ((yych = this._charAt(cursor)) == '=') { gotoCase = 260; continue; };
case 139:
            { this.tokenType = null; return cursor; }
case 140:
            yyaccept = 0;
            yych = this._charAt(YYMARKER = ++cursor);
            if (yych == '\n') { gotoCase = 137; continue; };
            if (yych == '\r') { gotoCase = 137; continue; };
            { gotoCase = 252; continue; };
case 141:
            yyaccept = 1;
            yych = this._charAt(YYMARKER = ++cursor);
            { gotoCase = 170; continue; };
case 142:
            this.setLexCondition(this._lexConditions.DIV);
            {
                    var token = this._line.substring(cursorOnEnter, cursor);
                    if (this._keywords[token] === true && token !== "__proto__")
                        this.tokenType = "javascript-keyword";
                    else
                        this.tokenType = "javascript-ident";
                    return cursor;
                }
case 143:
            yych = this._charAt(++cursor);
            if (yych == '=') { gotoCase = 163; continue; };
            { gotoCase = 139; continue; };
case 144:
            yych = this._charAt(++cursor);
            if (yych == '&') { gotoCase = 163; continue; };
            if (yych == '=') { gotoCase = 163; continue; };
            { gotoCase = 139; continue; };
case 145:
            yyaccept = 0;
            yych = this._charAt(YYMARKER = ++cursor);
            if (yych == '\n') { gotoCase = 137; continue; };
            if (yych == '\r') { gotoCase = 137; continue; };
            { gotoCase = 241; continue; };
case 146:
            yych = this._charAt(++cursor);
            { gotoCase = 139; continue; };
case 147:
            ++cursor;
            this.setLexCondition(this._lexConditions.DIV);
            { this.tokenType = null; return cursor; }
case 149:
            yych = this._charAt(++cursor);
            if (yych == '=') { gotoCase = 163; continue; };
            { gotoCase = 139; continue; };
case 150:
            yych = this._charAt(++cursor);
            if (yych == '+') { gotoCase = 163; continue; };
            if (yych == '=') { gotoCase = 163; continue; };
            { gotoCase = 139; continue; };
case 151:
            yych = this._charAt(++cursor);
            if (yych == '-') { gotoCase = 163; continue; };
            if (yych == '=') { gotoCase = 163; continue; };
            { gotoCase = 139; continue; };
case 152:
            yych = this._charAt(++cursor);
            if (yych <= '/') { gotoCase = 139; continue; };
            if (yych <= '9') { gotoCase = 234; continue; };
            { gotoCase = 139; continue; };
case 153:
            yyaccept = 0;
            yych = this._charAt(YYMARKER = ++cursor);
            if (yych <= '*') {
                if (yych <= '\f') {
                    if (yych == '\n') { gotoCase = 137; continue; };
                    { gotoCase = 197; continue; };
                } else {
                    if (yych <= '\r') { gotoCase = 137; continue; };
                    if (yych <= ')') { gotoCase = 197; continue; };
                    { gotoCase = 202; continue; };
                }
            } else {
                if (yych <= 'Z') {
                    if (yych == '/') { gotoCase = 204; continue; };
                    { gotoCase = 197; continue; };
                } else {
                    if (yych <= '[') { gotoCase = 200; continue; };
                    if (yych <= '\\') { gotoCase = 199; continue; };
                    if (yych <= ']') { gotoCase = 137; continue; };
                    { gotoCase = 197; continue; };
                }
            }
case 154:
            yyaccept = 2;
            yych = this._charAt(YYMARKER = ++cursor);
            if (yych <= 'E') {
                if (yych <= '/') {
                    if (yych == '.') { gotoCase = 183; continue; };
                } else {
                    if (yych <= '7') { gotoCase = 192; continue; };
                    if (yych >= 'E') { gotoCase = 182; continue; };
                }
            } else {
                if (yych <= 'd') {
                    if (yych == 'X') { gotoCase = 194; continue; };
                } else {
                    if (yych <= 'e') { gotoCase = 182; continue; };
                    if (yych == 'x') { gotoCase = 194; continue; };
                }
            }
case 155:
            this.setLexCondition(this._lexConditions.DIV);
            { this.tokenType = "javascript-number"; return cursor; }
case 156:
            yyaccept = 2;
            yych = this._charAt(YYMARKER = ++cursor);
            if (yych <= '9') {
                if (yych == '.') { gotoCase = 183; continue; };
                if (yych <= '/') { gotoCase = 155; continue; };
                { gotoCase = 180; continue; };
            } else {
                if (yych <= 'E') {
                    if (yych <= 'D') { gotoCase = 155; continue; };
                    { gotoCase = 182; continue; };
                } else {
                    if (yych == 'e') { gotoCase = 182; continue; };
                    { gotoCase = 155; continue; };
                }
            }
case 157:
            yych = this._charAt(++cursor);
            if (yych <= ';') { gotoCase = 139; continue; };
            if (yych <= '<') { gotoCase = 179; continue; };
            if (yych <= '=') { gotoCase = 163; continue; };
            { gotoCase = 139; continue; };
case 158:
            yych = this._charAt(++cursor);
            if (yych == '=') { gotoCase = 178; continue; };
            { gotoCase = 139; continue; };
case 159:
            yych = this._charAt(++cursor);
            if (yych <= '<') { gotoCase = 139; continue; };
            if (yych <= '=') { gotoCase = 163; continue; };
            if (yych <= '>') { gotoCase = 176; continue; };
            { gotoCase = 139; continue; };
case 160:
            yyaccept = 0;
            yych = this._charAt(YYMARKER = ++cursor);
            if (yych == 'u') { gotoCase = 164; continue; };
            { gotoCase = 137; continue; };
case 161:
            yych = this._charAt(++cursor);
            if (yych == '=') { gotoCase = 163; continue; };
            { gotoCase = 139; continue; };
case 162:
            yych = this._charAt(++cursor);
            if (yych == '=') { gotoCase = 163; continue; };
            if (yych != '|') { gotoCase = 139; continue; };
case 163:
            yych = this._charAt(++cursor);
            { gotoCase = 139; continue; };
case 164:
            yych = this._charAt(++cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 165; continue; };
                if (yych <= '9') { gotoCase = 166; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 166; continue; };
                if (yych <= '`') { gotoCase = 165; continue; };
                if (yych <= 'f') { gotoCase = 166; continue; };
            }
case 165:
            cursor = YYMARKER;
            if (yyaccept <= 1) {
                if (yyaccept <= 0) {
                    { gotoCase = 137; continue; };
                } else {
                    { gotoCase = 142; continue; };
                }
            } else {
                if (yyaccept <= 2) {
                    { gotoCase = 155; continue; };
                } else {
                    { gotoCase = 217; continue; };
                }
            }
case 166:
            yych = this._charAt(++cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 165; continue; };
                if (yych >= ':') { gotoCase = 165; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 167; continue; };
                if (yych <= '`') { gotoCase = 165; continue; };
                if (yych >= 'g') { gotoCase = 165; continue; };
            }
case 167:
            yych = this._charAt(++cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 165; continue; };
                if (yych >= ':') { gotoCase = 165; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 168; continue; };
                if (yych <= '`') { gotoCase = 165; continue; };
                if (yych >= 'g') { gotoCase = 165; continue; };
            }
case 168:
            yych = this._charAt(++cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 165; continue; };
                if (yych >= ':') { gotoCase = 165; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 169; continue; };
                if (yych <= '`') { gotoCase = 165; continue; };
                if (yych >= 'g') { gotoCase = 165; continue; };
            }
case 169:
            yyaccept = 1;
            YYMARKER = ++cursor;
            yych = this._charAt(cursor);
case 170:
            if (yych <= '[') {
                if (yych <= '/') {
                    if (yych == '$') { gotoCase = 169; continue; };
                    { gotoCase = 142; continue; };
                } else {
                    if (yych <= '9') { gotoCase = 169; continue; };
                    if (yych <= '@') { gotoCase = 142; continue; };
                    if (yych <= 'Z') { gotoCase = 169; continue; };
                    { gotoCase = 142; continue; };
                }
            } else {
                if (yych <= '_') {
                    if (yych <= '\\') { gotoCase = 171; continue; };
                    if (yych <= '^') { gotoCase = 142; continue; };
                    { gotoCase = 169; continue; };
                } else {
                    if (yych <= '`') { gotoCase = 142; continue; };
                    if (yych <= 'z') { gotoCase = 169; continue; };
                    if (yych <= String.fromCharCode(0x7F)) { gotoCase = 142; continue; };
                    { gotoCase = 169; continue; };
                }
            }
case 171:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych != 'u') { gotoCase = 165; continue; };
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 165; continue; };
                if (yych >= ':') { gotoCase = 165; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 173; continue; };
                if (yych <= '`') { gotoCase = 165; continue; };
                if (yych >= 'g') { gotoCase = 165; continue; };
            }
case 173:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 165; continue; };
                if (yych >= ':') { gotoCase = 165; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 174; continue; };
                if (yych <= '`') { gotoCase = 165; continue; };
                if (yych >= 'g') { gotoCase = 165; continue; };
            }
case 174:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 165; continue; };
                if (yych >= ':') { gotoCase = 165; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 175; continue; };
                if (yych <= '`') { gotoCase = 165; continue; };
                if (yych >= 'g') { gotoCase = 165; continue; };
            }
case 175:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 165; continue; };
                if (yych <= '9') { gotoCase = 169; continue; };
                { gotoCase = 165; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 169; continue; };
                if (yych <= '`') { gotoCase = 165; continue; };
                if (yych <= 'f') { gotoCase = 169; continue; };
                { gotoCase = 165; continue; };
            }
case 176:
            yych = this._charAt(++cursor);
            if (yych <= '<') { gotoCase = 139; continue; };
            if (yych <= '=') { gotoCase = 163; continue; };
            if (yych >= '?') { gotoCase = 139; continue; };
            yych = this._charAt(++cursor);
            if (yych == '=') { gotoCase = 163; continue; };
            { gotoCase = 139; continue; };
case 178:
            yych = this._charAt(++cursor);
            if (yych == '=') { gotoCase = 163; continue; };
            { gotoCase = 139; continue; };
case 179:
            yych = this._charAt(++cursor);
            if (yych == '=') { gotoCase = 163; continue; };
            { gotoCase = 139; continue; };
case 180:
            yyaccept = 2;
            YYMARKER = ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '9') {
                if (yych == '.') { gotoCase = 183; continue; };
                if (yych <= '/') { gotoCase = 155; continue; };
                { gotoCase = 180; continue; };
            } else {
                if (yych <= 'E') {
                    if (yych <= 'D') { gotoCase = 155; continue; };
                } else {
                    if (yych != 'e') { gotoCase = 155; continue; };
                }
            }
case 182:
            yych = this._charAt(++cursor);
            if (yych <= ',') {
                if (yych == '+') { gotoCase = 189; continue; };
                { gotoCase = 165; continue; };
            } else {
                if (yych <= '-') { gotoCase = 189; continue; };
                if (yych <= '/') { gotoCase = 165; continue; };
                if (yych <= '9') { gotoCase = 190; continue; };
                { gotoCase = 165; continue; };
            }
case 183:
            yyaccept = 2;
            YYMARKER = ++cursor;
            yych = this._charAt(cursor);
            if (yych <= 'D') {
                if (yych <= '/') { gotoCase = 155; continue; };
                if (yych <= '9') { gotoCase = 183; continue; };
                { gotoCase = 155; continue; };
            } else {
                if (yych <= 'E') { gotoCase = 185; continue; };
                if (yych != 'e') { gotoCase = 155; continue; };
            }
case 185:
            yych = this._charAt(++cursor);
            if (yych <= ',') {
                if (yych != '+') { gotoCase = 165; continue; };
            } else {
                if (yych <= '-') { gotoCase = 186; continue; };
                if (yych <= '/') { gotoCase = 165; continue; };
                if (yych <= '9') { gotoCase = 187; continue; };
                { gotoCase = 165; continue; };
            }
case 186:
            yych = this._charAt(++cursor);
            if (yych <= '/') { gotoCase = 165; continue; };
            if (yych >= ':') { gotoCase = 165; continue; };
case 187:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '/') { gotoCase = 155; continue; };
            if (yych <= '9') { gotoCase = 187; continue; };
            { gotoCase = 155; continue; };
case 189:
            yych = this._charAt(++cursor);
            if (yych <= '/') { gotoCase = 165; continue; };
            if (yych >= ':') { gotoCase = 165; continue; };
case 190:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '/') { gotoCase = 155; continue; };
            if (yych <= '9') { gotoCase = 190; continue; };
            { gotoCase = 155; continue; };
case 192:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '/') { gotoCase = 155; continue; };
            if (yych <= '7') { gotoCase = 192; continue; };
            { gotoCase = 155; continue; };
case 194:
            yych = this._charAt(++cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 165; continue; };
                if (yych >= ':') { gotoCase = 165; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 195; continue; };
                if (yych <= '`') { gotoCase = 165; continue; };
                if (yych >= 'g') { gotoCase = 165; continue; };
            }
case 195:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 155; continue; };
                if (yych <= '9') { gotoCase = 195; continue; };
                { gotoCase = 155; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 195; continue; };
                if (yych <= '`') { gotoCase = 155; continue; };
                if (yych <= 'f') { gotoCase = 195; continue; };
                { gotoCase = 155; continue; };
            }
case 197:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '.') {
                if (yych <= '\n') {
                    if (yych <= '\t') { gotoCase = 197; continue; };
                    { gotoCase = 165; continue; };
                } else {
                    if (yych == '\r') { gotoCase = 165; continue; };
                    { gotoCase = 197; continue; };
                }
            } else {
                if (yych <= '[') {
                    if (yych <= '/') { gotoCase = 220; continue; };
                    if (yych <= 'Z') { gotoCase = 197; continue; };
                    { gotoCase = 228; continue; };
                } else {
                    if (yych <= '\\') { gotoCase = 227; continue; };
                    if (yych <= ']') { gotoCase = 165; continue; };
                    { gotoCase = 197; continue; };
                }
            }
case 199:
            yych = this._charAt(++cursor);
            if (yych == '\n') { gotoCase = 165; continue; };
            if (yych == '\r') { gotoCase = 165; continue; };
            { gotoCase = 197; continue; };
case 200:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '*') {
                if (yych <= '\f') {
                    if (yych == '\n') { gotoCase = 165; continue; };
                    { gotoCase = 200; continue; };
                } else {
                    if (yych <= '\r') { gotoCase = 165; continue; };
                    if (yych <= ')') { gotoCase = 200; continue; };
                    { gotoCase = 165; continue; };
                }
            } else {
                if (yych <= '[') {
                    if (yych == '/') { gotoCase = 165; continue; };
                    { gotoCase = 200; continue; };
                } else {
                    if (yych <= '\\') { gotoCase = 215; continue; };
                    if (yych <= ']') { gotoCase = 213; continue; };
                    { gotoCase = 200; continue; };
                }
            }
case 202:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '\f') {
                if (yych == '\n') { gotoCase = 209; continue; };
                { gotoCase = 202; continue; };
            } else {
                if (yych <= '\r') { gotoCase = 209; continue; };
                if (yych == '*') { gotoCase = 207; continue; };
                { gotoCase = 202; continue; };
            }
case 204:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych == '\n') { gotoCase = 206; continue; };
            if (yych != '\r') { gotoCase = 204; continue; };
case 206:
            { this.tokenType = "javascript-comment"; return cursor; }
case 207:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych == '*') { gotoCase = 207; continue; };
            if (yych == '/') { gotoCase = 211; continue; };
            { gotoCase = 202; continue; };
case 209:
            ++cursor;
            this.setLexCondition(this._lexConditions.COMMENT);
            { this.tokenType = "javascript-comment"; return cursor; }
case 211:
            ++cursor;
            { this.tokenType = "javascript-comment"; return cursor; }
case 213:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '*') {
                if (yych <= '\f') {
                    if (yych == '\n') { gotoCase = 165; continue; };
                    { gotoCase = 213; continue; };
                } else {
                    if (yych <= '\r') { gotoCase = 165; continue; };
                    if (yych <= ')') { gotoCase = 213; continue; };
                    { gotoCase = 197; continue; };
                }
            } else {
                if (yych <= 'Z') {
                    if (yych == '/') { gotoCase = 220; continue; };
                    { gotoCase = 213; continue; };
                } else {
                    if (yych <= '[') { gotoCase = 218; continue; };
                    if (yych <= '\\') { gotoCase = 216; continue; };
                    { gotoCase = 213; continue; };
                }
            }
case 215:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych == '\n') { gotoCase = 165; continue; };
            if (yych == '\r') { gotoCase = 165; continue; };
            { gotoCase = 200; continue; };
case 216:
            yyaccept = 3;
            YYMARKER = ++cursor;
            yych = this._charAt(cursor);
            if (yych == '\n') { gotoCase = 217; continue; };
            if (yych != '\r') { gotoCase = 213; continue; };
case 217:
            this.setLexCondition(this._lexConditions.REGEX);
            { this.tokenType = "javascript-regexp"; return cursor; }
case 218:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '*') {
                if (yych <= '\f') {
                    if (yych == '\n') { gotoCase = 165; continue; };
                    { gotoCase = 218; continue; };
                } else {
                    if (yych <= '\r') { gotoCase = 165; continue; };
                    if (yych <= ')') { gotoCase = 218; continue; };
                    { gotoCase = 165; continue; };
                }
            } else {
                if (yych <= '[') {
                    if (yych == '/') { gotoCase = 165; continue; };
                    { gotoCase = 218; continue; };
                } else {
                    if (yych <= '\\') { gotoCase = 225; continue; };
                    if (yych <= ']') { gotoCase = 223; continue; };
                    { gotoCase = 218; continue; };
                }
            }
case 220:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= 'h') {
                if (yych == 'g') { gotoCase = 220; continue; };
            } else {
                if (yych <= 'i') { gotoCase = 220; continue; };
                if (yych == 'm') { gotoCase = 220; continue; };
            }
            { this.tokenType = "javascript-regexp"; return cursor; }
case 223:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '*') {
                if (yych <= '\f') {
                    if (yych == '\n') { gotoCase = 165; continue; };
                    { gotoCase = 223; continue; };
                } else {
                    if (yych <= '\r') { gotoCase = 165; continue; };
                    if (yych <= ')') { gotoCase = 223; continue; };
                    { gotoCase = 197; continue; };
                }
            } else {
                if (yych <= 'Z') {
                    if (yych == '/') { gotoCase = 220; continue; };
                    { gotoCase = 223; continue; };
                } else {
                    if (yych <= '[') { gotoCase = 218; continue; };
                    if (yych <= '\\') { gotoCase = 226; continue; };
                    { gotoCase = 223; continue; };
                }
            }
case 225:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych == '\n') { gotoCase = 165; continue; };
            if (yych == '\r') { gotoCase = 165; continue; };
            { gotoCase = 218; continue; };
case 226:
            yyaccept = 3;
            YYMARKER = ++cursor;
            yych = this._charAt(cursor);
            if (yych == '\n') { gotoCase = 217; continue; };
            if (yych == '\r') { gotoCase = 217; continue; };
            { gotoCase = 223; continue; };
case 227:
            yyaccept = 3;
            YYMARKER = ++cursor;
            yych = this._charAt(cursor);
            if (yych == '\n') { gotoCase = 217; continue; };
            if (yych == '\r') { gotoCase = 217; continue; };
            { gotoCase = 197; continue; };
case 228:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '*') {
                if (yych <= '\f') {
                    if (yych == '\n') { gotoCase = 165; continue; };
                    { gotoCase = 228; continue; };
                } else {
                    if (yych <= '\r') { gotoCase = 165; continue; };
                    if (yych <= ')') { gotoCase = 228; continue; };
                    { gotoCase = 165; continue; };
                }
            } else {
                if (yych <= '[') {
                    if (yych == '/') { gotoCase = 165; continue; };
                    { gotoCase = 228; continue; };
                } else {
                    if (yych <= '\\') { gotoCase = 232; continue; };
                    if (yych >= '^') { gotoCase = 228; continue; };
                }
            }
case 230:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '*') {
                if (yych <= '\f') {
                    if (yych == '\n') { gotoCase = 165; continue; };
                    { gotoCase = 230; continue; };
                } else {
                    if (yych <= '\r') { gotoCase = 165; continue; };
                    if (yych <= ')') { gotoCase = 230; continue; };
                    { gotoCase = 197; continue; };
                }
            } else {
                if (yych <= 'Z') {
                    if (yych == '/') { gotoCase = 220; continue; };
                    { gotoCase = 230; continue; };
                } else {
                    if (yych <= '[') { gotoCase = 228; continue; };
                    if (yych <= '\\') { gotoCase = 233; continue; };
                    { gotoCase = 230; continue; };
                }
            }
case 232:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych == '\n') { gotoCase = 165; continue; };
            if (yych == '\r') { gotoCase = 165; continue; };
            { gotoCase = 228; continue; };
case 233:
            yyaccept = 3;
            YYMARKER = ++cursor;
            yych = this._charAt(cursor);
            if (yych == '\n') { gotoCase = 217; continue; };
            if (yych == '\r') { gotoCase = 217; continue; };
            { gotoCase = 230; continue; };
case 234:
            yyaccept = 2;
            YYMARKER = ++cursor;
            yych = this._charAt(cursor);
            if (yych <= 'D') {
                if (yych <= '/') { gotoCase = 155; continue; };
                if (yych <= '9') { gotoCase = 234; continue; };
                { gotoCase = 155; continue; };
            } else {
                if (yych <= 'E') { gotoCase = 236; continue; };
                if (yych != 'e') { gotoCase = 155; continue; };
            }
case 236:
            yych = this._charAt(++cursor);
            if (yych <= ',') {
                if (yych != '+') { gotoCase = 165; continue; };
            } else {
                if (yych <= '-') { gotoCase = 237; continue; };
                if (yych <= '/') { gotoCase = 165; continue; };
                if (yych <= '9') { gotoCase = 238; continue; };
                { gotoCase = 165; continue; };
            }
case 237:
            yych = this._charAt(++cursor);
            if (yych <= '/') { gotoCase = 165; continue; };
            if (yych >= ':') { gotoCase = 165; continue; };
case 238:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '/') { gotoCase = 155; continue; };
            if (yych <= '9') { gotoCase = 238; continue; };
            { gotoCase = 155; continue; };
case 240:
            ++cursor;
            yych = this._charAt(cursor);
case 241:
            if (yych <= '\r') {
                if (yych == '\n') { gotoCase = 165; continue; };
                if (yych <= '\f') { gotoCase = 240; continue; };
                { gotoCase = 165; continue; };
            } else {
                if (yych <= '\'') {
                    if (yych <= '&') { gotoCase = 240; continue; };
                    { gotoCase = 243; continue; };
                } else {
                    if (yych != '\\') { gotoCase = 240; continue; };
                }
            }
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= 'a') {
                if (yych <= '!') {
                    if (yych <= '\n') {
                        if (yych <= '\t') { gotoCase = 165; continue; };
                        { gotoCase = 246; continue; };
                    } else {
                        if (yych == '\r') { gotoCase = 246; continue; };
                        { gotoCase = 165; continue; };
                    }
                } else {
                    if (yych <= '\'') {
                        if (yych <= '"') { gotoCase = 240; continue; };
                        if (yych <= '&') { gotoCase = 165; continue; };
                        { gotoCase = 240; continue; };
                    } else {
                        if (yych == '\\') { gotoCase = 240; continue; };
                        { gotoCase = 165; continue; };
                    }
                }
            } else {
                if (yych <= 'q') {
                    if (yych <= 'f') {
                        if (yych <= 'b') { gotoCase = 240; continue; };
                        if (yych <= 'e') { gotoCase = 165; continue; };
                        { gotoCase = 240; continue; };
                    } else {
                        if (yych == 'n') { gotoCase = 240; continue; };
                        { gotoCase = 165; continue; };
                    }
                } else {
                    if (yych <= 't') {
                        if (yych == 's') { gotoCase = 165; continue; };
                        { gotoCase = 240; continue; };
                    } else {
                        if (yych <= 'u') { gotoCase = 245; continue; };
                        if (yych <= 'v') { gotoCase = 240; continue; };
                        { gotoCase = 165; continue; };
                    }
                }
            }
case 243:
            ++cursor;
            { this.tokenType = "javascript-string"; return cursor; }
case 245:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 165; continue; };
                if (yych <= '9') { gotoCase = 248; continue; };
                { gotoCase = 165; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 248; continue; };
                if (yych <= '`') { gotoCase = 165; continue; };
                if (yych <= 'f') { gotoCase = 248; continue; };
                { gotoCase = 165; continue; };
            }
case 246:
            ++cursor;
            this.setLexCondition(this._lexConditions.SSTRING);
            { this.tokenType = "javascript-string"; return cursor; }
case 248:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 165; continue; };
                if (yych >= ':') { gotoCase = 165; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 249; continue; };
                if (yych <= '`') { gotoCase = 165; continue; };
                if (yych >= 'g') { gotoCase = 165; continue; };
            }
case 249:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 165; continue; };
                if (yych >= ':') { gotoCase = 165; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 250; continue; };
                if (yych <= '`') { gotoCase = 165; continue; };
                if (yych >= 'g') { gotoCase = 165; continue; };
            }
case 250:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 165; continue; };
                if (yych <= '9') { gotoCase = 240; continue; };
                { gotoCase = 165; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 240; continue; };
                if (yych <= '`') { gotoCase = 165; continue; };
                if (yych <= 'f') { gotoCase = 240; continue; };
                { gotoCase = 165; continue; };
            }
case 251:
            ++cursor;
            yych = this._charAt(cursor);
case 252:
            if (yych <= '\r') {
                if (yych == '\n') { gotoCase = 165; continue; };
                if (yych <= '\f') { gotoCase = 251; continue; };
                { gotoCase = 165; continue; };
            } else {
                if (yych <= '"') {
                    if (yych <= '!') { gotoCase = 251; continue; };
                    { gotoCase = 243; continue; };
                } else {
                    if (yych != '\\') { gotoCase = 251; continue; };
                }
            }
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= 'a') {
                if (yych <= '!') {
                    if (yych <= '\n') {
                        if (yych <= '\t') { gotoCase = 165; continue; };
                        { gotoCase = 255; continue; };
                    } else {
                        if (yych == '\r') { gotoCase = 255; continue; };
                        { gotoCase = 165; continue; };
                    }
                } else {
                    if (yych <= '\'') {
                        if (yych <= '"') { gotoCase = 251; continue; };
                        if (yych <= '&') { gotoCase = 165; continue; };
                        { gotoCase = 251; continue; };
                    } else {
                        if (yych == '\\') { gotoCase = 251; continue; };
                        { gotoCase = 165; continue; };
                    }
                }
            } else {
                if (yych <= 'q') {
                    if (yych <= 'f') {
                        if (yych <= 'b') { gotoCase = 251; continue; };
                        if (yych <= 'e') { gotoCase = 165; continue; };
                        { gotoCase = 251; continue; };
                    } else {
                        if (yych == 'n') { gotoCase = 251; continue; };
                        { gotoCase = 165; continue; };
                    }
                } else {
                    if (yych <= 't') {
                        if (yych == 's') { gotoCase = 165; continue; };
                        { gotoCase = 251; continue; };
                    } else {
                        if (yych <= 'u') { gotoCase = 254; continue; };
                        if (yych <= 'v') { gotoCase = 251; continue; };
                        { gotoCase = 165; continue; };
                    }
                }
            }
case 254:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 165; continue; };
                if (yych <= '9') { gotoCase = 257; continue; };
                { gotoCase = 165; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 257; continue; };
                if (yych <= '`') { gotoCase = 165; continue; };
                if (yych <= 'f') { gotoCase = 257; continue; };
                { gotoCase = 165; continue; };
            }
case 255:
            ++cursor;
            this.setLexCondition(this._lexConditions.DSTRING);
            { this.tokenType = "javascript-string"; return cursor; }
case 257:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 165; continue; };
                if (yych >= ':') { gotoCase = 165; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 258; continue; };
                if (yych <= '`') { gotoCase = 165; continue; };
                if (yych >= 'g') { gotoCase = 165; continue; };
            }
case 258:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 165; continue; };
                if (yych >= ':') { gotoCase = 165; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 259; continue; };
                if (yych <= '`') { gotoCase = 165; continue; };
                if (yych >= 'g') { gotoCase = 165; continue; };
            }
case 259:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 165; continue; };
                if (yych <= '9') { gotoCase = 251; continue; };
                { gotoCase = 165; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 251; continue; };
                if (yych <= '`') { gotoCase = 165; continue; };
                if (yych <= 'f') { gotoCase = 251; continue; };
                { gotoCase = 165; continue; };
            }
case 260:
            ++cursor;
            if ((yych = this._charAt(cursor)) == '=') { gotoCase = 163; continue; };
            { gotoCase = 139; continue; };
/* *********************************** */
case this.case_REGEX:
            yych = this._charAt(cursor);
            if (yych <= '.') {
                if (yych <= '\n') {
                    if (yych <= '\t') { gotoCase = 264; continue; };
                    { gotoCase = 265; continue; };
                } else {
                    if (yych == '\r') { gotoCase = 265; continue; };
                    { gotoCase = 264; continue; };
                }
            } else {
                if (yych <= '[') {
                    if (yych <= '/') { gotoCase = 267; continue; };
                    if (yych <= 'Z') { gotoCase = 264; continue; };
                    { gotoCase = 269; continue; };
                } else {
                    if (yych <= '\\') { gotoCase = 270; continue; };
                    if (yych <= ']') { gotoCase = 265; continue; };
                    { gotoCase = 264; continue; };
                }
            }
case 263:
            { this.tokenType = "javascript-regexp"; return cursor; }
case 264:
            yyaccept = 0;
            yych = this._charAt(YYMARKER = ++cursor);
            { gotoCase = 272; continue; };
case 265:
            ++cursor;
case 266:
            { this.tokenType = null; return cursor; }
case 267:
            ++cursor;
            yych = this._charAt(cursor);
            { gotoCase = 278; continue; };
case 268:
            this.setLexCondition(this._lexConditions.NODIV);
            { this.tokenType = "javascript-regexp"; return cursor; }
case 269:
            yyaccept = 1;
            yych = this._charAt(YYMARKER = ++cursor);
            if (yych <= '\r') {
                if (yych == '\n') { gotoCase = 266; continue; };
                if (yych <= '\f') { gotoCase = 276; continue; };
                { gotoCase = 266; continue; };
            } else {
                if (yych <= '*') {
                    if (yych <= ')') { gotoCase = 276; continue; };
                    { gotoCase = 266; continue; };
                } else {
                    if (yych == '/') { gotoCase = 266; continue; };
                    { gotoCase = 276; continue; };
                }
            }
case 270:
            yych = this._charAt(++cursor);
            if (yych == '\n') { gotoCase = 266; continue; };
            if (yych == '\r') { gotoCase = 266; continue; };
case 271:
            yyaccept = 0;
            YYMARKER = ++cursor;
            yych = this._charAt(cursor);
case 272:
            if (yych <= '.') {
                if (yych <= '\n') {
                    if (yych <= '\t') { gotoCase = 271; continue; };
                    { gotoCase = 263; continue; };
                } else {
                    if (yych == '\r') { gotoCase = 263; continue; };
                    { gotoCase = 271; continue; };
                }
            } else {
                if (yych <= '[') {
                    if (yych <= '/') { gotoCase = 277; continue; };
                    if (yych <= 'Z') { gotoCase = 271; continue; };
                    { gotoCase = 275; continue; };
                } else {
                    if (yych <= '\\') { gotoCase = 273; continue; };
                    if (yych <= ']') { gotoCase = 263; continue; };
                    { gotoCase = 271; continue; };
                }
            }
case 273:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych == '\n') { gotoCase = 274; continue; };
            if (yych != '\r') { gotoCase = 271; continue; };
case 274:
            cursor = YYMARKER;
            if (yyaccept <= 0) {
                { gotoCase = 263; continue; };
            } else {
                { gotoCase = 266; continue; };
            }
case 275:
            ++cursor;
            yych = this._charAt(cursor);
case 276:
            if (yych <= '*') {
                if (yych <= '\f') {
                    if (yych == '\n') { gotoCase = 274; continue; };
                    { gotoCase = 275; continue; };
                } else {
                    if (yych <= '\r') { gotoCase = 274; continue; };
                    if (yych <= ')') { gotoCase = 275; continue; };
                    { gotoCase = 274; continue; };
                }
            } else {
                if (yych <= '[') {
                    if (yych == '/') { gotoCase = 274; continue; };
                    { gotoCase = 275; continue; };
                } else {
                    if (yych <= '\\') { gotoCase = 281; continue; };
                    if (yych <= ']') { gotoCase = 279; continue; };
                    { gotoCase = 275; continue; };
                }
            }
case 277:
            ++cursor;
            yych = this._charAt(cursor);
case 278:
            if (yych <= 'h') {
                if (yych == 'g') { gotoCase = 277; continue; };
                { gotoCase = 268; continue; };
            } else {
                if (yych <= 'i') { gotoCase = 277; continue; };
                if (yych == 'm') { gotoCase = 277; continue; };
                { gotoCase = 268; continue; };
            }
case 279:
            yyaccept = 0;
            YYMARKER = ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '*') {
                if (yych <= '\f') {
                    if (yych == '\n') { gotoCase = 263; continue; };
                    { gotoCase = 279; continue; };
                } else {
                    if (yych <= '\r') { gotoCase = 263; continue; };
                    if (yych <= ')') { gotoCase = 279; continue; };
                    { gotoCase = 271; continue; };
                }
            } else {
                if (yych <= 'Z') {
                    if (yych == '/') { gotoCase = 277; continue; };
                    { gotoCase = 279; continue; };
                } else {
                    if (yych <= '[') { gotoCase = 275; continue; };
                    if (yych <= '\\') { gotoCase = 282; continue; };
                    { gotoCase = 279; continue; };
                }
            }
case 281:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych == '\n') { gotoCase = 274; continue; };
            if (yych == '\r') { gotoCase = 274; continue; };
            { gotoCase = 275; continue; };
case 282:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych == '\n') { gotoCase = 274; continue; };
            if (yych == '\r') { gotoCase = 274; continue; };
            { gotoCase = 279; continue; };
/* *********************************** */
case this.case_SSTRING:
            yych = this._charAt(cursor);
            if (yych <= '\r') {
                if (yych == '\n') { gotoCase = 287; continue; };
                if (yych <= '\f') { gotoCase = 286; continue; };
                { gotoCase = 287; continue; };
            } else {
                if (yych <= '\'') {
                    if (yych <= '&') { gotoCase = 286; continue; };
                    { gotoCase = 289; continue; };
                } else {
                    if (yych == '\\') { gotoCase = 291; continue; };
                    { gotoCase = 286; continue; };
                }
            }
case 285:
            { this.tokenType = "javascript-string"; return cursor; }
case 286:
            yyaccept = 0;
            yych = this._charAt(YYMARKER = ++cursor);
            { gotoCase = 293; continue; };
case 287:
            ++cursor;
case 288:
            { this.tokenType = null; return cursor; }
case 289:
            ++cursor;
case 290:
            this.setLexCondition(this._lexConditions.NODIV);
            { this.tokenType = "javascript-string"; return cursor; }
case 291:
            yyaccept = 1;
            yych = this._charAt(YYMARKER = ++cursor);
            if (yych <= 'e') {
                if (yych <= '\'') {
                    if (yych == '"') { gotoCase = 292; continue; };
                    if (yych <= '&') { gotoCase = 288; continue; };
                } else {
                    if (yych <= '\\') {
                        if (yych <= '[') { gotoCase = 288; continue; };
                    } else {
                        if (yych != 'b') { gotoCase = 288; continue; };
                    }
                }
            } else {
                if (yych <= 'r') {
                    if (yych <= 'm') {
                        if (yych >= 'g') { gotoCase = 288; continue; };
                    } else {
                        if (yych <= 'n') { gotoCase = 292; continue; };
                        if (yych <= 'q') { gotoCase = 288; continue; };
                    }
                } else {
                    if (yych <= 't') {
                        if (yych <= 's') { gotoCase = 288; continue; };
                    } else {
                        if (yych <= 'u') { gotoCase = 294; continue; };
                        if (yych >= 'w') { gotoCase = 288; continue; };
                    }
                }
            }
case 292:
            yyaccept = 0;
            YYMARKER = ++cursor;
            yych = this._charAt(cursor);
case 293:
            if (yych <= '\r') {
                if (yych == '\n') { gotoCase = 285; continue; };
                if (yych <= '\f') { gotoCase = 292; continue; };
                { gotoCase = 285; continue; };
            } else {
                if (yych <= '\'') {
                    if (yych <= '&') { gotoCase = 292; continue; };
                    { gotoCase = 300; continue; };
                } else {
                    if (yych == '\\') { gotoCase = 299; continue; };
                    { gotoCase = 292; continue; };
                }
            }
case 294:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 295; continue; };
                if (yych <= '9') { gotoCase = 296; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 296; continue; };
                if (yych <= '`') { gotoCase = 295; continue; };
                if (yych <= 'f') { gotoCase = 296; continue; };
            }
case 295:
            cursor = YYMARKER;
            if (yyaccept <= 0) {
                { gotoCase = 285; continue; };
            } else {
                { gotoCase = 288; continue; };
            }
case 296:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 295; continue; };
                if (yych >= ':') { gotoCase = 295; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 297; continue; };
                if (yych <= '`') { gotoCase = 295; continue; };
                if (yych >= 'g') { gotoCase = 295; continue; };
            }
case 297:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 295; continue; };
                if (yych >= ':') { gotoCase = 295; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 298; continue; };
                if (yych <= '`') { gotoCase = 295; continue; };
                if (yych >= 'g') { gotoCase = 295; continue; };
            }
case 298:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= '@') {
                if (yych <= '/') { gotoCase = 295; continue; };
                if (yych <= '9') { gotoCase = 292; continue; };
                { gotoCase = 295; continue; };
            } else {
                if (yych <= 'F') { gotoCase = 292; continue; };
                if (yych <= '`') { gotoCase = 295; continue; };
                if (yych <= 'f') { gotoCase = 292; continue; };
                { gotoCase = 295; continue; };
            }
case 299:
            ++cursor;
            yych = this._charAt(cursor);
            if (yych <= 'e') {
                if (yych <= '\'') {
                    if (yych == '"') { gotoCase = 292; continue; };
                    if (yych <= '&') { gotoCase = 295; continue; };
                    { gotoCase = 292; continue; };
                } else {
                    if (yych <= '\\') {
                        if (yych <= '[') { gotoCase = 295; continue; };
                        { gotoCase = 292; continue; };
                    } else {
                        if (yych == 'b') { gotoCase = 292; continue; };
                        { gotoCase = 295; continue; };
                    }
                }
            } else {
                if (yych <= 'r') {
                    if (yych <= 'm') {
                        if (yych <= 'f') { gotoCase = 292; continue; };
                        { gotoCase = 295; continue; };
                    } else {
                        if (yych <= 'n') { gotoCase = 292; continue; };
                        if (yych <= 'q') { gotoCase = 295; continue; };
                        { gotoCase = 292; continue; };
                    }
                } else {
                    if (yych <= 't') {
                        if (yych <= 's') { gotoCase = 295; continue; };
                        { gotoCase = 292; continue; };
                    } else {
                        if (yych <= 'u') { gotoCase = 294; continue; };
                        if (yych <= 'v') { gotoCase = 292; continue; };
                        { gotoCase = 295; continue; };
                    }
                }
            }
case 300:
            ++cursor;
            yych = this._charAt(cursor);
            { gotoCase = 290; continue; };
        }

        }
    }
}

WebInspector.SourceJavaScriptTokenizer.prototype.__proto__ = WebInspector.SourceTokenizer.prototype;
;

HTMLScriptFormatter = function(indentString)
{
    WebInspector.SourceHTMLTokenizer.call(this);
    this._indentString = indentString;
}

HTMLScriptFormatter.prototype = {
    format: function(content)
    {
        this.line = content;
        this._content = content;
        this._formattedContent = "";
        this._mapping = { original: [0], formatted: [0] };
        this._position = 0;

        var cursor = 0;
        while (cursor < this._content.length)
            cursor = this.nextToken(cursor);

        this._formattedContent += this._content.substring(this._position);
        return { content: this._formattedContent, mapping: this._mapping };
    },

    scriptStarted: function(cursor)
    {
        this._formattedContent += this._content.substring(this._position, cursor);
        this._formattedContent += "\n";
        this._position = cursor;
    },

    scriptEnded: function(cursor)
    {
        if (cursor === this._position)
            return;

        var scriptContent = this._content.substring(this._position, cursor);
        this._mapping.original.push(this._position);
        this._mapping.formatted.push(this._formattedContent.length);
        var formattedScriptContent = formatScript(scriptContent, this._mapping, this._position, this._formattedContent.length, this._indentString);

        this._formattedContent += formattedScriptContent;
        this._position = cursor;
    },

    styleSheetStarted: function(cursor)
    {
    },

    styleSheetEnded: function(cursor)
    {
    }
}

HTMLScriptFormatter.prototype.__proto__ = WebInspector.SourceHTMLTokenizer.prototype;

function require()
{
    return parse;
}

var exports = {};
/***********************************************************************

  A JavaScript tokenizer / parser / beautifier / compressor.

  This version is suitable for Node.js.  With minimal changes (the
  exports stuff) it should work on any JS platform.

  This file contains the tokenizer/parser.  It is a port to JavaScript
  of parse-js [1], a JavaScript parser library written in Common Lisp
  by Marijn Haverbeke.  Thank you Marijn!

  [1] http://marijn.haverbeke.nl/parse-js/

  Exported functions:

    - tokenizer(code) -- returns a function.  Call the returned
      function to fetch the next token.

    - parse(code) -- returns an AST of the given JavaScript code.

  -------------------------------- (C) ---------------------------------

                           Author: Mihai Bazon
                         <mihai.bazon@gmail.com>
                       http://mihai.bazon.net/blog

  Distributed under the BSD license:

    Copyright 2010 (c) Mihai Bazon <mihai.bazon@gmail.com>
    Based on parse-js (http://marijn.haverbeke.nl/parse-js/).

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions
    are met:

        * Redistributions of source code must retain the above
          copyright notice, this list of conditions and the following
          disclaimer.

        * Redistributions in binary form must reproduce the above
          copyright notice, this list of conditions and the following
          disclaimer in the documentation and/or other materials
          provided with the distribution.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER “AS IS” AND ANY
    EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
    IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
    PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER BE
    LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
    OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
    PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
    PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
    THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
    TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
    THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
    SUCH DAMAGE.

 ***********************************************************************/

/* -----[ Tokenizer (constants) ]----- */

var KEYWORDS = array_to_hash([
        "break",
        "case",
        "catch",
        "const",
        "continue",
        "default",
        "delete",
        "do",
        "else",
        "finally",
        "for",
        "function",
        "if",
        "in",
        "instanceof",
        "new",
        "return",
        "switch",
        "throw",
        "try",
        "typeof",
        "var",
        "void",
        "while",
        "with"
]);

var RESERVED_WORDS = array_to_hash([
        "abstract",
        "boolean",
        "byte",
        "char",
        "class",
        "debugger",
        "double",
        "enum",
        "export",
        "extends",
        "final",
        "float",
        "goto",
        "implements",
        "import",
        "int",
        "interface",
        "long",
        "native",
        "package",
        "private",
        "protected",
        "public",
        "short",
        "static",
        "super",
        "synchronized",
        "throws",
        "transient",
        "volatile"
]);

var KEYWORDS_BEFORE_EXPRESSION = array_to_hash([
        "return",
        "new",
        "delete",
        "throw",
        "else",
        "case"
]);

var KEYWORDS_ATOM = array_to_hash([
        "false",
        "null",
        "true",
        "undefined"
]);

var OPERATOR_CHARS = array_to_hash(characters("+-*&%=<>!?|~^"));

var RE_HEX_NUMBER = /^0x[0-9a-f]+$/i;
var RE_OCT_NUMBER = /^0[0-7]+$/;
var RE_DEC_NUMBER = /^\d*\.?\d*(?:e[+-]?\d*(?:\d\.?|\.?\d)\d*)?$/i;

var OPERATORS = array_to_hash([
        "in",
        "instanceof",
        "typeof",
        "new",
        "void",
        "delete",
        "++",
        "--",
        "+",
        "-",
        "!",
        "~",
        "&",
        "|",
        "^",
        "*",
        "/",
        "%",
        ">>",
        "<<",
        ">>>",
        "<",
        ">",
        "<=",
        ">=",
        "==",
        "===",
        "!=",
        "!==",
        "?",
        "=",
        "+=",
        "-=",
        "/=",
        "*=",
        "%=",
        ">>=",
        "<<=",
        ">>>=",
        "%=",
        "|=",
        "^=",
        "&=",
        "&&",
        "||"
]);

var WHITESPACE_CHARS = array_to_hash(characters(" \n\r\t"));

var PUNC_BEFORE_EXPRESSION = array_to_hash(characters("[{}(,.;:"));

var PUNC_CHARS = array_to_hash(characters("[]{}(),;:"));

var REGEXP_MODIFIERS = array_to_hash(characters("gmsiy"));

/* -----[ Tokenizer ]----- */

function is_alphanumeric_char(ch) {
        ch = ch.charCodeAt(0);
        return (ch >= 48 && ch <= 57) ||
                (ch >= 65 && ch <= 90) ||
                (ch >= 97 && ch <= 122);
};

function is_identifier_char(ch) {
        return is_alphanumeric_char(ch) || ch == "$" || ch == "_";
};

function is_digit(ch) {
        ch = ch.charCodeAt(0);
        return ch >= 48 && ch <= 57;
};

function parse_js_number(num) {
        if (RE_HEX_NUMBER.test(num)) {
                return parseInt(num.substr(2), 16);
        } else if (RE_OCT_NUMBER.test(num)) {
                return parseInt(num.substr(1), 8);
        } else if (RE_DEC_NUMBER.test(num)) {
                return parseFloat(num);
        }
};

function JS_Parse_Error(message, line, col, pos) {
        this.message = message;
        this.line = line;
        this.col = col;
        this.pos = pos;
        try {
                ({})();
        } catch(ex) {
                this.stack = ex.stack;
        };
};

JS_Parse_Error.prototype.toString = function() {
        return this.message + " (line: " + this.line + ", col: " + this.col + ", pos: " + this.pos + ")" + "\n\n" + this.stack;
};

function js_error(message, line, col, pos) {
        throw new JS_Parse_Error(message, line, col, pos);
};

function is_token(token, type, val) {
        return token.type == type && (val == null || token.value == val);
};

var EX_EOF = {};

function tokenizer($TEXT) {

        var S = {
                text            : $TEXT.replace(/\r\n?|[\n\u2028\u2029]/g, "\n").replace(/^\uFEFF/, ''),
                pos             : 0,
                tokpos          : 0,
                line            : 0,
                tokline         : 0,
                col             : 0,
                tokcol          : 0,
                newline_before  : false,
                regex_allowed   : false,
                comments_before : []
        };

        function peek() { return S.text.charAt(S.pos); };

        function next(signal_eof) {
                var ch = S.text.charAt(S.pos++);
                if (signal_eof && !ch)
                        throw EX_EOF;
                if (ch == "\n") {
                        S.newline_before = true;
                        ++S.line;
                        S.col = 0;
                } else {
                        ++S.col;
                }
                return ch;
        };

        function eof() {
                return !S.peek();
        };

        function find(what, signal_eof) {
                var pos = S.text.indexOf(what, S.pos);
                if (signal_eof && pos == -1) throw EX_EOF;
                return pos;
        };

        function start_token() {
                S.tokline = S.line;
                S.tokcol = S.col;
                S.tokpos = S.pos;
        };

        function token(type, value, is_comment) {
                S.regex_allowed = ((type == "operator" && !HOP(UNARY_POSTFIX, value)) ||
                                   (type == "keyword" && HOP(KEYWORDS_BEFORE_EXPRESSION, value)) ||
                                   (type == "punc" && HOP(PUNC_BEFORE_EXPRESSION, value)));
                var ret = {
                        type  : type,
                        value : value,
                        line  : S.tokline,
                        col   : S.tokcol,
                        pos   : S.tokpos,
                        nlb   : S.newline_before
                };
                if (!is_comment) {
                        ret.comments_before = S.comments_before;
                        S.comments_before = [];
                }
                S.newline_before = false;
                return ret;
        };

        function skip_whitespace() {
                while (HOP(WHITESPACE_CHARS, peek()))
                        next();
        };

        function read_while(pred) {
                var ret = "", ch = peek(), i = 0;
                while (ch && pred(ch, i++)) {
                        ret += next();
                        ch = peek();
                }
                return ret;
        };

        function parse_error(err) {
                js_error(err, S.tokline, S.tokcol, S.tokpos);
        };

        function read_num(prefix) {
                var has_e = false, after_e = false, has_x = false, has_dot = prefix == ".";
                var num = read_while(function(ch, i){
                        if (ch == "x" || ch == "X") {
                                if (has_x) return false;
                                return has_x = true;
                        }
                        if (!has_x && (ch == "E" || ch == "e")) {
                                if (has_e) return false;
                                return has_e = after_e = true;
                        }
                        if (ch == "-") {
                                if (after_e || (i == 0 && !prefix)) return true;
                                return false;
                        }
                        if (ch == "+") return after_e;
                        after_e = false;
                        if (ch == ".") {
                                if (!has_dot)
                                        return has_dot = true;
                                return false;
                        }
                        return is_alphanumeric_char(ch);
                });
                if (prefix)
                        num = prefix + num;
                var valid = parse_js_number(num);
                if (!isNaN(valid)) {
                        return token("num", valid);
                } else {
                        parse_error("Invalid syntax: " + num);
                }
        };

        function read_escaped_char() {
                var ch = next(true);
                switch (ch) {
                    case "n" : return "\n";
                    case "r" : return "\r";
                    case "t" : return "\t";
                    case "b" : return "\b";
                    case "v" : return "\v";
                    case "f" : return "\f";
                    case "0" : return "\0";
                    case "x" : return String.fromCharCode(hex_bytes(2));
                    case "u" : return String.fromCharCode(hex_bytes(4));
                    default  : return ch;
                }
        };

        function hex_bytes(n) {
                var num = 0;
                for (; n > 0; --n) {
                        var digit = parseInt(next(true), 16);
                        if (isNaN(digit))
                                parse_error("Invalid hex-character pattern in string");
                        num = (num << 4) | digit;
                }
                return num;
        };

        function read_string() {
                return with_eof_error("Unterminated string constant", function(){
                        var quote = next(), ret = "";
                        for (;;) {
                                var ch = next(true);
                                if (ch == "\\") ch = read_escaped_char();
                                else if (ch == quote) break;
                                ret += ch;
                        }
                        return token("string", ret);
                });
        };

        function read_line_comment() {
                next();
                var i = find("\n"), ret;
                if (i == -1) {
                        ret = S.text.substr(S.pos);
                        S.pos = S.text.length;
                } else {
                        ret = S.text.substring(S.pos, i);
                        S.pos = i;
                }
                return token("comment1", ret, true);
        };

        function read_multiline_comment() {
                next();
                return with_eof_error("Unterminated multiline comment", function(){
                        var i = find("*/", true),
                            text = S.text.substring(S.pos, i),
                            tok = token("comment2", text, true);
                        S.pos = i + 2;
                        S.line += text.split("\n").length - 1;
                        S.newline_before = text.indexOf("\n") >= 0;
                        return tok;
                });
        };

        function read_regexp() {
                return with_eof_error("Unterminated regular expression", function(){
                        var prev_backslash = false, regexp = "", ch, in_class = false;
                        while ((ch = next(true))) if (prev_backslash) {
                                regexp += "\\" + ch;
                                prev_backslash = false;
                        } else if (ch == "[") {
                                in_class = true;
                                regexp += ch;
                        } else if (ch == "]" && in_class) {
                                in_class = false;
                                regexp += ch;
                        } else if (ch == "/" && !in_class) {
                                break;
                        } else if (ch == "\\") {
                                prev_backslash = true;
                        } else {
                                regexp += ch;
                        }
                        var mods = read_while(function(ch){
                                return HOP(REGEXP_MODIFIERS, ch);
                        });
                        return token("regexp", [ regexp, mods ]);
                });
        };

        function read_operator(prefix) {
                function grow(op) {
                        if (!peek()) return op;
                        var bigger = op + peek();
                        if (HOP(OPERATORS, bigger)) {
                                next();
                                return grow(bigger);
                        } else {
                                return op;
                        }
                };
                return token("operator", grow(prefix || next()));
        };

        function handle_slash() {
                next();
                var regex_allowed = S.regex_allowed;
                switch (peek()) {
                    case "/":
                        S.comments_before.push(read_line_comment());
                        S.regex_allowed = regex_allowed;
                        return next_token();
                    case "*":
                        S.comments_before.push(read_multiline_comment());
                        S.regex_allowed = regex_allowed;
                        return next_token();
                }
                return S.regex_allowed ? read_regexp() : read_operator("/");
        };

        function handle_dot() {
                next();
                return is_digit(peek())
                        ? read_num(".")
                        : token("punc", ".");
        };

        function read_word() {
                var word = read_while(is_identifier_char);
                return !HOP(KEYWORDS, word)
                        ? token("name", word)
                        : HOP(OPERATORS, word)
                        ? token("operator", word)
                        : HOP(KEYWORDS_ATOM, word)
                        ? token("atom", word)
                        : token("keyword", word);
        };

        function with_eof_error(eof_error, cont) {
                try {
                        return cont();
                } catch(ex) {
                        if (ex === EX_EOF) parse_error(eof_error);
                        else throw ex;
                }
        };

        function next_token(force_regexp) {
                if (force_regexp)
                        return read_regexp();
                skip_whitespace();
                start_token();
                var ch = peek();
                if (!ch) return token("eof");
                if (is_digit(ch)) return read_num();
                if (ch == '"' || ch == "'") return read_string();
                if (HOP(PUNC_CHARS, ch)) return token("punc", next());
                if (ch == ".") return handle_dot();
                if (ch == "/") return handle_slash();
                if (HOP(OPERATOR_CHARS, ch)) return read_operator();
                if (is_identifier_char(ch)) return read_word();
                parse_error("Unexpected character '" + ch + "'");
        };

        next_token.context = function(nc) {
                if (nc) S = nc;
                return S;
        };

        return next_token;

};

/* -----[ Parser (constants) ]----- */

var UNARY_PREFIX = array_to_hash([
        "typeof",
        "void",
        "delete",
        "--",
        "++",
        "!",
        "~",
        "-",
        "+"
]);

var UNARY_POSTFIX = array_to_hash([ "--", "++" ]);

var ASSIGNMENT = (function(a, ret, i){
        while (i < a.length) {
                ret[a[i]] = a[i].substr(0, a[i].length - 1);
                i++;
        }
        return ret;
})(
        ["+=", "-=", "/=", "*=", "%=", ">>=", "<<=", ">>>=", "|=", "^=", "&="],
        { "=": true },
        0
);

var PRECEDENCE = (function(a, ret){
        for (var i = 0, n = 1; i < a.length; ++i, ++n) {
                var b = a[i];
                for (var j = 0; j < b.length; ++j) {
                        ret[b[j]] = n;
                }
        }
        return ret;
})(
        [
                ["||"],
                ["&&"],
                ["|"],
                ["^"],
                ["&"],
                ["==", "===", "!=", "!=="],
                ["<", ">", "<=", ">=", "in", "instanceof"],
                [">>", "<<", ">>>"],
                ["+", "-"],
                ["*", "/", "%"]
        ],
        {}
);

var STATEMENTS_WITH_LABELS = array_to_hash([ "for", "do", "while", "switch" ]);

var ATOMIC_START_TOKEN = array_to_hash([ "atom", "num", "string", "regexp", "name" ]);

/* -----[ Parser ]----- */

function NodeWithToken(str, start, end) {
        this.name = str;
        this.start = start;
        this.end = end;
};

NodeWithToken.prototype.toString = function() { return this.name; };

function parse($TEXT, strict_mode, embed_tokens) {

        var S = {
                input       : typeof $TEXT == "string" ? tokenizer($TEXT, true) : $TEXT,
                token       : null,
                prev        : null,
                peeked      : null,
                in_function : 0,
                in_loop     : 0,
                labels      : []
        };

        S.token = next();

        function is(type, value) {
                return is_token(S.token, type, value);
        };

        function peek() { return S.peeked || (S.peeked = S.input()); };

        function next() {
                S.prev = S.token;
                if (S.peeked) {
                        S.token = S.peeked;
                        S.peeked = null;
                } else {
                        S.token = S.input();
                }
                return S.token;
        };

        function prev() {
                return S.prev;
        };

        function croak(msg, line, col, pos) {
                var ctx = S.input.context();
                js_error(msg,
                         line != null ? line : ctx.tokline,
                         col != null ? col : ctx.tokcol,
                         pos != null ? pos : ctx.tokpos);
        };

        function token_error(token, msg) {
                croak(msg, token.line, token.col);
        };

        function unexpected(token) {
                if (token == null)
                        token = S.token;
                token_error(token, "Unexpected token: " + token.type + " (" + token.value + ")");
        };

        function expect_token(type, val) {
                if (is(type, val)) {
                        return next();
                }
                token_error(S.token, "Unexpected token " + S.token.type + ", expected " + type);
        };

        function expect(punc) { return expect_token("punc", punc); };

        function can_insert_semicolon() {
                return !strict_mode && (
                        S.token.nlb || is("eof") || is("punc", "}")
                );
        };

        function semicolon() {
                if (is("punc", ";")) next();
                else if (!can_insert_semicolon()) unexpected();
        };

        function as() {
                return slice(arguments);
        };

        function parenthesised() {
                expect("(");
                var ex = expression();
                expect(")");
                return ex;
        };

        function add_tokens(str, start, end) {
                return new NodeWithToken(str, start, end);
        };

        var statement = embed_tokens ? function() {
                var start = S.token;
                var stmt = $statement();
                stmt[0] = add_tokens(stmt[0], start, prev());
                return stmt;
        } : $statement;

        function $statement() {
                if (is("operator", "/")) {
                        S.peeked = null;
                        S.token = S.input(true); // force regexp
                }
                switch (S.token.type) {
                    case "num":
                    case "string":
                    case "regexp":
                    case "operator":
                    case "atom":
                        return simple_statement();

                    case "name":
                        return is_token(peek(), "punc", ":")
                                ? labeled_statement(prog1(S.token.value, next, next))
                                : simple_statement();

                    case "punc":
                        switch (S.token.value) {
                            case "{":
                                return as("block", block_());
                            case "[":
                            case "(":
                                return simple_statement();
                            case ";":
                                next();
                                return as("block");
                            default:
                                unexpected();
                        }

                    case "keyword":
                        switch (prog1(S.token.value, next)) {
                            case "break":
                                return break_cont("break");

                            case "continue":
                                return break_cont("continue");

                            case "debugger":
                                semicolon();
                                return as("debugger");

                            case "do":
                                return (function(body){
                                        expect_token("keyword", "while");
                                        return as("do", prog1(parenthesised, semicolon), body);
                                })(in_loop(statement));

                            case "for":
                                return for_();

                            case "function":
                                return function_(true);

                            case "if":
                                return if_();

                            case "return":
                                if (S.in_function == 0)
                                        croak("'return' outside of function");
                                return as("return",
                                          is("punc", ";")
                                          ? (next(), null)
                                          : can_insert_semicolon()
                                          ? null
                                          : prog1(expression, semicolon));

                            case "switch":
                                return as("switch", parenthesised(), switch_block_());

                            case "throw":
                                return as("throw", prog1(expression, semicolon));

                            case "try":
                                return try_();

                            case "var":
                                return prog1(var_, semicolon);

                            case "const":
                                return prog1(const_, semicolon);

                            case "while":
                                return as("while", parenthesised(), in_loop(statement));

                            case "with":
                                return as("with", parenthesised(), statement());

                            default:
                                unexpected();
                        }
                }
        };

        function labeled_statement(label) {
                S.labels.push(label);
                var start = S.token, stat = statement();
                if (strict_mode && !HOP(STATEMENTS_WITH_LABELS, stat[0]))
                        unexpected(start);
                S.labels.pop();
                return as("label", label, stat);
        };

        function simple_statement() {
                return as("stat", prog1(expression, semicolon));
        };

        function break_cont(type) {
                var name = is("name") ? S.token.value : null;
                if (name != null) {
                        next();
                        if (!member(name, S.labels))
                                croak("Label " + name + " without matching loop or statement");
                }
                else if (S.in_loop == 0)
                        croak(type + " not inside a loop or switch");
                semicolon();
                return as(type, name);
        };

        function for_() {
                expect("(");
                var has_var = is("keyword", "var");
                if (has_var)
                        next();
                if (is("name") && is_token(peek(), "operator", "in")) {
                        // for (i in foo)
                        var name = S.token.value;
                        next(); next();
                        var obj = expression();
                        expect(")");
                        return as("for-in", has_var, name, obj, in_loop(statement));
                } else {
                        // classic for
                        var init = is("punc", ";") ? null : has_var ? var_() : expression();
                        expect(";");
                        var test = is("punc", ";") ? null : expression();
                        expect(";");
                        var step = is("punc", ")") ? null : expression();
                        expect(")");
                        return as("for", init, test, step, in_loop(statement));
                }
        };

        function function_(in_statement) {
                var name = is("name") ? prog1(S.token.value, next) : null;
                if (in_statement && !name)
                        unexpected();
                expect("(");
                return as(in_statement ? "defun" : "function",
                          name,
                          // arguments
                          (function(first, a){
                                  while (!is("punc", ")")) {
                                          if (first) first = false; else expect(",");
                                          if (!is("name")) unexpected();
                                          a.push(S.token.value);
                                          next();
                                  }
                                  next();
                                  return a;
                          })(true, []),
                          // body
                          (function(){
                                  ++S.in_function;
                                  var loop = S.in_loop;
                                  S.in_loop = 0;
                                  var a = block_();
                                  --S.in_function;
                                  S.in_loop = loop;
                                  return a;
                          })());
        };

        function if_() {
                var cond = parenthesised(), body = statement(), belse;
                if (is("keyword", "else")) {
                        next();
                        belse = statement();
                }
                return as("if", cond, body, belse);
        };

        function block_() {
                expect("{");
                var a = [];
                while (!is("punc", "}")) {
                        if (is("eof")) unexpected();
                        a.push(statement());
                }
                next();
                return a;
        };

        var switch_block_ = curry(in_loop, function(){
                expect("{");
                var a = [], cur = null;
                while (!is("punc", "}")) {
                        if (is("eof")) unexpected();
                        if (is("keyword", "case")) {
                                next();
                                cur = [];
                                a.push([ expression(), cur ]);
                                expect(":");
                        }
                        else if (is("keyword", "default")) {
                                next();
                                expect(":");
                                cur = [];
                                a.push([ null, cur ]);
                        }
                        else {
                                if (!cur) unexpected();
                                cur.push(statement());
                        }
                }
                next();
                return a;
        });

        function try_() {
                var body = block_(), bcatch, bfinally;
                if (is("keyword", "catch")) {
                        next();
                        expect("(");
                        if (!is("name"))
                                croak("Name expected");
                        var name = S.token.value;
                        next();
                        expect(")");
                        bcatch = [ name, block_() ];
                }
                if (is("keyword", "finally")) {
                        next();
                        bfinally = block_();
                }
                if (!bcatch && !bfinally)
                        croak("Missing catch/finally blocks");
                return as("try", body, bcatch, bfinally);
        };

        function vardefs() {
                var a = [];
                for (;;) {
                        if (!is("name"))
                                unexpected();
                        var name = S.token.value;
                        next();
                        if (is("operator", "=")) {
                                next();
                                a.push([ name, expression(false) ]);
                        } else {
                                a.push([ name ]);
                        }
                        if (!is("punc", ","))
                                break;
                        next();
                }
                return a;
        };

        function var_() {
                return as("var", vardefs());
        };

        function const_() {
                return as("const", vardefs());
        };

        function new_() {
                var newexp = expr_atom(false), args;
                if (is("punc", "(")) {
                        next();
                        args = expr_list(")");
                } else {
                        args = [];
                }
                return subscripts(as("new", newexp, args), true);
        };

        function expr_atom(allow_calls) {
                if (is("operator", "new")) {
                        next();
                        return new_();
                }
                if (is("operator") && HOP(UNARY_PREFIX, S.token.value)) {
                        return make_unary("unary-prefix",
                                          prog1(S.token.value, next),
                                          expr_atom(allow_calls));
                }
                if (is("punc")) {
                        switch (S.token.value) {
                            case "(":
                                next();
                                return subscripts(prog1(expression, curry(expect, ")")), allow_calls);
                            case "[":
                                next();
                                return subscripts(array_(), allow_calls);
                            case "{":
                                next();
                                return subscripts(object_(), allow_calls);
                        }
                        unexpected();
                }
                if (is("keyword", "function")) {
                        next();
                        return subscripts(function_(false), allow_calls);
                }
                if (HOP(ATOMIC_START_TOKEN, S.token.type)) {
                        var atom = S.token.type == "regexp"
                                ? as("regexp", S.token.value[0], S.token.value[1])
                                : as(S.token.type, S.token.value);
                        return subscripts(prog1(atom, next), allow_calls);
                }
                unexpected();
        };

        function expr_list(closing, allow_trailing_comma, allow_empty) {
                var first = true, a = [];
                while (!is("punc", closing)) {
                        if (first) first = false; else expect(",");
                        if (allow_trailing_comma && is("punc", closing)) break;
                        if (is("punc", ",") && allow_empty) {
                                a.push([ "atom", "undefined" ]);
                        } else {
                                a.push(expression(false));
                        }
                }
                next();
                return a;
        };

        function array_() {
                return as("array", expr_list("]", !strict_mode, true));
        };

        function object_() {
                var first = true, a = [];
                while (!is("punc", "}")) {
                        if (first) first = false; else expect(",");
                        if (!strict_mode && is("punc", "}"))
                                // allow trailing comma
                                break;
                        var type = S.token.type;
                        var name = as_property_name();
                        if (type == "name" && (name == "get" || name == "set") && !is("punc", ":")) {
                                a.push([ as_name(), function_(false), name ]);
                        } else {
                                expect(":");
                                a.push([ name, expression(false) ]);
                        }
                }
                next();
                return as("object", a);
        };

        function as_property_name() {
                switch (S.token.type) {
                    case "num":
                    case "string":
                        return prog1(S.token.value, next);
                }
                return as_name();
        };

        function as_name() {
                switch (S.token.type) {
                    case "name":
                    case "operator":
                    case "keyword":
                    case "atom":
                        return prog1(S.token.value, next);
                    default:
                        unexpected();
                }
        };

        function subscripts(expr, allow_calls) {
                if (is("punc", ".")) {
                        next();
                        return subscripts(as("dot", expr, as_name()), allow_calls);
                }
                if (is("punc", "[")) {
                        next();
                        return subscripts(as("sub", expr, prog1(expression, curry(expect, "]"))), allow_calls);
                }
                if (allow_calls && is("punc", "(")) {
                        next();
                        return subscripts(as("call", expr, expr_list(")")), true);
                }
                if (allow_calls && is("operator") && HOP(UNARY_POSTFIX, S.token.value)) {
                        return prog1(curry(make_unary, "unary-postfix", S.token.value, expr),
                                     next);
                }
                return expr;
        };

        function make_unary(tag, op, expr) {
                if ((op == "++" || op == "--") && !is_assignable(expr))
                        croak("Invalid use of " + op + " operator");
                return as(tag, op, expr);
        };

        function expr_op(left, min_prec) {
                var op = is("operator") ? S.token.value : null;
                var prec = op != null ? PRECEDENCE[op] : null;
                if (prec != null && prec > min_prec) {
                        next();
                        var right = expr_op(expr_atom(true), prec);
                        return expr_op(as("binary", op, left, right), min_prec);
                }
                return left;
        };

        function expr_ops() {
                return expr_op(expr_atom(true), 0);
        };

        function maybe_conditional() {
                var expr = expr_ops();
                if (is("operator", "?")) {
                        next();
                        var yes = expression(false);
                        expect(":");
                        return as("conditional", expr, yes, expression(false));
                }
                return expr;
        };

        function is_assignable(expr) {
                switch (expr[0]) {
                    case "dot":
                    case "sub":
                        return true;
                    case "name":
                        return expr[1] != "this";
                }
        };

        function maybe_assign() {
                var left = maybe_conditional(), val = S.token.value;
                if (is("operator") && HOP(ASSIGNMENT, val)) {
                        if (is_assignable(left)) {
                                next();
                                return as("assign", ASSIGNMENT[val], left, maybe_assign());
                        }
                        croak("Invalid assignment");
                }
                return left;
        };

        function expression(commas) {
                if (arguments.length == 0)
                        commas = true;
                var expr = maybe_assign();
                if (commas && is("punc", ",")) {
                        next();
                        return as("seq", expr, expression());
                }
                return expr;
        };

        function in_loop(cont) {
                try {
                        ++S.in_loop;
                        return cont();
                } finally {
                        --S.in_loop;
                }
        };

        return as("toplevel", (function(a){
                while (!is("eof"))
                        a.push(statement());
                return a;
        })([]));

};

/* -----[ Utilities ]----- */

function curry(f) {
        var args = slice(arguments, 1);
        return function() { return f.apply(this, args.concat(slice(arguments))); };
};

function prog1(ret) {
        if (ret instanceof Function)
                ret = ret();
        for (var i = 1, n = arguments.length; --n > 0; ++i)
                arguments[i]();
        return ret;
};

function array_to_hash(a) {
        var ret = {};
        for (var i = 0; i < a.length; ++i)
                ret[a[i]] = true;
        return ret;
};

function slice(a, start) {
        return Array.prototype.slice.call(a, start == null ? 0 : start);
};

function characters(str) {
        return str.split("");
};

function member(name, array) {
        for (var i = array.length; --i >= 0;)
                if (array[i] === name)
                        return true;
        return false;
};

function HOP(obj, prop) {
        return Object.prototype.hasOwnProperty.call(obj, prop);
};

/* -----[ Exports ]----- */

exports.tokenizer = tokenizer;
exports.parse = parse;
exports.slice = slice;
exports.curry = curry;
exports.member = member;
exports.array_to_hash = array_to_hash;
exports.PRECEDENCE = PRECEDENCE;
exports.KEYWORDS_ATOM = KEYWORDS_ATOM;
exports.RESERVED_WORDS = RESERVED_WORDS;
exports.KEYWORDS = KEYWORDS;
exports.ATOMIC_START_TOKEN = ATOMIC_START_TOKEN;
exports.OPERATORS = OPERATORS;
exports.is_alphanumeric_char = is_alphanumeric_char;
exports.is_identifier_char = is_identifier_char;
;
var parse = exports;

/*
 * Copyright (C) 2011 Google Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 *     * Redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above
 * copyright notice, this list of conditions and the following disclaimer
 * in the documentation and/or other materials provided with the
 * distribution.
 *     * Neither the name of Google Inc. nor the names of its
 * contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
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

function FormattedContentBuilder(content, mapping, originalOffset, formattedOffset, indentString)
{
    this._originalContent = content;
    this._originalOffset = originalOffset;
    this._lastOriginalPosition = 0;

    this._formattedContent = [];
    this._formattedContentLength = 0;
    this._formattedOffset = formattedOffset;
    this._lastFormattedPosition = 0;

    this._mapping = mapping;

    this._lineNumber = 0;
    this._nestingLevel = 0;
    this._indentString = indentString;
    this._cachedIndents = {};
}

FormattedContentBuilder.prototype = {
    addToken: function(token)
    {
        for (var i = 0; i < token.comments_before.length; ++i)
            this._addComment(token.comments_before[i]);

        while (this._lineNumber < token.line) {
            this._addText("\n");
            this._addIndent();
            this._needNewLine = false;
            this._lineNumber += 1;
        }

        if (this._needNewLine) {
            this._addText("\n");
            this._addIndent();
            this._needNewLine = false;
        }

        this._addMappingIfNeeded(token.pos);
        this._addText(this._originalContent.substring(token.pos, token.endPos));
        this._lineNumber = token.endLine;
    },

    addSpace: function()
    {
        this._addText(" ");
    },

    addNewLine: function()
    {
        this._needNewLine = true;
    },

    increaseNestingLevel: function()
    {
        this._nestingLevel += 1;
    },

    decreaseNestingLevel: function()
    {
        this._nestingLevel -= 1;
    },

    content: function()
    {
        return this._formattedContent.join("");
    },

    mapping: function()
    {
        return { original: this._originalPositions, formatted: this._formattedPositions };
    },

    _addIndent: function()
    {
        if (this._cachedIndents[this._nestingLevel]) {
            this._addText(this._cachedIndents[this._nestingLevel]);
            return;
        }

        var fullIndent = "";
        for (var i = 0; i < this._nestingLevel; ++i)
            fullIndent += this._indentString;
        this._addText(fullIndent);

        // Cache a maximum of 20 nesting level indents.
        if (this._nestingLevel <= 20)
            this._cachedIndents[this._nestingLevel] = fullIndent;
    },

    _addComment: function(comment)
    {
        if (this._lineNumber < comment.line) {
            for (var j = this._lineNumber; j < comment.line; ++j)
                this._addText("\n");
            this._lineNumber = comment.line;
            this._needNewLine = false;
            this._addIndent();
        } else
            this.addSpace();

        this._addMappingIfNeeded(comment.pos);
        if (comment.type === "comment1")
            this._addText("//");
        else
            this._addText("/*");

        this._addText(comment.value);

        if (comment.type !== "comment1") {
            this._addText("*/");
            var position;
            while ((position = comment.value.indexOf("\n", position + 1)) !== -1)
                this._lineNumber += 1;
        }
    },

    _addText: function(text)
    {
        this._formattedContent.push(text);
        this._formattedContentLength += text.length;
    },

    _addMappingIfNeeded: function(originalPosition)
    {
        if (originalPosition - this._lastOriginalPosition === this._formattedContentLength - this._lastFormattedPosition)
            return;
        this._mapping.original.push(this._originalOffset + originalPosition);
        this._lastOriginalPosition = originalPosition;
        this._mapping.formatted.push(this._formattedOffset + this._formattedContentLength);
        this._lastFormattedPosition = this._formattedContentLength;
    }
}

var tokens = [
    ["EOS"],
    ["LPAREN", "("], ["RPAREN", ")"], ["LBRACK", "["], ["RBRACK", "]"], ["LBRACE", "{"], ["RBRACE", "}"], ["COLON", ":"], ["SEMICOLON", ";"], ["PERIOD", "."], ["CONDITIONAL", "?"],
    ["INC", "++"], ["DEC", "--"],
    ["ASSIGN", "="], ["ASSIGN_BIT_OR", "|="], ["ASSIGN_BIT_XOR", "^="], ["ASSIGN_BIT_AND", "&="], ["ASSIGN_SHL", "<<="], ["ASSIGN_SAR", ">>="], ["ASSIGN_SHR", ">>>="],
    ["ASSIGN_ADD", "+="], ["ASSIGN_SUB", "-="], ["ASSIGN_MUL", "*="], ["ASSIGN_DIV", "/="], ["ASSIGN_MOD", "%="],
    ["COMMA", ","], ["OR", "||"], ["AND", "&&"], ["BIT_OR", "|"], ["BIT_XOR", "^"], ["BIT_AND", "&"], ["SHL", "<<"], ["SAR", ">>"], ["SHR", ">>>"],
    ["ADD", "+"], ["SUB", "-"], ["MUL", "*"], ["DIV", "/"], ["MOD", "%"],
    ["EQ", "=="], ["NE", "!="], ["EQ_STRICT", "==="], ["NE_STRICT", "!=="], ["LT", "<"], ["GT", ">"], ["LTE", "<="], ["GTE", ">="],
    ["INSTANCEOF", "instanceof"], ["IN", "in"], ["NOT", "!"], ["BIT_NOT", "~"], ["DELETE", "delete"], ["TYPEOF", "typeof"], ["VOID", "void"],
    ["BREAK", "break"], ["CASE", "case"], ["CATCH", "catch"], ["CONTINUE", "continue"], ["DEBUGGER", "debugger"], ["DEFAULT", "default"], ["DO", "do"], ["ELSE", "else"], ["FINALLY", "finally"],
    ["FOR", "for"], ["FUNCTION", "function"], ["IF", "if"], ["NEW", "new"], ["RETURN", "return"], ["SWITCH", "switch"], ["THIS", "this"], ["THROW", "throw"], ["TRY", "try"], ["VAR", "var"],
    ["WHILE", "while"], ["WITH", "with"], ["NULL_LITERAL", "null"], ["TRUE_LITERAL", "true"], ["FALSE_LITERAL", "false"], ["NUMBER"], ["STRING"], ["IDENTIFIER"], ["CONST", "const"]
];

var Tokens = {};
for (var i = 0; i < tokens.length; ++i)
    Tokens[tokens[i][0]] = i;

var TokensByValue = {};
for (var i = 0; i < tokens.length; ++i) {
    if (tokens[i][1])
        TokensByValue[tokens[i][1]] = i;
}

var TokensByType = {
    "eof": Tokens.EOS,
    "name": Tokens.IDENTIFIER,
    "num": Tokens.NUMBER,
    "regexp": Tokens.DIV,
    "string": Tokens.STRING
};

function Tokenizer(content)
{
    this._readNextToken = parse.tokenizer(content);
    this._state = this._readNextToken.context();
}

Tokenizer.prototype = {
    content: function()
    {
        return this._state.text;
    },

    next: function(forceRegexp)
    {
        var uglifyToken = this._readNextToken(forceRegexp);
        uglifyToken.endPos = this._state.pos;
        uglifyToken.endLine = this._state.line;
        uglifyToken.token = this._convertUglifyToken(uglifyToken);
        return uglifyToken;
    },

    _convertUglifyToken: function(uglifyToken)
    {
        var token = TokensByType[uglifyToken.type];
        if (typeof token === "number")
            return token;
        token = TokensByValue[uglifyToken.value];
        if (typeof token === "number")
            return token;
        throw "Unknown token type " + uglifyToken.type;
    }
}

function JavaScriptFormatter(tokenizer, builder)
{
    this._tokenizer = tokenizer;
    this._builder = builder;
    this._token = null;
    this._nextToken = this._tokenizer.next();
}

JavaScriptFormatter.prototype = {
    format: function()
    {
        this._parseSourceElements(Tokens.EOS);
        this._consume(Tokens.EOS);
    },

    _peek: function()
    {
        return this._nextToken.token;
    },

    _next: function()
    {
        if (this._token && this._token.token === Tokens.EOS)
            throw "Unexpected EOS token";

        this._builder.addToken(this._nextToken);
        this._token = this._nextToken;
        this._nextToken = this._tokenizer.next(this._forceRegexp);
        this._forceRegexp = false;
        return this._token.token;
    },

    _consume: function(token)
    {
        var next = this._next();
        if (next !== token)
            throw "Unexpected token in consume: expected " + token + ", actual " + next;
    },

    _expect: function(token)
    {
        var next = this._next();
        if (next !== token)
            throw "Unexpected token: expected " + token + ", actual " + next;
    },

    _expectSemicolon: function()
    {
        if (this._peek() === Tokens.SEMICOLON)
            this._consume(Tokens.SEMICOLON);
    },

    _hasLineTerminatorBeforeNext: function()
    {
        return this._nextToken.nlb;
    },

    _parseSourceElements: function(endToken)
    {
        while (this._peek() !== endToken) {
            this._parseStatement();
            this._builder.addNewLine();
        }
    },

    _parseStatementOrBlock: function()
    {
        if (this._peek() === Tokens.LBRACE) {
            this._builder.addSpace();
            this._parseBlock();
            return true;
        }

        this._builder.addNewLine();
        this._builder.increaseNestingLevel();
        this._parseStatement();
        this._builder.decreaseNestingLevel();
    },

    _parseStatement: function()
    {
        switch (this._peek()) {
        case Tokens.LBRACE:
            return this._parseBlock();
        case Tokens.CONST:
        case Tokens.VAR:
            return this._parseVariableStatement();
        case Tokens.SEMICOLON:
            return this._next();
        case Tokens.IF:
            return this._parseIfStatement();
        case Tokens.DO:
            return this._parseDoWhileStatement();
        case Tokens.WHILE:
            return this._parseWhileStatement();
        case Tokens.FOR:
            return this._parseForStatement();
        case Tokens.CONTINUE:
            return this._parseContinueStatement();
        case Tokens.BREAK:
            return this._parseBreakStatement();
        case Tokens.RETURN:
            return this._parseReturnStatement();
        case Tokens.WITH:
            return this._parseWithStatement();
        case Tokens.SWITCH:
            return this._parseSwitchStatement();
        case Tokens.THROW:
            return this._parseThrowStatement();
        case Tokens.TRY:
            return this._parseTryStatement();
        case Tokens.FUNCTION:
            return this._parseFunctionDeclaration();
        case Tokens.DEBUGGER:
            return this._parseDebuggerStatement();
        default:
            return this._parseExpressionOrLabelledStatement();
        }
    },

    _parseFunctionDeclaration: function()
    {
        this._expect(Tokens.FUNCTION);
        this._builder.addSpace();
        this._expect(Tokens.IDENTIFIER);
        this._parseFunctionLiteral()
    },

    _parseBlock: function()
    {
        this._expect(Tokens.LBRACE);
        this._builder.addNewLine();
        this._builder.increaseNestingLevel();
        while (this._peek() !== Tokens.RBRACE) {
            this._parseStatement();
            this._builder.addNewLine();
        }
        this._builder.decreaseNestingLevel();
        this._expect(Tokens.RBRACE);
    },

    _parseVariableStatement: function()
    {
        this._parseVariableDeclarations();
        this._expectSemicolon();
    },

    _parseVariableDeclarations: function()
    {
        if (this._peek() === Tokens.VAR)
            this._consume(Tokens.VAR);
        else
            this._consume(Tokens.CONST)
        this._builder.addSpace();

        var isFirstVariable = true;
        do {
            if (!isFirstVariable) {
                this._consume(Tokens.COMMA);
                this._builder.addSpace();
            }
            isFirstVariable = false;
            this._expect(Tokens.IDENTIFIER);
            if (this._peek() === Tokens.ASSIGN) {
                this._builder.addSpace();
                this._consume(Tokens.ASSIGN);
                this._builder.addSpace();
                this._parseAssignmentExpression();
            }
        } while (this._peek() === Tokens.COMMA);
    },

    _parseExpressionOrLabelledStatement: function()
    {
        this._parseExpression();
        if (this._peek() === Tokens.COLON) {
            this._expect(Tokens.COLON);
            this._builder.addSpace();
            this._parseStatement();
        }
        this._expectSemicolon();
    },

    _parseIfStatement: function()
    {
        this._expect(Tokens.IF);
        this._builder.addSpace();
        this._expect(Tokens.LPAREN);
        this._parseExpression();
        this._expect(Tokens.RPAREN);

        var isBlock = this._parseStatementOrBlock();
        if (this._peek() === Tokens.ELSE) {
            if (isBlock)
                this._builder.addSpace();
            else
                this._builder.addNewLine();
            this._next();

            if (this._peek() === Tokens.IF) {
                this._builder.addSpace();
                this._parseStatement();
            } else
                this._parseStatementOrBlock();
        }
    },

    _parseContinueStatement: function()
    {
        this._expect(Tokens.CONTINUE);
        var token = this._peek();
        if (!this._hasLineTerminatorBeforeNext() && token !== Tokens.SEMICOLON && token !== Tokens.RBRACE && token !== Tokens.EOS) {
            this._builder.addSpace();
            this._expect(Tokens.IDENTIFIER);
        }
        this._expectSemicolon();
    },

    _parseBreakStatement: function()
    {
        this._expect(Tokens.BREAK);
        var token = this._peek();
        if (!this._hasLineTerminatorBeforeNext() && token !== Tokens.SEMICOLON && token !== Tokens.RBRACE && token !== Tokens.EOS) {
            this._builder.addSpace();
            this._expect(Tokens.IDENTIFIER);
        }
        this._expectSemicolon();
    },

    _parseReturnStatement: function()
    {
        this._expect(Tokens.RETURN);
        var token = this._peek();
        if (!this._hasLineTerminatorBeforeNext() && token !== Tokens.SEMICOLON && token !== Tokens.RBRACE && token !== Tokens.EOS) {
            this._builder.addSpace();
            this._parseExpression();
        }
        this._expectSemicolon();
    },

    _parseWithStatement: function()
    {
        this._expect(Tokens.WITH);
        this._builder.addSpace();
        this._expect(Tokens.LPAREN);
        this._parseExpression();
        this._expect(Tokens.RPAREN);
        this._parseStatementOrBlock();
    },

    _parseCaseClause: function()
    {
        if (this._peek() === Tokens.CASE) {
            this._expect(Tokens.CASE);
            this._builder.addSpace();
            this._parseExpression();
        } else
            this._expect(Tokens.DEFAULT);
        this._expect(Tokens.COLON);
        this._builder.addNewLine();

        this._builder.increaseNestingLevel();
        while (this._peek() !== Tokens.CASE && this._peek() !== Tokens.DEFAULT && this._peek() !== Tokens.RBRACE) {
            this._parseStatement();
            this._builder.addNewLine();
        }
        this._builder.decreaseNestingLevel();
    },

    _parseSwitchStatement: function()
    {
        this._expect(Tokens.SWITCH);
        this._builder.addSpace();
        this._expect(Tokens.LPAREN);
        this._parseExpression();
        this._expect(Tokens.RPAREN);
        this._builder.addSpace();

        this._expect(Tokens.LBRACE);
        this._builder.addNewLine();
        this._builder.increaseNestingLevel();
        while (this._peek() !== Tokens.RBRACE)
            this._parseCaseClause();
        this._builder.decreaseNestingLevel();
        this._expect(Tokens.RBRACE);
    },

    _parseThrowStatement: function()
    {
        this._expect(Tokens.THROW);
        this._builder.addSpace();
        this._parseExpression();
        this._expectSemicolon();
    },

    _parseTryStatement: function()
    {
        this._expect(Tokens.TRY);
        this._builder.addSpace();
        this._parseBlock();

        var token = this._peek();
        if (token === Tokens.CATCH) {
            this._builder.addSpace();
            this._consume(Tokens.CATCH);
            this._builder.addSpace();
            this._expect(Tokens.LPAREN);
            this._expect(Tokens.IDENTIFIER);
            this._expect(Tokens.RPAREN);
            this._builder.addSpace();
            this._parseBlock();
            token = this._peek();
        }

        if (token === Tokens.FINALLY) {
            this._consume(Tokens.FINALLY);
            this._builder.addSpace();
            this._parseBlock();
        }
    },

    _parseDoWhileStatement: function()
    {
        this._expect(Tokens.DO);
        var isBlock = this._parseStatementOrBlock();
        if (isBlock)
            this._builder.addSpace();
        else
            this._builder.addNewLine();
        this._expect(Tokens.WHILE);
        this._builder.addSpace();
        this._expect(Tokens.LPAREN);
        this._parseExpression();
        this._expect(Tokens.RPAREN);
        this._expectSemicolon();
    },

    _parseWhileStatement: function()
    {
        this._expect(Tokens.WHILE);
        this._builder.addSpace();
        this._expect(Tokens.LPAREN);
        this._parseExpression();
        this._expect(Tokens.RPAREN);
        this._parseStatementOrBlock();
    },

    _parseForStatement: function()
    {
        this._expect(Tokens.FOR);
        this._builder.addSpace();
        this._expect(Tokens.LPAREN);
        if (this._peek() !== Tokens.SEMICOLON) {
            if (this._peek() === Tokens.VAR || this._peek() === Tokens.CONST) {
                this._parseVariableDeclarations();
                if (this._peek() === Tokens.IN) {
                    this._builder.addSpace();
                    this._consume(Tokens.IN);
                    this._builder.addSpace();
                    this._parseExpression();
                }
            } else
                this._parseExpression();
        }

        if (this._peek() !== Tokens.RPAREN) {
            this._expect(Tokens.SEMICOLON);
            this._builder.addSpace();
            if (this._peek() !== Tokens.SEMICOLON)
                this._parseExpression();
            this._expect(Tokens.SEMICOLON);
            this._builder.addSpace();
            if (this._peek() !== Tokens.RPAREN)
                this._parseExpression();
        }
        this._expect(Tokens.RPAREN);

        this._parseStatementOrBlock();
    },

    _parseExpression: function()
    {
        this._parseAssignmentExpression();
        while (this._peek() === Tokens.COMMA) {
            this._expect(Tokens.COMMA);
            this._builder.addSpace();
            this._parseAssignmentExpression();
        }
    },

    _parseAssignmentExpression: function()
    {
        this._parseConditionalExpression();
        var token = this._peek();
        if (Tokens.ASSIGN <= token && token <= Tokens.ASSIGN_MOD) {
            this._builder.addSpace();
            this._next();
            this._builder.addSpace();
            this._parseAssignmentExpression();
        }
    },

    _parseConditionalExpression: function()
    {
        this._parseBinaryExpression();
        if (this._peek() === Tokens.CONDITIONAL) {
            this._builder.addSpace();
            this._consume(Tokens.CONDITIONAL);
            this._builder.addSpace();
            this._parseAssignmentExpression();
            this._builder.addSpace();
            this._expect(Tokens.COLON);
            this._builder.addSpace();
            this._parseAssignmentExpression();
        }
    },

    _parseBinaryExpression: function()
    {
        this._parseUnaryExpression();
        var token = this._peek();
        while (Tokens.OR <= token && token <= Tokens.IN) {
            this._builder.addSpace();
            this._next();
            this._builder.addSpace();
            this._parseBinaryExpression();
            token = this._peek();
        }
    },

    _parseUnaryExpression: function()
    {
        var token = this._peek();
        if ((Tokens.NOT <= token && token <= Tokens.VOID) || token === Tokens.ADD || token === Tokens.SUB || token ===  Tokens.INC || token === Tokens.DEC) {
            this._next();
            if (token === Tokens.DELETE || token === Tokens.TYPEOF || token === Tokens.VOID)
                this._builder.addSpace();
            this._parseUnaryExpression();
        } else
            return this._parsePostfixExpression();
    },

    _parsePostfixExpression: function()
    {
        this._parseLeftHandSideExpression();
        var token = this._peek();
        if (!this._hasLineTerminatorBeforeNext() && (token === Tokens.INC || token === Tokens.DEC))
            this._next();
    },

    _parseLeftHandSideExpression: function()
    {
        if (this._peek() === Tokens.NEW)
            this._parseNewExpression();
        else
            this._parseMemberExpression();

        while (true) {
            switch (this._peek()) {
            case Tokens.LBRACK:
                this._consume(Tokens.LBRACK);
                this._parseExpression();
                this._expect(Tokens.RBRACK);
                break;

            case Tokens.LPAREN:
                this._parseArguments();
                break;

            case Tokens.PERIOD:
                this._consume(Tokens.PERIOD);
                this._expect(Tokens.IDENTIFIER);
                break;

            default:
                return;
            }
        }
    },

    _parseNewExpression: function()
    {
        this._expect(Tokens.NEW);
        this._builder.addSpace();
        if (this._peek() === Tokens.NEW)
            this._parseNewExpression();
        else
            this._parseMemberExpression();
    },

    _parseMemberExpression: function()
    {
        if (this._peek() === Tokens.FUNCTION) {
            this._expect(Tokens.FUNCTION);
            if (this._peek() === Tokens.IDENTIFIER) {
                this._builder.addSpace();
                this._expect(Tokens.IDENTIFIER);
            }
            this._parseFunctionLiteral();
        } else
            this._parsePrimaryExpression();

        while (true) {
            switch (this._peek()) {
            case Tokens.LBRACK:
                this._consume(Tokens.LBRACK);
                this._parseExpression();
                this._expect(Tokens.RBRACK);
                break;

            case Tokens.PERIOD:
                this._consume(Tokens.PERIOD);
                this._expect(Tokens.IDENTIFIER);
                break;

            case Tokens.LPAREN:
                this._parseArguments();
                break;

            default:
                return;
            }
        }
    },

    _parseDebuggerStatement: function()
    {
        this._expect(Tokens.DEBUGGER);
        this._expectSemicolon();
    },

    _parsePrimaryExpression: function()
    {
        switch (this._peek()) {
        case Tokens.THIS:
            return this._consume(Tokens.THIS);
        case Tokens.NULL_LITERAL:
            return this._consume(Tokens.NULL_LITERAL);
        case Tokens.TRUE_LITERAL:
            return this._consume(Tokens.TRUE_LITERAL);
        case Tokens.FALSE_LITERAL:
            return this._consume(Tokens.FALSE_LITERAL);
        case Tokens.IDENTIFIER:
            return this._consume(Tokens.IDENTIFIER);
        case Tokens.NUMBER:
            return this._consume(Tokens.NUMBER);
        case Tokens.STRING:
            return this._consume(Tokens.STRING);
        case Tokens.ASSIGN_DIV:
            return this._parseRegExpLiteral();
        case Tokens.DIV:
            return this._parseRegExpLiteral();
        case Tokens.LBRACK:
            return this._parseArrayLiteral();
        case Tokens.LBRACE:
            return this._parseObjectLiteral();
        case Tokens.LPAREN:
            this._consume(Tokens.LPAREN);
            this._parseExpression();
            this._expect(Tokens.RPAREN);
            return;
        default:
            return this._next();
        }
    },

    _parseArrayLiteral: function()
    {
        this._expect(Tokens.LBRACK);
        this._builder.increaseNestingLevel();
        while (this._peek() !== Tokens.RBRACK) {
            if (this._peek() !== Tokens.COMMA)
                this._parseAssignmentExpression();
            if (this._peek() !== Tokens.RBRACK) {
                this._expect(Tokens.COMMA);
                this._builder.addSpace();
            }
        }
        this._builder.decreaseNestingLevel();
        this._expect(Tokens.RBRACK);
    },

    _parseObjectLiteralGetSet: function()
    {
        var token = this._peek();
        if (token === Tokens.IDENTIFIER || token === Tokens.NUMBER || token === Tokens.STRING ||
            Tokens.DELETE <= token && token <= Tokens.FALSE_LITERAL ||
            token === Tokens.INSTANCEOF || token === Tokens.IN || token === Tokens.CONST) {
            this._next();
            this._parseFunctionLiteral();
        }
    },

    _parseObjectLiteral: function()
    {
        this._expect(Tokens.LBRACE);
        this._builder.increaseNestingLevel();
        while (this._peek() !== Tokens.RBRACE) {
            var token = this._peek();
            switch (token) {
            case Tokens.IDENTIFIER:
                this._consume(Tokens.IDENTIFIER);
                var name = this._token.value;
                if ((name === "get" || name === "set") && this._peek() !== Tokens.COLON) {
                    this._builder.addSpace();
                    this._parseObjectLiteralGetSet();
                    if (this._peek() !== Tokens.RBRACE) {
                        this._expect(Tokens.COMMA);
                    }
                    continue;
                }
                break;

            case Tokens.STRING:
                this._consume(Tokens.STRING);
                break;

            case Tokens.NUMBER:
                this._consume(Tokens.NUMBER);
                break;

            default:
                this._next();
            }

            this._expect(Tokens.COLON);
            this._builder.addSpace();
            this._parseAssignmentExpression();
            if (this._peek() !== Tokens.RBRACE) {
                this._expect(Tokens.COMMA);
            }
        }
        this._builder.decreaseNestingLevel();

        this._expect(Tokens.RBRACE);
    },

    _parseRegExpLiteral: function()
    {
        if (this._nextToken.type === "regexp")
            this._next();
        else {
            this._forceRegexp = true;
            this._next();
        }
    },

    _parseArguments: function()
    {
        this._expect(Tokens.LPAREN);
        var done = (this._peek() === Tokens.RPAREN);
        while (!done) {
            this._parseAssignmentExpression();
            done = (this._peek() === Tokens.RPAREN);
            if (!done) {
                this._expect(Tokens.COMMA);
                this._builder.addSpace();
            }
        }
        this._expect(Tokens.RPAREN);
    },

    _parseFunctionLiteral: function()
    {
        this._expect(Tokens.LPAREN);
        var done = (this._peek() === Tokens.RPAREN);
        while (!done) {
            this._expect(Tokens.IDENTIFIER);
            done = (this._peek() === Tokens.RPAREN);
            if (!done) {
                this._expect(Tokens.COMMA);
                this._builder.addSpace();
            }
        }
        this._expect(Tokens.RPAREN);
        this._builder.addSpace();

        this._expect(Tokens.LBRACE);
        this._builder.addNewLine();
        this._builder.increaseNestingLevel();
        this._parseSourceElements(Tokens.RBRACE);
        this._builder.decreaseNestingLevel();
        this._expect(Tokens.RBRACE);
    }
}
;
