// Modified
//
// Added
//     module.exports.less = window.less = less = {}
//     less.tree = tree = {}
//     less.mode = 'browser'
//
// LESS - Leaner CSS v1.4.0
// http://lesscss.org
//
// Copyright (c) 2009-2013, Alexis Sellier
// Licensed under the Apache 2.0 License.
//
(function (window, undefined) {
//
// Stub out `require` in the browser
//
function require(arg) {
    return window.less[arg.split('/')[1]];
};

// ecma-5.js
//
// -- kriskowal Kris Kowal Copyright (C) 2009-2010 MIT License
// -- tlrobinson Tom Robinson
// dantman Daniel Friesen

//
// Array
//
if (!Array.isArray) {
    Array.isArray = function(obj) {
        return Object.prototype.toString.call(obj) === "[object Array]" ||
               (obj instanceof Array);
    };
}
if (!Array.prototype.forEach) {
    Array.prototype.forEach =  function(block, thisObject) {
        var len = this.length >>> 0;
        for (var i = 0; i < len; i++) {
            if (i in this) {
                block.call(thisObject, this[i], i, this);
            }
        }
    };
}
if (!Array.prototype.map) {
    Array.prototype.map = function(fun /*, thisp*/) {
        var len = this.length >>> 0;
        var res = new Array(len);
        var thisp = arguments[1];

        for (var i = 0; i < len; i++) {
            if (i in this) {
                res[i] = fun.call(thisp, this[i], i, this);
            }
        }
        return res;
    };
}
if (!Array.prototype.filter) {
    Array.prototype.filter = function (block /*, thisp */) {
        var values = [];
        var thisp = arguments[1];
        for (var i = 0; i < this.length; i++) {
            if (block.call(thisp, this[i])) {
                values.push(this[i]);
            }
        }
        return values;
    };
}
if (!Array.prototype.reduce) {
    Array.prototype.reduce = function(fun /*, initial*/) {
        var len = this.length >>> 0;
        var i = 0;

        // no value to return if no initial value and an empty array
        if (len === 0 && arguments.length === 1) throw new TypeError();

        if (arguments.length >= 2) {
            var rv = arguments[1];
        } else {
            do {
                if (i in this) {
                    rv = this[i++];
                    break;
                }
                // if array contains no values, no initial value to return
                if (++i >= len) throw new TypeError();
            } while (true);
        }
        for (; i < len; i++) {
            if (i in this) {
                rv = fun.call(null, rv, this[i], i, this);
            }
        }
        return rv;
    };
}
if (!Array.prototype.indexOf) {
    Array.prototype.indexOf = function (value /*, fromIndex */ ) {
        var length = this.length;
        var i = arguments[1] || 0;

        if (!length)     return -1;
        if (i >= length) return -1;
        if (i < 0)       i += length;

        for (; i < length; i++) {
            if (!Object.prototype.hasOwnProperty.call(this, i)) { continue }
            if (value === this[i]) return i;
        }
        return -1;
    };
}

//
// Object
//
if (!Object.keys) {
    Object.keys = function (object) {
        var keys = [];
        for (var name in object) {
            if (Object.prototype.hasOwnProperty.call(object, name)) {
                keys.push(name);
            }
        }
        return keys;
    };
}

//
// String
//
if (!String.prototype.trim) {
    String.prototype.trim = function () {
        return String(this).replace(/^\s\s*/, '').replace(/\s\s*$/, '');
    };
}
var less, tree, charset;

module.exports.less = window.less = less = {}
less.tree = tree = {}
less.mode = 'browser'
//
// less.js - parser
//
//    A relatively straight-forward predictive parser.
//    There is no tokenization/lexing stage, the input is parsed
//    in one sweep.
//
//    To make the parser fast enough to run in the browser, several
//    optimization had to be made:
//
//    - Matching and slicing on a huge input is often cause of slowdowns.
//      The solution is to chunkify the input into smaller strings.
//      The chunks are stored in the `chunks` var,
//      `j` holds the current chunk index, and `current` holds
//      the index of the current chunk in relation to `input`.
//      This gives us an almost 4x speed-up.
//
//    - In many cases, we don't need to match individual tokens;
//      for example, if a value doesn't hold any variables, operations
//      or dynamic references, the parser can effectively 'skip' it,
//      treating it as a literal.
//      An example would be '1px solid #000' - which evaluates to itself,
//      we don't need to know what the individual components are.
//      The drawback, of course is that you don't get the benefits of
//      syntax-checking on the CSS. This gives us a 50% speed-up in the parser,
//      and a smaller speed-up in the code-gen.
//
//
//    Token matching is done with the `$` function, which either takes
//    a terminal string or regexp, or a non-terminal function to call.
//    It also takes care of moving all the indices forwards.
//
//
less.Parser = function Parser(env) {
    var input,       // LeSS input string
        i,           // current index in `input`
        j,           // current chunk
        temp,        // temporarily holds a chunk's state, for backtracking
        memo,        // temporarily holds `i`, when backtracking
        furthest,    // furthest index the parser has gone to
        chunks,      // chunkified input
        current,     // index of current chunk, in `input`
        parser;

    var that = this;

    // Top parser on an import tree must be sure there is one "env"
    // which will then be passed around by reference.
    if (!(env instanceof tree.parseEnv)) {
        env = new tree.parseEnv(env);
    }

    if (!env.currentDirectory && env.filename) {
        // only works for node, only used for node
        env.currentDirectory = env.filename.replace(/[^\/\\]*$/, "");
    }

    // This function is called after all files
    // have been imported through `@import`.
    var finish = function () {};

    var imports = this.imports = {
        paths: env.paths || [],  // Search paths, when importing
        queue: [],               // Files which haven't been imported yet
        files: env.files,        // Holds the imported parse trees
        contents: env.contents,  // Holds the imported file contents
        mime:  env.mime,         // MIME type of .less files
        error: null,             // Error in parsing/evaluating an import
        push: function (path, callback) {
            var that = this;
            this.queue.push(path);

            //
            // Import a file asynchronously
            //
            less.Parser.importer(path, this.paths, function (e, root, fullPath) {
                that.queue.splice(that.queue.indexOf(path), 1); // Remove the path from the queue

                var imported = fullPath in that.files;

                that.files[fullPath] = root;                        // Store the root

                if (e && !that.error) { that.error = e; }

                callback(e, root, imported);

                if (that.queue.length === 0) { finish(that.error); }       // Call `finish` if we're done importing
            }, env);
        }
    };

    function save()    { temp = chunks[j], memo = i, current = i; }
    function restore() { chunks[j] = temp, i = memo, current = i; }

    function sync() {
        if (i > current) {
            chunks[j] = chunks[j].slice(i - current);
            current = i;
        }
    }
    function isWhitespace(c) {
        // Could change to \s?
        var code = c.charCodeAt(0);
        return code === 32 || code === 10 || code === 9;
    }
    //
    // Parse from a token, regexp or string, and move forward if match
    //
    function $(tok) {
        var match, args, length, index, k;

        //
        // Non-terminal
        //
        if (tok instanceof Function) {
            return tok.call(parser.parsers);
        //
        // Terminal
        //
        //     Either match a single character in the input,
        //     or match a regexp in the current chunk (chunk[j]).
        //
        } else if (typeof(tok) === 'string') {
            match = input.charAt(i) === tok ? tok : null;
            length = 1;
            sync ();
        } else {
            sync ();

            if (match = tok.exec(chunks[j])) {
                length = match[0].length;
            } else {
                return null;
            }
        }

        // The match is confirmed, add the match length to `i`,
        // and consume any extra white-space characters (' ' || '\n')
        // which come after that. The reason for this is that LeSS's
        // grammar is mostly white-space insensitive.
        //
        if (match) {
            skipWhitespace(length);

            if(typeof(match) === 'string') {
                return match;
            } else {
                return match.length === 1 ? match[0] : match;
            }
        }
    }

    function skipWhitespace(length) {
        var oldi = i, oldj = j,
            endIndex = i + chunks[j].length,
            mem = i += length;

        while (i < endIndex) {
            if (! isWhitespace(input.charAt(i))) { break }
            i++;
        }
        chunks[j] = chunks[j].slice(length + (i - mem));
        current = i;

        if (chunks[j].length === 0 && j < chunks.length - 1) { j++ }

        return oldi !== i || oldj !== j;
    }

    function expect(arg, msg) {
        var result = $(arg);
        if (! result) {
            error(msg || (typeof(arg) === 'string' ? "expected '" + arg + "' got '" + input.charAt(i) + "'"
                                                   : "unexpected token"));
        } else {
            return result;
        }
    }

    function error(msg, type) {
        var e = new Error(msg);
        e.index = i;
        e.type = type || 'Syntax';
        throw e;
    }

    // Same as $(), but don't change the state of the parser,
    // just return the match.
    function peek(tok) {
        if (typeof(tok) === 'string') {
            return input.charAt(i) === tok;
        } else {
            if (tok.test(chunks[j])) {
                return true;
            } else {
                return false;
            }
        }
    }

    function getInput(e, env) {
        if (e.filename && env.filename && (e.filename !== env.filename)) {
            return parser.imports.contents[e.filename];
        } else {
            return input;
        }
    }

    function getLocation(index, input) {
        for (var n = index, column = -1;
                 n >= 0 && input.charAt(n) !== '\n';
                 n--) { column++ }

        return { line:   typeof(index) === 'number' ? (input.slice(0, index).match(/\n/g) || "").length : null,
                 column: column };
    }

    function getFileName(e) {
        if(less.mode === 'browser' || less.mode === 'rhino')
            return e.filename;
        else
            return require('path').resolve(e.filename);
    }

    function getDebugInfo(index, inputStream, e) {
        return {
            lineNumber: getLocation(index, inputStream).line + 1,
            fileName: getFileName(e)
        };
    }

    function LessError(e, env) {
        var input = getInput(e, env),
            loc = getLocation(e.index, input),
            line = loc.line,
            col  = loc.column,
            lines = input.split('\n');

        this.type = e.type || 'Syntax';
        this.message = e.message;
        this.filename = e.filename || env.filename;
        this.index = e.index;
        this.line = typeof(line) === 'number' ? line + 1 : null;
        this.callLine = e.call && (getLocation(e.call, input).line + 1);
        this.callExtract = lines[getLocation(e.call, input).line];
        this.stack = e.stack;
        this.column = col;
        this.extract = [
            lines[line - 1],
            lines[line],
            lines[line + 1]
        ];
    }

    this.env = env = env || {};

    // The optimization level dictates the thoroughness of the parser,
    // the lower the number, the less nodes it will create in the tree.
    // This could matter for debugging, or if you want to access
    // the individual nodes in the tree.
    this.optimization = ('optimization' in this.env) ? this.env.optimization : 1;

    this.env.filename = this.env.filename || null;

    //
    // The Parser
    //
    return parser = {

        imports: imports,
        //
        // Parse an input string into an abstract syntax tree,
        // call `callback` when done.
        //
        parse: function (str, callback) {
            var root, start, end, zone, line, lines, buff = [], c, error = null;

            i = j = current = furthest = 0;
            input = str.replace(/\r\n/g, '\n');

            // Remove potential UTF Byte Order Mark
            input = input.replace(/^\uFEFF/, '');

            // Split the input into chunks.
            chunks = (function (chunks) {
                var j = 0,
                    skip = /(?:@\{[\w-]+\}|[^"'`\{\}\/\(\)\\])+/g,
                    comment = /\/\*(?:[^*]|\*+[^\/*])*\*+\/|\/\/.*/g,
                    string = /"((?:[^"\\\r\n]|\\.)*)"|'((?:[^'\\\r\n]|\\.)*)'|`((?:[^`]|\\.)*)`/g,
                    level = 0,
                    match,
                    chunk = chunks[0],
                    inParam;

                for (var i = 0, c, cc; i < input.length;) {
                    skip.lastIndex = i;
                    if (match = skip.exec(input)) {
                        if (match.index === i) {
                            i += match[0].length;
                            chunk.push(match[0]);
                        }
                    }
                    c = input.charAt(i);
                    comment.lastIndex = string.lastIndex = i;

                    if (match = string.exec(input)) {
                        if (match.index === i) {
                            i += match[0].length;
                            chunk.push(match[0]);
                            continue;
                        }
                    }

                    if (!inParam && c === '/') {
                        cc = input.charAt(i + 1);
                        if (cc === '/' || cc === '*') {
                            if (match = comment.exec(input)) {
                                if (match.index === i) {
                                    i += match[0].length;
                                    chunk.push(match[0]);
                                    continue;
                                }
                            }
                        }
                    }

                    switch (c) {
                        case '{': if (! inParam) { level ++;        chunk.push(c);                           break }
                        case '}': if (! inParam) { level --;        chunk.push(c); chunks[++j] = chunk = []; break }
                        case '(': if (! inParam) { inParam = true;  chunk.push(c);                           break }
                        case ')': if (  inParam) { inParam = false; chunk.push(c);                           break }
                        default:                                    chunk.push(c);
                    }

                    i++;
                }
                if (level != 0) {
                    error = new(LessError)({
                        index: i-1,
                        type: 'Parse',
                        message: (level > 0) ? "missing closing `}`" : "missing opening `{`",
                        filename: env.filename
                    }, env);
                }

                return chunks.map(function (c) { return c.join('') });;
            })([[]]);

            if (error) {
                return callback(new(LessError)(error, env));
            }

            // Start with the primary rule.
            // The whole syntax tree is held under a Ruleset node,
            // with the `root` property set to true, so no `{}` are
            // output. The callback is called when the input is parsed.
            try {
                root = new(tree.Ruleset)([], $(this.parsers.primary));
                root.root = true;
            } catch (e) {
                return callback(new(LessError)(e, env));
            }

            root.toCSS = (function (evaluate) {
                var line, lines, column;

                return function (options, variables) {
                    options = options || {};
                    var importError,
                        evalEnv = new tree.evalEnv(options);

                    //
                    // Allows setting variables with a hash, so:
                    //
                    //   `{ color: new(tree.Color)('#f01') }` will become:
                    //
                    //   new(tree.Rule)('@color',
                    //     new(tree.Value)([
                    //       new(tree.Expression)([
                    //         new(tree.Color)('#f01')
                    //       ])
                    //     ])
                    //   )
                    //
                    if (typeof(variables) === 'object' && !Array.isArray(variables)) {
                        variables = Object.keys(variables).map(function (k) {
                            var value = variables[k];

                            if (! (value instanceof tree.Value)) {
                                if (! (value instanceof tree.Expression)) {
                                    value = new(tree.Expression)([value]);
                                }
                                value = new(tree.Value)([value]);
                            }
                            return new(tree.Rule)('@' + k, value, false, 0);
                        });
                        evalEnv.frames = [new(tree.Ruleset)(null, variables)];
                    }

                    try {
                        var css = evaluate.call(this, evalEnv)
                                          .toCSS([], {
                                compress: options.compress || false,
                                dumpLineNumbers: env.dumpLineNumbers,
                                strictUnits: options.strictUnits === false ? false : true});
                    } catch (e) {
                        throw new(LessError)(e, env);
                    }

                    if (options.yuicompress && less.mode === 'node') {
                        return require('ycssmin').cssmin(css);
                    } else if (options.compress) {
                        return css.replace(/(\s)+/g, "$1");
                    } else {
                        return css;
                    }
                };
            })(root.eval);

            // If `i` is smaller than the `input.length - 1`,
            // it means the parser wasn't able to parse the whole
            // string, so we've got a parsing error.
            //
            // We try to extract a \n delimited string,
            // showing the line where the parse error occured.
            // We split it up into two parts (the part which parsed,
            // and the part which didn't), so we can color them differently.
            if (i < input.length - 1) {
                i = furthest;
                lines = input.split('\n');
                line = (input.slice(0, i).match(/\n/g) || "").length + 1;

                for (var n = i, column = -1; n >= 0 && input.charAt(n) !== '\n'; n--) { column++ }

                error = {
                    type: "Parse",
                    message: "Unrecognised input",
                    index: i,
                    filename: env.filename,
                    line: line,
                    column: column,
                    extract: [
                        lines[line - 2],
                        lines[line - 1],
                        lines[line]
                    ]
                };
            }

            finish = function (e) {
                e = error || e || parser.imports.error;

                if (e) {
                    if (!(e instanceof LessError)) {
                        e = new(LessError)(e, env);
                    }

                    callback(e);
                }
                else {
                    callback(null, root);
                }
            };

            if (this.imports.queue.length === 0) {
                finish();
            }
        },

        //
        // Here in, the parsing rules/functions
        //
        // The basic structure of the syntax tree generated is as follows:
        //
        //   Ruleset ->  Rule -> Value -> Expression -> Entity
        //
        // Here's some LESS code:
        //
        //    .class {
        //      color: #fff;
        //      border: 1px solid #000;
        //      width: @w + 4px;
        //      > .child {...}
        //    }
        //
        // And here's what the parse tree might look like:
        //
        //     Ruleset (Selector '.class', [
        //         Rule ("color",  Value ([Expression [Color #fff]]))
        //         Rule ("border", Value ([Expression [Dimension 1px][Keyword "solid"][Color #000]]))
        //         Rule ("width",  Value ([Expression [Operation "+" [Variable "@w"][Dimension 4px]]]))
        //         Ruleset (Selector [Element '>', '.child'], [...])
        //     ])
        //
        //  In general, most rules will try to parse a token with the `$()` function, and if the return
        //  value is truly, will return a new node, of the relevant type. Sometimes, we need to check
        //  first, before parsing, that's when we use `peek()`.
        //
        parsers: {
            //
            // The `primary` rule is the *entry* and *exit* point of the parser.
            // The rules here can appear at any level of the parse tree.
            //
            // The recursive nature of the grammar is an interplay between the `block`
            // rule, which represents `{ ... }`, the `ruleset` rule, and this `primary` rule,
            // as represented by this simplified grammar:
            //
            //     primary  →  (ruleset | rule)+
            //     ruleset  →  selector+ block
            //     block    →  '{' primary '}'
            //
            // Only at one point is the primary rule not called from the
            // block rule: at the root level.
            //
            primary: function () {
                var node, root = [];

                while ((node = $(this.extendRule) || $(this.mixin.definition) || $(this.rule)    ||  $(this.ruleset) ||
                               $(this.mixin.call)       || $(this.comment) ||  $(this.directive))
                               || $(/^[\s\n]+/) || $(/^;+/)) {
                    node && root.push(node);
                }
                return root;
            },

            // We create a Comment node for CSS comments `/* */`,
            // but keep the LeSS comments `//` silent, by just skipping
            // over them.
            comment: function () {
                var comment;

                if (input.charAt(i) !== '/') return;

                if (input.charAt(i + 1) === '/') {
                    return new(tree.Comment)($(/^\/\/.*/), true);
                } else if (comment = $(/^\/\*(?:[^*]|\*+[^\/*])*\*+\/\n?/)) {
                    return new(tree.Comment)(comment);
                }
            },

            //
            // Entities are tokens which can be found inside an Expression
            //
            entities: {
                //
                // A string, which supports escaping " and '
                //
                //     "milky way" 'he\'s the one!'
                //
                quoted: function () {
                    var str, j = i, e;

                    if (input.charAt(j) === '~') { j++, e = true } // Escaped strings
                    if (input.charAt(j) !== '"' && input.charAt(j) !== "'") return;

                    e && $('~');

                    if (str = $(/^"((?:[^"\\\r\n]|\\.)*)"|'((?:[^'\\\r\n]|\\.)*)'/)) {
                        return new(tree.Quoted)(str[0], str[1] || str[2], e);
                    }
                },

                //
                // A catch-all word, such as:
                //
                //     black border-collapse
                //
                keyword: function () {
                    var k;

                    if (k = $(/^[_A-Za-z-][_A-Za-z0-9-]*/)) {
                        if (tree.colors.hasOwnProperty(k)) {
                            // detect named color
                            return new(tree.Color)(tree.colors[k].slice(1));
                        } else {
                            return new(tree.Keyword)(k);
                        }
                    }
                },

                //
                // A function call
                //
                //     rgb(255, 0, 255)
                //
                // We also try to catch IE's `alpha()`, but let the `alpha` parser
                // deal with the details.
                //
                // The arguments are parsed with the `entities.arguments` parser.
                //
                call: function () {
                    var name, nameLC, args, alpha_ret, index = i;

                    if (! (name = /^([\w-]+|%|progid:[\w\.]+)\(/.exec(chunks[j]))) return;

                    name = name[1];
                    nameLC = name.toLowerCase();

                    if (nameLC === 'url') { return null }
                    else                  { i += name.length }

                    if (nameLC === 'alpha') {
                        alpha_ret = $(this.alpha);
                        if(typeof alpha_ret !== 'undefined') {
                            return alpha_ret;
                        }
                    }

                    $('('); // Parse the '(' and consume whitespace.

                    args = $(this.entities.arguments);

                    if (! $(')')) {
                        return;
                    }

                    if (name) { return new(tree.Call)(name, args, index, env.filename, env.rootpath, env.currentDirectory); }
                },
                arguments: function () {
                    var args = [], arg;

                    while (arg = $(this.entities.assignment) || $(this.expression)) {
                        args.push(arg);
                        if (! $(',')) { break }
                    }
                    return args;
                },
                literal: function () {
                    return $(this.entities.dimension) ||
                           $(this.entities.color) ||
                           $(this.entities.quoted) ||
                           $(this.entities.unicodeDescriptor);
                },

                // Assignments are argument entities for calls.
                // They are present in ie filter properties as shown below.
                //
                //     filter: progid:DXImageTransform.Microsoft.Alpha( *opacity=50* )
                //

                assignment: function () {
                    var key, value;
                    if ((key = $(/^\w+(?=\s?=)/i)) && $('=') && (value = $(this.entity))) {
                        return new(tree.Assignment)(key, value);
                    }
                },

                //
                // Parse url() tokens
                //
                // We use a specific rule for urls, because they don't really behave like
                // standard function calls. The difference is that the argument doesn't have
                // to be enclosed within a string, so it can't be parsed as an Expression.
                //
                url: function () {
                    var value;

                    if (input.charAt(i) !== 'u' || !$(/^url\(/)) return;
                    value = $(this.entities.quoted)  || $(this.entities.variable) ||
                            $(/^(?:(?:\\[\(\)'"])|[^\(\)'"])+/) || "";

                    expect(')');

                    return new(tree.URL)((value.value != null || value instanceof tree.Variable)
                                        ? value : new(tree.Anonymous)(value), env.rootpath);
                },

                //
                // A Variable entity, such as `@fink`, in
                //
                //     width: @fink + 2px
                //
                // We use a different parser for variable definitions,
                // see `parsers.variable`.
                //
                variable: function () {
                    var name, index = i;

                    if (input.charAt(i) === '@' && (name = $(/^@@?[\w-]+/))) {
                        return new(tree.Variable)(name, index, env.filename);
                    }
                },

                // A variable entity useing the protective {} e.g. @{var}
                variableCurly: function () {
                    var name, curly, index = i;

                    if (input.charAt(i) === '@' && (curly = $(/^@\{([\w-]+)\}/))) {
                        return new(tree.Variable)("@" + curly[1], index, env.filename);
                    }
                },

                //
                // A Hexadecimal color
                //
                //     #4F3C2F
                //
                // `rgb` and `hsl` colors are parsed through the `entities.call` parser.
                //
                color: function () {
                    var rgb;

                    if (input.charAt(i) === '#' && (rgb = $(/^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})/))) {
                        return new(tree.Color)(rgb[1]);
                    }
                },

                //
                // A Dimension, that is, a number and a unit
                //
                //     0.5em 95%
                //
                dimension: function () {
                    var value, c = input.charCodeAt(i);
                    //Is the first char of the dimension 0-9, '.', '+' or '-'
                    if ((c > 57 || c < 43) || c === 47 || c == 44) return;

                    if (value = $(/^([+-]?\d*\.?\d+)(%|[a-z]+)?/)) {
                        return new(tree.Dimension)(value[1], value[2]);
                    }
                },

                //
                // A unicode descriptor, as is used in unicode-range
                //
                // U+0??  or U+00A1-00A9
                //
                unicodeDescriptor: function () {
                    var ud;

                    if (ud = $(/^U\+[0-9a-fA-F?]+(\-[0-9a-fA-F?]+)?/)) {
                        return new(tree.UnicodeDescriptor)(ud[0]);
                    }
                },

                //
                // JavaScript code to be evaluated
                //
                //     `window.location.href`
                //
                javascript: function () {
                    var str, j = i, e;

                    if (input.charAt(j) === '~') { j++, e = true } // Escaped strings
                    if (input.charAt(j) !== '`') { return }

                    e && $('~');

                    if (str = $(/^`([^`]*)`/)) {
                        return new(tree.JavaScript)(str[1], i, e);
                    }
                }
            },

            //
            // The variable part of a variable definition. Used in the `rule` parser
            //
            //     @fink:
            //
            variable: function () {
                var name;

                if (input.charAt(i) === '@' && (name = $(/^(@[\w-]+)\s*:/))) { return name[1] }
            },

            //
            // extend syntax - used to extend selectors
            //
            extend: function(isRule) {
                var elements = [], e, args, index = i;

                if (!$(isRule ? /^&:extend\(/ : /^:extend\(/)) { return; }

                while (e = $(/^[#.](?:[\w-]|\\(?:[a-fA-F0-9]{1,6} ?|[^a-fA-F0-9]))+/)) {
                    elements.push(new(tree.Element)(null, e, i));
                }

                expect(/^\)/);

                if (isRule) {
                    expect(/^;/);
                }

                return new(tree.Extend)(elements, index);
            },

            //
            // extendRule - used in a rule to extend all the parent selectors
            //
            extendRule: function() {
                return this.extend(true);
            },

            //
            // Mixins
            //
            mixin: {
                //
                // A Mixin call, with an optional argument list
                //
                //     #mixins > .square(#fff);
                //     .rounded(4px, black);
                //     .button;
                //
                // The `while` loop is there because mixins can be
                // namespaced, but we only support the child and descendant
                // selector for now.
                //
                call: function () {
                    var elements = [], e, c, argsSemiColon = [], argsComma = [], args, delim, arg, nameLoop, expressions, isSemiColonSeperated, expressionContainsNamed, index = i, s = input.charAt(i), name, value, important = false;

                    if (s !== '.' && s !== '#') { return }

                    save(); // stop us absorbing part of an invalid selector

                    while (e = $(/^[#.](?:[\w-]|\\(?:[A-Fa-f0-9]{1,6} ?|[^A-Fa-f0-9]))+/)) {
                        elements.push(new(tree.Element)(c, e, i));
                        c = $('>');
                    }
                    if ($('(')) {
                        expressions = [];
                        while (arg = $(this.expression)) {
                            nameLoop = null;
                            arg.throwAwayComments();
                            value = arg;

                            // Variable
                            if (arg.value.length == 1) {
                                var val = arg.value[0];
                                if (val instanceof tree.Variable) {
                                    if ($(':')) {
                                        if (expressions.length > 0) {
                                            if (isSemiColonSeperated) {
                                                error("Cannot mix ; and , as delimiter types");
                                            }
                                            expressionContainsNamed = true;
                                        }
                                        value = expect(this.expression);
                                        nameLoop = (name = val.name);
                                    }
                                }
                            }

                            expressions.push(value);

                            argsComma.push({ name: nameLoop, value: value });

                            if ($(',')) {
                                continue;
                            }

                            if ($(';') || isSemiColonSeperated) {

                                if (expressionContainsNamed) {
                                    error("Cannot mix ; and , as delimiter types");
                                }

                                isSemiColonSeperated = true;

                                if (expressions.length > 1) {
                                    value = new(tree.Value)(expressions);
                                }
                                argsSemiColon.push({ name: name, value: value });

                                name = null;
                                expressions = [];
                                expressionContainsNamed = false;
                            }
                        }

                        expect(')');
                    }

                    args = isSemiColonSeperated ? argsSemiColon : argsComma;

                    if ($(this.important)) {
                        important = true;
                    }

                    if (elements.length > 0 && ($(';') || peek('}'))) {
                        return new(tree.mixin.Call)(elements, args, index, env.filename, important);
                    }

                    restore();
                },

                //
                // A Mixin definition, with a list of parameters
                //
                //     .rounded (@radius: 2px, @color) {
                //        ...
                //     }
                //
                // Until we have a finer grained state-machine, we have to
                // do a look-ahead, to make sure we don't have a mixin call.
                // See the `rule` function for more information.
                //
                // We start by matching `.rounded (`, and then proceed on to
                // the argument list, which has optional default values.
                // We store the parameters in `params`, with a `value` key,
                // if there is a value, such as in the case of `@radius`.
                //
                // Once we've got our params list, and a closing `)`, we parse
                // the `{...}` block.
                //
                definition: function () {
                    var name, params = [], match, ruleset, param, value, cond, variadic = false;
                    if ((input.charAt(i) !== '.' && input.charAt(i) !== '#') ||
                        peek(/^[^{]*\}/)) return;

                    save();

                    if (match = $(/^([#.](?:[\w-]|\\(?:[A-Fa-f0-9]{1,6} ?|[^A-Fa-f0-9]))+)\s*\(/)) {
                        name = match[1];

                        do {
                            $(this.comment);
                            if (input.charAt(i) === '.' && $(/^\.{3}/)) {
                                variadic = true;
                                params.push({ variadic: true });
                                break;
                            } else if (param = $(this.entities.variable) || $(this.entities.literal)
                                                                         || $(this.entities.keyword)) {
                                // Variable
                                if (param instanceof tree.Variable) {
                                    if ($(':')) {
                                        value = expect(this.expression, 'expected expression');
                                        params.push({ name: param.name, value: value });
                                    } else if ($(/^\.{3}/)) {
                                        params.push({ name: param.name, variadic: true });
                                        variadic = true;
                                        break;
                                    } else {
                                        params.push({ name: param.name });
                                    }
                                } else {
                                    params.push({ value: param });
                                }
                            } else {
                                break;
                            }
                        } while ($(',') || $(';'))

                        // .mixincall("@{a}");
                        // looks a bit like a mixin definition.. so we have to be nice and restore
                        if (!$(')')) {
                            furthest = i;
                            restore();
                        }

                        $(this.comment);

                        if ($(/^when/)) { // Guard
                            cond = expect(this.conditions, 'expected condition');
                        }

                        ruleset = $(this.block);

                        if (ruleset) {
                            return new(tree.mixin.Definition)(name, params, ruleset, cond, variadic);
                        } else {
                            restore();
                        }
                    }
                }
            },

            //
            // Entities are the smallest recognized token,
            // and can be found inside a rule's value.
            //
            entity: function () {
                return $(this.entities.literal) || $(this.entities.variable) || $(this.entities.url) ||
                       $(this.entities.call)    || $(this.entities.keyword)  ||$(this.entities.javascript) ||
                       $(this.comment);
            },

            //
            // A Rule terminator. Note that we use `peek()` to check for '}',
            // because the `block` rule will be expecting it, but we still need to make sure
            // it's there, if ';' was ommitted.
            //
            end: function () {
                return $(';') || peek('}');
            },

            //
            // IE's alpha function
            //
            //     alpha(opacity=88)
            //
            alpha: function () {
                var value;

                if (! $(/^\(opacity=/i)) return;
                if (value = $(/^\d+/) || $(this.entities.variable)) {
                    expect(')');
                    return new(tree.Alpha)(value);
                }
            },

            //
            // A Selector Element
            //
            //     div
            //     + h1
            //     #socks
            //     input[type="text"]
            //
            // Elements are the building blocks for Selectors,
            // they are made out of a `Combinator` (see combinator rule),
            // and an element name, such as a tag a class, or `*`.
            //
            element: function () {
                var e, t, c, v;

                c = $(this.combinator);

                e = $(/^(?:\d+\.\d+|\d+)%/) || $(/^(?:[.#]?|:*)(?:[\w-]|[^\x00-\x9f]|\\(?:[A-Fa-f0-9]{1,6} ?|[^A-Fa-f0-9]))+/) ||
                    $('*') || $('&') || $(this.attribute) || $(/^\([^()@]+\)/) || $(/^[\.#](?=@)/) || $(this.entities.variableCurly);

                if (! e) {
                    if ($('(')) {
                        if ((v = (//$(this.entities.variableCurly) ||
                                $(this.selector))) &&
                                $(')')) {
                            e = new(tree.Paren)(v);
                        }
                    }
                }

                if (e) { return new(tree.Element)(c, e, i) }
            },

            //
            // Combinators combine elements together, in a Selector.
            //
            // Because our parser isn't white-space sensitive, special care
            // has to be taken, when parsing the descendant combinator, ` `,
            // as it's an empty space. We have to check the previous character
            // in the input, to see if it's a ` ` character. More info on how
            // we deal with this in *combinator.js*.
            //
            combinator: function () {
                var match, c = input.charAt(i);

                if (c === '>' || c === '+' || c === '~' || c === '|') {
                    i++;
                    while (input.charAt(i).match(/\s/)) { i++ }
                    return new(tree.Combinator)(c);
                } else if (input.charAt(i - 1).match(/\s/)) {
                    return new(tree.Combinator)(" ");
                } else {
                    return new(tree.Combinator)(null);
                }
            },

            //
            // A CSS Selector
            //
            //     .class > div + h1
            //     li a:hover
            //
            // Selectors are made out of one or more Elements, see above.
            //
            selector: function () {
                var sel, e, elements = [], c, match, extend;

                while ((extend = $(this.extend)) || (e = $(this.element))) {
                    if (!e) {
                        break;
                    }
                    c = input.charAt(i);
                    elements.push(e)
                    e = null;
                    if (c === '{' || c === '}' || c === ';' || c === ',' || c === ')') { break }
                }

                if (elements.length > 0) { return new(tree.Selector)(elements, extend) }
                if (extend) { error("Extend must be used to extend a selector"); }
            },
            attribute: function () {
                var attr = '', key, val, op;

                if (! $('[')) return;

                if (key = $(/^(?:[_A-Za-z0-9-]|\\.)+/) || $(this.entities.quoted)) {
                    if ((op = $(/^[|~*$^]?=/)) &&
                        (val = $(this.entities.quoted) || $(/^[\w-]+/))) {
                        attr = [key, op, val.toCSS ? val.toCSS() : val].join('');
                    } else { attr = key }
                }

                if (! $(']')) return;

                if (attr) { return "[" + attr + "]" }
            },

            //
            // The `block` rule is used by `ruleset` and `mixin.definition`.
            // It's a wrapper around the `primary` rule, with added `{}`.
            //
            block: function () {
                var content;
                if ($('{') && (content = $(this.primary)) && $('}')) {
                    return content;
                }
            },

            //
            // div, .class, body > p {...}
            //
            ruleset: function () {
                var selectors = [], s, rules, match, debugInfo;

                save();

                if (env.dumpLineNumbers)
                    debugInfo = getDebugInfo(i, input, env);

                while (s = $(this.selector)) {
                    selectors.push(s);
                    $(this.comment);
                    if (! $(',')) { break }
                    $(this.comment);
                }

                if (selectors.length > 0 && (rules = $(this.block))) {
                    var ruleset = new(tree.Ruleset)(selectors, rules, env.strictImports);
                    if (env.dumpLineNumbers)
                        ruleset.debugInfo = debugInfo;
                    return ruleset;
                } else {
                    // Backtrack
                    furthest = i;
                    restore();
                }
            },
            rule: function () {
                var name, value, c = input.charAt(i), important, match;
                save();

                if (c === '.' || c === '#' || c === '&') { return }

                if (name = $(this.variable) || $(this.property)) {
                    if (!env.compress && (name.charAt(0) != '@') && (match = /^([^@+\/'"*`(;{}-]*);/.exec(chunks[j]))) {
                        i += match[0].length - 1;
                        value = new(tree.Anonymous)(match[1]);
                    } else {
                        value = $(this.value);
                    }
                    important = $(this.important);

                    if (value && $(this.end)) {
                        return new(tree.Rule)(name, value, important, memo);
                    } else {
                        furthest = i;
                        restore();
                    }
                }
            },

            //
            // An @import directive
            //
            //     @import "lib";
            //
            // Depending on our environemnt, importing is done differently:
            // In the browser, it's an XHR request, in Node, it would be a
            // file-system operation. The function used for importing is
            // stored in `import`, which we pass to the Import constructor.
            //
            "import": function () {
                var path, features, index = i;

                save();

                var dir = $(/^@import(?:-(once|multiple))?\s+/);

                if (dir && (path = $(this.entities.quoted) || $(this.entities.url))) {
                    features = $(this.mediaFeatures);
                    if ($(';')) {
                        features = features && new(tree.Value)(features);
                        var importOnce = dir[1] !== 'multiple';
                        return new(tree.Import)(path, imports, features, importOnce, index, env.rootpath);
                    }
                }

                restore();
            },

            mediaFeature: function () {
                var e, p, nodes = [];

                do {
                    if (e = $(this.entities.keyword)) {
                        nodes.push(e);
                    } else if ($('(')) {
                        p = $(this.property);
                        e = $(this.value);
                        if ($(')')) {
                            if (p && e) {
                                nodes.push(new(tree.Paren)(new(tree.Rule)(p, e, null, i, true)));
                            } else if (e) {
                                nodes.push(new(tree.Paren)(e));
                            } else {
                                return null;
                            }
                        } else { return null }
                    }
                } while (e);

                if (nodes.length > 0) {
                    return new(tree.Expression)(nodes);
                }
            },

            mediaFeatures: function () {
                var e, features = [];

                do {
                  if (e = $(this.mediaFeature)) {
                      features.push(e);
                      if (! $(',')) { break }
                  } else if (e = $(this.entities.variable)) {
                      features.push(e);
                      if (! $(',')) { break }
                  }
                } while (e);

                return features.length > 0 ? features : null;
            },

            media: function () {
                var features, rules, media, debugInfo;

                if (env.dumpLineNumbers)
                    debugInfo = getDebugInfo(i, input, env);

                if ($(/^@media/)) {
                    features = $(this.mediaFeatures);

                    if (rules = $(this.block)) {
                        media = new(tree.Media)(rules, features);
                        if(env.dumpLineNumbers)
                            media.debugInfo = debugInfo;
                        return media;
                    }
                }
            },

            //
            // A CSS Directive
            //
            //     @charset "utf-8";
            //
            directive: function () {
                var name, value, rules, identifier, e, nodes, nonVendorSpecificName,
                    hasBlock, hasIdentifier, hasExpression;

                if (input.charAt(i) !== '@') return;

                if (value = $(this['import']) || $(this.media)) {
                    return value;
                }

                save();

                name = $(/^@[a-z-]+/);

                if (!name) return;

                nonVendorSpecificName = name;
                if (name.charAt(1) == '-' && name.indexOf('-', 2) > 0) {
                    nonVendorSpecificName = "@" + name.slice(name.indexOf('-', 2) + 1);
                }

                switch(nonVendorSpecificName) {
                    case "@font-face":
                        hasBlock = true;
                        break;
                    case "@viewport":
                    case "@top-left":
                    case "@top-left-corner":
                    case "@top-center":
                    case "@top-right":
                    case "@top-right-corner":
                    case "@bottom-left":
                    case "@bottom-left-corner":
                    case "@bottom-center":
                    case "@bottom-right":
                    case "@bottom-right-corner":
                    case "@left-top":
                    case "@left-middle":
                    case "@left-bottom":
                    case "@right-top":
                    case "@right-middle":
                    case "@right-bottom":
                        hasBlock = true;
                        break;
                    case "@page":
                    case "@document":
                    case "@supports":
                    case "@keyframes":
                        hasBlock = true;
                        hasIdentifier = true;
                        break;
                    case "@namespace":
                        hasExpression = true;
                        break;
                }

                if (hasIdentifier) {
                    name += " " + ($(/^[^{]+/) || '').trim();
                }

                if (hasBlock)
                {
                    if (rules = $(this.block)) {
                        return new(tree.Directive)(name, rules);
                    }
                } else {
                    if ((value = hasExpression ? $(this.expression) : $(this.entity)) && $(';')) {
                        var directive = new(tree.Directive)(name, value);
                        if (env.dumpLineNumbers) {
                            directive.debugInfo = getDebugInfo(i, input, env);
                        }
                        return directive;
                    }
                }

                restore();
            },

            //
            // A Value is a comma-delimited list of Expressions
            //
            //     font-family: Baskerville, Georgia, serif;
            //
            // In a Rule, a Value represents everything after the `:`,
            // and before the `;`.
            //
            value: function () {
                var e, expressions = [], important;

                while (e = $(this.expression)) {
                    expressions.push(e);
                    if (! $(',')) { break }
                }

                if (expressions.length > 0) {
                    return new(tree.Value)(expressions);
                }
            },
            important: function () {
                if (input.charAt(i) === '!') {
                    return $(/^! *important/);
                }
            },
            sub: function () {
                var a, e;

                if ($('(')) {
                    if (a = $(this.addition)) {
                        e = new(tree.Expression)([a]);
                        expect(')');
                        e.parens = true;
                        return e;
                    }
                }
            },
            multiplication: function () {
                var m, a, op, operation, isSpaced, expression = [];
                if (m = $(this.operand)) {
                    isSpaced = isWhitespace(input.charAt(i - 1));
                    while (!peek(/^\/[*\/]/) && (op = ($('/') || $('*')))) {
                        if (a = $(this.operand)) {
                            m.parensInOp = true;
                            a.parensInOp = true;
                            operation = new(tree.Operation)(op, [operation || m, a], isSpaced);
                            isSpaced = isWhitespace(input.charAt(i - 1));
                        } else {
                            break;
                        }
                    }
                    return operation || m;
                }
            },
            addition: function () {
                var m, a, op, operation, isSpaced;
                if (m = $(this.multiplication)) {
                    isSpaced = isWhitespace(input.charAt(i - 1));
                    while ((op = $(/^[-+]\s+/) || (!isSpaced && ($('+') || $('-')))) &&
                           (a = $(this.multiplication))) {
                        m.parensInOp = true;
                        a.parensInOp = true;
                        operation = new(tree.Operation)(op, [operation || m, a], isSpaced);
                        isSpaced = isWhitespace(input.charAt(i - 1));
                    }
                    return operation || m;
                }
            },
            conditions: function () {
                var a, b, index = i, condition;

                if (a = $(this.condition)) {
                    while ($(',') && (b = $(this.condition))) {
                        condition = new(tree.Condition)('or', condition || a, b, index);
                    }
                    return condition || a;
                }
            },
            condition: function () {
                var a, b, c, op, index = i, negate = false;

                if ($(/^not/)) { negate = true }
                expect('(');
                if (a = $(this.addition) || $(this.entities.keyword) || $(this.entities.quoted)) {
                    if (op = $(/^(?:>=|=<|[<=>])/)) {
                        if (b = $(this.addition) || $(this.entities.keyword) || $(this.entities.quoted)) {
                            c = new(tree.Condition)(op, a, b, index, negate);
                        } else {
                            error('expected expression');
                        }
                    } else {
                        c = new(tree.Condition)('=', a, new(tree.Keyword)('true'), index, negate);
                    }
                    expect(')');
                    return $(/^and/) ? new(tree.Condition)('and', c, $(this.condition)) : c;
                }
            },

            //
            // An operand is anything that can be part of an operation,
            // such as a Color, or a Variable
            //
            operand: function () {
                var negate, p = input.charAt(i + 1);

                if (input.charAt(i) === '-' && (p === '@' || p === '(')) { negate = $('-') }
                var o = $(this.sub) || $(this.entities.dimension) ||
                        $(this.entities.color) || $(this.entities.variable) ||
                        $(this.entities.call);

                if (negate) {
                    o.parensInOp = true;
                    o = new(tree.Negative)(o);
                }

                return o;
            },

            //
            // Expressions either represent mathematical operations,
            // or white-space delimited Entities.
            //
            //     1px solid black
            //     @var * 2
            //
            expression: function () {
                var e, delim, entities = [], d;

                while (e = $(this.addition) || $(this.entity)) {
                    entities.push(e);
                    // operations do not allow keyword "/" dimension (e.g. small/20px) so we support that here
                    if (!peek(/^\/[\/*]/) && (delim = $('/'))) {
                        entities.push(new(tree.Anonymous)(delim));
                    }
                }
                if (entities.length > 0) {
                    return new(tree.Expression)(entities);
                }
            },
            property: function () {
                var name;

                if (name = $(/^(\*?-?[_a-z0-9-]+)\s*:/)) {
                    return name[1];
                }
            }
        }
    };
};

if (less.mode === 'browser' || less.mode === 'rhino') {
    //
    // Used by `@import` directives
    //
    less.Parser.importer = function (path, paths, callback, env) {
        if (!/^([a-z-]+:)?\//.test(path) && paths.length > 0) {
            path = paths[0] + path;
        }
        // We pass `true` as 3rd argument, to force the reload of the import.
        // This is so we can get the syntax tree as opposed to just the CSS output,
        // as we need this to evaluate the current stylesheet.
        loadStyleSheet(env.toSheet(path),
            function (e, root, data, sheet, _, path) {
                callback.call(null, e, root, path);
            }, true);
    };
}

(function (tree) {

tree.functions = {
    rgb: function (r, g, b) {
        return this.rgba(r, g, b, 1.0);
    },
    rgba: function (r, g, b, a) {
        var rgb = [r, g, b].map(function (c) { return scaled(c, 256); });
        a = number(a);
        return new(tree.Color)(rgb, a);
    },
    hsl: function (h, s, l) {
        return this.hsla(h, s, l, 1.0);
    },
    hsla: function (h, s, l, a) {
        h = (number(h) % 360) / 360;
        s = number(s); l = number(l); a = number(a);

        var m2 = l <= 0.5 ? l * (s + 1) : l + s - l * s;
        var m1 = l * 2 - m2;

        return this.rgba(hue(h + 1/3) * 255,
                         hue(h)       * 255,
                         hue(h - 1/3) * 255,
                         a);

        function hue(h) {
            h = h < 0 ? h + 1 : (h > 1 ? h - 1 : h);
            if      (h * 6 < 1) return m1 + (m2 - m1) * h * 6;
            else if (h * 2 < 1) return m2;
            else if (h * 3 < 2) return m1 + (m2 - m1) * (2/3 - h) * 6;
            else                return m1;
        }
    },

    hsv: function(h, s, v) {
        return this.hsva(h, s, v, 1.0);
    },

    hsva: function(h, s, v, a) {
        h = ((number(h) % 360) / 360) * 360;
        s = number(s); v = number(v); a = number(a);

        var i, f;
        i = Math.floor((h / 60) % 6);
        f = (h / 60) - i;

        var vs = [v,
                  v * (1 - s),
                  v * (1 - f * s),
                  v * (1 - (1 - f) * s)];
        var perm = [[0, 3, 1],
                    [2, 0, 1],
                    [1, 0, 3],
                    [1, 2, 0],
                    [3, 1, 0],
                    [0, 1, 2]];

        return this.rgba(vs[perm[i][0]] * 255,
                         vs[perm[i][1]] * 255,
                         vs[perm[i][2]] * 255,
                         a);
    },

    hue: function (color) {
        return new(tree.Dimension)(Math.round(color.toHSL().h));
    },
    saturation: function (color) {
        return new(tree.Dimension)(Math.round(color.toHSL().s * 100), '%');
    },
    lightness: function (color) {
        return new(tree.Dimension)(Math.round(color.toHSL().l * 100), '%');
    },
    hsvhue: function(color) {
        return new(tree.Dimension)(Math.round(color.toHSV().h));
    },
    hsvsaturation: function (color) {
        return new(tree.Dimension)(Math.round(color.toHSV().s * 100), '%');
    },
    hsvvalue: function (color) {
        return new(tree.Dimension)(Math.round(color.toHSV().v * 100), '%');
    },
    red: function (color) {
        return new(tree.Dimension)(color.rgb[0]);
    },
    green: function (color) {
        return new(tree.Dimension)(color.rgb[1]);
    },
    blue: function (color) {
        return new(tree.Dimension)(color.rgb[2]);
    },
    alpha: function (color) {
        return new(tree.Dimension)(color.toHSL().a);
    },
    luma: function (color) {
        return new(tree.Dimension)(Math.round(color.luma() * color.alpha * 100), '%');
    },
    saturate: function (color, amount) {
        var hsl = color.toHSL();

        hsl.s += amount.value / 100;
        hsl.s = clamp(hsl.s);
        return hsla(hsl);
    },
    desaturate: function (color, amount) {
        var hsl = color.toHSL();

        hsl.s -= amount.value / 100;
        hsl.s = clamp(hsl.s);
        return hsla(hsl);
    },
    lighten: function (color, amount) {
        var hsl = color.toHSL();

        hsl.l += amount.value / 100;
        hsl.l = clamp(hsl.l);
        return hsla(hsl);
    },
    darken: function (color, amount) {
        var hsl = color.toHSL();

        hsl.l -= amount.value / 100;
        hsl.l = clamp(hsl.l);
        return hsla(hsl);
    },
    fadein: function (color, amount) {
        var hsl = color.toHSL();

        hsl.a += amount.value / 100;
        hsl.a = clamp(hsl.a);
        return hsla(hsl);
    },
    fadeout: function (color, amount) {
        var hsl = color.toHSL();

        hsl.a -= amount.value / 100;
        hsl.a = clamp(hsl.a);
        return hsla(hsl);
    },
    fade: function (color, amount) {
        var hsl = color.toHSL();

        hsl.a = amount.value / 100;
        hsl.a = clamp(hsl.a);
        return hsla(hsl);
    },
    spin: function (color, amount) {
        var hsl = color.toHSL();
        var hue = (hsl.h + amount.value) % 360;

        hsl.h = hue < 0 ? 360 + hue : hue;

        return hsla(hsl);
    },
    //
    // Copyright (c) 2006-2009 Hampton Catlin, Nathan Weizenbaum, and Chris Eppstein
    // http://sass-lang.com
    //
    mix: function (color1, color2, weight) {
        if (!weight) {
            weight = new(tree.Dimension)(50);
        }
        var p = weight.value / 100.0;
        var w = p * 2 - 1;
        var a = color1.toHSL().a - color2.toHSL().a;

        var w1 = (((w * a == -1) ? w : (w + a) / (1 + w * a)) + 1) / 2.0;
        var w2 = 1 - w1;

        var rgb = [color1.rgb[0] * w1 + color2.rgb[0] * w2,
                   color1.rgb[1] * w1 + color2.rgb[1] * w2,
                   color1.rgb[2] * w1 + color2.rgb[2] * w2];

        var alpha = color1.alpha * p + color2.alpha * (1 - p);

        return new(tree.Color)(rgb, alpha);
    },
    greyscale: function (color) {
        return this.desaturate(color, new(tree.Dimension)(100));
    },
    contrast: function (color, dark, light, threshold) {
        // filter: contrast(3.2);
        // should be kept as is, so check for color
        if (!color.rgb) {
            return null;
        }
        if (typeof light === 'undefined') {
            light = this.rgba(255, 255, 255, 1.0);
        }
        if (typeof dark === 'undefined') {
            dark = this.rgba(0, 0, 0, 1.0);
        }
        //Figure out which is actually light and dark!
        if (dark.luma() > light.luma()) {
            var t = light;
            light = dark;
            dark = t;
        }
        if (typeof threshold === 'undefined') {
            threshold = 0.43;
        } else {
            threshold = number(threshold);
        }
        if ((color.luma() * color.alpha) < threshold) {
            return light;
        } else {
            return dark;
        }
    },
    e: function (str) {
        return new(tree.Anonymous)(str instanceof tree.JavaScript ? str.evaluated : str);
    },
    escape: function (str) {
        return new(tree.Anonymous)(encodeURI(str.value).replace(/=/g, "%3D").replace(/:/g, "%3A").replace(/#/g, "%23").replace(/;/g, "%3B").replace(/\(/g, "%28").replace(/\)/g, "%29"));
    },
    '%': function (quoted /* arg, arg, ...*/) {
        var args = Array.prototype.slice.call(arguments, 1),
            str = quoted.value;

        for (var i = 0; i < args.length; i++) {
            str = str.replace(/%[sda]/i, function(token) {
                var value = token.match(/s/i) ? args[i].value : args[i].toCSS();
                return token.match(/[A-Z]$/) ? encodeURIComponent(value) : value;
            });
        }
        str = str.replace(/%%/g, '%');
        return new(tree.Quoted)('"' + str + '"', str);
    },
    unit: function (val, unit) {
        return new(tree.Dimension)(val.value, unit ? unit.toCSS() : "");
    },
    convert: function (val, unit) {
        return val.convertTo(unit.value);
    },
    round: function (n, f) {
        var fraction = typeof(f) === "undefined" ? 0 : f.value;
        return this._math(function(num) { return num.toFixed(fraction); }, null, n);
    },
    pi: function () {
        return new(tree.Dimension)(Math.PI);
    },
    mod: function(a, b) {
        return new(tree.Dimension)(a.value % b.value, a.unit);
    },
    pow: function(x, y) {
        if (typeof x === "number" && typeof y === "number") {
            x = new(tree.Dimension)(x);
            y = new(tree.Dimension)(y);
        } else if (!(x instanceof tree.Dimension) || !(y instanceof tree.Dimension)) {
            throw { type: "Argument", message: "arguments must be numbers" };
        }

        return new(tree.Dimension)(Math.pow(x.value, y.value), x.unit);
    },
    _math: function (fn, unit, n) {
        if (n instanceof tree.Dimension) {
            return new(tree.Dimension)(fn(parseFloat(n.value)), unit == null ? n.unit : unit);
        } else if (typeof(n) === 'number') {
            return fn(n);
        } else {
            throw { type: "Argument", message: "argument must be a number" };
        }
    },
    argb: function (color) {
        return new(tree.Anonymous)(color.toARGB());

    },
    percentage: function (n) {
        return new(tree.Dimension)(n.value * 100, '%');
    },
    color: function (n) {
        if (n instanceof tree.Quoted) {
            return new(tree.Color)(n.value.slice(1));
        } else {
            throw { type: "Argument", message: "argument must be a string" };
        }
    },
    iscolor: function (n) {
        return this._isa(n, tree.Color);
    },
    isnumber: function (n) {
        return this._isa(n, tree.Dimension);
    },
    isstring: function (n) {
        return this._isa(n, tree.Quoted);
    },
    iskeyword: function (n) {
        return this._isa(n, tree.Keyword);
    },
    isurl: function (n) {
        return this._isa(n, tree.URL);
    },
    ispixel: function (n) {
        return (n instanceof tree.Dimension) && n.unit.is('px') ? tree.True : tree.False;
    },
    ispercentage: function (n) {
        return (n instanceof tree.Dimension) && n.unit.is('%') ? tree.True : tree.False;
    },
    isem: function (n) {
        return (n instanceof tree.Dimension) && n.unit.is('em') ? tree.True : tree.False;
    },
    _isa: function (n, Type) {
        return (n instanceof Type) ? tree.True : tree.False;
    },

    /* Blending modes */

    multiply: function(color1, color2) {
        var r = color1.rgb[0] * color2.rgb[0] / 255;
        var g = color1.rgb[1] * color2.rgb[1] / 255;
        var b = color1.rgb[2] * color2.rgb[2] / 255;
        return this.rgb(r, g, b);
    },
    screen: function(color1, color2) {
        var r = 255 - (255 - color1.rgb[0]) * (255 - color2.rgb[0]) / 255;
        var g = 255 - (255 - color1.rgb[1]) * (255 - color2.rgb[1]) / 255;
        var b = 255 - (255 - color1.rgb[2]) * (255 - color2.rgb[2]) / 255;
        return this.rgb(r, g, b);
    },
    overlay: function(color1, color2) {
        var r = color1.rgb[0] < 128 ? 2 * color1.rgb[0] * color2.rgb[0] / 255 : 255 - 2 * (255 - color1.rgb[0]) * (255 - color2.rgb[0]) / 255;
        var g = color1.rgb[1] < 128 ? 2 * color1.rgb[1] * color2.rgb[1] / 255 : 255 - 2 * (255 - color1.rgb[1]) * (255 - color2.rgb[1]) / 255;
        var b = color1.rgb[2] < 128 ? 2 * color1.rgb[2] * color2.rgb[2] / 255 : 255 - 2 * (255 - color1.rgb[2]) * (255 - color2.rgb[2]) / 255;
        return this.rgb(r, g, b);
    },
    softlight: function(color1, color2) {
        var t = color2.rgb[0] * color1.rgb[0] / 255;
        var r = t + color1.rgb[0] * (255 - (255 - color1.rgb[0]) * (255 - color2.rgb[0]) / 255 - t) / 255;
        t = color2.rgb[1] * color1.rgb[1] / 255;
        var g = t + color1.rgb[1] * (255 - (255 - color1.rgb[1]) * (255 - color2.rgb[1]) / 255 - t) / 255;
        t = color2.rgb[2] * color1.rgb[2] / 255;
        var b = t + color1.rgb[2] * (255 - (255 - color1.rgb[2]) * (255 - color2.rgb[2]) / 255 - t) / 255;
        return this.rgb(r, g, b);
    },
    hardlight: function(color1, color2) {
        var r = color2.rgb[0] < 128 ? 2 * color2.rgb[0] * color1.rgb[0] / 255 : 255 - 2 * (255 - color2.rgb[0]) * (255 - color1.rgb[0]) / 255;
        var g = color2.rgb[1] < 128 ? 2 * color2.rgb[1] * color1.rgb[1] / 255 : 255 - 2 * (255 - color2.rgb[1]) * (255 - color1.rgb[1]) / 255;
        var b = color2.rgb[2] < 128 ? 2 * color2.rgb[2] * color1.rgb[2] / 255 : 255 - 2 * (255 - color2.rgb[2]) * (255 - color1.rgb[2]) / 255;
        return this.rgb(r, g, b);
    },
    difference: function(color1, color2) {
        var r = Math.abs(color1.rgb[0] - color2.rgb[0]);
        var g = Math.abs(color1.rgb[1] - color2.rgb[1]);
        var b = Math.abs(color1.rgb[2] - color2.rgb[2]);
        return this.rgb(r, g, b);
    },
    exclusion: function(color1, color2) {
        var r = color1.rgb[0] + color2.rgb[0] * (255 - color1.rgb[0] - color1.rgb[0]) / 255;
        var g = color1.rgb[1] + color2.rgb[1] * (255 - color1.rgb[1] - color1.rgb[1]) / 255;
        var b = color1.rgb[2] + color2.rgb[2] * (255 - color1.rgb[2] - color1.rgb[2]) / 255;
        return this.rgb(r, g, b);
    },
    average: function(color1, color2) {
        var r = (color1.rgb[0] + color2.rgb[0]) / 2;
        var g = (color1.rgb[1] + color2.rgb[1]) / 2;
        var b = (color1.rgb[2] + color2.rgb[2]) / 2;
        return this.rgb(r, g, b);
    },
    negation: function(color1, color2) {
        var r = 255 - Math.abs(255 - color2.rgb[0] - color1.rgb[0]);
        var g = 255 - Math.abs(255 - color2.rgb[1] - color1.rgb[1]);
        var b = 255 - Math.abs(255 - color2.rgb[2] - color1.rgb[2]);
        return this.rgb(r, g, b);
    },
    tint: function(color, amount) {
        return this.mix(this.rgb(255,255,255), color, amount);
    },
    shade: function(color, amount) {
        return this.mix(this.rgb(0, 0, 0), color, amount);
    },
    extract: function(values, index) {
        index = index.value - 1; // (1-based index)
        return values.value[index];
    },

    "data-uri": function(mimetypeNode, filePathNode) {

        if (typeof window !== 'undefined') {
            return new tree.URL(filePathNode || mimetypeNode, this.rootpath).eval(this.env);
        }

        var mimetype = mimetypeNode.value;
        var filePath = (filePathNode && filePathNode.value);

        var fs = require("fs"),
            path = require("path"),
            useBase64 = false;

        if (arguments.length < 2) {
            filePath = mimetype;
        }

        if (this.currentDirectory && this.env.isPathRelative(filePath)) {
            filePath = path.join(this.currentDirectory, filePath);
        }

        // detect the mimetype if not given
        if (arguments.length < 2) {
            var mime;
            try {
                mime = require('mime');
            } catch (ex) {
                mime = tree._mime;
            }

            mimetype = mime.lookup(filePath);

            // use base 64 unless it's an ASCII or UTF-8 format
            var charset = mime.charsets.lookup(mimetype);
            useBase64 = ['US-ASCII', 'UTF-8'].indexOf(charset) < 0;
            if (useBase64) mimetype += ';base64';
        }
        else {
            useBase64 = /;base64$/.test(mimetype)
        }

        var buf = fs.readFileSync(filePath);

        // IE8 cannot handle a data-uri larger than 32KB. If this is exceeded
        // and the --ieCompat flag is enabled, return a normal url() instead.
        var DATA_URI_MAX_KB = 32,
            fileSizeInKB = parseInt((buf.length / 1024), 10);
        if (fileSizeInKB >= DATA_URI_MAX_KB) {
            // the url() must be relative, not an absolute file path
            filePath = path.relative(this.currentDirectory, filePath);

            if (this.env.ieCompat !== false) {
                if (!this.env.silent) {
                    console.warn("Skipped data-uri embedding of %s because its size (%dKB) exceeds IE8-safe %dKB!", filePath, fileSizeInKB, DATA_URI_MAX_KB);
                }

                return new tree.URL(filePathNode || mimetypeNode, this.rootpath).eval(this.env);
            } else if (!this.env.silent) {
                // if explicitly disabled (via --no-ie-compat on CLI, or env.ieCompat === false), merely warn
                console.warn("WARNING: Embedding %s (%dKB) exceeds IE8's data-uri size limit of %dKB!", filePath, fileSizeInKB, DATA_URI_MAX_KB);
            }
        }

        buf = useBase64 ? buf.toString('base64')
                        : encodeURIComponent(buf);

        var uri = "'data:" + mimetype + ',' + buf + "'";
        return new(tree.URL)(new(tree.Anonymous)(uri));
    }
};

// these static methods are used as a fallback when the optional 'mime' dependency is missing
tree._mime = {
    // this map is intentionally incomplete
    // if you want more, install 'mime' dep
    _types: {
        '.htm' : 'text/html',
        '.html': 'text/html',
        '.gif' : 'image/gif',
        '.jpg' : 'image/jpeg',
        '.jpeg': 'image/jpeg',
        '.png' : 'image/png'
    },
    lookup: function (filepath) {
        var ext = require('path').extname(filepath),
            type = tree._mime._types[ext];
        if (type === undefined) {
            throw new Error('Optional dependency "mime" is required for ' + ext);
        }
        return type;
    },
    charsets: {
        lookup: function (type) {
            // assumes all text types are UTF-8
            return type && (/^text\//).test(type) ? 'UTF-8' : '';
        }
    }
};

var mathFunctions = [{name:"ceil"}, {name:"floor"}, {name: "sqrt"}, {name:"abs"},
        {name:"tan", unit: ""}, {name:"sin", unit: ""}, {name:"cos", unit: ""},
        {name:"atan", unit: "rad"}, {name:"asin", unit: "rad"}, {name:"acos", unit: "rad"}],
    createMathFunction = function(name, unit) {
        return function(n) {
            if (unit != null) {
                n = n.unify();
            }
            return this._math(Math[name], unit, n);
        };
    };

for(var i = 0; i < mathFunctions.length; i++) {
    tree.functions[mathFunctions[i].name] = createMathFunction(mathFunctions[i].name, mathFunctions[i].unit);
}

function hsla(color) {
    return tree.functions.hsla(color.h, color.s, color.l, color.a);
}

function scaled(n, size) {
    if (n instanceof tree.Dimension && n.unit.is('%')) {
        return parseFloat(n.value * size / 100);
    } else {
        return number(n);
    }
}

function number(n) {
    if (n instanceof tree.Dimension) {
        return parseFloat(n.unit.is('%') ? n.value / 100 : n.value);
    } else if (typeof(n) === 'number') {
        return n;
    } else {
        throw {
            error: "RuntimeError",
            message: "color functions take numbers as parameters"
        };
    }
}

function clamp(val) {
    return Math.min(1, Math.max(0, val));
}

tree.functionCall = function(env, rootpath, currentDirectory) {
    this.env = env;
    this.rootpath = rootpath;
    this.currentDirectory = currentDirectory;
};

tree.functionCall.prototype = tree.functions;

})(require('./tree'));
(function (tree) {
    tree.colors = {
        'aliceblue':'#f0f8ff',
        'antiquewhite':'#faebd7',
        'aqua':'#00ffff',
        'aquamarine':'#7fffd4',
        'azure':'#f0ffff',
        'beige':'#f5f5dc',
        'bisque':'#ffe4c4',
        'black':'#000000',
        'blanchedalmond':'#ffebcd',
        'blue':'#0000ff',
        'blueviolet':'#8a2be2',
        'brown':'#a52a2a',
        'burlywood':'#deb887',
        'cadetblue':'#5f9ea0',
        'chartreuse':'#7fff00',
        'chocolate':'#d2691e',
        'coral':'#ff7f50',
        'cornflowerblue':'#6495ed',
        'cornsilk':'#fff8dc',
        'crimson':'#dc143c',
        'cyan':'#00ffff',
        'darkblue':'#00008b',
        'darkcyan':'#008b8b',
        'darkgoldenrod':'#b8860b',
        'darkgray':'#a9a9a9',
        'darkgrey':'#a9a9a9',
        'darkgreen':'#006400',
        'darkkhaki':'#bdb76b',
        'darkmagenta':'#8b008b',
        'darkolivegreen':'#556b2f',
        'darkorange':'#ff8c00',
        'darkorchid':'#9932cc',
        'darkred':'#8b0000',
        'darksalmon':'#e9967a',
        'darkseagreen':'#8fbc8f',
        'darkslateblue':'#483d8b',
        'darkslategray':'#2f4f4f',
        'darkslategrey':'#2f4f4f',
        'darkturquoise':'#00ced1',
        'darkviolet':'#9400d3',
        'deeppink':'#ff1493',
        'deepskyblue':'#00bfff',
        'dimgray':'#696969',
        'dimgrey':'#696969',
        'dodgerblue':'#1e90ff',
        'firebrick':'#b22222',
        'floralwhite':'#fffaf0',
        'forestgreen':'#228b22',
        'fuchsia':'#ff00ff',
        'gainsboro':'#dcdcdc',
        'ghostwhite':'#f8f8ff',
        'gold':'#ffd700',
        'goldenrod':'#daa520',
        'gray':'#808080',
        'grey':'#808080',
        'green':'#008000',
        'greenyellow':'#adff2f',
        'honeydew':'#f0fff0',
        'hotpink':'#ff69b4',
        'indianred':'#cd5c5c',
        'indigo':'#4b0082',
        'ivory':'#fffff0',
        'khaki':'#f0e68c',
        'lavender':'#e6e6fa',
        'lavenderblush':'#fff0f5',
        'lawngreen':'#7cfc00',
        'lemonchiffon':'#fffacd',
        'lightblue':'#add8e6',
        'lightcoral':'#f08080',
        'lightcyan':'#e0ffff',
        'lightgoldenrodyellow':'#fafad2',
        'lightgray':'#d3d3d3',
        'lightgrey':'#d3d3d3',
        'lightgreen':'#90ee90',
        'lightpink':'#ffb6c1',
        'lightsalmon':'#ffa07a',
        'lightseagreen':'#20b2aa',
        'lightskyblue':'#87cefa',
        'lightslategray':'#778899',
        'lightslategrey':'#778899',
        'lightsteelblue':'#b0c4de',
        'lightyellow':'#ffffe0',
        'lime':'#00ff00',
        'limegreen':'#32cd32',
        'linen':'#faf0e6',
        'magenta':'#ff00ff',
        'maroon':'#800000',
        'mediumaquamarine':'#66cdaa',
        'mediumblue':'#0000cd',
        'mediumorchid':'#ba55d3',
        'mediumpurple':'#9370d8',
        'mediumseagreen':'#3cb371',
        'mediumslateblue':'#7b68ee',
        'mediumspringgreen':'#00fa9a',
        'mediumturquoise':'#48d1cc',
        'mediumvioletred':'#c71585',
        'midnightblue':'#191970',
        'mintcream':'#f5fffa',
        'mistyrose':'#ffe4e1',
        'moccasin':'#ffe4b5',
        'navajowhite':'#ffdead',
        'navy':'#000080',
        'oldlace':'#fdf5e6',
        'olive':'#808000',
        'olivedrab':'#6b8e23',
        'orange':'#ffa500',
        'orangered':'#ff4500',
        'orchid':'#da70d6',
        'palegoldenrod':'#eee8aa',
        'palegreen':'#98fb98',
        'paleturquoise':'#afeeee',
        'palevioletred':'#d87093',
        'papayawhip':'#ffefd5',
        'peachpuff':'#ffdab9',
        'peru':'#cd853f',
        'pink':'#ffc0cb',
        'plum':'#dda0dd',
        'powderblue':'#b0e0e6',
        'purple':'#800080',
        'red':'#ff0000',
        'rosybrown':'#bc8f8f',
        'royalblue':'#4169e1',
        'saddlebrown':'#8b4513',
        'salmon':'#fa8072',
        'sandybrown':'#f4a460',
        'seagreen':'#2e8b57',
        'seashell':'#fff5ee',
        'sienna':'#a0522d',
        'silver':'#c0c0c0',
        'skyblue':'#87ceeb',
        'slateblue':'#6a5acd',
        'slategray':'#708090',
        'slategrey':'#708090',
        'snow':'#fffafa',
        'springgreen':'#00ff7f',
        'steelblue':'#4682b4',
        'tan':'#d2b48c',
        'teal':'#008080',
        'thistle':'#d8bfd8',
        'tomato':'#ff6347',
        // 'transparent':'rgba(0,0,0,0)',
        'turquoise':'#40e0d0',
        'violet':'#ee82ee',
        'wheat':'#f5deb3',
        'white':'#ffffff',
        'whitesmoke':'#f5f5f5',
        'yellow':'#ffff00',
        'yellowgreen':'#9acd32'
    };
})(require('./tree'));
(function (tree) {

tree.Alpha = function (val) {
    this.value = val;
};
tree.Alpha.prototype = {
    toCSS: function () {
        return "alpha(opacity=" +
               (this.value.toCSS ? this.value.toCSS() : this.value) + ")";
    },
    eval: function (env) {
        if (this.value.eval) { this.value = this.value.eval(env) }
        return this;
    }
};

})(require('../tree'));
(function (tree) {

tree.Anonymous = function (string) {
    this.value = string.value || string;
};
tree.Anonymous.prototype = {
    toCSS: function () {
        return this.value;
    },
    eval: function () { return this },
    compare: function (x) {
        if (!x.toCSS) {
            return -1;
        }

        var left = this.toCSS(),
            right = x.toCSS();

        if (left === right) {
            return 0;
        }

        return left < right ? -1 : 1;
    }
};

})(require('../tree'));
(function (tree) {

tree.Assignment = function (key, val) {
    this.key = key;
    this.value = val;
};
tree.Assignment.prototype = {
    toCSS: function () {
        return this.key + '=' + (this.value.toCSS ? this.value.toCSS() : this.value);
    },
    eval: function (env) {
        if (this.value.eval) {
            return new(tree.Assignment)(this.key, this.value.eval(env));
        }
        return this;
    }
};

})(require('../tree'));(function (tree) {

//
// A function call node.
//
tree.Call = function (name, args, index, filename, rootpath, currentDirectory) {
    this.name = name;
    this.args = args;
    this.index = index;
    this.filename = filename;
    this.rootpath = rootpath;
    this.currentDirectory = currentDirectory;
};
tree.Call.prototype = {
    //
    // When evaluating a function call,
    // we either find the function in `tree.functions` [1],
    // in which case we call it, passing the  evaluated arguments,
    // if this returns null or we cannot find the function, we
    // simply print it out as it appeared originally [2].
    //
    // The *functions.js* file contains the built-in functions.
    //
    // The reason why we evaluate the arguments, is in the case where
    // we try to pass a variable to a function, like: `saturate(@color)`.
    // The function should receive the value, not the variable.
    //
    eval: function (env) {
        var args = this.args.map(function (a) { return a.eval(env); }),
            nameLC = this.name.toLowerCase(),
            result, func;

        if (nameLC in tree.functions) { // 1.
            try {
                func = new tree.functionCall(env, this.rootpath, this.currentDirectory);
                result = func[nameLC].apply(func, args);
                if (result != null) {
                    return result;
                }
            } catch (e) {
                throw { type: e.type || "Runtime",
                        message: "error evaluating function `" + this.name + "`" +
                                 (e.message ? ': ' + e.message : ''),
                        index: this.index, filename: this.filename };
            }
        }

        // 2.
        return new(tree.Anonymous)(this.name +
            "(" + args.map(function (a) { return a.toCSS(env); }).join(', ') + ")");
    },

    toCSS: function (env) {
        return this.eval(env).toCSS();
    }
};

})(require('../tree'));
(function (tree) {
//
// RGB Colors - #ff0014, #eee
//
tree.Color = function (rgb, a) {
    //
    // The end goal here, is to parse the arguments
    // into an integer triplet, such as `128, 255, 0`
    //
    // This facilitates operations and conversions.
    //
    if (Array.isArray(rgb)) {
        this.rgb = rgb;
    } else if (rgb.length == 6) {
        this.rgb = rgb.match(/.{2}/g).map(function (c) {
            return parseInt(c, 16);
        });
    } else {
        this.rgb = rgb.split('').map(function (c) {
            return parseInt(c + c, 16);
        });
    }
    this.alpha = typeof(a) === 'number' ? a : 1;
};
tree.Color.prototype = {
    eval: function () { return this },
    luma: function () { return (0.2126 * this.rgb[0] / 255) + (0.7152 * this.rgb[1] / 255) + (0.0722 * this.rgb[2] / 255); },

    //
    // If we have some transparency, the only way to represent it
    // is via `rgba`. Otherwise, we use the hex representation,
    // which has better compatibility with older browsers.
    // Values are capped between `0` and `255`, rounded and zero-padded.
    //
    toCSS: function (env, doNotCompress) {
        var compress = env && env.compress && !doNotCompress;
        if (this.alpha < 1.0) {
            return "rgba(" + this.rgb.map(function (c) {
                return Math.round(c);
            }).concat(this.alpha).join(',' + (compress ? '' : ' ')) + ")";
        } else {
            var color = this.rgb.map(function (i) {
                i = Math.round(i);
                i = (i > 255 ? 255 : (i < 0 ? 0 : i)).toString(16);
                return i.length === 1 ? '0' + i : i;
            }).join('');

            if (compress) {
                color = color.split('');

                // Convert color to short format
                if (color[0] == color[1] && color[2] == color[3] && color[4] == color[5]) {
                    color = color[0] + color[2] + color[4];
                } else {
                    color = color.join('');
                }
            }

            return '#' + color;
        }
    },

    //
    // Operations have to be done per-channel, if not,
    // channels will spill onto each other. Once we have
    // our result, in the form of an integer triplet,
    // we create a new Color node to hold the result.
    //
    operate: function (env, op, other) {
        var result = [];

        if (! (other instanceof tree.Color)) {
            other = other.toColor();
        }

        for (var c = 0; c < 3; c++) {
            result[c] = tree.operate(env, op, this.rgb[c], other.rgb[c]);
        }
        return new(tree.Color)(result, this.alpha + other.alpha);
    },

    toHSL: function () {
        var r = this.rgb[0] / 255,
            g = this.rgb[1] / 255,
            b = this.rgb[2] / 255,
            a = this.alpha;

        var max = Math.max(r, g, b), min = Math.min(r, g, b);
        var h, s, l = (max + min) / 2, d = max - min;

        if (max === min) {
            h = s = 0;
        } else {
            s = l > 0.5 ? d / (2 - max - min) : d / (max + min);

            switch (max) {
                case r: h = (g - b) / d + (g < b ? 6 : 0); break;
                case g: h = (b - r) / d + 2;               break;
                case b: h = (r - g) / d + 4;               break;
            }
            h /= 6;
        }
        return { h: h * 360, s: s, l: l, a: a };
    },
    //Adapted from http://mjijackson.com/2008/02/rgb-to-hsl-and-rgb-to-hsv-color-model-conversion-algorithms-in-javascript
    toHSV: function () {
        var r = this.rgb[0] / 255,
            g = this.rgb[1] / 255,
            b = this.rgb[2] / 255,
            a = this.alpha;

        var max = Math.max(r, g, b), min = Math.min(r, g, b);
        var h, s, v = max;

        var d = max - min;
        if (max === 0) {
            s = 0;
        } else {
            s = d / max;
        }

        if (max === min) {
            h = 0;
        } else {
            switch(max){
                case r: h = (g - b) / d + (g < b ? 6 : 0); break;
                case g: h = (b - r) / d + 2; break;
                case b: h = (r - g) / d + 4; break;
            }
            h /= 6;
        }
        return { h: h * 360, s: s, v: v, a: a };
    },
    toARGB: function () {
        var argb = [Math.round(this.alpha * 255)].concat(this.rgb);
        return '#' + argb.map(function (i) {
            i = Math.round(i);
            i = (i > 255 ? 255 : (i < 0 ? 0 : i)).toString(16);
            return i.length === 1 ? '0' + i : i;
        }).join('');
    },
    compare: function (x) {
        if (!x.rgb) {
            return -1;
        }

        return (x.rgb[0] === this.rgb[0] &&
            x.rgb[1] === this.rgb[1] &&
            x.rgb[2] === this.rgb[2] &&
            x.alpha === this.alpha) ? 0 : -1;
    }
};


})(require('../tree'));
(function (tree) {

tree.Comment = function (value, silent) {
    this.value = value;
    this.silent = !!silent;
};
tree.Comment.prototype = {
    toCSS: function (env) {
        return env.compress ? '' : this.value;
    },
    eval: function () { return this }
};

})(require('../tree'));
(function (tree) {

tree.Condition = function (op, l, r, i, negate) {
    this.op = op.trim();
    this.lvalue = l;
    this.rvalue = r;
    this.index = i;
    this.negate = negate;
};
tree.Condition.prototype.eval = function (env) {
    var a = this.lvalue.eval(env),
        b = this.rvalue.eval(env);

    var i = this.index, result;

    var result = (function (op) {
        switch (op) {
            case 'and':
                return a && b;
            case 'or':
                return a || b;
            default:
                if (a.compare) {
                    result = a.compare(b);
                } else if (b.compare) {
                    result = b.compare(a);
                } else {
                    throw { type: "Type",
                            message: "Unable to perform comparison",
                            index: i };
                }
                switch (result) {
                    case -1: return op === '<' || op === '=<';
                    case  0: return op === '=' || op === '>=' || op === '=<';
                    case  1: return op === '>' || op === '>=';
                }
        }
    })(this.op);
    return this.negate ? !result : result;
};

})(require('../tree'));
(function (tree) {

//
// A number with a unit
//
tree.Dimension = function (value, unit) {
    this.value = parseFloat(value);
    this.unit = (unit && unit instanceof tree.Unit) ? unit :
      new(tree.Unit)(unit ? [unit] : undefined);
};

tree.Dimension.prototype = {
    eval: function (env) {
        return this;
    },
    toColor: function () {
        return new(tree.Color)([this.value, this.value, this.value]);
    },
    toCSS: function (env) {
        if ((!env || env.strictUnits !== false) && !this.unit.isSingular()) {
            throw new Error("Multiple units in dimension. Correct the units or use the unit function. Bad unit: "+this.unit.toString());
        }

        var value = this.value,
            strValue = String(value);

        if (value !== 0 && value < 0.000001 && value > -0.000001) {
            // would be output 1e-6 etc.
            strValue = value.toFixed(20).replace(/0+$/, "");
        }

        if (env && env.compress) {
            // Zero values doesn't need a unit
            if (value === 0 && !this.unit.isAngle()) {
                return strValue;
            }

            // Float values doesn't need a leading zero
            if (value > 0 && value < 1) {
                strValue = (strValue).substr(1);
            }
        }

        return this.unit.isEmpty() ? strValue : (strValue + this.unit.toCSS());
    },

    // In an operation between two Dimensions,
    // we default to the first Dimension's unit,
    // so `1px + 2` will yield `3px`.
    operate: function (env, op, other) {
        var value = tree.operate(env, op, this.value, other.value),
            unit = this.unit.clone();

        if (op === '+' || op === '-') {
            if (unit.numerator.length === 0 && unit.denominator.length === 0) {
                unit.numerator = other.unit.numerator.slice(0);
                unit.denominator = other.unit.denominator.slice(0);
            } else if (other.unit.numerator.length == 0 && unit.denominator.length == 0) {
                // do nothing
            } else {
                other = other.convertTo(this.unit.usedUnits());

                if(env.strictUnits !== false && other.unit.toString() !== unit.toString()) {
                  throw new Error("Incompatible units. Change the units or use the unit function. Bad units: '" + unit.toString() +
                    "' and '" + other.unit.toString() + "'.");
                }

                value = tree.operate(env, op, this.value, other.value);
            }
        } else if (op === '*') {
            unit.numerator = unit.numerator.concat(other.unit.numerator).sort();
            unit.denominator = unit.denominator.concat(other.unit.denominator).sort();
            unit.cancel();
        } else if (op === '/') {
            unit.numerator = unit.numerator.concat(other.unit.denominator).sort();
            unit.denominator = unit.denominator.concat(other.unit.numerator).sort();
            unit.cancel();
        }
        return new(tree.Dimension)(value, unit);
    },

    compare: function (other) {
        if (other instanceof tree.Dimension) {
            var a = this.unify(), b = other.unify(),
                aValue = a.value, bValue = b.value;

            if (bValue > aValue) {
                return -1;
            } else if (bValue < aValue) {
                return 1;
            } else {
                if (!b.unit.isEmpty() && a.unit.compare(b) !== 0) {
                    return -1;
                }
                return 0;
            }
        } else {
            return -1;
        }
    },

    unify: function () {
      return this.convertTo({ length: 'm', duration: 's', angle: 'rad' });
    },

    convertTo: function (conversions) {
      var value = this.value, unit = this.unit.clone(),
          i, groupName, group, conversion, targetUnit, derivedConversions = {};

      if (typeof conversions === 'string') {
          for(i in tree.UnitConversions) {
              if (tree.UnitConversions[i].hasOwnProperty(conversions)) {
                  derivedConversions = {};
                  derivedConversions[i] = conversions;
              }
          }
          conversions = derivedConversions;
      }

      for (groupName in conversions) {
        if (conversions.hasOwnProperty(groupName)) {
          targetUnit = conversions[groupName];
          group = tree.UnitConversions[groupName];

          unit.map(function (atomicUnit, denominator) {
            if (group.hasOwnProperty(atomicUnit)) {
              if (denominator) {
                value = value / (group[atomicUnit] / group[targetUnit]);
              } else {
                value = value * (group[atomicUnit] / group[targetUnit]);
              }

              return targetUnit;
            }

            return atomicUnit;
          });
        }
      }

      unit.cancel();

      return new(tree.Dimension)(value, unit);
    }
};

// http://www.w3.org/TR/css3-values/#absolute-lengths
tree.UnitConversions = {
  length: {
     'm': 1,
    'cm': 0.01,
    'mm': 0.001,
    'in': 0.0254,
    'pt': 0.0254 / 72,
    'pc': 0.0254 / 72 * 12
  },
  duration: {
    's': 1,
    'ms': 0.001
  },
  angle: {
    'rad': 1/(2*Math.PI),
    'deg': 1/360,
    'grad': 1/400,
    'turn': 1
  }
};

tree.Unit = function (numerator, denominator) {
  this.numerator = numerator ? numerator.slice(0).sort() : [];
  this.denominator = denominator ? denominator.slice(0).sort() : [];
};

tree.Unit.prototype = {
  clone: function () {
    return new tree.Unit(this.numerator.slice(0), this.denominator.slice(0));
  },

  toCSS: function () {
    if (this.numerator.length >= 1) {
        return this.numerator[0];
    }
    if (this.denominator.length >= 1) {
        return this.denominator[0];
    }
    return "";
  },

  toString: function () {
      var i, returnStr = this.numerator.join("*");
      for (i = 0; i < this.denominator.length; i++) {
          returnStr += "/" + this.denominator[i];
      }
      return returnStr;
  },

  compare: function (other) {
    return this.is(other.toCSS()) ? 0 : -1;
  },

  is: function (unitString) {
    return this.toCSS() === unitString;
  },

  isAngle: function () {
    return tree.UnitConversions.angle.hasOwnProperty(this.toCSS());
  },

  isEmpty: function () {
    return this.numerator.length == 0 && this.denominator.length == 0;
  },

  isSingular: function() {
      return this.numerator.length <= 1 && this.denominator.length == 0;
  },

  map: function(callback) {
    var i;

    for (i = 0; i < this.numerator.length; i++) {
      this.numerator[i] = callback(this.numerator[i], false);
    }

    for (i = 0; i < this.denominator.length; i++) {
      this.denominator[i] = callback(this.denominator[i], true);
    }
  },

  usedUnits: function() {
    var group, groupName, result = {};

    for (groupName in tree.UnitConversions) {
      if (tree.UnitConversions.hasOwnProperty(groupName)) {
        group = tree.UnitConversions[groupName];

        this.map(function (atomicUnit) {
          if (group.hasOwnProperty(atomicUnit) && !result[groupName]) {
            result[groupName] = atomicUnit;
          }

          return atomicUnit;
        });
      }
    }

    return result;
  },

  cancel: function () {
    var counter = {}, atomicUnit, i;

    for (i = 0; i < this.numerator.length; i++) {
      atomicUnit = this.numerator[i];
      counter[atomicUnit] = (counter[atomicUnit] || 0) + 1;
    }

    for (i = 0; i < this.denominator.length; i++) {
      atomicUnit = this.denominator[i];
      counter[atomicUnit] = (counter[atomicUnit] || 0) - 1;
    }

    this.numerator = [];
    this.denominator = [];

    for (atomicUnit in counter) {
      if (counter.hasOwnProperty(atomicUnit)) {
        var count = counter[atomicUnit];

        if (count > 0) {
          for (i = 0; i < count; i++) {
            this.numerator.push(atomicUnit);
          }
        } else if (count < 0) {
          for (i = 0; i < -count; i++) {
            this.denominator.push(atomicUnit);
          }
        }
      }
    }

    this.numerator.sort();
    this.denominator.sort();
  }
};

})(require('../tree'));
(function (tree) {

tree.Directive = function (name, value) {
    this.name = name;

    if (Array.isArray(value)) {
        this.ruleset = new(tree.Ruleset)([], value);
        this.ruleset.allowImports = true;
    } else {
        this.value = value;
    }
};
tree.Directive.prototype = {
    toCSS: function (ctx, env) {
        if (this.ruleset) {
            this.ruleset.root = true;
            return this.name + (env.compress ? '{' : ' {\n  ') +
                   this.ruleset.toCSS(ctx, env).trim().replace(/\n/g, '\n  ') +
                               (env.compress ? '}': '\n}\n');
        } else {
            return this.name + ' ' + this.value.toCSS() + ';\n';
        }
    },
    eval: function (env) {
        var evaldDirective = this;
        if (this.ruleset) {
            env.frames.unshift(this);
            evaldDirective = new(tree.Directive)(this.name);
            evaldDirective.ruleset = this.ruleset.eval(env);
            env.frames.shift();
        }
        return evaldDirective;
    },
    variable: function (name) { return tree.Ruleset.prototype.variable.call(this.ruleset, name) },
    find: function () { return tree.Ruleset.prototype.find.apply(this.ruleset, arguments) },
    rulesets: function () { return tree.Ruleset.prototype.rulesets.apply(this.ruleset) }
};

})(require('../tree'));
(function (tree) {

tree.Element = function (combinator, value, index) {
    this.combinator = combinator instanceof tree.Combinator ?
                      combinator : new(tree.Combinator)(combinator);

    if (typeof(value) === 'string') {
        this.value = value.trim();
    } else if (value) {
        this.value = value;
    } else {
        this.value = "";
    }
    this.index = index;
};
tree.Element.prototype.eval = function (env) {
    return new(tree.Element)(this.combinator,
                             this.value.eval ? this.value.eval(env) : this.value,
                             this.index);
};
tree.Element.prototype.toCSS = function (env) {
  var value = (this.value.toCSS ? this.value.toCSS(env) : this.value);
  if (value == '' && this.combinator.value.charAt(0) == '&') {
    return '';
  } else {
    return this.combinator.toCSS(env || {}) + value;
  }
};

tree.Combinator = function (value) {
    if (value === ' ') {
        this.value = ' ';
    } else {
        this.value = value ? value.trim() : "";
    }
};
tree.Combinator.prototype.toCSS = function (env) {
    return {
        ''  : '',
        ' ' : ' ',
        ':' : ' :',
        '+' : env.compress ? '+' : ' + ',
        '~' : env.compress ? '~' : ' ~ ',
        '>' : env.compress ? '>' : ' > ',
        '|' : env.compress ? '|' : ' | '
    }[this.value];
};

})(require('../tree'));
(function (tree) {

tree.Expression = function (value) { this.value = value; };
tree.Expression.prototype = {
    eval: function (env) {
        var returnValue,
            inParenthesis = this.parens && !this.parensInOp,
            doubleParen = false;
        if (inParenthesis) {
            env.inParenthesis();
        }
        if (this.value.length > 1) {
            returnValue = new(tree.Expression)(this.value.map(function (e) {
                return e.eval(env);
            }));
        } else if (this.value.length === 1) {
            if (this.value[0].parens && !this.value[0].parensInOp) {
                doubleParen = true;
            }
            returnValue = this.value[0].eval(env);
        } else {
            returnValue = this;
        }
        if (inParenthesis) {
            env.outOfParenthesis();
        }
        if (this.parens && this.parensInOp && !(env.isMathsOn()) && !doubleParen) {
            returnValue = new(tree.Paren)(returnValue);
        }
        return returnValue;
    },
    toCSS: function (env) {
        return this.value.map(function (e) {
            return e.toCSS ? e.toCSS(env) : '';
        }).join(' ');
    },
    throwAwayComments: function () {
        this.value = this.value.filter(function(v) {
            return !(v instanceof tree.Comment);
        });
    }
};

})(require('../tree'));
(function (tree) {

tree.Extend = function Extend(elements, index) {
    this.selector = new(tree.Selector)(elements);
    this.index = index;
};

tree.Extend.prototype.eval = function Extend_eval(env, selectors) {
    var selfSelectors = findSelfSelectors(selectors || env.selectors),
        targetValue = this.selector.elements[0].value;

    env.frames.forEach(function(frame) {
        frame.rulesets().forEach(function(rule) {
            rule.selectors.forEach(function(selector) {
                selector.elements.forEach(function(element, idx) {
                    if (element.value === targetValue) {
                        selfSelectors.forEach(function(_selector) {
                            _selector.elements[0] = new tree.Element(
                                element.combinator,
                                _selector.elements[0].value,
                                _selector.elements[0].index
                            );
                            rule.selectors.push(new tree.Selector(
                                selector.elements
                                    .slice(0, idx)
                                    .concat(_selector.elements)
                                    .concat(selector.elements.slice(idx + 1))
                            ));
                        });
                    }
                });
            });
        });
    });
    return this;
};

function findSelfSelectors(selectors) {
    var ret = [];

    (function loop(elem, i) {
        if (selectors[i] && selectors[i].length) {
            selectors[i].forEach(function(s) {
                loop(s.elements.concat(elem), i + 1);
            });
        }
        else {
            ret.push({ elements: elem });
        }
    })([], 0);

    return ret;
}


})(require('../tree'));
(function (tree) {
//
// CSS @import node
//
// The general strategy here is that we don't want to wait
// for the parsing to be completed, before we start importing
// the file. That's because in the context of a browser,
// most of the time will be spent waiting for the server to respond.
//
// On creation, we push the import path to our import queue, though
// `import,push`, we also pass it a callback, which it'll call once
// the file has been fetched, and parsed.
//
tree.Import = function (path, imports, features, once, index, rootpath) {
    var that = this;

    this.once = once;
    this.index = index;
    this._path = path;
    this.features = features;
    this.rootpath = rootpath;

    // The '.less' extension is optional
    if (path instanceof tree.Quoted) {
        this.path = /(\.[a-z]*$)|([\?;].*)$/.test(path.value) ? path.value : path.value + '.less';
    } else {
        this.path = path.value.value || path.value;
    }

    this.css = /css([\?;].*)?$/.test(this.path);

    // Only pre-compile .less files
    if (! this.css) {
        imports.push(this.path, function (e, root, imported) {
            if (e) { e.index = index; }
            if (imported && that.once) { that.skip = imported; }
            that.root = root || new(tree.Ruleset)([], []);
        });
    }
};

//
// The actual import node doesn't return anything, when converted to CSS.
// The reason is that it's used at the evaluation stage, so that the rules
// it imports can be treated like any other rules.
//
// In `eval`, we make sure all Import nodes get evaluated, recursively, so
// we end up with a flat structure, which can easily be imported in the parent
// ruleset.
//
tree.Import.prototype = {
    toCSS: function (env) {
        var features = this.features ? ' ' + this.features.toCSS(env) : '';

        if (this.css) {
            // Add the base path if the import is relative
            if (typeof this._path.value === "string" && !/^(?:[a-z-]+:|\/)/.test(this._path.value)) {
                this._path.value = this.rootpath + this._path.value;
            }
            return "@import " + this._path.toCSS() + features + ';\n';
        } else {
            return "";
        }
    },
    eval: function (env) {
        var ruleset, features = this.features && this.features.eval(env);

        if (this.skip) { return []; }

        if (this.css) {
            return new(tree.Import)(this._path, null, features, this.once, this.index, this.rootpath);
        } else {
            ruleset = new(tree.Ruleset)([], this.root.rules.slice(0));

            ruleset.evalImports(env);

            return this.features ? new(tree.Media)(ruleset.rules, this.features.value) : ruleset.rules;
        }
    }
};

})(require('../tree'));
(function (tree) {

tree.JavaScript = function (string, index, escaped) {
    this.escaped = escaped;
    this.expression = string;
    this.index = index;
};
tree.JavaScript.prototype = {
    eval: function (env) {
        var result,
            that = this,
            context = {};

        var expression = this.expression.replace(/@\{([\w-]+)\}/g, function (_, name) {
            return tree.jsify(new(tree.Variable)('@' + name, that.index).eval(env));
        });

        try {
            expression = new(Function)('return (' + expression + ')');
        } catch (e) {
            throw { message: "JavaScript evaluation error: `" + expression + "`" ,
                    index: this.index };
        }

        for (var k in env.frames[0].variables()) {
            context[k.slice(1)] = {
                value: env.frames[0].variables()[k].value,
                toJS: function () {
                    return this.value.eval(env).toCSS();
                }
            };
        }

        try {
            result = expression.call(context);
        } catch (e) {
            throw { message: "JavaScript evaluation error: '" + e.name + ': ' + e.message + "'" ,
                    index: this.index };
        }
        if (typeof(result) === 'string') {
            return new(tree.Quoted)('"' + result + '"', result, this.escaped, this.index);
        } else if (Array.isArray(result)) {
            return new(tree.Anonymous)(result.join(', '));
        } else {
            return new(tree.Anonymous)(result);
        }
    }
};

})(require('../tree'));

(function (tree) {

tree.Keyword = function (value) { this.value = value };
tree.Keyword.prototype = {
    eval: function () { return this },
    toCSS: function () { return this.value },
    compare: function (other) {
        if (other instanceof tree.Keyword) {
            return other.value === this.value ? 0 : 1;
        } else {
            return -1;
        }
    }
};

tree.True = new(tree.Keyword)('true');
tree.False = new(tree.Keyword)('false');

})(require('../tree'));
(function (tree) {

tree.Media = function (value, features) {
    var selectors = this.emptySelectors();

    this.features = new(tree.Value)(features);
    this.ruleset = new(tree.Ruleset)(selectors, value);
    this.ruleset.allowImports = true;
};
tree.Media.prototype = {
    toCSS: function (ctx, env) {
        var features = this.features.toCSS(env);

        this.ruleset.root = (ctx.length === 0 || ctx[0].multiMedia);
        return '@media ' + features + (env.compress ? '{' : ' {\n  ') +
               this.ruleset.toCSS(ctx, env).trim().replace(/\n/g, '\n  ') +
                           (env.compress ? '}': '\n}\n');
    },
    eval: function (env) {
        if (!env.mediaBlocks) {
            env.mediaBlocks = [];
            env.mediaPath = [];
        }

        var media = new(tree.Media)([], []);
        if(this.debugInfo) {
            this.ruleset.debugInfo = this.debugInfo;
            media.debugInfo = this.debugInfo;
        }
        var strictMathsBypass = false;
        if (env.strictMaths === false) {
            strictMathsBypass = true;
            env.strictMaths = true;
        }
        try {
            media.features = this.features.eval(env);
        }
        finally {
            if (strictMathsBypass) {
                env.strictMaths = false;
            }
        }

        env.mediaPath.push(media);
        env.mediaBlocks.push(media);

        env.frames.unshift(this.ruleset);
        media.ruleset = this.ruleset.eval(env);
        env.frames.shift();

        env.mediaPath.pop();

        return env.mediaPath.length === 0 ? media.evalTop(env) :
                    media.evalNested(env)
    },
    variable: function (name) { return tree.Ruleset.prototype.variable.call(this.ruleset, name) },
    find: function () { return tree.Ruleset.prototype.find.apply(this.ruleset, arguments) },
    rulesets: function () { return tree.Ruleset.prototype.rulesets.apply(this.ruleset) },
    emptySelectors: function() {
        var el = new(tree.Element)('', '&', 0);
        return [new(tree.Selector)([el])];
    },

    evalTop: function (env) {
        var result = this;

        // Render all dependent Media blocks.
        if (env.mediaBlocks.length > 1) {
            var selectors = this.emptySelectors();
            result = new(tree.Ruleset)(selectors, env.mediaBlocks);
            result.multiMedia = true;
        }

        delete env.mediaBlocks;
        delete env.mediaPath;

        return result;
    },
    evalNested: function (env) {
        var i, value,
            path = env.mediaPath.concat([this]);

        // Extract the media-query conditions separated with `,` (OR).
        for (i = 0; i < path.length; i++) {
            value = path[i].features instanceof tree.Value ?
                        path[i].features.value : path[i].features;
            path[i] = Array.isArray(value) ? value : [value];
        }

        // Trace all permutations to generate the resulting media-query.
        //
        // (a, b and c) with nested (d, e) ->
        //    a and d
        //    a and e
        //    b and c and d
        //    b and c and e
        this.features = new(tree.Value)(this.permute(path).map(function (path) {
            path = path.map(function (fragment) {
                return fragment.toCSS ? fragment : new(tree.Anonymous)(fragment);
            });

            for(i = path.length - 1; i > 0; i--) {
                path.splice(i, 0, new(tree.Anonymous)("and"));
            }

            return new(tree.Expression)(path);
        }));

        // Fake a tree-node that doesn't output anything.
        return new(tree.Ruleset)([], []);
    },
    permute: function (arr) {
      if (arr.length === 0) {
          return [];
      } else if (arr.length === 1) {
          return arr[0];
      } else {
          var result = [];
          var rest = this.permute(arr.slice(1));
          for (var i = 0; i < rest.length; i++) {
              for (var j = 0; j < arr[0].length; j++) {
                  result.push([arr[0][j]].concat(rest[i]));
              }
          }
          return result;
      }
    },
    bubbleSelectors: function (selectors) {
      this.ruleset = new(tree.Ruleset)(selectors.slice(0), [this.ruleset]);
    }
};

})(require('../tree'));
(function (tree) {

tree.mixin = {};
tree.mixin.Call = function (elements, args, index, filename, important) {
    this.selector = new(tree.Selector)(elements);
    this.arguments = args;
    this.index = index;
    this.filename = filename;
    this.important = important;
};
tree.mixin.Call.prototype = {
    eval: function (env) {
        var mixins, mixin, args, rules = [], match = false, i, m, f, isRecursive, isOneFound;

        args = this.arguments && this.arguments.map(function (a) {
            return { name: a.name, value: a.value.eval(env) };
        });

        for (i = 0; i < env.frames.length; i++) {
            if ((mixins = env.frames[i].find(this.selector)).length > 0) {
                isOneFound = true;
                for (m = 0; m < mixins.length; m++) {
                    mixin = mixins[m];
                    isRecursive = false;
                    for(f = 0; f < env.frames.length; f++) {
                        if ((!(mixin instanceof tree.mixin.Definition)) && mixin === (env.frames[f].originalRuleset || env.frames[f])) {
                            isRecursive = true;
                            break;
                        }
                    }
                    if (isRecursive) {
                        continue;
                    }
                    if (mixin.matchArgs(args, env)) {
                        if (!mixin.matchCondition || mixin.matchCondition(args, env)) {
                            try {
                                Array.prototype.push.apply(
                                      rules, mixin.eval(env, args, this.important).rules);
                            } catch (e) {
                                throw { message: e.message, index: this.index, filename: this.filename, stack: e.stack };
                            }
                        }
                        match = true;
                    }
                }
                if (match) {
                    return rules;
                }
            }
        }
        if (isOneFound) {
            throw { type:    'Runtime',
                    message: 'No matching definition was found for `' +
                              this.selector.toCSS().trim() + '('      +
                              (args ? args.map(function (a) {
                                  var argValue = "";
                                  if (a.name) {
                                      argValue += a.name + ":";
                                  }
                                  if (a.value.toCSS) {
                                      argValue += a.value.toCSS();
                                  } else {
                                      argValue += "???";
                                  }
                                  return argValue;
                              }).join(', ') : "") + ")`",
                    index:   this.index, filename: this.filename };
        } else {
            throw { type: 'Name',
                message: this.selector.toCSS().trim() + " is undefined",
                index: this.index, filename: this.filename };
        }
    }
};

tree.mixin.Definition = function (name, params, rules, condition, variadic) {
    this.name = name;
    this.selectors = [new(tree.Selector)([new(tree.Element)(null, name)])];
    this.params = params;
    this.condition = condition;
    this.variadic = variadic;
    this.arity = params.length;
    this.rules = rules;
    this._lookups = {};
    this.required = params.reduce(function (count, p) {
        if (!p.name || (p.name && !p.value)) { return count + 1 }
        else                                 { return count }
    }, 0);
    this.parent = tree.Ruleset.prototype;
    this.frames = [];
};
tree.mixin.Definition.prototype = {
    toCSS:     function ()     { return "" },
    variable:  function (name) { return this.parent.variable.call(this, name) },
    variables: function ()     { return this.parent.variables.call(this) },
    find:      function ()     { return this.parent.find.apply(this, arguments) },
    rulesets:  function ()     { return this.parent.rulesets.apply(this) },

    evalParams: function (env, mixinEnv, args, evaldArguments) {
        var frame = new(tree.Ruleset)(null, []),
            varargs, arg,
            params = this.params.slice(0),
            i, j, val, name, isNamedFound, argIndex;

        mixinEnv = new tree.evalEnv(mixinEnv, [frame].concat(mixinEnv.frames));

        if (args) {
            args = args.slice(0);

            for(i = 0; i < args.length; i++) {
                arg = args[i];
                if (name = (arg && arg.name)) {
                    isNamedFound = false;
                    for(j = 0; j < params.length; j++) {
                        if (!evaldArguments[j] && name === params[j].name) {
                            evaldArguments[j] = arg.value.eval(env);
                            frame.rules.unshift(new(tree.Rule)(name, arg.value.eval(env)));
                            isNamedFound = true;
                            break;
                        }
                    }
                    if (isNamedFound) {
                        args.splice(i, 1);
                        i--;
                        continue;
                    } else {
                        throw { type: 'Runtime', message: "Named argument for " + this.name +
                            ' ' + args[i].name + ' not found' };
                    }
                }
            }
        }
        argIndex = 0;
        for (i = 0; i < params.length; i++) {
            if (evaldArguments[i]) continue;

            arg = args && args[argIndex];

            if (name = params[i].name) {
                if (params[i].variadic && args) {
                    varargs = [];
                    for (j = argIndex; j < args.length; j++) {
                        varargs.push(args[j].value.eval(env));
                    }
                    frame.rules.unshift(new(tree.Rule)(name, new(tree.Expression)(varargs).eval(env)));
                } else {
                    val = arg && arg.value;
                    if (val) {
                        val = val.eval(env);
                    } else if (params[i].value) {
                        val = params[i].value.eval(mixinEnv);
                        frame.resetCache();
                    } else {
                        throw { type: 'Runtime', message: "wrong number of arguments for " + this.name +
                            ' (' + args.length + ' for ' + this.arity + ')' };
                    }

                    frame.rules.unshift(new(tree.Rule)(name, val));
                    evaldArguments[i] = val;
                }
            }

            if (params[i].variadic && args) {
                for (j = argIndex; j < args.length; j++) {
                    evaldArguments[j] = args[j].value.eval(env);
                }
            }
            argIndex++;
        }

        return frame;
    },
    eval: function (env, args, important) {
        var _arguments = [],
            mixinFrames = this.frames.concat(env.frames),
            frame = this.evalParams(env, new(tree.evalEnv)(env, mixinFrames), args, _arguments),
            context, rules, start, ruleset;

        frame.rules.unshift(new(tree.Rule)('@arguments', new(tree.Expression)(_arguments).eval(env)));

        rules = important ?
            this.parent.makeImportant.apply(this).rules : this.rules.slice(0);

        ruleset = new(tree.Ruleset)(null, rules).eval(new(tree.evalEnv)(env,
                                                    [this, frame].concat(mixinFrames)));
        ruleset.originalRuleset = this;
        return ruleset;
    },
    matchCondition: function (args, env) {

        if (this.condition && !this.condition.eval(
            new(tree.evalEnv)(env,
                [this.evalParams(env, new(tree.evalEnv)(env, this.frames.concat(env.frames)), args, [])]
                    .concat(env.frames)))) {
            return false;
        }
        return true;
    },
    matchArgs: function (args, env) {
        var argsLength = (args && args.length) || 0, len, frame;

        if (! this.variadic) {
            if (argsLength < this.required)                               { return false }
            if (argsLength > this.params.length)                          { return false }
            if ((this.required > 0) && (argsLength > this.params.length)) { return false }
        }

        len = Math.min(argsLength, this.arity);

        for (var i = 0; i < len; i++) {
            if (!this.params[i].name && !this.params[i].variadic) {
                if (args[i].value.eval(env).toCSS() != this.params[i].value.eval(env).toCSS()) {
                    return false;
                }
            }
        }
        return true;
    }
};

})(require('../tree'));
(function (tree) {

tree.Negative = function (node) {
    this.value = node;
};
tree.Negative.prototype = {
    toCSS: function (env) {
        return '-' + this.value.toCSS(env);
    },
    eval: function (env) {
        if (env.isMathsOn()) {
            return (new(tree.Operation)('*', [new(tree.Dimension)(-1), this.value])).eval(env);
        }
        return new(tree.Negative)(this.value.eval(env));
    }
};

})(require('../tree'));
(function (tree) {

tree.Operation = function (op, operands, isSpaced) {
    this.op = op.trim();
    this.operands = operands;
    this.isSpaced = isSpaced;
};
tree.Operation.prototype.eval = function (env) {
    var a = this.operands[0].eval(env),
        b = this.operands[1].eval(env),
        temp;

    if (env.isMathsOn()) {
        if (a instanceof tree.Dimension && b instanceof tree.Color) {
            if (this.op === '*' || this.op === '+') {
                temp = b, b = a, a = temp;
            } else {
                throw { type: "Operation",
                        message: "Can't substract or divide a color from a number" };
            }
        }
        if (!a.operate) {
            throw { type: "Operation",
                    message: "Operation on an invalid type" };
        }

        return a.operate(env, this.op, b);
    } else {
        return new(tree.Operation)(this.op, [a, b], this.isSpaced);
    }
};
tree.Operation.prototype.toCSS = function (env) {
    var separator = this.isSpaced ? " " : "";
    return this.operands[0].toCSS() + separator + this.op + separator + this.operands[1].toCSS();
};

tree.operate = function (env, op, a, b) {
    switch (op) {
        case '+': return a + b;
        case '-': return a - b;
        case '*': return a * b;
        case '/': return a / b;
    }
};

})(require('../tree'));

(function (tree) {

tree.Paren = function (node) {
    this.value = node;
};
tree.Paren.prototype = {
    toCSS: function (env) {
        return '(' + this.value.toCSS(env).trim() + ')';
    },
    eval: function (env) {
        return new(tree.Paren)(this.value.eval(env));
    }
};

})(require('../tree'));
(function (tree) {

tree.Quoted = function (str, content, escaped, i) {
    this.escaped = escaped;
    this.value = content || '';
    this.quote = str.charAt(0);
    this.index = i;
};
tree.Quoted.prototype = {
    toCSS: function () {
        if (this.escaped) {
            return this.value;
        } else {
            return this.quote + this.value + this.quote;
        }
    },
    eval: function (env) {
        var that = this;
        var value = this.value.replace(/`([^`]+)`/g, function (_, exp) {
            return new(tree.JavaScript)(exp, that.index, true).eval(env).value;
        }).replace(/@\{([\w-]+)\}/g, function (_, name) {
            var v = new(tree.Variable)('@' + name, that.index).eval(env, true);
            return (v instanceof tree.Quoted) ? v.value : v.toCSS();
        });
        return new(tree.Quoted)(this.quote + value + this.quote, value, this.escaped, this.index);
    },
    compare: function (x) {
        if (!x.toCSS) {
            return -1;
        }

        var left = this.toCSS(),
            right = x.toCSS();

        if (left === right) {
            return 0;
        }

        return left < right ? -1 : 1;
    }
};

})(require('../tree'));
(function (tree) {

tree.Rule = function (name, value, important, index, inline) {
    this.name = name;
    this.value = (value instanceof tree.Value) ? value : new(tree.Value)([value]);
    this.important = important ? ' ' + important.trim() : '';
    this.index = index;
    this.inline = inline || false;

    if (name.charAt(0) === '@') {
        this.variable = true;
    } else { this.variable = false }
};
tree.Rule.prototype.toCSS = function (env) {
    if (this.variable) { return "" }
    else {
        return this.name + (env.compress ? ':' : ': ') +
               this.value.toCSS(env) +
               this.important + (this.inline ? "" : ";");
    }
};

tree.Rule.prototype.eval = function (env) {
    var strictMathsBypass = false;
    if (this.name === "font" && env.strictMaths === false) {
        strictMathsBypass = true;
        env.strictMaths = true;
    }
    try {
        return new(tree.Rule)(this.name,
                          this.value.eval(env),
                          this.important,
                          this.index, this.inline);
    }
    finally {
        if (strictMathsBypass) {
            env.strictMaths = false;
        }
    }
};

tree.Rule.prototype.makeImportant = function () {
    return new(tree.Rule)(this.name,
                          this.value,
                          "!important",
                          this.index, this.inline);
};

})(require('../tree'));
(function (tree) {

tree.Ruleset = function (selectors, rules, strictImports) {
    this.selectors = selectors;
    this.rules = rules;
    this._lookups = {};
    this.strictImports = strictImports;
};
tree.Ruleset.prototype = {
    eval: function (env) {
        var selectors = this.selectors && this.selectors.map(function (s) { return s.eval(env) });
        var ruleset = new(tree.Ruleset)(selectors, this.rules.slice(0), this.strictImports);
        var rules;

        ruleset.originalRuleset = this;
        ruleset.root = this.root;
        ruleset.allowImports = this.allowImports;

        if(this.debugInfo) {
            ruleset.debugInfo = this.debugInfo;
        }

        // push the current ruleset to the frames stack
        env.frames.unshift(ruleset);

        // currrent selectors
        if (!env.selectors) {
            env.selectors = [];
        }
        env.selectors.unshift(this.selectors);

        // Evaluate imports
        if (ruleset.root || ruleset.allowImports || !ruleset.strictImports) {
            ruleset.evalImports(env);
        }

        // Store the frames around mixin definitions,
        // so they can be evaluated like closures when the time comes.
        for (var i = 0; i < ruleset.rules.length; i++) {
            if (ruleset.rules[i] instanceof tree.mixin.Definition) {
                ruleset.rules[i].frames = env.frames.slice(0);
            }
        }

        var mediaBlockCount = (env.mediaBlocks && env.mediaBlocks.length) || 0;

        // Evaluate mixin calls.
        for (var i = 0; i < ruleset.rules.length; i++) {
            if (ruleset.rules[i] instanceof tree.mixin.Call) {
                rules = ruleset.rules[i].eval(env).filter(function(r) {
                    if ((r instanceof tree.Rule) && r.variable) {
                        // do not pollute the scope if the variable is
                        // already there. consider returning false here
                        // but we need a way to "return" variable from mixins
                        return !(ruleset.variable(r.name));
                    }
                    return true;
                });
                ruleset.rules.splice.apply(ruleset.rules, [i, 1].concat(rules));
                i += rules.length-1;
                ruleset.resetCache();
            }
        }

        if (this.selectors) {
            for (var i = 0; i < this.selectors.length; i++) {
                if (this.selectors[i].extend) {
                    this.selectors[i].extend.eval(env, [[this.selectors[i]]].concat(env.selectors.slice(1)));
                }
            }
        }

        // Evaluate everything else
        for (var i = 0, rule; i < ruleset.rules.length; i++) {
            rule = ruleset.rules[i];

            if (! (rule instanceof tree.mixin.Definition)) {
                ruleset.rules[i] = rule.eval ? rule.eval(env) : rule;
            }
        }

        // Pop the stack
        env.frames.shift();
        env.selectors.shift();

        if (env.mediaBlocks) {
            for(var i = mediaBlockCount; i < env.mediaBlocks.length; i++) {
                env.mediaBlocks[i].bubbleSelectors(selectors);
            }
        }

        return ruleset;
    },
    evalImports: function(env) {
        var i, rules;
        for (i = 0; i < this.rules.length; i++) {
            if (this.rules[i] instanceof tree.Import) {
                rules = this.rules[i].eval(env);
                if (typeof rules.length === "number") {
                    this.rules.splice.apply(this.rules, [i, 1].concat(rules));
                    i+= rules.length-1;
                } else {
                    this.rules.splice(i, 1, rules);
                }
                this.resetCache();
            }
        }
    },
    makeImportant: function() {
        return new tree.Ruleset(this.selectors, this.rules.map(function (r) {
                    if (r.makeImportant) {
                        return r.makeImportant();
                    } else {
                        return r;
                    }
                }), this.strictImports);
    },
    matchArgs: function (args) {
        return !args || args.length === 0;
    },
    resetCache: function () {
        this._rulesets = null;
        this._variables = null;
        this._lookups = {};
    },
    variables: function () {
        if (this._variables) { return this._variables }
        else {
            return this._variables = this.rules.reduce(function (hash, r) {
                if (r instanceof tree.Rule && r.variable === true) {
                    hash[r.name] = r;
                }
                return hash;
            }, {});
        }
    },
    variable: function (name) {
        return this.variables()[name];
    },
    rulesets: function () {
        return this.rules.filter(function (r) {
            return (r instanceof tree.Ruleset) || (r instanceof tree.mixin.Definition);
        });
    },
    find: function (selector, self) {
        self = self || this;
        var rules = [], rule, match,
            key = selector.toCSS();

        if (key in this._lookups) { return this._lookups[key] }

        this.rulesets().forEach(function (rule) {
            if (rule !== self) {
                for (var j = 0; j < rule.selectors.length; j++) {
                    if (match = selector.match(rule.selectors[j])) {
                        if (selector.elements.length > rule.selectors[j].elements.length) {
                            Array.prototype.push.apply(rules, rule.find(
                                new(tree.Selector)(selector.elements.slice(1)), self));
                        } else {
                            rules.push(rule);
                        }
                        break;
                    }
                }
            }
        });
        return this._lookups[key] = rules;
    },
    //
    // Entry point for code generation
    //
    //     `context` holds an array of arrays.
    //
    toCSS: function (context, env) {
        var css = [],      // The CSS output
            rules = [],    // node.Rule instances
           _rules = [],    //
            rulesets = [], // node.Ruleset instances
            paths = [],    // Current selectors
            selector,      // The fully rendered selector
            debugInfo,     // Line number debugging
            rule;

        if (! this.root) {
            this.joinSelectors(paths, context, this.selectors);
        }

        // Compile rules and rulesets
        for (var i = 0; i < this.rules.length; i++) {
            rule = this.rules[i];

            if (rule.rules || (rule instanceof tree.Media)) {
                rulesets.push(rule.toCSS(paths, env));
            } else if (rule instanceof tree.Directive) {
                var cssValue = rule.toCSS(paths, env);
                // Output only the first @charset definition as such - convert the others
                // to comments in case debug is enabled
                if (rule.name === "@charset") {
                    // Only output the debug info together with subsequent @charset definitions
                    // a comment (or @media statement) before the actual @charset directive would
                    // be considered illegal css as it has to be on the first line
                    if (env.charset) {
                        if (rule.debugInfo) {
                            rulesets.push(tree.debugInfo(env, rule));
                            rulesets.push(new tree.Comment("/* "+cssValue.replace(/\n/g, "")+" */\n").toCSS(env));
                        }
                        continue;
                    }
                    env.charset = true;
                }
                rulesets.push(cssValue);
            } else if (rule instanceof tree.Comment) {
                if (!rule.silent) {
                    if (this.root) {
                        rulesets.push(rule.toCSS(env));
                    } else {
                        rules.push(rule.toCSS(env));
                    }
                }
            } else {
                if (rule.toCSS && !rule.variable) {
                    rules.push(rule.toCSS(env));
                } else if (rule.value && !rule.variable) {
                    rules.push(rule.value.toString());
                }
            }
        }

        // Remove last semicolon
        if (env.compress && rules.length) {
            rule = rules[rules.length - 1];
            if (rule.charAt(rule.length - 1) === ';') {
                rules[rules.length - 1] = rule.substring(0, rule.length - 1);
            }
        }

        rulesets = rulesets.join('');

        // If this is the root node, we don't render
        // a selector, or {}.
        // Otherwise, only output if this ruleset has rules.
        if (this.root) {
            css.push(rules.join(env.compress ? '' : '\n'));
        } else {
            if (rules.length > 0) {
                debugInfo = tree.debugInfo(env, this);
                selector = paths.map(function (p) {
                    return p.map(function (s) {
                        return s.toCSS(env);
                    }).join('').trim();
                }).join(env.compress ? ',' : ',\n');

                // Remove duplicates
                for (var i = rules.length - 1; i >= 0; i--) {
                    if (_rules.indexOf(rules[i]) === -1) {
                        _rules.unshift(rules[i]);
                    }
                }
                rules = _rules;

                css.push(debugInfo + selector +
                        (env.compress ? '{' : ' {\n  ') +
                        rules.join(env.compress ? '' : '\n  ') +
                        (env.compress ? '}' : '\n}\n'));
            }
        }
        css.push(rulesets);

        return css.join('')  + (env.compress ? '\n' : '');
    },

    joinSelectors: function (paths, context, selectors) {
        for (var s = 0; s < selectors.length; s++) {
            this.joinSelector(paths, context, selectors[s]);
        }
    },

    joinSelector: function (paths, context, selector) {

        var i, j, k,
            hasParentSelector, newSelectors, el, sel, parentSel,
            newSelectorPath, afterParentJoin, newJoinedSelector,
            newJoinedSelectorEmpty, lastSelector, currentElements,
            selectorsMultiplied;

        for (i = 0; i < selector.elements.length; i++) {
            el = selector.elements[i];
            if (el.value === '&') {
                hasParentSelector = true;
            }
        }

        if (!hasParentSelector) {
            if (context.length > 0) {
                for(i = 0; i < context.length; i++) {
                    paths.push(context[i].concat(selector));
                }
            }
            else {
                paths.push([selector]);
            }
            return;
        }

        // The paths are [[Selector]]
        // The first list is a list of comma seperated selectors
        // The inner list is a list of inheritance seperated selectors
        // e.g.
        // .a, .b {
        //   .c {
        //   }
        // }
        // == [[.a] [.c]] [[.b] [.c]]
        //

        // the elements from the current selector so far
        currentElements = [];
        // the current list of new selectors to add to the path.
        // We will build it up. We initiate it with one empty selector as we "multiply" the new selectors
        // by the parents
        newSelectors = [[]];

        for (i = 0; i < selector.elements.length; i++) {
            el = selector.elements[i];
            // non parent reference elements just get added
            if (el.value !== "&") {
                currentElements.push(el);
            } else {
                // the new list of selectors to add
                selectorsMultiplied = [];

                // merge the current list of non parent selector elements
                // on to the current list of selectors to add
                if (currentElements.length > 0) {
                    this.mergeElementsOnToSelectors(currentElements, newSelectors);
                }

                // loop through our current selectors
                for(j = 0; j < newSelectors.length; j++) {
                    sel = newSelectors[j];
                    // if we don't have any parent paths, the & might be in a mixin so that it can be used
                    // whether there are parents or not
                    if (context.length == 0) {
                        // the combinator used on el should now be applied to the next element instead so that
                        // it is not lost
                        if (sel.length > 0) {
                            sel[0].elements = sel[0].elements.slice(0);
                            sel[0].elements.push(new(tree.Element)(el.combinator, '', 0)); //new Element(el.Combinator,  ""));
                        }
                        selectorsMultiplied.push(sel);
                    }
                    else {
                        // and the parent selectors
                        for(k = 0; k < context.length; k++) {
                            parentSel = context[k];
                            // We need to put the current selectors
                            // then join the last selector's elements on to the parents selectors

                            // our new selector path
                            newSelectorPath = [];
                            // selectors from the parent after the join
                            afterParentJoin = [];
                            newJoinedSelectorEmpty = true;

                            //construct the joined selector - if & is the first thing this will be empty,
                            // if not newJoinedSelector will be the last set of elements in the selector
                            if (sel.length > 0) {
                                newSelectorPath = sel.slice(0);
                                lastSelector = newSelectorPath.pop();
                                newJoinedSelector = new(tree.Selector)(lastSelector.elements.slice(0));
                                newJoinedSelectorEmpty = false;
                            }
                            else {
                                newJoinedSelector = new(tree.Selector)([]);
                            }

                            //put together the parent selectors after the join
                            if (parentSel.length > 1) {
                                afterParentJoin = afterParentJoin.concat(parentSel.slice(1));
                            }

                            if (parentSel.length > 0) {
                                newJoinedSelectorEmpty = false;

                                // join the elements so far with the first part of the parent
                                newJoinedSelector.elements.push(new(tree.Element)(el.combinator, parentSel[0].elements[0].value, 0));
                                newJoinedSelector.elements = newJoinedSelector.elements.concat(parentSel[0].elements.slice(1));
                            }

                            if (!newJoinedSelectorEmpty) {
                                // now add the joined selector
                                newSelectorPath.push(newJoinedSelector);
                            }

                            // and the rest of the parent
                            newSelectorPath = newSelectorPath.concat(afterParentJoin);

                            // add that to our new set of selectors
                            selectorsMultiplied.push(newSelectorPath);
                        }
                    }
                }

                // our new selectors has been multiplied, so reset the state
                newSelectors = selectorsMultiplied;
                currentElements = [];
            }
        }

        // if we have any elements left over (e.g. .a& .b == .b)
        // add them on to all the current selectors
        if (currentElements.length > 0) {
            this.mergeElementsOnToSelectors(currentElements, newSelectors);
        }

        for(i = 0; i < newSelectors.length; i++) {
            if (newSelectors[i].length > 0) {
                paths.push(newSelectors[i]);
            }
        }
    },

    mergeElementsOnToSelectors: function(elements, selectors) {
        var i, sel;

        if (selectors.length == 0) {
            selectors.push([ new(tree.Selector)(elements) ]);
            return;
        }

        for(i = 0; i < selectors.length; i++) {
            sel = selectors[i];

            // if the previous thing in sel is a parent this needs to join on to it
            if (sel.length > 0) {
                sel[sel.length - 1] = new(tree.Selector)(sel[sel.length - 1].elements.concat(elements));
            }
            else {
                sel.push(new(tree.Selector)(elements));
            }
        }
    }
};
})(require('../tree'));
(function (tree) {

tree.Selector = function (elements, extend) {
    this.elements = elements;
    this.extend = extend;
};
tree.Selector.prototype.match = function (other) {
    var elements = this.elements,
        len = elements.length,
        oelements, olen, max, i;

    oelements = other.elements.slice(
        (other.elements.length && other.elements[0].value === "&") ? 1 : 0);
    olen = oelements.length;
    max = Math.min(len, olen)

    if (olen === 0 || len < olen) {
        return false;
    } else {
        for (i = 0; i < max; i++) {
            if (elements[i].value !== oelements[i].value) {
                return false;
            }
        }
    }
    return true;
};
tree.Selector.prototype.eval = function (env) {
    return new(tree.Selector)(this.elements.map(function (e) {
        return e.eval(env);
    }), this.extend);
};
tree.Selector.prototype.toCSS = function (env) {
    if (this._css) { return this._css }

    if (this.elements[0].combinator.value === "") {
        this._css = ' ';
    } else {
        this._css = '';
    }

    this._css += this.elements.map(function (e) {
        if (typeof(e) === 'string') {
            return ' ' + e.trim();
        } else {
            return e.toCSS(env);
        }
    }).join('');

    return this._css;
};

})(require('../tree'));
(function (tree) {

tree.UnicodeDescriptor = function (value) {
    this.value = value;
};
tree.UnicodeDescriptor.prototype = {
    toCSS: function (env) {
        return this.value;
    },
    eval: function () { return this }
};

})(require('../tree'));
(function (tree) {

tree.URL = function (val, rootpath) {
    this.value = val;
    this.rootpath = rootpath;
};
tree.URL.prototype = {
    toCSS: function () {
        return "url(" + this.value.toCSS() + ")";
    },
    eval: function (ctx) {
        var val = this.value.eval(ctx), rootpath;

        // Add the base path if the URL is relative
        if (this.rootpath && typeof val.value === "string" && ctx.isPathRelative(val.value)) {
            rootpath = this.rootpath;
            if (!val.quote) {
                rootpath = rootpath.replace(/[\(\)'"\s]/g, function(match) { return "\\"+match; });
            }
            val.value = rootpath + val.value;
        }

        return new(tree.URL)(val, null);
    }
};

})(require('../tree'));
(function (tree) {

tree.Value = function (value) {
    this.value = value;
    this.is = 'value';
};
tree.Value.prototype = {
    eval: function (env) {
        if (this.value.length === 1) {
            return this.value[0].eval(env);
        } else {
            return new(tree.Value)(this.value.map(function (v) {
                return v.eval(env);
            }));
        }
    },
    toCSS: function (env) {
        return this.value.map(function (e) {
            return e.toCSS(env);
        }).join(env.compress ? ',' : ', ');
    }
};

})(require('../tree'));
(function (tree) {

tree.Variable = function (name, index, file) { this.name = name, this.index = index, this.file = file };
tree.Variable.prototype = {
    eval: function (env) {
        var variable, v, name = this.name;

        if (name.indexOf('@@') == 0) {
            name = '@' + new(tree.Variable)(name.slice(1)).eval(env).value;
        }

        if (this.evaluating) {
            throw { type: 'Name',
                    message: "Recursive variable definition for " + name,
                    filename: this.file,
                    index: this.index };
        }

        this.evaluating = true;

        if (variable = tree.find(env.frames, function (frame) {
            if (v = frame.variable(name)) {
                return v.value.eval(env);
            }
        })) {
            this.evaluating = false;
            return variable;
        }
        else {
            throw { type: 'Name',
                    message: "variable " + name + " is undefined",
                    filename: this.file,
                    index: this.index };
        }
    }
};

})(require('../tree'));
(function (tree) {

tree.debugInfo = function(env, ctx) {
    var result="";
    if (env.dumpLineNumbers && !env.compress) {
        switch(env.dumpLineNumbers) {
            case 'comments':
                result = tree.debugInfo.asComment(ctx);
                break;
            case 'mediaquery':
                result = tree.debugInfo.asMediaQuery(ctx);
                break;
            case 'all':
                result = tree.debugInfo.asComment(ctx)+tree.debugInfo.asMediaQuery(ctx);
                break;
        }
    }
    return result;
};

tree.debugInfo.asComment = function(ctx) {
    return '/* line ' + ctx.debugInfo.lineNumber + ', ' + ctx.debugInfo.fileName + ' */\n';
};

tree.debugInfo.asMediaQuery = function(ctx) {
    return '@media -sass-debug-info{filename{font-family:' +
        ('file://' + ctx.debugInfo.fileName).replace(/[\/:.]/g, '\\$&') +
        '}line{font-family:\\00003' + ctx.debugInfo.lineNumber + '}}\n';
};

tree.find = function (obj, fun) {
    for (var i = 0, r; i < obj.length; i++) {
        if (r = fun.call(obj, obj[i])) { return r }
    }
    return null;
};
tree.jsify = function (obj) {
    if (Array.isArray(obj.value) && (obj.value.length > 1)) {
        return '[' + obj.value.map(function (v) { return v.toCSS(false) }).join(', ') + ']';
    } else {
        return obj.toCSS(false);
    }
};

})(require('./tree'));
(function (tree) {

    var parseCopyProperties = [
        'paths',            // paths to search for imports on
        'optimization',     // option - optimization level (for the chunker)
        'filename',         // current filename, used for error reporting
        'files',            // list of files that have been imported, used for import-once
        'contents',         // browser-only, contents of all the files
        'rootpath',         // current rootpath to append to all url's
        'relativeUrls',     // option - whether to adjust URL's to be relative
        'strictImports',    // option -
        'dumpLineNumbers',  // option - whether to dump line numbers
        'compress',         // option - whether to compress
        'mime',             // browser only - mime type for sheet import
        'entryPath',        // browser only - path of entry less file
        'rootFilename',     // browser only - href of the entry less file
        'currentDirectory'  // node only - the current directory
    ];

    tree.parseEnv = function(options) {
        copyFromOriginal(options, this, parseCopyProperties);

        if (!this.contents) { this.contents = {}; }
        if (!this.rootpath) { this.rootpath = ''; }
        if (!this.files) { this.files = {}; }
    };

    tree.parseEnv.prototype.toSheet = function (path) {
        var env = new tree.parseEnv(this);
        env.href = path;
        //env.title = path;
        env.type = this.mime;
        return env;
    };

    var evalCopyProperties = [
        'silent',      // whether to swallow errors and warnings
        'verbose',     // whether to log more activity
        'compress',    // whether to compress
        'ieCompat',    // whether to enforce IE compatibility (IE8 data-uri)
        'strictMaths', // whether maths has to be within parenthesis
        'strictUnits'  // whether units need to evaluate correctly
        ];

    tree.evalEnv = function(options, frames) {
        copyFromOriginal(options, this, evalCopyProperties);

        this.frames = frames || [];
    };

    tree.evalEnv.prototype.inParenthesis = function () {
        if (!this.parensStack) {
            this.parensStack = [];
        }
        this.parensStack.push(true);
    };

    tree.evalEnv.prototype.outOfParenthesis = function () {
        this.parensStack.pop();
    };

    tree.evalEnv.prototype.isMathsOn = function () {
        return this.strictMaths === false ? true : (this.parensStack && this.parensStack.length);
    };

    tree.evalEnv.prototype.isPathRelative = function (path) {
        return !/^(?:[a-z-]+:|\/)/.test(path);
    };

    //todo - do the same for the toCSS env
    //tree.toCSSEnv = function (options) {
    //};

    var copyFromOriginal = function(original, destination, propertiesToCopy) {
        if (!original) { return; }

        for(var i = 0; i < propertiesToCopy.length; i++) {
            if (original.hasOwnProperty(propertiesToCopy[i])) {
                destination[propertiesToCopy[i]] = original[propertiesToCopy[i]];
            }
        }
    }
})(require('./tree'));//
// browser.js - client-side engine
//

var isFileProtocol = /^(file|chrome(-extension)?|resource|qrc|app):/.test(location.protocol);

less.env = less.env || (location.hostname == '127.0.0.1' ||
                        location.hostname == '0.0.0.0'   ||
                        location.hostname == 'localhost' ||
                        location.port.length > 0         ||
                        isFileProtocol                   ? 'development'
                                                         : 'production');

// Load styles asynchronously (default: false)
//
// This is set to `false` by default, so that the body
// doesn't start loading before the stylesheets are parsed.
// Setting this to `true` can result in flickering.
//
less.async = less.async || false;
less.fileAsync = less.fileAsync || false;

// Interval between watch polls
less.poll = less.poll || (isFileProtocol ? 1000 : 1500);

//Setup user functions
if (less.functions) {
    for(var func in less.functions) {
        less.tree.functions[func] = less.functions[func];
   }
}

var dumpLineNumbers = /!dumpLineNumbers:(comments|mediaquery|all)/.exec(location.hash);
if (dumpLineNumbers) {
    less.dumpLineNumbers = dumpLineNumbers[1];
}

//
// Watch mode
//
less.watch   = function () {
    if (!less.watchMode ){
        less.env = 'development';
         initRunningMode();
    }
    return this.watchMode = true
};

less.unwatch = function () {clearInterval(less.watchTimer); return this.watchMode = false; };

function initRunningMode(){
    if (less.env === 'development') {
        less.optimization = 0;
        less.watchTimer = setInterval(function () {
            if (less.watchMode) {
                loadStyleSheets(function (e, root, _, sheet, env) {
                    if (e) {
                        error(e, sheet.href);
                    } else if (root) {
                        createCSS(root.toCSS(less), sheet, env.lastModified);
                    }
                });
            }
        }, less.poll);
    } else {
        less.optimization = 3;
    }
}

if (/!watch/.test(location.hash)) {
    less.watch();
}

var cache = null;

if (less.env != 'development') {
    try {
        cache = (typeof(window.localStorage) === 'undefined') ? null : window.localStorage;
    } catch (_) {}
}

//
// Get all <link> tags with the 'rel' attribute set to "stylesheet/less"
//
var links = document.getElementsByTagName('link');
var typePattern = /^text\/(x-)?less$/;

less.sheets = [];

for (var i = 0; i < links.length; i++) {
    if (links[i].rel === 'stylesheet/less' || (links[i].rel.match(/stylesheet/) &&
       (links[i].type.match(typePattern)))) {
        less.sheets.push(links[i]);
    }
}

//
// With this function, it's possible to alter variables and re-render
// CSS without reloading less-files
//
var session_cache = '';
less.modifyVars = function(record) {
    var str = session_cache;
    for (name in record) {
        str += ((name.slice(0,1) === '@')? '' : '@') + name +': '+
                ((record[name].slice(-1) === ';')? record[name] : record[name] +';');
    }
    new(less.Parser)(new less.tree.parseEnv(less)).parse(str, function (e, root) {
        if (e) {
            error(e, "session_cache");
        } else {
            createCSS(root.toCSS(less), less.sheets[less.sheets.length - 1]);
        }
    });
};

less.refresh = function (reload) {
    var startTime, endTime;
    startTime = endTime = new(Date);

    loadStyleSheets(function (e, root, _, sheet, env) {
        if (e) {
            return error(e, sheet.href);
        }
        if (env.local) {
            log("loading " + sheet.href + " from cache.");
        } else {
            log("parsed " + sheet.href + " successfully.");
            createCSS(root.toCSS(less), sheet, env.lastModified);
        }
        log("css for " + sheet.href + " generated in " + (new(Date) - endTime) + 'ms');
        (env.remaining === 0) && log("css generated in " + (new(Date) - startTime) + 'ms');
        endTime = new(Date);
    }, reload);

    loadStyles();
};
less.refreshStyles = loadStyles;

less.refresh(less.env === 'development');

function loadStyles() {
    var styles = document.getElementsByTagName('style');
    for (var i = 0; i < styles.length; i++) {
        if (styles[i].type.match(typePattern)) {
            var env = new less.tree.parseEnv(less);
            env.filename = document.location.href.replace(/#.*$/, '');

            new(less.Parser)(env).parse(styles[i].innerHTML || '', function (e, cssAST) {
                if (e) {
                    return error(e, "inline");
                }
                var css = cssAST.toCSS(less);
                var style = styles[i];
                style.type = 'text/css';
                if (style.styleSheet) {
                    style.styleSheet.cssText = css;
                } else {
                    style.innerHTML = css;
                }
            });
        }
    }
}

function loadStyleSheets(callback, reload) {
    for (var i = 0; i < less.sheets.length; i++) {
        loadStyleSheet(less.sheets[i], callback, reload, less.sheets.length - (i + 1));
    }
}

function pathDiff(url, baseUrl) {
    // diff between two paths to create a relative path

    var urlParts = extractUrlParts(url),
        baseUrlParts = extractUrlParts(baseUrl),
        i, max, urlDirectories, baseUrlDirectories, diff = "";
    if (urlParts.hostPart !== baseUrlParts.hostPart) {
        return "";
    }
    max = Math.max(baseUrlParts.directories.length, urlParts.directories.length);
    for(i = 0; i < max; i++) {
        if (baseUrlParts.directories[i] !== urlParts.directories[i]) { break; }
    }
    baseUrlDirectories = baseUrlParts.directories.slice(i);
    urlDirectories = urlParts.directories.slice(i);
    for(i = 0; i < baseUrlDirectories.length-1; i++) {
        diff += "../";
    }
    for(i = 0; i < urlDirectories.length-1; i++) {
        diff += urlDirectories[i] + "/";
    }
    return diff;
}

function extractUrlParts(url, baseUrl) {
    // urlParts[1] = protocol&hostname || /
    // urlParts[2] = / if path relative to host base
    // urlParts[3] = directories
    // urlParts[4] = filename
    // urlParts[5] = parameters

    var urlPartsRegex = /^((?:[a-z-]+:)?\/+?(?:[^\/\?#]*\/)|([\/\\]))?((?:[^\/\\\?#]*[\/\\])*)([^\/\\\?#]*)([#\?].*)?$/,
        urlParts = url.match(urlPartsRegex),
        returner = {}, directories = [], i, baseUrlParts;

    if (!urlParts) {
        throw new Error("Could not parse sheet href - '"+url+"'");
    }

    // Stylesheets in IE don't always return the full path
    if (!urlParts[1] || urlParts[2]) {
        baseUrlParts = baseUrl.match(urlPartsRegex);
        if (!baseUrlParts) {
            throw new Error("Could not parse page url - '"+baseUrl+"'");
        }
        urlParts[1] = baseUrlParts[1];
        if (!urlParts[2]) {
            urlParts[3] = baseUrlParts[3] + urlParts[3];
        }
    }

    if (urlParts[3]) {
        directories = urlParts[3].replace("\\", "/").split("/");

        for(i = 0; i < directories.length; i++) {
            if (directories[i] === ".." && i > 0) {
                directories.splice(i-1, 2);
                i -= 2;
            }
        }
    }

    returner.hostPart = urlParts[1];
    returner.directories = directories;
    returner.path = urlParts[1] + directories.join("/");
    returner.fileUrl = returner.path + (urlParts[4] || "");
    returner.url = returner.fileUrl + (urlParts[5] || "");
    return returner;
}

function loadStyleSheet(sheet, callback, reload, remaining) {

    // sheet may be set to the stylesheet for the initial load or a collection of properties including
    // some env variables for imports
    var hrefParts = extractUrlParts(sheet.href, window.location.href);
    var href      = hrefParts.url;
    var css       = cache && cache.getItem(href);
    var timestamp = cache && cache.getItem(href + ':timestamp');
    var styles    = { css: css, timestamp: timestamp };
    var env;

    if (sheet instanceof less.tree.parseEnv) {
        env = new less.tree.parseEnv(sheet);
    } else {
        env = new less.tree.parseEnv(less);
        env.entryPath = hrefParts.path;
        env.mime = sheet.type;
    }

    if (env.relativeUrls) {
        //todo - this relies on option being set on less object rather than being passed in as an option
        //     - need an originalRootpath
        if (less.rootpath) {
            env.rootpath = extractUrlParts(less.rootpath + pathDiff(hrefParts.path, env.entryPath)).path;
        } else {
            env.rootpath = hrefParts.path;
        }
    } else  {
        if (!less.rootpath) {
            env.rootpath = env.entryPath;
        }
    }

    xhr(href, sheet.type, function (data, lastModified) {
        // Store data this session
        session_cache += data.replace(/@import .+?;/ig, '');

        if (!reload && styles && lastModified &&
           (new(Date)(lastModified).valueOf() ===
            new(Date)(styles.timestamp).valueOf())) {
            // Use local copy
            createCSS(styles.css, sheet);
            callback(null, null, data, sheet, { local: true, remaining: remaining }, href);
        } else {
            // Use remote copy (re-parse)
            try {
                env.contents[href] = data;  // Updating content cache
                env.paths = [hrefParts.path];
                env.filename = href;
                env.rootFilename = env.rootFilename || href;
                new(less.Parser)(env).parse(data, function (e, root) {
                    if (e) { return callback(e, null, null, sheet); }
                    try {
                        callback(e, root, data, sheet, { local: false, lastModified: lastModified, remaining: remaining }, href);
                        //TODO - there must be a better way? A generic less-to-css function that can both call error
                        //and removeNode where appropriate
                        //should also add tests
                        if (env.rootFilename === href) {
                            removeNode(document.getElementById('less-error-message:' + extractId(href)));
                        }
                    } catch (e) {
                        callback(e, null, null, sheet);
                    }
                });
            } catch (e) {
                callback(e, null, null, sheet);
            }
        }
    }, function (status, url) {
        callback({ type: 'File', message: "'" + url + "' wasn't found (" + status + ")" }, null, null, sheet);
    });
}

function extractId(href) {
    return href.replace(/^[a-z-]+:\/+?[^\/]+/, '' )  // Remove protocol & domain
               .replace(/^\//,                 '' )  // Remove root /
               .replace(/\.[a-zA-Z]+$/,        '' )  // Remove simple extension
               .replace(/[^\.\w-]+/g,          '-')  // Replace illegal characters
               .replace(/\./g,                 ':'); // Replace dots with colons(for valid id)
}

function createCSS(styles, sheet, lastModified) {
    // Strip the query-string
    var href = sheet.href || '';

    // If there is no title set, use the filename, minus the extension
    var id = 'less:' + (sheet.title || extractId(href));

    // If this has already been inserted into the DOM, we may need to replace it
    var oldCss = document.getElementById(id);
    var keepOldCss = false;

    // Create a new stylesheet node for insertion or (if necessary) replacement
    var css = document.createElement('style');
    css.setAttribute('type', 'text/css');
    if (sheet.media) {
        css.setAttribute('media', sheet.media);
    }
    css.id = id;

    if (css.styleSheet) { // IE
        try {
            css.styleSheet.cssText = styles;
        } catch (e) {
            throw new(Error)("Couldn't reassign styleSheet.cssText.");
        }
    } else {
        css.appendChild(document.createTextNode(styles));

        // If new contents match contents of oldCss, don't replace oldCss
        keepOldCss = (oldCss !== null && oldCss.childNodes.length > 0 && css.childNodes.length > 0 &&
            oldCss.firstChild.nodeValue === css.firstChild.nodeValue);
    }

    var head = document.getElementsByTagName('head')[0];

    // If there is no oldCss, just append; otherwise, only append if we need
    // to replace oldCss with an updated stylesheet
    if (oldCss == null || keepOldCss === false) {
        var nextEl = sheet && sheet.nextSibling || null;
        (nextEl || document.getElementsByTagName('head')[0]).parentNode.insertBefore(css, nextEl);
    }
    if (oldCss && keepOldCss === false) {
        head.removeChild(oldCss);
    }

    // Don't update the local store if the file wasn't modified
    if (lastModified && cache) {
        log('saving ' + href + ' to cache.');
        try {
            cache.setItem(href, styles);
            cache.setItem(href + ':timestamp', lastModified);
        } catch(e) {
            //TODO - could do with adding more robust error handling
            log('failed to save');
        }
    }
}

function xhr(url, type, callback, errback) {
    var xhr = getXMLHttpRequest();
    var async = isFileProtocol ? less.fileAsync : less.async;

    if (typeof(xhr.overrideMimeType) === 'function') {
        xhr.overrideMimeType('text/css');
    }
    xhr.open('GET', url, async);
    xhr.setRequestHeader('Accept', type || 'text/x-less, text/css; q=0.9, */*; q=0.5');
    xhr.send(null);

    if (isFileProtocol && !less.fileAsync) {
        if (xhr.status === 0 || (xhr.status >= 200 && xhr.status < 300)) {
            callback(xhr.responseText);
        } else {
            errback(xhr.status, url);
        }
    } else if (async) {
        xhr.onreadystatechange = function () {
            if (xhr.readyState == 4) {
                handleResponse(xhr, callback, errback);
            }
        };
    } else {
        handleResponse(xhr, callback, errback);
    }

    function handleResponse(xhr, callback, errback) {
        if (xhr.status >= 200 && xhr.status < 300) {
            callback(xhr.responseText,
                     xhr.getResponseHeader("Last-Modified"));
        } else if (typeof(errback) === 'function') {
            errback(xhr.status, url);
        }
    }
}

function getXMLHttpRequest() {
    if (window.XMLHttpRequest) {
        return new(XMLHttpRequest);
    } else {
        try {
            return new(ActiveXObject)("MSXML2.XMLHTTP.3.0");
        } catch (e) {
            log("browser doesn't support AJAX.");
            return null;
        }
    }
}

function removeNode(node) {
    return node && node.parentNode.removeChild(node);
}

function log(str) {
    if (less.env == 'development' && typeof(console) !== "undefined") { console.log('less: ' + str) }
}

function error(e, rootHref) {
    var id = 'less-error-message:' + extractId(rootHref || "");
    var template = '<li><label>{line}</label><pre class="{class}">{content}</pre></li>';
    var elem = document.createElement('div'), timer, content, error = [];
    var filename = e.filename || rootHref;
    var filenameNoPath = filename.match(/([^\/]+(\?.*)?)$/)[1];

    elem.id        = id;
    elem.className = "less-error-message";

    content = '<h3>'  + (e.type || "Syntax") + "Error: " + (e.message || 'There is an error in your .less file') +
              '</h3>' + '<p>in <a href="' + filename   + '">' + filenameNoPath + "</a> ";

    var errorline = function (e, i, classname) {
        if (e.extract[i] != undefined) {
            error.push(template.replace(/\{line\}/, (parseInt(e.line) || 0) + (i - 1))
                               .replace(/\{class\}/, classname)
                               .replace(/\{content\}/, e.extract[i]));
        }
    };

    if (e.extract) {
        errorline(e, 0, '');
        errorline(e, 1, 'line');
        errorline(e, 2, '');
        content += 'on line ' + e.line + ', column ' + (e.column + 1) + ':</p>' +
                    '<ul>' + error.join('') + '</ul>';
    } else if (e.stack) {
        content += '<br/>' + e.stack.split('\n').slice(1).join('<br/>');
    }
    elem.innerHTML = content;

    // CSS for error messages
    createCSS([
        '.less-error-message ul, .less-error-message li {',
            'list-style-type: none;',
            'margin-right: 15px;',
            'padding: 4px 0;',
            'margin: 0;',
        '}',
        '.less-error-message label {',
            'font-size: 12px;',
            'margin-right: 15px;',
            'padding: 4px 0;',
            'color: #cc7777;',
        '}',
        '.less-error-message pre {',
            'color: #dd6666;',
            'padding: 4px 0;',
            'margin: 0;',
            'display: inline-block;',
        '}',
        '.less-error-message pre.line {',
            'color: #ff0000;',
        '}',
        '.less-error-message h3 {',
            'font-size: 20px;',
            'font-weight: bold;',
            'padding: 15px 0 5px 0;',
            'margin: 0;',
        '}',
        '.less-error-message a {',
            'color: #10a',
        '}',
        '.less-error-message .error {',
            'color: red;',
            'font-weight: bold;',
            'padding-bottom: 2px;',
            'border-bottom: 1px dashed red;',
        '}'
    ].join('\n'), { title: 'error-message' });

    elem.style.cssText = [
        "font-family: Arial, sans-serif",
        "border: 1px solid #e00",
        "background-color: #eee",
        "border-radius: 5px",
        "-webkit-border-radius: 5px",
        "-moz-border-radius: 5px",
        "color: #e00",
        "padding: 15px",
        "margin-bottom: 15px"
    ].join(';');

    if (less.env == 'development') {
        timer = setInterval(function () {
            if (document.body) {
                if (document.getElementById(id)) {
                    document.body.replaceChild(elem, document.getElementById(id));
                } else {
                    document.body.insertBefore(elem, document.body.firstChild);
                }
                clearInterval(timer);
            }
        }, 10);
    }
}
// amd.js
//
// Define Less as an AMD module.
if (typeof define === "function" && define.amd) {
    define(function () { return less; } );
}
})(window);