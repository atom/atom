// MODIFIED:
// Generated with `MINIFY=false cake build:browser` from CoffeeScript source
// Removed call to `define` at end of file so our wrapper kicks in

/**
 * CoffeeScript Compiler v1.2.0
 * http://coffeescript.org
 *
 * Copyright 2011, Jeremy Ashkenas
 * Released under the MIT License
 */
(function(root) {
  var CoffeeScript = function() {
    function require(path){ return require[path]; }
    require['./helpers'] = new function() {
  var exports = this;
  (function() {
  var extend, flatten;

  exports.starts = function(string, literal, start) {
    return literal === string.substr(start, literal.length);
  };

  exports.ends = function(string, literal, back) {
    var len;
    len = literal.length;
    return literal === string.substr(string.length - len - (back || 0), len);
  };

  exports.compact = function(array) {
    var item, _i, _len, _results;
    _results = [];
    for (_i = 0, _len = array.length; _i < _len; _i++) {
      item = array[_i];
      if (item) _results.push(item);
    }
    return _results;
  };

  exports.count = function(string, substr) {
    var num, pos;
    num = pos = 0;
    if (!substr.length) return 1 / 0;
    while (pos = 1 + string.indexOf(substr, pos)) {
      num++;
    }
    return num;
  };

  exports.merge = function(options, overrides) {
    return extend(extend({}, options), overrides);
  };

  extend = exports.extend = function(object, properties) {
    var key, val;
    for (key in properties) {
      val = properties[key];
      object[key] = val;
    }
    return object;
  };

  exports.flatten = flatten = function(array) {
    var element, flattened, _i, _len;
    flattened = [];
    for (_i = 0, _len = array.length; _i < _len; _i++) {
      element = array[_i];
      if (element instanceof Array) {
        flattened = flattened.concat(flatten(element));
      } else {
        flattened.push(element);
      }
    }
    return flattened;
  };

  exports.del = function(obj, key) {
    var val;
    val = obj[key];
    delete obj[key];
    return val;
  };

  exports.last = function(array, back) {
    return array[array.length - (back || 0) - 1];
  };

}).call(this);

};require['./rewriter'] = new function() {
  var exports = this;
  (function() {
  var BALANCED_PAIRS, EXPRESSION_CLOSE, EXPRESSION_END, EXPRESSION_START, IMPLICIT_BLOCK, IMPLICIT_CALL, IMPLICIT_END, IMPLICIT_FUNC, IMPLICIT_UNSPACED_CALL, INVERSES, LINEBREAKS, SINGLE_CLOSERS, SINGLE_LINERS, left, rite, _i, _len, _ref,
    __indexOf = Array.prototype.indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; },
    __slice = Array.prototype.slice;

  exports.Rewriter = (function() {

    function Rewriter() {}

    Rewriter.prototype.rewrite = function(tokens) {
      this.tokens = tokens;
      this.removeLeadingNewlines();
      this.removeMidExpressionNewlines();
      this.closeOpenCalls();
      this.closeOpenIndexes();
      this.addImplicitIndentation();
      this.tagPostfixConditionals();
      this.addImplicitBraces();
      this.addImplicitParentheses();
      return this.tokens;
    };

    Rewriter.prototype.scanTokens = function(block) {
      var i, token, tokens;
      tokens = this.tokens;
      i = 0;
      while (token = tokens[i]) {
        i += block.call(this, token, i, tokens);
      }
      return true;
    };

    Rewriter.prototype.detectEnd = function(i, condition, action) {
      var levels, token, tokens, _ref, _ref2;
      tokens = this.tokens;
      levels = 0;
      while (token = tokens[i]) {
        if (levels === 0 && condition.call(this, token, i)) {
          return action.call(this, token, i);
        }
        if (!token || levels < 0) return action.call(this, token, i - 1);
        if (_ref = token[0], __indexOf.call(EXPRESSION_START, _ref) >= 0) {
          levels += 1;
        } else if (_ref2 = token[0], __indexOf.call(EXPRESSION_END, _ref2) >= 0) {
          levels -= 1;
        }
        i += 1;
      }
      return i - 1;
    };

    Rewriter.prototype.removeLeadingNewlines = function() {
      var i, tag, _len, _ref;
      _ref = this.tokens;
      for (i = 0, _len = _ref.length; i < _len; i++) {
        tag = _ref[i][0];
        if (tag !== 'TERMINATOR') break;
      }
      if (i) return this.tokens.splice(0, i);
    };

    Rewriter.prototype.removeMidExpressionNewlines = function() {
      return this.scanTokens(function(token, i, tokens) {
        var _ref;
        if (!(token[0] === 'TERMINATOR' && (_ref = this.tag(i + 1), __indexOf.call(EXPRESSION_CLOSE, _ref) >= 0))) {
          return 1;
        }
        tokens.splice(i, 1);
        return 0;
      });
    };

    Rewriter.prototype.closeOpenCalls = function() {
      var action, condition;
      condition = function(token, i) {
        var _ref;
        return ((_ref = token[0]) === ')' || _ref === 'CALL_END') || token[0] === 'OUTDENT' && this.tag(i - 1) === ')';
      };
      action = function(token, i) {
        return this.tokens[token[0] === 'OUTDENT' ? i - 1 : i][0] = 'CALL_END';
      };
      return this.scanTokens(function(token, i) {
        if (token[0] === 'CALL_START') this.detectEnd(i + 1, condition, action);
        return 1;
      });
    };

    Rewriter.prototype.closeOpenIndexes = function() {
      var action, condition;
      condition = function(token, i) {
        var _ref;
        return (_ref = token[0]) === ']' || _ref === 'INDEX_END';
      };
      action = function(token, i) {
        return token[0] = 'INDEX_END';
      };
      return this.scanTokens(function(token, i) {
        if (token[0] === 'INDEX_START') this.detectEnd(i + 1, condition, action);
        return 1;
      });
    };

    Rewriter.prototype.addImplicitBraces = function() {
      var action, condition, sameLine, stack, start, startIndent, startsLine;
      stack = [];
      start = null;
      startsLine = null;
      sameLine = true;
      startIndent = 0;
      condition = function(token, i) {
        var one, tag, three, two, _ref, _ref2;
        _ref = this.tokens.slice(i + 1, (i + 3) + 1 || 9e9), one = _ref[0], two = _ref[1], three = _ref[2];
        if ('HERECOMMENT' === (one != null ? one[0] : void 0)) return false;
        tag = token[0];
        if (__indexOf.call(LINEBREAKS, tag) >= 0) sameLine = false;
        return (((tag === 'TERMINATOR' || tag === 'OUTDENT') || (__indexOf.call(IMPLICIT_END, tag) >= 0 && sameLine)) && ((!startsLine && this.tag(i - 1) !== ',') || !((two != null ? two[0] : void 0) === ':' || (one != null ? one[0] : void 0) === '@' && (three != null ? three[0] : void 0) === ':'))) || (tag === ',' && one && ((_ref2 = one[0]) !== 'IDENTIFIER' && _ref2 !== 'NUMBER' && _ref2 !== 'STRING' && _ref2 !== '@' && _ref2 !== 'TERMINATOR' && _ref2 !== 'OUTDENT'));
      };
      action = function(token, i) {
        var tok;
        tok = ['}', '}', token[2]];
        tok.generated = true;
        return this.tokens.splice(i, 0, tok);
      };
      return this.scanTokens(function(token, i, tokens) {
        var ago, idx, prevTag, tag, tok, value, _ref, _ref2;
        if (_ref = (tag = token[0]), __indexOf.call(EXPRESSION_START, _ref) >= 0) {
          stack.push([(tag === 'INDENT' && this.tag(i - 1) === '{' ? '{' : tag), i]);
          return 1;
        }
        if (__indexOf.call(EXPRESSION_END, tag) >= 0) {
          start = stack.pop();
          return 1;
        }
        if (!(tag === ':' && ((ago = this.tag(i - 2)) === ':' || ((_ref2 = stack[stack.length - 1]) != null ? _ref2[0] : void 0) !== '{'))) {
          return 1;
        }
        sameLine = true;
        stack.push(['{']);
        idx = ago === '@' ? i - 2 : i - 1;
        while (this.tag(idx - 2) === 'HERECOMMENT') {
          idx -= 2;
        }
        prevTag = this.tag(idx - 1);
        startsLine = !prevTag || (__indexOf.call(LINEBREAKS, prevTag) >= 0);
        value = new String('{');
        value.generated = true;
        tok = ['{', value, token[2]];
        tok.generated = true;
        tokens.splice(idx, 0, tok);
        this.detectEnd(i + 2, condition, action);
        return 2;
      });
    };

    Rewriter.prototype.addImplicitParentheses = function() {
      var action, condition, noCall, seenControl, seenSingle;
      noCall = seenSingle = seenControl = false;
      condition = function(token, i) {
        var post, tag, _ref, _ref2;
        tag = token[0];
        if (!seenSingle && token.fromThen) return true;
        if (tag === 'IF' || tag === 'ELSE' || tag === 'CATCH' || tag === '->' || tag === '=>' || tag === 'CLASS') {
          seenSingle = true;
        }
        if (tag === 'IF' || tag === 'ELSE' || tag === 'SWITCH' || tag === 'TRY' || tag === '=') {
          seenControl = true;
        }
        if ((tag === '.' || tag === '?.' || tag === '::') && this.tag(i - 1) === 'OUTDENT') {
          return true;
        }
        return !token.generated && this.tag(i - 1) !== ',' && (__indexOf.call(IMPLICIT_END, tag) >= 0 || (tag === 'INDENT' && !seenControl)) && (tag !== 'INDENT' || (((_ref = this.tag(i - 2)) !== 'CLASS' && _ref !== 'EXTENDS') && (_ref2 = this.tag(i - 1), __indexOf.call(IMPLICIT_BLOCK, _ref2) < 0) && !((post = this.tokens[i + 1]) && post.generated && post[0] === '{')));
      };
      action = function(token, i) {
        return this.tokens.splice(i, 0, ['CALL_END', ')', token[2]]);
      };
      return this.scanTokens(function(token, i, tokens) {
        var callObject, current, next, prev, tag, _ref, _ref2, _ref3;
        tag = token[0];
        if (tag === 'CLASS' || tag === 'IF') noCall = true;
        _ref = tokens.slice(i - 1, (i + 1) + 1 || 9e9), prev = _ref[0], current = _ref[1], next = _ref[2];
        callObject = !noCall && tag === 'INDENT' && next && next.generated && next[0] === '{' && prev && (_ref2 = prev[0], __indexOf.call(IMPLICIT_FUNC, _ref2) >= 0);
        seenSingle = false;
        seenControl = false;
        if (__indexOf.call(LINEBREAKS, tag) >= 0) noCall = false;
        if (prev && !prev.spaced && tag === '?') token.call = true;
        if (token.fromThen) return 1;
        if (!(callObject || (prev != null ? prev.spaced : void 0) && (prev.call || (_ref3 = prev[0], __indexOf.call(IMPLICIT_FUNC, _ref3) >= 0)) && (__indexOf.call(IMPLICIT_CALL, tag) >= 0 || !(token.spaced || token.newLine) && __indexOf.call(IMPLICIT_UNSPACED_CALL, tag) >= 0))) {
          return 1;
        }
        tokens.splice(i, 0, ['CALL_START', '(', token[2]]);
        this.detectEnd(i + 1, condition, action);
        if (prev[0] === '?') prev[0] = 'FUNC_EXIST';
        return 2;
      });
    };

    Rewriter.prototype.addImplicitIndentation = function() {
      var action, condition, indent, outdent, starter;
      starter = indent = outdent = null;
      condition = function(token, i) {
        var _ref;
        return token[1] !== ';' && (_ref = token[0], __indexOf.call(SINGLE_CLOSERS, _ref) >= 0) && !(token[0] === 'ELSE' && (starter !== 'IF' && starter !== 'THEN'));
      };
      action = function(token, i) {
        return this.tokens.splice((this.tag(i - 1) === ',' ? i - 1 : i), 0, outdent);
      };
      return this.scanTokens(function(token, i, tokens) {
        var tag, _ref, _ref2;
        tag = token[0];
        if (tag === 'TERMINATOR' && this.tag(i + 1) === 'THEN') {
          tokens.splice(i, 1);
          return 0;
        }
        if (tag === 'ELSE' && this.tag(i - 1) !== 'OUTDENT') {
          tokens.splice.apply(tokens, [i, 0].concat(__slice.call(this.indentation(token))));
          return 2;
        }
        if (tag === 'CATCH' && ((_ref = this.tag(i + 2)) === 'OUTDENT' || _ref === 'TERMINATOR' || _ref === 'FINALLY')) {
          tokens.splice.apply(tokens, [i + 2, 0].concat(__slice.call(this.indentation(token))));
          return 4;
        }
        if (__indexOf.call(SINGLE_LINERS, tag) >= 0 && this.tag(i + 1) !== 'INDENT' && !(tag === 'ELSE' && this.tag(i + 1) === 'IF')) {
          starter = tag;
          _ref2 = this.indentation(token), indent = _ref2[0], outdent = _ref2[1];
          if (starter === 'THEN') indent.fromThen = true;
          indent.generated = outdent.generated = true;
          tokens.splice(i + 1, 0, indent);
          this.detectEnd(i + 2, condition, action);
          if (tag === 'THEN') tokens.splice(i, 1);
          return 1;
        }
        return 1;
      });
    };

    Rewriter.prototype.tagPostfixConditionals = function() {
      var action, condition, original;
      original = null;
      condition = function(token, i) {
        var _ref;
        return (_ref = token[0]) === 'TERMINATOR' || _ref === 'INDENT';
      };
      action = function(token, i) {
        if (token[0] !== 'INDENT' || (token.generated && !token.fromThen)) {
          return original[0] = 'POST_' + original[0];
        }
      };
      return this.scanTokens(function(token, i) {
        if (token[0] !== 'IF') return 1;
        original = token;
        this.detectEnd(i + 1, condition, action);
        return 1;
      });
    };

    Rewriter.prototype.indentation = function(token) {
      return [['INDENT', 2, token[2]], ['OUTDENT', 2, token[2]]];
    };

    Rewriter.prototype.tag = function(i) {
      var _ref;
      return (_ref = this.tokens[i]) != null ? _ref[0] : void 0;
    };

    return Rewriter;

  })();

  BALANCED_PAIRS = [['(', ')'], ['[', ']'], ['{', '}'], ['INDENT', 'OUTDENT'], ['CALL_START', 'CALL_END'], ['PARAM_START', 'PARAM_END'], ['INDEX_START', 'INDEX_END']];

  exports.INVERSES = INVERSES = {};

  EXPRESSION_START = [];

  EXPRESSION_END = [];

  for (_i = 0, _len = BALANCED_PAIRS.length; _i < _len; _i++) {
    _ref = BALANCED_PAIRS[_i], left = _ref[0], rite = _ref[1];
    EXPRESSION_START.push(INVERSES[rite] = left);
    EXPRESSION_END.push(INVERSES[left] = rite);
  }

  EXPRESSION_CLOSE = ['CATCH', 'WHEN', 'ELSE', 'FINALLY'].concat(EXPRESSION_END);

  IMPLICIT_FUNC = ['IDENTIFIER', 'SUPER', ')', 'CALL_END', ']', 'INDEX_END', '@', 'THIS'];

  IMPLICIT_CALL = ['IDENTIFIER', 'NUMBER', 'STRING', 'JS', 'REGEX', 'NEW', 'PARAM_START', 'CLASS', 'IF', 'TRY', 'SWITCH', 'THIS', 'BOOL', 'UNARY', 'SUPER', '@', '->', '=>', '[', '(', '{', '--', '++'];

  IMPLICIT_UNSPACED_CALL = ['+', '-'];

  IMPLICIT_BLOCK = ['->', '=>', '{', '[', ','];

  IMPLICIT_END = ['POST_IF', 'FOR', 'WHILE', 'UNTIL', 'WHEN', 'BY', 'LOOP', 'TERMINATOR'];

  SINGLE_LINERS = ['ELSE', '->', '=>', 'TRY', 'FINALLY', 'THEN'];

  SINGLE_CLOSERS = ['TERMINATOR', 'CATCH', 'FINALLY', 'ELSE', 'OUTDENT', 'LEADING_WHEN'];

  LINEBREAKS = ['TERMINATOR', 'INDENT', 'OUTDENT'];

}).call(this);

};require['./lexer'] = new function() {
  var exports = this;
  (function() {
  var BOOL, CALLABLE, CODE, COFFEE_ALIASES, COFFEE_ALIAS_MAP, COFFEE_KEYWORDS, COMMENT, COMPARE, COMPOUND_ASSIGN, HEREDOC, HEREDOC_ILLEGAL, HEREDOC_INDENT, HEREGEX, HEREGEX_OMIT, IDENTIFIER, INDEXABLE, INVERSES, JSTOKEN, JS_FORBIDDEN, JS_KEYWORDS, LINE_BREAK, LINE_CONTINUER, LOGIC, Lexer, MATH, MULTILINER, MULTI_DENT, NOT_REGEX, NOT_SPACED_REGEX, NUMBER, OPERATOR, REGEX, RELATION, RESERVED, Rewriter, SHIFT, SIMPLESTR, TRAILING_SPACES, UNARY, WHITESPACE, compact, count, key, last, starts, _ref, _ref2,
    __indexOf = Array.prototype.indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  _ref = require('./rewriter'), Rewriter = _ref.Rewriter, INVERSES = _ref.INVERSES;

  _ref2 = require('./helpers'), count = _ref2.count, starts = _ref2.starts, compact = _ref2.compact, last = _ref2.last;

  exports.Lexer = Lexer = (function() {

    function Lexer() {}

    Lexer.prototype.tokenize = function(code, opts) {
      var i, tag;
      if (opts == null) opts = {};
      if (WHITESPACE.test(code)) code = "\n" + code;
      code = code.replace(/\r/g, '').replace(TRAILING_SPACES, '');
      this.code = code;
      this.line = opts.line || 0;
      this.indent = 0;
      this.indebt = 0;
      this.outdebt = 0;
      this.indents = [];
      this.ends = [];
      this.tokens = [];
      i = 0;
      while (this.chunk = code.slice(i)) {
        i += this.identifierToken() || this.commentToken() || this.whitespaceToken() || this.lineToken() || this.heredocToken() || this.stringToken() || this.numberToken() || this.regexToken() || this.jsToken() || this.literalToken();
      }
      this.closeIndentation();
      if (tag = this.ends.pop()) this.error("missing " + tag);
      if (opts.rewrite === false) return this.tokens;
      return (new Rewriter).rewrite(this.tokens);
    };

    Lexer.prototype.identifierToken = function() {
      var colon, forcedIdentifier, id, input, match, prev, tag, _ref3, _ref4;
      if (!(match = IDENTIFIER.exec(this.chunk))) return 0;
      input = match[0], id = match[1], colon = match[2];
      if (id === 'own' && this.tag() === 'FOR') {
        this.token('OWN', id);
        return id.length;
      }
      forcedIdentifier = colon || (prev = last(this.tokens)) && (((_ref3 = prev[0]) === '.' || _ref3 === '?.' || _ref3 === '::') || !prev.spaced && prev[0] === '@');
      tag = 'IDENTIFIER';
      if (!forcedIdentifier && (__indexOf.call(JS_KEYWORDS, id) >= 0 || __indexOf.call(COFFEE_KEYWORDS, id) >= 0)) {
        tag = id.toUpperCase();
        if (tag === 'WHEN' && (_ref4 = this.tag(), __indexOf.call(LINE_BREAK, _ref4) >= 0)) {
          tag = 'LEADING_WHEN';
        } else if (tag === 'FOR') {
          this.seenFor = true;
        } else if (tag === 'UNLESS') {
          tag = 'IF';
        } else if (__indexOf.call(UNARY, tag) >= 0) {
          tag = 'UNARY';
        } else if (__indexOf.call(RELATION, tag) >= 0) {
          if (tag !== 'INSTANCEOF' && this.seenFor) {
            tag = 'FOR' + tag;
            this.seenFor = false;
          } else {
            tag = 'RELATION';
            if (this.value() === '!') {
              this.tokens.pop();
              id = '!' + id;
            }
          }
        }
      }
      if (__indexOf.call(['eval', 'arguments'].concat(JS_FORBIDDEN), id) >= 0) {
        if (forcedIdentifier) {
          tag = 'IDENTIFIER';
          id = new String(id);
          id.reserved = true;
        } else if (__indexOf.call(RESERVED, id) >= 0) {
          this.error("reserved word \"" + id + "\"");
        }
      }
      if (!forcedIdentifier) {
        if (__indexOf.call(COFFEE_ALIASES, id) >= 0) id = COFFEE_ALIAS_MAP[id];
        tag = (function() {
          switch (id) {
            case '!':
              return 'UNARY';
            case '==':
            case '!=':
              return 'COMPARE';
            case '&&':
            case '||':
              return 'LOGIC';
            case 'true':
            case 'false':
            case 'null':
            case 'undefined':
              return 'BOOL';
            case 'break':
            case 'continue':
              return 'STATEMENT';
            default:
              return tag;
          }
        })();
      }
      this.token(tag, id);
      if (colon) this.token(':', ':');
      return input.length;
    };

    Lexer.prototype.numberToken = function() {
      var binaryLiteral, lexedLength, match, number;
      if (!(match = NUMBER.exec(this.chunk))) return 0;
      number = match[0];
      lexedLength = number.length;
      if (binaryLiteral = /0b([01]+)/.exec(number)) {
        number = (parseInt(binaryLiteral[1], 2)).toString();
      }
      this.token('NUMBER', number);
      return lexedLength;
    };

    Lexer.prototype.stringToken = function() {
      var match, string;
      switch (this.chunk.charAt(0)) {
        case "'":
          if (!(match = SIMPLESTR.exec(this.chunk))) return 0;
          this.token('STRING', (string = match[0]).replace(MULTILINER, '\\\n'));
          break;
        case '"':
          if (!(string = this.balancedString(this.chunk, '"'))) return 0;
          if (0 < string.indexOf('#{', 1)) {
            this.interpolateString(string.slice(1, -1));
          } else {
            this.token('STRING', this.escapeLines(string));
          }
          break;
        default:
          return 0;
      }
      this.line += count(string, '\n');
      return string.length;
    };

    Lexer.prototype.heredocToken = function() {
      var doc, heredoc, match, quote;
      if (!(match = HEREDOC.exec(this.chunk))) return 0;
      heredoc = match[0];
      quote = heredoc.charAt(0);
      doc = this.sanitizeHeredoc(match[2], {
        quote: quote,
        indent: null
      });
      if (quote === '"' && 0 <= doc.indexOf('#{')) {
        this.interpolateString(doc, {
          heredoc: true
        });
      } else {
        this.token('STRING', this.makeString(doc, quote, true));
      }
      this.line += count(heredoc, '\n');
      return heredoc.length;
    };

    Lexer.prototype.commentToken = function() {
      var comment, here, match;
      if (!(match = this.chunk.match(COMMENT))) return 0;
      comment = match[0], here = match[1];
      if (here) {
        this.token('HERECOMMENT', this.sanitizeHeredoc(here, {
          herecomment: true,
          indent: Array(this.indent + 1).join(' ')
        }));
        this.token('TERMINATOR', '\n');
      }
      this.line += count(comment, '\n');
      return comment.length;
    };

    Lexer.prototype.jsToken = function() {
      var match, script;
      if (!(this.chunk.charAt(0) === '`' && (match = JSTOKEN.exec(this.chunk)))) {
        return 0;
      }
      this.token('JS', (script = match[0]).slice(1, -1));
      return script.length;
    };

    Lexer.prototype.regexToken = function() {
      var flags, length, match, prev, regex, _ref3, _ref4;
      if (this.chunk.charAt(0) !== '/') return 0;
      if (match = HEREGEX.exec(this.chunk)) {
        length = this.heregexToken(match);
        this.line += count(match[0], '\n');
        return length;
      }
      prev = last(this.tokens);
      if (prev && (_ref3 = prev[0], __indexOf.call((prev.spaced ? NOT_REGEX : NOT_SPACED_REGEX), _ref3) >= 0)) {
        return 0;
      }
      if (!(match = REGEX.exec(this.chunk))) return 0;
      _ref4 = match, match = _ref4[0], regex = _ref4[1], flags = _ref4[2];
      if (regex.slice(0, 2) === '/*') {
        this.error('regular expressions cannot begin with `*`');
      }
      if (regex === '//') regex = '/(?:)/';
      this.token('REGEX', "" + regex + flags);
      return match.length;
    };

    Lexer.prototype.heregexToken = function(match) {
      var body, flags, heregex, re, tag, tokens, value, _i, _len, _ref3, _ref4, _ref5, _ref6;
      heregex = match[0], body = match[1], flags = match[2];
      if (0 > body.indexOf('#{')) {
        re = body.replace(HEREGEX_OMIT, '').replace(/\//g, '\\/');
        if (re.match(/^\*/)) {
          this.error('regular expressions cannot begin with `*`');
        }
        this.token('REGEX', "/" + (re || '(?:)') + "/" + flags);
        return heregex.length;
      }
      this.token('IDENTIFIER', 'RegExp');
      this.tokens.push(['CALL_START', '(']);
      tokens = [];
      _ref3 = this.interpolateString(body, {
        regex: true
      });
      for (_i = 0, _len = _ref3.length; _i < _len; _i++) {
        _ref4 = _ref3[_i], tag = _ref4[0], value = _ref4[1];
        if (tag === 'TOKENS') {
          tokens.push.apply(tokens, value);
        } else {
          if (!(value = value.replace(HEREGEX_OMIT, ''))) continue;
          value = value.replace(/\\/g, '\\\\');
          tokens.push(['STRING', this.makeString(value, '"', true)]);
        }
        tokens.push(['+', '+']);
      }
      tokens.pop();
      if (((_ref5 = tokens[0]) != null ? _ref5[0] : void 0) !== 'STRING') {
        this.tokens.push(['STRING', '""'], ['+', '+']);
      }
      (_ref6 = this.tokens).push.apply(_ref6, tokens);
      if (flags) this.tokens.push([',', ','], ['STRING', '"' + flags + '"']);
      this.token(')', ')');
      return heregex.length;
    };

    Lexer.prototype.lineToken = function() {
      var diff, indent, match, noNewlines, prev, size;
      if (!(match = MULTI_DENT.exec(this.chunk))) return 0;
      indent = match[0];
      this.line += count(indent, '\n');
      this.seenFor = false;
      prev = last(this.tokens, 1);
      size = indent.length - 1 - indent.lastIndexOf('\n');
      noNewlines = this.unfinished();
      if (size - this.indebt === this.indent) {
        if (noNewlines) {
          this.suppressNewlines();
        } else {
          this.newlineToken();
        }
        return indent.length;
      }
      if (size > this.indent) {
        if (noNewlines) {
          this.indebt = size - this.indent;
          this.suppressNewlines();
          return indent.length;
        }
        diff = size - this.indent + this.outdebt;
        this.token('INDENT', diff);
        this.indents.push(diff);
        this.ends.push('OUTDENT');
        this.outdebt = this.indebt = 0;
      } else {
        this.indebt = 0;
        this.outdentToken(this.indent - size, noNewlines);
      }
      this.indent = size;
      return indent.length;
    };

    Lexer.prototype.outdentToken = function(moveOut, noNewlines) {
      var dent, len;
      while (moveOut > 0) {
        len = this.indents.length - 1;
        if (this.indents[len] === void 0) {
          moveOut = 0;
        } else if (this.indents[len] === this.outdebt) {
          moveOut -= this.outdebt;
          this.outdebt = 0;
        } else if (this.indents[len] < this.outdebt) {
          this.outdebt -= this.indents[len];
          moveOut -= this.indents[len];
        } else {
          dent = this.indents.pop() - this.outdebt;
          moveOut -= dent;
          this.outdebt = 0;
          this.pair('OUTDENT');
          this.token('OUTDENT', dent);
        }
      }
      if (dent) this.outdebt -= moveOut;
      while (this.value() === ';') {
        this.tokens.pop();
      }
      if (!(this.tag() === 'TERMINATOR' || noNewlines)) {
        this.token('TERMINATOR', '\n');
      }
      return this;
    };

    Lexer.prototype.whitespaceToken = function() {
      var match, nline, prev;
      if (!((match = WHITESPACE.exec(this.chunk)) || (nline = this.chunk.charAt(0) === '\n'))) {
        return 0;
      }
      prev = last(this.tokens);
      if (prev) prev[match ? 'spaced' : 'newLine'] = true;
      if (match) {
        return match[0].length;
      } else {
        return 0;
      }
    };

    Lexer.prototype.newlineToken = function() {
      while (this.value() === ';') {
        this.tokens.pop();
      }
      if (this.tag() !== 'TERMINATOR') this.token('TERMINATOR', '\n');
      return this;
    };

    Lexer.prototype.suppressNewlines = function() {
      if (this.value() === '\\') this.tokens.pop();
      return this;
    };

    Lexer.prototype.literalToken = function() {
      var match, prev, tag, value, _ref3, _ref4, _ref5, _ref6;
      if (match = OPERATOR.exec(this.chunk)) {
        value = match[0];
        if (CODE.test(value)) this.tagParameters();
      } else {
        value = this.chunk.charAt(0);
      }
      tag = value;
      prev = last(this.tokens);
      if (value === '=' && prev) {
        if (!prev[1].reserved && (_ref3 = prev[1], __indexOf.call(JS_FORBIDDEN, _ref3) >= 0)) {
          this.error("reserved word \"" + (this.value()) + "\" can't be assigned");
        }
        if ((_ref4 = prev[1]) === '||' || _ref4 === '&&') {
          prev[0] = 'COMPOUND_ASSIGN';
          prev[1] += '=';
          return value.length;
        }
      }
      if (value === ';') {
        this.seenFor = false;
        tag = 'TERMINATOR';
      } else if (__indexOf.call(MATH, value) >= 0) {
        tag = 'MATH';
      } else if (__indexOf.call(COMPARE, value) >= 0) {
        tag = 'COMPARE';
      } else if (__indexOf.call(COMPOUND_ASSIGN, value) >= 0) {
        tag = 'COMPOUND_ASSIGN';
      } else if (__indexOf.call(UNARY, value) >= 0) {
        tag = 'UNARY';
      } else if (__indexOf.call(SHIFT, value) >= 0) {
        tag = 'SHIFT';
      } else if (__indexOf.call(LOGIC, value) >= 0 || value === '?' && (prev != null ? prev.spaced : void 0)) {
        tag = 'LOGIC';
      } else if (prev && !prev.spaced) {
        if (value === '(' && (_ref5 = prev[0], __indexOf.call(CALLABLE, _ref5) >= 0)) {
          if (prev[0] === '?') prev[0] = 'FUNC_EXIST';
          tag = 'CALL_START';
        } else if (value === '[' && (_ref6 = prev[0], __indexOf.call(INDEXABLE, _ref6) >= 0)) {
          tag = 'INDEX_START';
          switch (prev[0]) {
            case '?':
              prev[0] = 'INDEX_SOAK';
          }
        }
      }
      switch (value) {
        case '(':
        case '{':
        case '[':
          this.ends.push(INVERSES[value]);
          break;
        case ')':
        case '}':
        case ']':
          this.pair(value);
      }
      this.token(tag, value);
      return value.length;
    };

    Lexer.prototype.sanitizeHeredoc = function(doc, options) {
      var attempt, herecomment, indent, match, _ref3;
      indent = options.indent, herecomment = options.herecomment;
      if (herecomment) {
        if (HEREDOC_ILLEGAL.test(doc)) {
          this.error("block comment cannot contain \"*/\", starting");
        }
        if (doc.indexOf('\n') <= 0) return doc;
      } else {
        while (match = HEREDOC_INDENT.exec(doc)) {
          attempt = match[1];
          if (indent === null || (0 < (_ref3 = attempt.length) && _ref3 < indent.length)) {
            indent = attempt;
          }
        }
      }
      if (indent) doc = doc.replace(RegExp("\\n" + indent, "g"), '\n');
      if (!herecomment) doc = doc.replace(/^\n/, '');
      return doc;
    };

    Lexer.prototype.tagParameters = function() {
      var i, stack, tok, tokens;
      if (this.tag() !== ')') return this;
      stack = [];
      tokens = this.tokens;
      i = tokens.length;
      tokens[--i][0] = 'PARAM_END';
      while (tok = tokens[--i]) {
        switch (tok[0]) {
          case ')':
            stack.push(tok);
            break;
          case '(':
          case 'CALL_START':
            if (stack.length) {
              stack.pop();
            } else if (tok[0] === '(') {
              tok[0] = 'PARAM_START';
              return this;
            } else {
              return this;
            }
        }
      }
      return this;
    };

    Lexer.prototype.closeIndentation = function() {
      return this.outdentToken(this.indent);
    };

    Lexer.prototype.balancedString = function(str, end) {
      var i, letter, match, prev, stack, _ref3;
      stack = [end];
      for (i = 1, _ref3 = str.length; 1 <= _ref3 ? i < _ref3 : i > _ref3; 1 <= _ref3 ? i++ : i--) {
        switch (letter = str.charAt(i)) {
          case '\\':
            i++;
            continue;
          case end:
            stack.pop();
            if (!stack.length) return str.slice(0, i + 1);
            end = stack[stack.length - 1];
            continue;
        }
        if (end === '}' && (letter === '"' || letter === "'")) {
          stack.push(end = letter);
        } else if (end === '}' && letter === '/' && (match = HEREGEX.exec(str.slice(i)) || REGEX.exec(str.slice(i)))) {
          i += match[0].length - 1;
        } else if (end === '}' && letter === '{') {
          stack.push(end = '}');
        } else if (end === '"' && prev === '#' && letter === '{') {
          stack.push(end = '}');
        }
        prev = letter;
      }
      return this.error("missing " + (stack.pop()) + ", starting");
    };

    Lexer.prototype.interpolateString = function(str, options) {
      var expr, heredoc, i, inner, interpolated, len, letter, nested, pi, regex, tag, tokens, value, _len, _ref3, _ref4, _ref5;
      if (options == null) options = {};
      heredoc = options.heredoc, regex = options.regex;
      tokens = [];
      pi = 0;
      i = -1;
      while (letter = str.charAt(i += 1)) {
        if (letter === '\\') {
          i += 1;
          continue;
        }
        if (!(letter === '#' && str.charAt(i + 1) === '{' && (expr = this.balancedString(str.slice(i + 1), '}')))) {
          continue;
        }
        if (pi < i) tokens.push(['NEOSTRING', str.slice(pi, i)]);
        inner = expr.slice(1, -1);
        if (inner.length) {
          nested = new Lexer().tokenize(inner, {
            line: this.line,
            rewrite: false
          });
          nested.pop();
          if (((_ref3 = nested[0]) != null ? _ref3[0] : void 0) === 'TERMINATOR') {
            nested.shift();
          }
          if (len = nested.length) {
            if (len > 1) {
              nested.unshift(['(', '(', this.line]);
              nested.push([')', ')', this.line]);
            }
            tokens.push(['TOKENS', nested]);
          }
        }
        i += expr.length;
        pi = i + 1;
      }
      if ((i > pi && pi < str.length)) tokens.push(['NEOSTRING', str.slice(pi)]);
      if (regex) return tokens;
      if (!tokens.length) return this.token('STRING', '""');
      if (tokens[0][0] !== 'NEOSTRING') tokens.unshift(['', '']);
      if (interpolated = tokens.length > 1) this.token('(', '(');
      for (i = 0, _len = tokens.length; i < _len; i++) {
        _ref4 = tokens[i], tag = _ref4[0], value = _ref4[1];
        if (i) this.token('+', '+');
        if (tag === 'TOKENS') {
          (_ref5 = this.tokens).push.apply(_ref5, value);
        } else {
          this.token('STRING', this.makeString(value, '"', heredoc));
        }
      }
      if (interpolated) this.token(')', ')');
      return tokens;
    };

    Lexer.prototype.pair = function(tag) {
      var size, wanted;
      if (tag !== (wanted = last(this.ends))) {
        if ('OUTDENT' !== wanted) this.error("unmatched " + tag);
        this.indent -= size = last(this.indents);
        this.outdentToken(size, true);
        return this.pair(tag);
      }
      return this.ends.pop();
    };

    Lexer.prototype.token = function(tag, value) {
      return this.tokens.push([tag, value, this.line]);
    };

    Lexer.prototype.tag = function(index, tag) {
      var tok;
      return (tok = last(this.tokens, index)) && (tag ? tok[0] = tag : tok[0]);
    };

    Lexer.prototype.value = function(index, val) {
      var tok;
      return (tok = last(this.tokens, index)) && (val ? tok[1] = val : tok[1]);
    };

    Lexer.prototype.unfinished = function() {
      var _ref3;
      return LINE_CONTINUER.test(this.chunk) || ((_ref3 = this.tag()) === '\\' || _ref3 === '.' || _ref3 === '?.' || _ref3 === 'UNARY' || _ref3 === 'MATH' || _ref3 === '+' || _ref3 === '-' || _ref3 === 'SHIFT' || _ref3 === 'RELATION' || _ref3 === 'COMPARE' || _ref3 === 'LOGIC' || _ref3 === 'COMPOUND_ASSIGN' || _ref3 === 'THROW' || _ref3 === 'EXTENDS');
    };

    Lexer.prototype.escapeLines = function(str, heredoc) {
      return str.replace(MULTILINER, heredoc ? '\\n' : '');
    };

    Lexer.prototype.makeString = function(body, quote, heredoc) {
      if (!body) return quote + quote;
      body = body.replace(/\\([\s\S])/g, function(match, contents) {
        if (contents === '\n' || contents === quote) {
          return contents;
        } else {
          return match;
        }
      });
      body = body.replace(RegExp("" + quote, "g"), '\\$&');
      return quote + this.escapeLines(body, heredoc) + quote;
    };

    Lexer.prototype.error = function(message) {
      throw SyntaxError("" + message + " on line " + (this.line + 1));
    };

    return Lexer;

  })();

  JS_KEYWORDS = ['true', 'false', 'null', 'this', 'new', 'delete', 'typeof', 'in', 'instanceof', 'return', 'throw', 'break', 'continue', 'debugger', 'if', 'else', 'switch', 'for', 'while', 'do', 'try', 'catch', 'finally', 'class', 'extends', 'super'];

  COFFEE_KEYWORDS = ['undefined', 'then', 'unless', 'until', 'loop', 'of', 'by', 'when'];

  COFFEE_ALIAS_MAP = {
    and: '&&',
    or: '||',
    is: '==',
    isnt: '!=',
    not: '!',
    yes: 'true',
    no: 'false',
    on: 'true',
    off: 'false'
  };

  COFFEE_ALIASES = (function() {
    var _results;
    _results = [];
    for (key in COFFEE_ALIAS_MAP) {
      _results.push(key);
    }
    return _results;
  })();

  COFFEE_KEYWORDS = COFFEE_KEYWORDS.concat(COFFEE_ALIASES);

  RESERVED = ['case', 'default', 'function', 'var', 'void', 'with', 'const', 'let', 'enum', 'export', 'import', 'native', '__hasProp', '__extends', '__slice', '__bind', '__indexOf'];

  JS_FORBIDDEN = JS_KEYWORDS.concat(RESERVED);

  exports.RESERVED = RESERVED.concat(JS_KEYWORDS).concat(COFFEE_KEYWORDS);

  IDENTIFIER = /^([$A-Za-z_\x7f-\uffff][$\w\x7f-\uffff]*)([^\n\S]*:(?!:))?/;

  NUMBER = /^0x[\da-f]+|^0b[01]+|^\d*\.?\d+(?:e[+-]?\d+)?/i;

  HEREDOC = /^("""|''')([\s\S]*?)(?:\n[^\n\S]*)?\1/;

  OPERATOR = /^(?:[-=]>|[-+*\/%<>&|^!?=]=|>>>=?|([-+:])\1|([&|<>])\2=?|\?\.|\.{2,3})/;

  WHITESPACE = /^[^\n\S]+/;

  COMMENT = /^###([^#][\s\S]*?)(?:###[^\n\S]*|(?:###)?$)|^(?:\s*#(?!##[^#]).*)+/;

  CODE = /^[-=]>/;

  MULTI_DENT = /^(?:\n[^\n\S]*)+/;

  SIMPLESTR = /^'[^\\']*(?:\\.[^\\']*)*'/;

  JSTOKEN = /^`[^\\`]*(?:\\.[^\\`]*)*`/;

  REGEX = /^(\/(?![\s=])[^[\/\n\\]*(?:(?:\\[\s\S]|\[[^\]\n\\]*(?:\\[\s\S][^\]\n\\]*)*])[^[\/\n\\]*)*\/)([imgy]{0,4})(?!\w)/;

  HEREGEX = /^\/{3}([\s\S]+?)\/{3}([imgy]{0,4})(?!\w)/;

  HEREGEX_OMIT = /\s+(?:#.*)?/g;

  MULTILINER = /\n/g;

  HEREDOC_INDENT = /\n+([^\n\S]*)/g;

  HEREDOC_ILLEGAL = /\*\//;

  LINE_CONTINUER = /^\s*(?:,|\??\.(?![.\d])|::)/;

  TRAILING_SPACES = /\s+$/;

  COMPOUND_ASSIGN = ['-=', '+=', '/=', '*=', '%=', '||=', '&&=', '?=', '<<=', '>>=', '>>>=', '&=', '^=', '|='];

  UNARY = ['!', '~', 'NEW', 'TYPEOF', 'DELETE', 'DO'];

  LOGIC = ['&&', '||', '&', '|', '^'];

  SHIFT = ['<<', '>>', '>>>'];

  COMPARE = ['==', '!=', '<', '>', '<=', '>='];

  MATH = ['*', '/', '%'];

  RELATION = ['IN', 'OF', 'INSTANCEOF'];

  BOOL = ['TRUE', 'FALSE', 'NULL', 'UNDEFINED'];

  NOT_REGEX = ['NUMBER', 'REGEX', 'BOOL', '++', '--', ']'];

  NOT_SPACED_REGEX = NOT_REGEX.concat(')', '}', 'THIS', 'IDENTIFIER', 'STRING');

  CALLABLE = ['IDENTIFIER', 'STRING', 'REGEX', ')', ']', '}', '?', '::', '@', 'THIS', 'SUPER'];

  INDEXABLE = CALLABLE.concat('NUMBER', 'BOOL');

  LINE_BREAK = ['INDENT', 'OUTDENT', 'TERMINATOR'];

}).call(this);

};require['./parser'] = new function() {
  var exports = this;
  /* Jison generated parser */
var parser = (function(){
var parser = {trace: function trace() { },
yy: {},
symbols_: {"error":2,"Root":3,"Body":4,"Block":5,"TERMINATOR":6,"Line":7,"Expression":8,"Statement":9,"Return":10,"Comment":11,"STATEMENT":12,"Value":13,"Invocation":14,"Code":15,"Operation":16,"Assign":17,"If":18,"Try":19,"While":20,"For":21,"Switch":22,"Class":23,"Throw":24,"INDENT":25,"OUTDENT":26,"Identifier":27,"IDENTIFIER":28,"AlphaNumeric":29,"NUMBER":30,"STRING":31,"Literal":32,"JS":33,"REGEX":34,"DEBUGGER":35,"BOOL":36,"Assignable":37,"=":38,"AssignObj":39,"ObjAssignable":40,":":41,"ThisProperty":42,"RETURN":43,"HERECOMMENT":44,"PARAM_START":45,"ParamList":46,"PARAM_END":47,"FuncGlyph":48,"->":49,"=>":50,"OptComma":51,",":52,"Param":53,"ParamVar":54,"...":55,"Array":56,"Object":57,"Splat":58,"SimpleAssignable":59,"Accessor":60,"Parenthetical":61,"Range":62,"This":63,".":64,"?.":65,"::":66,"Index":67,"INDEX_START":68,"IndexValue":69,"INDEX_END":70,"INDEX_SOAK":71,"Slice":72,"{":73,"AssignList":74,"}":75,"CLASS":76,"EXTENDS":77,"OptFuncExist":78,"Arguments":79,"SUPER":80,"FUNC_EXIST":81,"CALL_START":82,"CALL_END":83,"ArgList":84,"THIS":85,"@":86,"[":87,"]":88,"RangeDots":89,"..":90,"Arg":91,"SimpleArgs":92,"TRY":93,"Catch":94,"FINALLY":95,"CATCH":96,"THROW":97,"(":98,")":99,"WhileSource":100,"WHILE":101,"WHEN":102,"UNTIL":103,"Loop":104,"LOOP":105,"ForBody":106,"FOR":107,"ForStart":108,"ForSource":109,"ForVariables":110,"OWN":111,"ForValue":112,"FORIN":113,"FOROF":114,"BY":115,"SWITCH":116,"Whens":117,"ELSE":118,"When":119,"LEADING_WHEN":120,"IfBlock":121,"IF":122,"POST_IF":123,"UNARY":124,"-":125,"+":126,"--":127,"++":128,"?":129,"MATH":130,"SHIFT":131,"COMPARE":132,"LOGIC":133,"RELATION":134,"COMPOUND_ASSIGN":135,"$accept":0,"$end":1},
terminals_: {2:"error",6:"TERMINATOR",12:"STATEMENT",25:"INDENT",26:"OUTDENT",28:"IDENTIFIER",30:"NUMBER",31:"STRING",33:"JS",34:"REGEX",35:"DEBUGGER",36:"BOOL",38:"=",41:":",43:"RETURN",44:"HERECOMMENT",45:"PARAM_START",47:"PARAM_END",49:"->",50:"=>",52:",",55:"...",64:".",65:"?.",66:"::",68:"INDEX_START",70:"INDEX_END",71:"INDEX_SOAK",73:"{",75:"}",76:"CLASS",77:"EXTENDS",80:"SUPER",81:"FUNC_EXIST",82:"CALL_START",83:"CALL_END",85:"THIS",86:"@",87:"[",88:"]",90:"..",93:"TRY",95:"FINALLY",96:"CATCH",97:"THROW",98:"(",99:")",101:"WHILE",102:"WHEN",103:"UNTIL",105:"LOOP",107:"FOR",111:"OWN",113:"FORIN",114:"FOROF",115:"BY",116:"SWITCH",118:"ELSE",120:"LEADING_WHEN",122:"IF",123:"POST_IF",124:"UNARY",125:"-",126:"+",127:"--",128:"++",129:"?",130:"MATH",131:"SHIFT",132:"COMPARE",133:"LOGIC",134:"RELATION",135:"COMPOUND_ASSIGN"},
productions_: [0,[3,0],[3,1],[3,2],[4,1],[4,3],[4,2],[7,1],[7,1],[9,1],[9,1],[9,1],[8,1],[8,1],[8,1],[8,1],[8,1],[8,1],[8,1],[8,1],[8,1],[8,1],[8,1],[8,1],[5,2],[5,3],[27,1],[29,1],[29,1],[32,1],[32,1],[32,1],[32,1],[32,1],[17,3],[17,4],[17,5],[39,1],[39,3],[39,5],[39,1],[40,1],[40,1],[40,1],[10,2],[10,1],[11,1],[15,5],[15,2],[48,1],[48,1],[51,0],[51,1],[46,0],[46,1],[46,3],[53,1],[53,2],[53,3],[54,1],[54,1],[54,1],[54,1],[58,2],[59,1],[59,2],[59,2],[59,1],[37,1],[37,1],[37,1],[13,1],[13,1],[13,1],[13,1],[13,1],[60,2],[60,2],[60,2],[60,1],[60,1],[67,3],[67,2],[69,1],[69,1],[57,4],[74,0],[74,1],[74,3],[74,4],[74,6],[23,1],[23,2],[23,3],[23,4],[23,2],[23,3],[23,4],[23,5],[14,3],[14,3],[14,1],[14,2],[78,0],[78,1],[79,2],[79,4],[63,1],[63,1],[42,2],[56,2],[56,4],[89,1],[89,1],[62,5],[72,3],[72,2],[72,2],[84,1],[84,3],[84,4],[84,4],[84,6],[91,1],[91,1],[92,1],[92,3],[19,2],[19,3],[19,4],[19,5],[94,3],[24,2],[61,3],[61,5],[100,2],[100,4],[100,2],[100,4],[20,2],[20,2],[20,2],[20,1],[104,2],[104,2],[21,2],[21,2],[21,2],[106,2],[106,2],[108,2],[108,3],[112,1],[112,1],[112,1],[110,1],[110,3],[109,2],[109,2],[109,4],[109,4],[109,4],[109,6],[109,6],[22,5],[22,7],[22,4],[22,6],[117,1],[117,2],[119,3],[119,4],[121,3],[121,5],[18,1],[18,3],[18,3],[18,3],[16,2],[16,2],[16,2],[16,2],[16,2],[16,2],[16,2],[16,2],[16,3],[16,3],[16,3],[16,3],[16,3],[16,3],[16,3],[16,3],[16,5],[16,3]],
performAction: function anonymous(yytext,yyleng,yylineno,yy,yystate,$$,_$) {

var $0 = $$.length - 1;
switch (yystate) {
case 1:return this.$ = new yy.Block;
break;
case 2:return this.$ = $$[$0];
break;
case 3:return this.$ = $$[$0-1];
break;
case 4:this.$ = yy.Block.wrap([$$[$0]]);
break;
case 5:this.$ = $$[$0-2].push($$[$0]);
break;
case 6:this.$ = $$[$0-1];
break;
case 7:this.$ = $$[$0];
break;
case 8:this.$ = $$[$0];
break;
case 9:this.$ = $$[$0];
break;
case 10:this.$ = $$[$0];
break;
case 11:this.$ = new yy.Literal($$[$0]);
break;
case 12:this.$ = $$[$0];
break;
case 13:this.$ = $$[$0];
break;
case 14:this.$ = $$[$0];
break;
case 15:this.$ = $$[$0];
break;
case 16:this.$ = $$[$0];
break;
case 17:this.$ = $$[$0];
break;
case 18:this.$ = $$[$0];
break;
case 19:this.$ = $$[$0];
break;
case 20:this.$ = $$[$0];
break;
case 21:this.$ = $$[$0];
break;
case 22:this.$ = $$[$0];
break;
case 23:this.$ = $$[$0];
break;
case 24:this.$ = new yy.Block;
break;
case 25:this.$ = $$[$0-1];
break;
case 26:this.$ = new yy.Literal($$[$0]);
break;
case 27:this.$ = new yy.Literal($$[$0]);
break;
case 28:this.$ = new yy.Literal($$[$0]);
break;
case 29:this.$ = $$[$0];
break;
case 30:this.$ = new yy.Literal($$[$0]);
break;
case 31:this.$ = new yy.Literal($$[$0]);
break;
case 32:this.$ = new yy.Literal($$[$0]);
break;
case 33:this.$ = (function () {
        var val;
        val = new yy.Literal($$[$0]);
        if ($$[$0] === 'undefined') val.isUndefined = true;
        return val;
      }());
break;
case 34:this.$ = new yy.Assign($$[$0-2], $$[$0]);
break;
case 35:this.$ = new yy.Assign($$[$0-3], $$[$0]);
break;
case 36:this.$ = new yy.Assign($$[$0-4], $$[$0-1]);
break;
case 37:this.$ = new yy.Value($$[$0]);
break;
case 38:this.$ = new yy.Assign(new yy.Value($$[$0-2]), $$[$0], 'object');
break;
case 39:this.$ = new yy.Assign(new yy.Value($$[$0-4]), $$[$0-1], 'object');
break;
case 40:this.$ = $$[$0];
break;
case 41:this.$ = $$[$0];
break;
case 42:this.$ = $$[$0];
break;
case 43:this.$ = $$[$0];
break;
case 44:this.$ = new yy.Return($$[$0]);
break;
case 45:this.$ = new yy.Return;
break;
case 46:this.$ = new yy.Comment($$[$0]);
break;
case 47:this.$ = new yy.Code($$[$0-3], $$[$0], $$[$0-1]);
break;
case 48:this.$ = new yy.Code([], $$[$0], $$[$0-1]);
break;
case 49:this.$ = 'func';
break;
case 50:this.$ = 'boundfunc';
break;
case 51:this.$ = $$[$0];
break;
case 52:this.$ = $$[$0];
break;
case 53:this.$ = [];
break;
case 54:this.$ = [$$[$0]];
break;
case 55:this.$ = $$[$0-2].concat($$[$0]);
break;
case 56:this.$ = new yy.Param($$[$0]);
break;
case 57:this.$ = new yy.Param($$[$0-1], null, true);
break;
case 58:this.$ = new yy.Param($$[$0-2], $$[$0]);
break;
case 59:this.$ = $$[$0];
break;
case 60:this.$ = $$[$0];
break;
case 61:this.$ = $$[$0];
break;
case 62:this.$ = $$[$0];
break;
case 63:this.$ = new yy.Splat($$[$0-1]);
break;
case 64:this.$ = new yy.Value($$[$0]);
break;
case 65:this.$ = $$[$0-1].add($$[$0]);
break;
case 66:this.$ = new yy.Value($$[$0-1], [].concat($$[$0]));
break;
case 67:this.$ = $$[$0];
break;
case 68:this.$ = $$[$0];
break;
case 69:this.$ = new yy.Value($$[$0]);
break;
case 70:this.$ = new yy.Value($$[$0]);
break;
case 71:this.$ = $$[$0];
break;
case 72:this.$ = new yy.Value($$[$0]);
break;
case 73:this.$ = new yy.Value($$[$0]);
break;
case 74:this.$ = new yy.Value($$[$0]);
break;
case 75:this.$ = $$[$0];
break;
case 76:this.$ = new yy.Access($$[$0]);
break;
case 77:this.$ = new yy.Access($$[$0], 'soak');
break;
case 78:this.$ = [new yy.Access(new yy.Literal('prototype')), new yy.Access($$[$0])];
break;
case 79:this.$ = new yy.Access(new yy.Literal('prototype'));
break;
case 80:this.$ = $$[$0];
break;
case 81:this.$ = $$[$0-1];
break;
case 82:this.$ = yy.extend($$[$0], {
          soak: true
        });
break;
case 83:this.$ = new yy.Index($$[$0]);
break;
case 84:this.$ = new yy.Slice($$[$0]);
break;
case 85:this.$ = new yy.Obj($$[$0-2], $$[$0-3].generated);
break;
case 86:this.$ = [];
break;
case 87:this.$ = [$$[$0]];
break;
case 88:this.$ = $$[$0-2].concat($$[$0]);
break;
case 89:this.$ = $$[$0-3].concat($$[$0]);
break;
case 90:this.$ = $$[$0-5].concat($$[$0-2]);
break;
case 91:this.$ = new yy.Class;
break;
case 92:this.$ = new yy.Class(null, null, $$[$0]);
break;
case 93:this.$ = new yy.Class(null, $$[$0]);
break;
case 94:this.$ = new yy.Class(null, $$[$0-1], $$[$0]);
break;
case 95:this.$ = new yy.Class($$[$0]);
break;
case 96:this.$ = new yy.Class($$[$0-1], null, $$[$0]);
break;
case 97:this.$ = new yy.Class($$[$0-2], $$[$0]);
break;
case 98:this.$ = new yy.Class($$[$0-3], $$[$0-1], $$[$0]);
break;
case 99:this.$ = new yy.Call($$[$0-2], $$[$0], $$[$0-1]);
break;
case 100:this.$ = new yy.Call($$[$0-2], $$[$0], $$[$0-1]);
break;
case 101:this.$ = new yy.Call('super', [new yy.Splat(new yy.Literal('arguments'))]);
break;
case 102:this.$ = new yy.Call('super', $$[$0]);
break;
case 103:this.$ = false;
break;
case 104:this.$ = true;
break;
case 105:this.$ = [];
break;
case 106:this.$ = $$[$0-2];
break;
case 107:this.$ = new yy.Value(new yy.Literal('this'));
break;
case 108:this.$ = new yy.Value(new yy.Literal('this'));
break;
case 109:this.$ = new yy.Value(new yy.Literal('this'), [new yy.Access($$[$0])], 'this');
break;
case 110:this.$ = new yy.Arr([]);
break;
case 111:this.$ = new yy.Arr($$[$0-2]);
break;
case 112:this.$ = 'inclusive';
break;
case 113:this.$ = 'exclusive';
break;
case 114:this.$ = new yy.Range($$[$0-3], $$[$0-1], $$[$0-2]);
break;
case 115:this.$ = new yy.Range($$[$0-2], $$[$0], $$[$0-1]);
break;
case 116:this.$ = new yy.Range($$[$0-1], null, $$[$0]);
break;
case 117:this.$ = new yy.Range(null, $$[$0], $$[$0-1]);
break;
case 118:this.$ = [$$[$0]];
break;
case 119:this.$ = $$[$0-2].concat($$[$0]);
break;
case 120:this.$ = $$[$0-3].concat($$[$0]);
break;
case 121:this.$ = $$[$0-2];
break;
case 122:this.$ = $$[$0-5].concat($$[$0-2]);
break;
case 123:this.$ = $$[$0];
break;
case 124:this.$ = $$[$0];
break;
case 125:this.$ = $$[$0];
break;
case 126:this.$ = [].concat($$[$0-2], $$[$0]);
break;
case 127:this.$ = new yy.Try($$[$0]);
break;
case 128:this.$ = new yy.Try($$[$0-1], $$[$0][0], $$[$0][1]);
break;
case 129:this.$ = new yy.Try($$[$0-2], null, null, $$[$0]);
break;
case 130:this.$ = new yy.Try($$[$0-3], $$[$0-2][0], $$[$0-2][1], $$[$0]);
break;
case 131:this.$ = [$$[$0-1], $$[$0]];
break;
case 132:this.$ = new yy.Throw($$[$0]);
break;
case 133:this.$ = new yy.Parens($$[$0-1]);
break;
case 134:this.$ = new yy.Parens($$[$0-2]);
break;
case 135:this.$ = new yy.While($$[$0]);
break;
case 136:this.$ = new yy.While($$[$0-2], {
          guard: $$[$0]
        });
break;
case 137:this.$ = new yy.While($$[$0], {
          invert: true
        });
break;
case 138:this.$ = new yy.While($$[$0-2], {
          invert: true,
          guard: $$[$0]
        });
break;
case 139:this.$ = $$[$0-1].addBody($$[$0]);
break;
case 140:this.$ = $$[$0].addBody(yy.Block.wrap([$$[$0-1]]));
break;
case 141:this.$ = $$[$0].addBody(yy.Block.wrap([$$[$0-1]]));
break;
case 142:this.$ = $$[$0];
break;
case 143:this.$ = new yy.While(new yy.Literal('true')).addBody($$[$0]);
break;
case 144:this.$ = new yy.While(new yy.Literal('true')).addBody(yy.Block.wrap([$$[$0]]));
break;
case 145:this.$ = new yy.For($$[$0-1], $$[$0]);
break;
case 146:this.$ = new yy.For($$[$0-1], $$[$0]);
break;
case 147:this.$ = new yy.For($$[$0], $$[$0-1]);
break;
case 148:this.$ = {
          source: new yy.Value($$[$0])
        };
break;
case 149:this.$ = (function () {
        $$[$0].own = $$[$0-1].own;
        $$[$0].name = $$[$0-1][0];
        $$[$0].index = $$[$0-1][1];
        return $$[$0];
      }());
break;
case 150:this.$ = $$[$0];
break;
case 151:this.$ = (function () {
        $$[$0].own = true;
        return $$[$0];
      }());
break;
case 152:this.$ = $$[$0];
break;
case 153:this.$ = new yy.Value($$[$0]);
break;
case 154:this.$ = new yy.Value($$[$0]);
break;
case 155:this.$ = [$$[$0]];
break;
case 156:this.$ = [$$[$0-2], $$[$0]];
break;
case 157:this.$ = {
          source: $$[$0]
        };
break;
case 158:this.$ = {
          source: $$[$0],
          object: true
        };
break;
case 159:this.$ = {
          source: $$[$0-2],
          guard: $$[$0]
        };
break;
case 160:this.$ = {
          source: $$[$0-2],
          guard: $$[$0],
          object: true
        };
break;
case 161:this.$ = {
          source: $$[$0-2],
          step: $$[$0]
        };
break;
case 162:this.$ = {
          source: $$[$0-4],
          guard: $$[$0-2],
          step: $$[$0]
        };
break;
case 163:this.$ = {
          source: $$[$0-4],
          step: $$[$0-2],
          guard: $$[$0]
        };
break;
case 164:this.$ = new yy.Switch($$[$0-3], $$[$0-1]);
break;
case 165:this.$ = new yy.Switch($$[$0-5], $$[$0-3], $$[$0-1]);
break;
case 166:this.$ = new yy.Switch(null, $$[$0-1]);
break;
case 167:this.$ = new yy.Switch(null, $$[$0-3], $$[$0-1]);
break;
case 168:this.$ = $$[$0];
break;
case 169:this.$ = $$[$0-1].concat($$[$0]);
break;
case 170:this.$ = [[$$[$0-1], $$[$0]]];
break;
case 171:this.$ = [[$$[$0-2], $$[$0-1]]];
break;
case 172:this.$ = new yy.If($$[$0-1], $$[$0], {
          type: $$[$0-2]
        });
break;
case 173:this.$ = $$[$0-4].addElse(new yy.If($$[$0-1], $$[$0], {
          type: $$[$0-2]
        }));
break;
case 174:this.$ = $$[$0];
break;
case 175:this.$ = $$[$0-2].addElse($$[$0]);
break;
case 176:this.$ = new yy.If($$[$0], yy.Block.wrap([$$[$0-2]]), {
          type: $$[$0-1],
          statement: true
        });
break;
case 177:this.$ = new yy.If($$[$0], yy.Block.wrap([$$[$0-2]]), {
          type: $$[$0-1],
          statement: true
        });
break;
case 178:this.$ = new yy.Op($$[$0-1], $$[$0]);
break;
case 179:this.$ = new yy.Op('-', $$[$0]);
break;
case 180:this.$ = new yy.Op('+', $$[$0]);
break;
case 181:this.$ = new yy.Op('--', $$[$0]);
break;
case 182:this.$ = new yy.Op('++', $$[$0]);
break;
case 183:this.$ = new yy.Op('--', $$[$0-1], null, true);
break;
case 184:this.$ = new yy.Op('++', $$[$0-1], null, true);
break;
case 185:this.$ = new yy.Existence($$[$0-1]);
break;
case 186:this.$ = new yy.Op('+', $$[$0-2], $$[$0]);
break;
case 187:this.$ = new yy.Op('-', $$[$0-2], $$[$0]);
break;
case 188:this.$ = new yy.Op($$[$0-1], $$[$0-2], $$[$0]);
break;
case 189:this.$ = new yy.Op($$[$0-1], $$[$0-2], $$[$0]);
break;
case 190:this.$ = new yy.Op($$[$0-1], $$[$0-2], $$[$0]);
break;
case 191:this.$ = new yy.Op($$[$0-1], $$[$0-2], $$[$0]);
break;
case 192:this.$ = (function () {
        if ($$[$0-1].charAt(0) === '!') {
          return new yy.Op($$[$0-1].slice(1), $$[$0-2], $$[$0]).invert();
        } else {
          return new yy.Op($$[$0-1], $$[$0-2], $$[$0]);
        }
      }());
break;
case 193:this.$ = new yy.Assign($$[$0-2], $$[$0], $$[$0-1]);
break;
case 194:this.$ = new yy.Assign($$[$0-4], $$[$0-1], $$[$0-3]);
break;
case 195:this.$ = new yy.Extends($$[$0-2], $$[$0]);
break;
}
},
table: [{1:[2,1],3:1,4:2,5:3,7:4,8:6,9:7,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,25:[1,5],27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{1:[3]},{1:[2,2],6:[1,72]},{6:[1,73]},{1:[2,4],6:[2,4],26:[2,4],99:[2,4]},{4:75,7:4,8:6,9:7,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,26:[1,74],27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{1:[2,7],6:[2,7],26:[2,7],99:[2,7],100:85,101:[1,63],103:[1,64],106:86,107:[1,66],108:67,123:[1,84],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[1,80],132:[1,81],133:[1,82],134:[1,83]},{1:[2,8],6:[2,8],26:[2,8],99:[2,8],100:88,101:[1,63],103:[1,64],106:89,107:[1,66],108:67,123:[1,87]},{1:[2,12],6:[2,12],25:[2,12],26:[2,12],47:[2,12],52:[2,12],55:[2,12],60:91,64:[1,93],65:[1,94],66:[1,95],67:96,68:[1,97],70:[2,12],71:[1,98],75:[2,12],78:90,81:[1,92],82:[2,103],83:[2,12],88:[2,12],90:[2,12],99:[2,12],101:[2,12],102:[2,12],103:[2,12],107:[2,12],115:[2,12],123:[2,12],125:[2,12],126:[2,12],129:[2,12],130:[2,12],131:[2,12],132:[2,12],133:[2,12],134:[2,12]},{1:[2,13],6:[2,13],25:[2,13],26:[2,13],47:[2,13],52:[2,13],55:[2,13],60:100,64:[1,93],65:[1,94],66:[1,95],67:96,68:[1,97],70:[2,13],71:[1,98],75:[2,13],78:99,81:[1,92],82:[2,103],83:[2,13],88:[2,13],90:[2,13],99:[2,13],101:[2,13],102:[2,13],103:[2,13],107:[2,13],115:[2,13],123:[2,13],125:[2,13],126:[2,13],129:[2,13],130:[2,13],131:[2,13],132:[2,13],133:[2,13],134:[2,13]},{1:[2,14],6:[2,14],25:[2,14],26:[2,14],47:[2,14],52:[2,14],55:[2,14],70:[2,14],75:[2,14],83:[2,14],88:[2,14],90:[2,14],99:[2,14],101:[2,14],102:[2,14],103:[2,14],107:[2,14],115:[2,14],123:[2,14],125:[2,14],126:[2,14],129:[2,14],130:[2,14],131:[2,14],132:[2,14],133:[2,14],134:[2,14]},{1:[2,15],6:[2,15],25:[2,15],26:[2,15],47:[2,15],52:[2,15],55:[2,15],70:[2,15],75:[2,15],83:[2,15],88:[2,15],90:[2,15],99:[2,15],101:[2,15],102:[2,15],103:[2,15],107:[2,15],115:[2,15],123:[2,15],125:[2,15],126:[2,15],129:[2,15],130:[2,15],131:[2,15],132:[2,15],133:[2,15],134:[2,15]},{1:[2,16],6:[2,16],25:[2,16],26:[2,16],47:[2,16],52:[2,16],55:[2,16],70:[2,16],75:[2,16],83:[2,16],88:[2,16],90:[2,16],99:[2,16],101:[2,16],102:[2,16],103:[2,16],107:[2,16],115:[2,16],123:[2,16],125:[2,16],126:[2,16],129:[2,16],130:[2,16],131:[2,16],132:[2,16],133:[2,16],134:[2,16]},{1:[2,17],6:[2,17],25:[2,17],26:[2,17],47:[2,17],52:[2,17],55:[2,17],70:[2,17],75:[2,17],83:[2,17],88:[2,17],90:[2,17],99:[2,17],101:[2,17],102:[2,17],103:[2,17],107:[2,17],115:[2,17],123:[2,17],125:[2,17],126:[2,17],129:[2,17],130:[2,17],131:[2,17],132:[2,17],133:[2,17],134:[2,17]},{1:[2,18],6:[2,18],25:[2,18],26:[2,18],47:[2,18],52:[2,18],55:[2,18],70:[2,18],75:[2,18],83:[2,18],88:[2,18],90:[2,18],99:[2,18],101:[2,18],102:[2,18],103:[2,18],107:[2,18],115:[2,18],123:[2,18],125:[2,18],126:[2,18],129:[2,18],130:[2,18],131:[2,18],132:[2,18],133:[2,18],134:[2,18]},{1:[2,19],6:[2,19],25:[2,19],26:[2,19],47:[2,19],52:[2,19],55:[2,19],70:[2,19],75:[2,19],83:[2,19],88:[2,19],90:[2,19],99:[2,19],101:[2,19],102:[2,19],103:[2,19],107:[2,19],115:[2,19],123:[2,19],125:[2,19],126:[2,19],129:[2,19],130:[2,19],131:[2,19],132:[2,19],133:[2,19],134:[2,19]},{1:[2,20],6:[2,20],25:[2,20],26:[2,20],47:[2,20],52:[2,20],55:[2,20],70:[2,20],75:[2,20],83:[2,20],88:[2,20],90:[2,20],99:[2,20],101:[2,20],102:[2,20],103:[2,20],107:[2,20],115:[2,20],123:[2,20],125:[2,20],126:[2,20],129:[2,20],130:[2,20],131:[2,20],132:[2,20],133:[2,20],134:[2,20]},{1:[2,21],6:[2,21],25:[2,21],26:[2,21],47:[2,21],52:[2,21],55:[2,21],70:[2,21],75:[2,21],83:[2,21],88:[2,21],90:[2,21],99:[2,21],101:[2,21],102:[2,21],103:[2,21],107:[2,21],115:[2,21],123:[2,21],125:[2,21],126:[2,21],129:[2,21],130:[2,21],131:[2,21],132:[2,21],133:[2,21],134:[2,21]},{1:[2,22],6:[2,22],25:[2,22],26:[2,22],47:[2,22],52:[2,22],55:[2,22],70:[2,22],75:[2,22],83:[2,22],88:[2,22],90:[2,22],99:[2,22],101:[2,22],102:[2,22],103:[2,22],107:[2,22],115:[2,22],123:[2,22],125:[2,22],126:[2,22],129:[2,22],130:[2,22],131:[2,22],132:[2,22],133:[2,22],134:[2,22]},{1:[2,23],6:[2,23],25:[2,23],26:[2,23],47:[2,23],52:[2,23],55:[2,23],70:[2,23],75:[2,23],83:[2,23],88:[2,23],90:[2,23],99:[2,23],101:[2,23],102:[2,23],103:[2,23],107:[2,23],115:[2,23],123:[2,23],125:[2,23],126:[2,23],129:[2,23],130:[2,23],131:[2,23],132:[2,23],133:[2,23],134:[2,23]},{1:[2,9],6:[2,9],26:[2,9],99:[2,9],101:[2,9],103:[2,9],107:[2,9],123:[2,9]},{1:[2,10],6:[2,10],26:[2,10],99:[2,10],101:[2,10],103:[2,10],107:[2,10],123:[2,10]},{1:[2,11],6:[2,11],26:[2,11],99:[2,11],101:[2,11],103:[2,11],107:[2,11],123:[2,11]},{1:[2,71],6:[2,71],25:[2,71],26:[2,71],38:[1,101],47:[2,71],52:[2,71],55:[2,71],64:[2,71],65:[2,71],66:[2,71],68:[2,71],70:[2,71],71:[2,71],75:[2,71],81:[2,71],82:[2,71],83:[2,71],88:[2,71],90:[2,71],99:[2,71],101:[2,71],102:[2,71],103:[2,71],107:[2,71],115:[2,71],123:[2,71],125:[2,71],126:[2,71],129:[2,71],130:[2,71],131:[2,71],132:[2,71],133:[2,71],134:[2,71]},{1:[2,72],6:[2,72],25:[2,72],26:[2,72],47:[2,72],52:[2,72],55:[2,72],64:[2,72],65:[2,72],66:[2,72],68:[2,72],70:[2,72],71:[2,72],75:[2,72],81:[2,72],82:[2,72],83:[2,72],88:[2,72],90:[2,72],99:[2,72],101:[2,72],102:[2,72],103:[2,72],107:[2,72],115:[2,72],123:[2,72],125:[2,72],126:[2,72],129:[2,72],130:[2,72],131:[2,72],132:[2,72],133:[2,72],134:[2,72]},{1:[2,73],6:[2,73],25:[2,73],26:[2,73],47:[2,73],52:[2,73],55:[2,73],64:[2,73],65:[2,73],66:[2,73],68:[2,73],70:[2,73],71:[2,73],75:[2,73],81:[2,73],82:[2,73],83:[2,73],88:[2,73],90:[2,73],99:[2,73],101:[2,73],102:[2,73],103:[2,73],107:[2,73],115:[2,73],123:[2,73],125:[2,73],126:[2,73],129:[2,73],130:[2,73],131:[2,73],132:[2,73],133:[2,73],134:[2,73]},{1:[2,74],6:[2,74],25:[2,74],26:[2,74],47:[2,74],52:[2,74],55:[2,74],64:[2,74],65:[2,74],66:[2,74],68:[2,74],70:[2,74],71:[2,74],75:[2,74],81:[2,74],82:[2,74],83:[2,74],88:[2,74],90:[2,74],99:[2,74],101:[2,74],102:[2,74],103:[2,74],107:[2,74],115:[2,74],123:[2,74],125:[2,74],126:[2,74],129:[2,74],130:[2,74],131:[2,74],132:[2,74],133:[2,74],134:[2,74]},{1:[2,75],6:[2,75],25:[2,75],26:[2,75],47:[2,75],52:[2,75],55:[2,75],64:[2,75],65:[2,75],66:[2,75],68:[2,75],70:[2,75],71:[2,75],75:[2,75],81:[2,75],82:[2,75],83:[2,75],88:[2,75],90:[2,75],99:[2,75],101:[2,75],102:[2,75],103:[2,75],107:[2,75],115:[2,75],123:[2,75],125:[2,75],126:[2,75],129:[2,75],130:[2,75],131:[2,75],132:[2,75],133:[2,75],134:[2,75]},{1:[2,101],6:[2,101],25:[2,101],26:[2,101],47:[2,101],52:[2,101],55:[2,101],64:[2,101],65:[2,101],66:[2,101],68:[2,101],70:[2,101],71:[2,101],75:[2,101],79:102,81:[2,101],82:[1,103],83:[2,101],88:[2,101],90:[2,101],99:[2,101],101:[2,101],102:[2,101],103:[2,101],107:[2,101],115:[2,101],123:[2,101],125:[2,101],126:[2,101],129:[2,101],130:[2,101],131:[2,101],132:[2,101],133:[2,101],134:[2,101]},{27:107,28:[1,71],42:108,46:104,47:[2,53],52:[2,53],53:105,54:106,56:109,57:110,73:[1,68],86:[1,111],87:[1,112]},{5:113,25:[1,5]},{8:114,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{8:116,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{8:117,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{13:119,14:120,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:121,42:61,56:47,57:48,59:118,61:25,62:26,63:27,73:[1,68],80:[1,28],85:[1,56],86:[1,57],87:[1,55],98:[1,54]},{13:119,14:120,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:121,42:61,56:47,57:48,59:122,61:25,62:26,63:27,73:[1,68],80:[1,28],85:[1,56],86:[1,57],87:[1,55],98:[1,54]},{1:[2,68],6:[2,68],25:[2,68],26:[2,68],38:[2,68],47:[2,68],52:[2,68],55:[2,68],64:[2,68],65:[2,68],66:[2,68],68:[2,68],70:[2,68],71:[2,68],75:[2,68],77:[1,126],81:[2,68],82:[2,68],83:[2,68],88:[2,68],90:[2,68],99:[2,68],101:[2,68],102:[2,68],103:[2,68],107:[2,68],115:[2,68],123:[2,68],125:[2,68],126:[2,68],127:[1,123],128:[1,124],129:[2,68],130:[2,68],131:[2,68],132:[2,68],133:[2,68],134:[2,68],135:[1,125]},{1:[2,174],6:[2,174],25:[2,174],26:[2,174],47:[2,174],52:[2,174],55:[2,174],70:[2,174],75:[2,174],83:[2,174],88:[2,174],90:[2,174],99:[2,174],101:[2,174],102:[2,174],103:[2,174],107:[2,174],115:[2,174],118:[1,127],123:[2,174],125:[2,174],126:[2,174],129:[2,174],130:[2,174],131:[2,174],132:[2,174],133:[2,174],134:[2,174]},{5:128,25:[1,5]},{5:129,25:[1,5]},{1:[2,142],6:[2,142],25:[2,142],26:[2,142],47:[2,142],52:[2,142],55:[2,142],70:[2,142],75:[2,142],83:[2,142],88:[2,142],90:[2,142],99:[2,142],101:[2,142],102:[2,142],103:[2,142],107:[2,142],115:[2,142],123:[2,142],125:[2,142],126:[2,142],129:[2,142],130:[2,142],131:[2,142],132:[2,142],133:[2,142],134:[2,142]},{5:130,25:[1,5]},{8:131,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,25:[1,132],27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{1:[2,91],5:133,6:[2,91],13:119,14:120,25:[1,5],26:[2,91],27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:121,42:61,47:[2,91],52:[2,91],55:[2,91],56:47,57:48,59:135,61:25,62:26,63:27,70:[2,91],73:[1,68],75:[2,91],77:[1,134],80:[1,28],83:[2,91],85:[1,56],86:[1,57],87:[1,55],88:[2,91],90:[2,91],98:[1,54],99:[2,91],101:[2,91],102:[2,91],103:[2,91],107:[2,91],115:[2,91],123:[2,91],125:[2,91],126:[2,91],129:[2,91],130:[2,91],131:[2,91],132:[2,91],133:[2,91],134:[2,91]},{8:136,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{1:[2,45],6:[2,45],8:137,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,26:[2,45],27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],99:[2,45],100:39,101:[2,45],103:[2,45],104:40,105:[1,65],106:41,107:[2,45],108:67,116:[1,42],121:37,122:[1,62],123:[2,45],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{1:[2,46],6:[2,46],25:[2,46],26:[2,46],52:[2,46],75:[2,46],99:[2,46],101:[2,46],103:[2,46],107:[2,46],123:[2,46]},{1:[2,69],6:[2,69],25:[2,69],26:[2,69],38:[2,69],47:[2,69],52:[2,69],55:[2,69],64:[2,69],65:[2,69],66:[2,69],68:[2,69],70:[2,69],71:[2,69],75:[2,69],81:[2,69],82:[2,69],83:[2,69],88:[2,69],90:[2,69],99:[2,69],101:[2,69],102:[2,69],103:[2,69],107:[2,69],115:[2,69],123:[2,69],125:[2,69],126:[2,69],129:[2,69],130:[2,69],131:[2,69],132:[2,69],133:[2,69],134:[2,69]},{1:[2,70],6:[2,70],25:[2,70],26:[2,70],38:[2,70],47:[2,70],52:[2,70],55:[2,70],64:[2,70],65:[2,70],66:[2,70],68:[2,70],70:[2,70],71:[2,70],75:[2,70],81:[2,70],82:[2,70],83:[2,70],88:[2,70],90:[2,70],99:[2,70],101:[2,70],102:[2,70],103:[2,70],107:[2,70],115:[2,70],123:[2,70],125:[2,70],126:[2,70],129:[2,70],130:[2,70],131:[2,70],132:[2,70],133:[2,70],134:[2,70]},{1:[2,29],6:[2,29],25:[2,29],26:[2,29],47:[2,29],52:[2,29],55:[2,29],64:[2,29],65:[2,29],66:[2,29],68:[2,29],70:[2,29],71:[2,29],75:[2,29],81:[2,29],82:[2,29],83:[2,29],88:[2,29],90:[2,29],99:[2,29],101:[2,29],102:[2,29],103:[2,29],107:[2,29],115:[2,29],123:[2,29],125:[2,29],126:[2,29],129:[2,29],130:[2,29],131:[2,29],132:[2,29],133:[2,29],134:[2,29]},{1:[2,30],6:[2,30],25:[2,30],26:[2,30],47:[2,30],52:[2,30],55:[2,30],64:[2,30],65:[2,30],66:[2,30],68:[2,30],70:[2,30],71:[2,30],75:[2,30],81:[2,30],82:[2,30],83:[2,30],88:[2,30],90:[2,30],99:[2,30],101:[2,30],102:[2,30],103:[2,30],107:[2,30],115:[2,30],123:[2,30],125:[2,30],126:[2,30],129:[2,30],130:[2,30],131:[2,30],132:[2,30],133:[2,30],134:[2,30]},{1:[2,31],6:[2,31],25:[2,31],26:[2,31],47:[2,31],52:[2,31],55:[2,31],64:[2,31],65:[2,31],66:[2,31],68:[2,31],70:[2,31],71:[2,31],75:[2,31],81:[2,31],82:[2,31],83:[2,31],88:[2,31],90:[2,31],99:[2,31],101:[2,31],102:[2,31],103:[2,31],107:[2,31],115:[2,31],123:[2,31],125:[2,31],126:[2,31],129:[2,31],130:[2,31],131:[2,31],132:[2,31],133:[2,31],134:[2,31]},{1:[2,32],6:[2,32],25:[2,32],26:[2,32],47:[2,32],52:[2,32],55:[2,32],64:[2,32],65:[2,32],66:[2,32],68:[2,32],70:[2,32],71:[2,32],75:[2,32],81:[2,32],82:[2,32],83:[2,32],88:[2,32],90:[2,32],99:[2,32],101:[2,32],102:[2,32],103:[2,32],107:[2,32],115:[2,32],123:[2,32],125:[2,32],126:[2,32],129:[2,32],130:[2,32],131:[2,32],132:[2,32],133:[2,32],134:[2,32]},{1:[2,33],6:[2,33],25:[2,33],26:[2,33],47:[2,33],52:[2,33],55:[2,33],64:[2,33],65:[2,33],66:[2,33],68:[2,33],70:[2,33],71:[2,33],75:[2,33],81:[2,33],82:[2,33],83:[2,33],88:[2,33],90:[2,33],99:[2,33],101:[2,33],102:[2,33],103:[2,33],107:[2,33],115:[2,33],123:[2,33],125:[2,33],126:[2,33],129:[2,33],130:[2,33],131:[2,33],132:[2,33],133:[2,33],134:[2,33]},{4:138,7:4,8:6,9:7,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,25:[1,139],27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{8:140,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,25:[1,144],27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,58:145,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],84:142,85:[1,56],86:[1,57],87:[1,55],88:[1,141],91:143,93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{1:[2,107],6:[2,107],25:[2,107],26:[2,107],47:[2,107],52:[2,107],55:[2,107],64:[2,107],65:[2,107],66:[2,107],68:[2,107],70:[2,107],71:[2,107],75:[2,107],81:[2,107],82:[2,107],83:[2,107],88:[2,107],90:[2,107],99:[2,107],101:[2,107],102:[2,107],103:[2,107],107:[2,107],115:[2,107],123:[2,107],125:[2,107],126:[2,107],129:[2,107],130:[2,107],131:[2,107],132:[2,107],133:[2,107],134:[2,107]},{1:[2,108],6:[2,108],25:[2,108],26:[2,108],27:146,28:[1,71],47:[2,108],52:[2,108],55:[2,108],64:[2,108],65:[2,108],66:[2,108],68:[2,108],70:[2,108],71:[2,108],75:[2,108],81:[2,108],82:[2,108],83:[2,108],88:[2,108],90:[2,108],99:[2,108],101:[2,108],102:[2,108],103:[2,108],107:[2,108],115:[2,108],123:[2,108],125:[2,108],126:[2,108],129:[2,108],130:[2,108],131:[2,108],132:[2,108],133:[2,108],134:[2,108]},{25:[2,49]},{25:[2,50]},{1:[2,64],6:[2,64],25:[2,64],26:[2,64],38:[2,64],47:[2,64],52:[2,64],55:[2,64],64:[2,64],65:[2,64],66:[2,64],68:[2,64],70:[2,64],71:[2,64],75:[2,64],77:[2,64],81:[2,64],82:[2,64],83:[2,64],88:[2,64],90:[2,64],99:[2,64],101:[2,64],102:[2,64],103:[2,64],107:[2,64],115:[2,64],123:[2,64],125:[2,64],126:[2,64],127:[2,64],128:[2,64],129:[2,64],130:[2,64],131:[2,64],132:[2,64],133:[2,64],134:[2,64],135:[2,64]},{1:[2,67],6:[2,67],25:[2,67],26:[2,67],38:[2,67],47:[2,67],52:[2,67],55:[2,67],64:[2,67],65:[2,67],66:[2,67],68:[2,67],70:[2,67],71:[2,67],75:[2,67],77:[2,67],81:[2,67],82:[2,67],83:[2,67],88:[2,67],90:[2,67],99:[2,67],101:[2,67],102:[2,67],103:[2,67],107:[2,67],115:[2,67],123:[2,67],125:[2,67],126:[2,67],127:[2,67],128:[2,67],129:[2,67],130:[2,67],131:[2,67],132:[2,67],133:[2,67],134:[2,67],135:[2,67]},{8:147,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{8:148,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{8:149,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{5:150,8:151,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,25:[1,5],27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{27:156,28:[1,71],56:157,57:158,62:152,73:[1,68],87:[1,55],110:153,111:[1,154],112:155},{109:159,113:[1,160],114:[1,161]},{6:[2,86],11:165,25:[2,86],27:166,28:[1,71],29:167,30:[1,69],31:[1,70],39:163,40:164,42:168,44:[1,46],52:[2,86],74:162,75:[2,86],86:[1,111]},{1:[2,27],6:[2,27],25:[2,27],26:[2,27],41:[2,27],47:[2,27],52:[2,27],55:[2,27],64:[2,27],65:[2,27],66:[2,27],68:[2,27],70:[2,27],71:[2,27],75:[2,27],81:[2,27],82:[2,27],83:[2,27],88:[2,27],90:[2,27],99:[2,27],101:[2,27],102:[2,27],103:[2,27],107:[2,27],115:[2,27],123:[2,27],125:[2,27],126:[2,27],129:[2,27],130:[2,27],131:[2,27],132:[2,27],133:[2,27],134:[2,27]},{1:[2,28],6:[2,28],25:[2,28],26:[2,28],41:[2,28],47:[2,28],52:[2,28],55:[2,28],64:[2,28],65:[2,28],66:[2,28],68:[2,28],70:[2,28],71:[2,28],75:[2,28],81:[2,28],82:[2,28],83:[2,28],88:[2,28],90:[2,28],99:[2,28],101:[2,28],102:[2,28],103:[2,28],107:[2,28],115:[2,28],123:[2,28],125:[2,28],126:[2,28],129:[2,28],130:[2,28],131:[2,28],132:[2,28],133:[2,28],134:[2,28]},{1:[2,26],6:[2,26],25:[2,26],26:[2,26],38:[2,26],41:[2,26],47:[2,26],52:[2,26],55:[2,26],64:[2,26],65:[2,26],66:[2,26],68:[2,26],70:[2,26],71:[2,26],75:[2,26],77:[2,26],81:[2,26],82:[2,26],83:[2,26],88:[2,26],90:[2,26],99:[2,26],101:[2,26],102:[2,26],103:[2,26],107:[2,26],113:[2,26],114:[2,26],115:[2,26],123:[2,26],125:[2,26],126:[2,26],127:[2,26],128:[2,26],129:[2,26],130:[2,26],131:[2,26],132:[2,26],133:[2,26],134:[2,26],135:[2,26]},{1:[2,6],6:[2,6],7:169,8:6,9:7,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,26:[2,6],27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],99:[2,6],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{1:[2,3]},{1:[2,24],6:[2,24],25:[2,24],26:[2,24],47:[2,24],52:[2,24],55:[2,24],70:[2,24],75:[2,24],83:[2,24],88:[2,24],90:[2,24],95:[2,24],96:[2,24],99:[2,24],101:[2,24],102:[2,24],103:[2,24],107:[2,24],115:[2,24],118:[2,24],120:[2,24],123:[2,24],125:[2,24],126:[2,24],129:[2,24],130:[2,24],131:[2,24],132:[2,24],133:[2,24],134:[2,24]},{6:[1,72],26:[1,170]},{1:[2,185],6:[2,185],25:[2,185],26:[2,185],47:[2,185],52:[2,185],55:[2,185],70:[2,185],75:[2,185],83:[2,185],88:[2,185],90:[2,185],99:[2,185],101:[2,185],102:[2,185],103:[2,185],107:[2,185],115:[2,185],123:[2,185],125:[2,185],126:[2,185],129:[2,185],130:[2,185],131:[2,185],132:[2,185],133:[2,185],134:[2,185]},{8:171,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{8:172,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{8:173,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{8:174,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{8:175,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{8:176,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{8:177,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{8:178,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{1:[2,141],6:[2,141],25:[2,141],26:[2,141],47:[2,141],52:[2,141],55:[2,141],70:[2,141],75:[2,141],83:[2,141],88:[2,141],90:[2,141],99:[2,141],101:[2,141],102:[2,141],103:[2,141],107:[2,141],115:[2,141],123:[2,141],125:[2,141],126:[2,141],129:[2,141],130:[2,141],131:[2,141],132:[2,141],133:[2,141],134:[2,141]},{1:[2,146],6:[2,146],25:[2,146],26:[2,146],47:[2,146],52:[2,146],55:[2,146],70:[2,146],75:[2,146],83:[2,146],88:[2,146],90:[2,146],99:[2,146],101:[2,146],102:[2,146],103:[2,146],107:[2,146],115:[2,146],123:[2,146],125:[2,146],126:[2,146],129:[2,146],130:[2,146],131:[2,146],132:[2,146],133:[2,146],134:[2,146]},{8:179,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{1:[2,140],6:[2,140],25:[2,140],26:[2,140],47:[2,140],52:[2,140],55:[2,140],70:[2,140],75:[2,140],83:[2,140],88:[2,140],90:[2,140],99:[2,140],101:[2,140],102:[2,140],103:[2,140],107:[2,140],115:[2,140],123:[2,140],125:[2,140],126:[2,140],129:[2,140],130:[2,140],131:[2,140],132:[2,140],133:[2,140],134:[2,140]},{1:[2,145],6:[2,145],25:[2,145],26:[2,145],47:[2,145],52:[2,145],55:[2,145],70:[2,145],75:[2,145],83:[2,145],88:[2,145],90:[2,145],99:[2,145],101:[2,145],102:[2,145],103:[2,145],107:[2,145],115:[2,145],123:[2,145],125:[2,145],126:[2,145],129:[2,145],130:[2,145],131:[2,145],132:[2,145],133:[2,145],134:[2,145]},{79:180,82:[1,103]},{1:[2,65],6:[2,65],25:[2,65],26:[2,65],38:[2,65],47:[2,65],52:[2,65],55:[2,65],64:[2,65],65:[2,65],66:[2,65],68:[2,65],70:[2,65],71:[2,65],75:[2,65],77:[2,65],81:[2,65],82:[2,65],83:[2,65],88:[2,65],90:[2,65],99:[2,65],101:[2,65],102:[2,65],103:[2,65],107:[2,65],115:[2,65],123:[2,65],125:[2,65],126:[2,65],127:[2,65],128:[2,65],129:[2,65],130:[2,65],131:[2,65],132:[2,65],133:[2,65],134:[2,65],135:[2,65]},{82:[2,104]},{27:181,28:[1,71]},{27:182,28:[1,71]},{1:[2,79],6:[2,79],25:[2,79],26:[2,79],27:183,28:[1,71],38:[2,79],47:[2,79],52:[2,79],55:[2,79],64:[2,79],65:[2,79],66:[2,79],68:[2,79],70:[2,79],71:[2,79],75:[2,79],77:[2,79],81:[2,79],82:[2,79],83:[2,79],88:[2,79],90:[2,79],99:[2,79],101:[2,79],102:[2,79],103:[2,79],107:[2,79],115:[2,79],123:[2,79],125:[2,79],126:[2,79],127:[2,79],128:[2,79],129:[2,79],130:[2,79],131:[2,79],132:[2,79],133:[2,79],134:[2,79],135:[2,79]},{1:[2,80],6:[2,80],25:[2,80],26:[2,80],38:[2,80],47:[2,80],52:[2,80],55:[2,80],64:[2,80],65:[2,80],66:[2,80],68:[2,80],70:[2,80],71:[2,80],75:[2,80],77:[2,80],81:[2,80],82:[2,80],83:[2,80],88:[2,80],90:[2,80],99:[2,80],101:[2,80],102:[2,80],103:[2,80],107:[2,80],115:[2,80],123:[2,80],125:[2,80],126:[2,80],127:[2,80],128:[2,80],129:[2,80],130:[2,80],131:[2,80],132:[2,80],133:[2,80],134:[2,80],135:[2,80]},{8:185,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],55:[1,189],56:47,57:48,59:36,61:25,62:26,63:27,69:184,72:186,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],89:187,90:[1,188],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{67:190,68:[1,97],71:[1,98]},{79:191,82:[1,103]},{1:[2,66],6:[2,66],25:[2,66],26:[2,66],38:[2,66],47:[2,66],52:[2,66],55:[2,66],64:[2,66],65:[2,66],66:[2,66],68:[2,66],70:[2,66],71:[2,66],75:[2,66],77:[2,66],81:[2,66],82:[2,66],83:[2,66],88:[2,66],90:[2,66],99:[2,66],101:[2,66],102:[2,66],103:[2,66],107:[2,66],115:[2,66],123:[2,66],125:[2,66],126:[2,66],127:[2,66],128:[2,66],129:[2,66],130:[2,66],131:[2,66],132:[2,66],133:[2,66],134:[2,66],135:[2,66]},{6:[1,193],8:192,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,25:[1,194],27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{1:[2,102],6:[2,102],25:[2,102],26:[2,102],47:[2,102],52:[2,102],55:[2,102],64:[2,102],65:[2,102],66:[2,102],68:[2,102],70:[2,102],71:[2,102],75:[2,102],81:[2,102],82:[2,102],83:[2,102],88:[2,102],90:[2,102],99:[2,102],101:[2,102],102:[2,102],103:[2,102],107:[2,102],115:[2,102],123:[2,102],125:[2,102],126:[2,102],129:[2,102],130:[2,102],131:[2,102],132:[2,102],133:[2,102],134:[2,102]},{8:197,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,25:[1,144],27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,58:145,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],83:[1,195],84:196,85:[1,56],86:[1,57],87:[1,55],91:143,93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{47:[1,198],52:[1,199]},{47:[2,54],52:[2,54]},{38:[1,201],47:[2,56],52:[2,56],55:[1,200]},{38:[2,59],47:[2,59],52:[2,59],55:[2,59]},{38:[2,60],47:[2,60],52:[2,60],55:[2,60]},{38:[2,61],47:[2,61],52:[2,61],55:[2,61]},{38:[2,62],47:[2,62],52:[2,62],55:[2,62]},{27:146,28:[1,71]},{8:197,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,25:[1,144],27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,58:145,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],84:142,85:[1,56],86:[1,57],87:[1,55],88:[1,141],91:143,93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{1:[2,48],6:[2,48],25:[2,48],26:[2,48],47:[2,48],52:[2,48],55:[2,48],70:[2,48],75:[2,48],83:[2,48],88:[2,48],90:[2,48],99:[2,48],101:[2,48],102:[2,48],103:[2,48],107:[2,48],115:[2,48],123:[2,48],125:[2,48],126:[2,48],129:[2,48],130:[2,48],131:[2,48],132:[2,48],133:[2,48],134:[2,48]},{1:[2,178],6:[2,178],25:[2,178],26:[2,178],47:[2,178],52:[2,178],55:[2,178],70:[2,178],75:[2,178],83:[2,178],88:[2,178],90:[2,178],99:[2,178],100:85,101:[2,178],102:[2,178],103:[2,178],106:86,107:[2,178],108:67,115:[2,178],123:[2,178],125:[2,178],126:[2,178],129:[1,76],130:[2,178],131:[2,178],132:[2,178],133:[2,178],134:[2,178]},{100:88,101:[1,63],103:[1,64],106:89,107:[1,66],108:67,123:[1,87]},{1:[2,179],6:[2,179],25:[2,179],26:[2,179],47:[2,179],52:[2,179],55:[2,179],70:[2,179],75:[2,179],83:[2,179],88:[2,179],90:[2,179],99:[2,179],100:85,101:[2,179],102:[2,179],103:[2,179],106:86,107:[2,179],108:67,115:[2,179],123:[2,179],125:[2,179],126:[2,179],129:[1,76],130:[2,179],131:[2,179],132:[2,179],133:[2,179],134:[2,179]},{1:[2,180],6:[2,180],25:[2,180],26:[2,180],47:[2,180],52:[2,180],55:[2,180],70:[2,180],75:[2,180],83:[2,180],88:[2,180],90:[2,180],99:[2,180],100:85,101:[2,180],102:[2,180],103:[2,180],106:86,107:[2,180],108:67,115:[2,180],123:[2,180],125:[2,180],126:[2,180],129:[1,76],130:[2,180],131:[2,180],132:[2,180],133:[2,180],134:[2,180]},{1:[2,181],6:[2,181],25:[2,181],26:[2,181],47:[2,181],52:[2,181],55:[2,181],64:[2,68],65:[2,68],66:[2,68],68:[2,68],70:[2,181],71:[2,68],75:[2,181],81:[2,68],82:[2,68],83:[2,181],88:[2,181],90:[2,181],99:[2,181],101:[2,181],102:[2,181],103:[2,181],107:[2,181],115:[2,181],123:[2,181],125:[2,181],126:[2,181],129:[2,181],130:[2,181],131:[2,181],132:[2,181],133:[2,181],134:[2,181]},{60:91,64:[1,93],65:[1,94],66:[1,95],67:96,68:[1,97],71:[1,98],78:90,81:[1,92],82:[2,103]},{60:100,64:[1,93],65:[1,94],66:[1,95],67:96,68:[1,97],71:[1,98],78:99,81:[1,92],82:[2,103]},{64:[2,71],65:[2,71],66:[2,71],68:[2,71],71:[2,71],81:[2,71],82:[2,71]},{1:[2,182],6:[2,182],25:[2,182],26:[2,182],47:[2,182],52:[2,182],55:[2,182],64:[2,68],65:[2,68],66:[2,68],68:[2,68],70:[2,182],71:[2,68],75:[2,182],81:[2,68],82:[2,68],83:[2,182],88:[2,182],90:[2,182],99:[2,182],101:[2,182],102:[2,182],103:[2,182],107:[2,182],115:[2,182],123:[2,182],125:[2,182],126:[2,182],129:[2,182],130:[2,182],131:[2,182],132:[2,182],133:[2,182],134:[2,182]},{1:[2,183],6:[2,183],25:[2,183],26:[2,183],47:[2,183],52:[2,183],55:[2,183],70:[2,183],75:[2,183],83:[2,183],88:[2,183],90:[2,183],99:[2,183],101:[2,183],102:[2,183],103:[2,183],107:[2,183],115:[2,183],123:[2,183],125:[2,183],126:[2,183],129:[2,183],130:[2,183],131:[2,183],132:[2,183],133:[2,183],134:[2,183]},{1:[2,184],6:[2,184],25:[2,184],26:[2,184],47:[2,184],52:[2,184],55:[2,184],70:[2,184],75:[2,184],83:[2,184],88:[2,184],90:[2,184],99:[2,184],101:[2,184],102:[2,184],103:[2,184],107:[2,184],115:[2,184],123:[2,184],125:[2,184],126:[2,184],129:[2,184],130:[2,184],131:[2,184],132:[2,184],133:[2,184],134:[2,184]},{8:202,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,25:[1,203],27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{8:204,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{5:205,25:[1,5],122:[1,206]},{1:[2,127],6:[2,127],25:[2,127],26:[2,127],47:[2,127],52:[2,127],55:[2,127],70:[2,127],75:[2,127],83:[2,127],88:[2,127],90:[2,127],94:207,95:[1,208],96:[1,209],99:[2,127],101:[2,127],102:[2,127],103:[2,127],107:[2,127],115:[2,127],123:[2,127],125:[2,127],126:[2,127],129:[2,127],130:[2,127],131:[2,127],132:[2,127],133:[2,127],134:[2,127]},{1:[2,139],6:[2,139],25:[2,139],26:[2,139],47:[2,139],52:[2,139],55:[2,139],70:[2,139],75:[2,139],83:[2,139],88:[2,139],90:[2,139],99:[2,139],101:[2,139],102:[2,139],103:[2,139],107:[2,139],115:[2,139],123:[2,139],125:[2,139],126:[2,139],129:[2,139],130:[2,139],131:[2,139],132:[2,139],133:[2,139],134:[2,139]},{1:[2,147],6:[2,147],25:[2,147],26:[2,147],47:[2,147],52:[2,147],55:[2,147],70:[2,147],75:[2,147],83:[2,147],88:[2,147],90:[2,147],99:[2,147],101:[2,147],102:[2,147],103:[2,147],107:[2,147],115:[2,147],123:[2,147],125:[2,147],126:[2,147],129:[2,147],130:[2,147],131:[2,147],132:[2,147],133:[2,147],134:[2,147]},{25:[1,210],100:85,101:[1,63],103:[1,64],106:86,107:[1,66],108:67,123:[1,84],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[1,80],132:[1,81],133:[1,82],134:[1,83]},{117:211,119:212,120:[1,213]},{1:[2,92],6:[2,92],25:[2,92],26:[2,92],47:[2,92],52:[2,92],55:[2,92],70:[2,92],75:[2,92],83:[2,92],88:[2,92],90:[2,92],99:[2,92],101:[2,92],102:[2,92],103:[2,92],107:[2,92],115:[2,92],123:[2,92],125:[2,92],126:[2,92],129:[2,92],130:[2,92],131:[2,92],132:[2,92],133:[2,92],134:[2,92]},{8:214,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{1:[2,95],5:215,6:[2,95],25:[1,5],26:[2,95],47:[2,95],52:[2,95],55:[2,95],64:[2,68],65:[2,68],66:[2,68],68:[2,68],70:[2,95],71:[2,68],75:[2,95],77:[1,216],81:[2,68],82:[2,68],83:[2,95],88:[2,95],90:[2,95],99:[2,95],101:[2,95],102:[2,95],103:[2,95],107:[2,95],115:[2,95],123:[2,95],125:[2,95],126:[2,95],129:[2,95],130:[2,95],131:[2,95],132:[2,95],133:[2,95],134:[2,95]},{1:[2,132],6:[2,132],25:[2,132],26:[2,132],47:[2,132],52:[2,132],55:[2,132],70:[2,132],75:[2,132],83:[2,132],88:[2,132],90:[2,132],99:[2,132],100:85,101:[2,132],102:[2,132],103:[2,132],106:86,107:[2,132],108:67,115:[2,132],123:[2,132],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[1,80],132:[1,81],133:[1,82],134:[1,83]},{1:[2,44],6:[2,44],26:[2,44],99:[2,44],100:85,101:[2,44],103:[2,44],106:86,107:[2,44],108:67,123:[2,44],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[1,80],132:[1,81],133:[1,82],134:[1,83]},{6:[1,72],99:[1,217]},{4:218,7:4,8:6,9:7,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{6:[2,123],25:[2,123],52:[2,123],55:[1,220],88:[2,123],89:219,90:[1,188],100:85,101:[1,63],103:[1,64],106:86,107:[1,66],108:67,123:[1,84],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[1,80],132:[1,81],133:[1,82],134:[1,83]},{1:[2,110],6:[2,110],25:[2,110],26:[2,110],38:[2,110],47:[2,110],52:[2,110],55:[2,110],64:[2,110],65:[2,110],66:[2,110],68:[2,110],70:[2,110],71:[2,110],75:[2,110],81:[2,110],82:[2,110],83:[2,110],88:[2,110],90:[2,110],99:[2,110],101:[2,110],102:[2,110],103:[2,110],107:[2,110],113:[2,110],114:[2,110],115:[2,110],123:[2,110],125:[2,110],126:[2,110],129:[2,110],130:[2,110],131:[2,110],132:[2,110],133:[2,110],134:[2,110]},{6:[2,51],25:[2,51],51:221,52:[1,222],88:[2,51]},{6:[2,118],25:[2,118],26:[2,118],52:[2,118],83:[2,118],88:[2,118]},{8:197,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,25:[1,144],27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,58:145,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],84:223,85:[1,56],86:[1,57],87:[1,55],91:143,93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{6:[2,124],25:[2,124],26:[2,124],52:[2,124],83:[2,124],88:[2,124]},{1:[2,109],6:[2,109],25:[2,109],26:[2,109],38:[2,109],41:[2,109],47:[2,109],52:[2,109],55:[2,109],64:[2,109],65:[2,109],66:[2,109],68:[2,109],70:[2,109],71:[2,109],75:[2,109],77:[2,109],81:[2,109],82:[2,109],83:[2,109],88:[2,109],90:[2,109],99:[2,109],101:[2,109],102:[2,109],103:[2,109],107:[2,109],115:[2,109],123:[2,109],125:[2,109],126:[2,109],127:[2,109],128:[2,109],129:[2,109],130:[2,109],131:[2,109],132:[2,109],133:[2,109],134:[2,109],135:[2,109]},{5:224,25:[1,5],100:85,101:[1,63],103:[1,64],106:86,107:[1,66],108:67,123:[1,84],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[1,80],132:[1,81],133:[1,82],134:[1,83]},{1:[2,135],6:[2,135],25:[2,135],26:[2,135],47:[2,135],52:[2,135],55:[2,135],70:[2,135],75:[2,135],83:[2,135],88:[2,135],90:[2,135],99:[2,135],100:85,101:[1,63],102:[1,225],103:[1,64],106:86,107:[1,66],108:67,115:[2,135],123:[2,135],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[1,80],132:[1,81],133:[1,82],134:[1,83]},{1:[2,137],6:[2,137],25:[2,137],26:[2,137],47:[2,137],52:[2,137],55:[2,137],70:[2,137],75:[2,137],83:[2,137],88:[2,137],90:[2,137],99:[2,137],100:85,101:[1,63],102:[1,226],103:[1,64],106:86,107:[1,66],108:67,115:[2,137],123:[2,137],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[1,80],132:[1,81],133:[1,82],134:[1,83]},{1:[2,143],6:[2,143],25:[2,143],26:[2,143],47:[2,143],52:[2,143],55:[2,143],70:[2,143],75:[2,143],83:[2,143],88:[2,143],90:[2,143],99:[2,143],101:[2,143],102:[2,143],103:[2,143],107:[2,143],115:[2,143],123:[2,143],125:[2,143],126:[2,143],129:[2,143],130:[2,143],131:[2,143],132:[2,143],133:[2,143],134:[2,143]},{1:[2,144],6:[2,144],25:[2,144],26:[2,144],47:[2,144],52:[2,144],55:[2,144],70:[2,144],75:[2,144],83:[2,144],88:[2,144],90:[2,144],99:[2,144],100:85,101:[1,63],102:[2,144],103:[1,64],106:86,107:[1,66],108:67,115:[2,144],123:[2,144],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[1,80],132:[1,81],133:[1,82],134:[1,83]},{1:[2,148],6:[2,148],25:[2,148],26:[2,148],47:[2,148],52:[2,148],55:[2,148],70:[2,148],75:[2,148],83:[2,148],88:[2,148],90:[2,148],99:[2,148],101:[2,148],102:[2,148],103:[2,148],107:[2,148],115:[2,148],123:[2,148],125:[2,148],126:[2,148],129:[2,148],130:[2,148],131:[2,148],132:[2,148],133:[2,148],134:[2,148]},{113:[2,150],114:[2,150]},{27:156,28:[1,71],56:157,57:158,73:[1,68],87:[1,112],110:227,112:155},{52:[1,228],113:[2,155],114:[2,155]},{52:[2,152],113:[2,152],114:[2,152]},{52:[2,153],113:[2,153],114:[2,153]},{52:[2,154],113:[2,154],114:[2,154]},{1:[2,149],6:[2,149],25:[2,149],26:[2,149],47:[2,149],52:[2,149],55:[2,149],70:[2,149],75:[2,149],83:[2,149],88:[2,149],90:[2,149],99:[2,149],101:[2,149],102:[2,149],103:[2,149],107:[2,149],115:[2,149],123:[2,149],125:[2,149],126:[2,149],129:[2,149],130:[2,149],131:[2,149],132:[2,149],133:[2,149],134:[2,149]},{8:229,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{8:230,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{6:[2,51],25:[2,51],51:231,52:[1,232],75:[2,51]},{6:[2,87],25:[2,87],26:[2,87],52:[2,87],75:[2,87]},{6:[2,37],25:[2,37],26:[2,37],41:[1,233],52:[2,37],75:[2,37]},{6:[2,40],25:[2,40],26:[2,40],52:[2,40],75:[2,40]},{6:[2,41],25:[2,41],26:[2,41],41:[2,41],52:[2,41],75:[2,41]},{6:[2,42],25:[2,42],26:[2,42],41:[2,42],52:[2,42],75:[2,42]},{6:[2,43],25:[2,43],26:[2,43],41:[2,43],52:[2,43],75:[2,43]},{1:[2,5],6:[2,5],26:[2,5],99:[2,5]},{1:[2,25],6:[2,25],25:[2,25],26:[2,25],47:[2,25],52:[2,25],55:[2,25],70:[2,25],75:[2,25],83:[2,25],88:[2,25],90:[2,25],95:[2,25],96:[2,25],99:[2,25],101:[2,25],102:[2,25],103:[2,25],107:[2,25],115:[2,25],118:[2,25],120:[2,25],123:[2,25],125:[2,25],126:[2,25],129:[2,25],130:[2,25],131:[2,25],132:[2,25],133:[2,25],134:[2,25]},{1:[2,186],6:[2,186],25:[2,186],26:[2,186],47:[2,186],52:[2,186],55:[2,186],70:[2,186],75:[2,186],83:[2,186],88:[2,186],90:[2,186],99:[2,186],100:85,101:[2,186],102:[2,186],103:[2,186],106:86,107:[2,186],108:67,115:[2,186],123:[2,186],125:[2,186],126:[2,186],129:[1,76],130:[1,79],131:[2,186],132:[2,186],133:[2,186],134:[2,186]},{1:[2,187],6:[2,187],25:[2,187],26:[2,187],47:[2,187],52:[2,187],55:[2,187],70:[2,187],75:[2,187],83:[2,187],88:[2,187],90:[2,187],99:[2,187],100:85,101:[2,187],102:[2,187],103:[2,187],106:86,107:[2,187],108:67,115:[2,187],123:[2,187],125:[2,187],126:[2,187],129:[1,76],130:[1,79],131:[2,187],132:[2,187],133:[2,187],134:[2,187]},{1:[2,188],6:[2,188],25:[2,188],26:[2,188],47:[2,188],52:[2,188],55:[2,188],70:[2,188],75:[2,188],83:[2,188],88:[2,188],90:[2,188],99:[2,188],100:85,101:[2,188],102:[2,188],103:[2,188],106:86,107:[2,188],108:67,115:[2,188],123:[2,188],125:[2,188],126:[2,188],129:[1,76],130:[2,188],131:[2,188],132:[2,188],133:[2,188],134:[2,188]},{1:[2,189],6:[2,189],25:[2,189],26:[2,189],47:[2,189],52:[2,189],55:[2,189],70:[2,189],75:[2,189],83:[2,189],88:[2,189],90:[2,189],99:[2,189],100:85,101:[2,189],102:[2,189],103:[2,189],106:86,107:[2,189],108:67,115:[2,189],123:[2,189],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[2,189],132:[2,189],133:[2,189],134:[2,189]},{1:[2,190],6:[2,190],25:[2,190],26:[2,190],47:[2,190],52:[2,190],55:[2,190],70:[2,190],75:[2,190],83:[2,190],88:[2,190],90:[2,190],99:[2,190],100:85,101:[2,190],102:[2,190],103:[2,190],106:86,107:[2,190],108:67,115:[2,190],123:[2,190],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[1,80],132:[2,190],133:[2,190],134:[1,83]},{1:[2,191],6:[2,191],25:[2,191],26:[2,191],47:[2,191],52:[2,191],55:[2,191],70:[2,191],75:[2,191],83:[2,191],88:[2,191],90:[2,191],99:[2,191],100:85,101:[2,191],102:[2,191],103:[2,191],106:86,107:[2,191],108:67,115:[2,191],123:[2,191],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[1,80],132:[1,81],133:[2,191],134:[1,83]},{1:[2,192],6:[2,192],25:[2,192],26:[2,192],47:[2,192],52:[2,192],55:[2,192],70:[2,192],75:[2,192],83:[2,192],88:[2,192],90:[2,192],99:[2,192],100:85,101:[2,192],102:[2,192],103:[2,192],106:86,107:[2,192],108:67,115:[2,192],123:[2,192],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[1,80],132:[2,192],133:[2,192],134:[2,192]},{1:[2,177],6:[2,177],25:[2,177],26:[2,177],47:[2,177],52:[2,177],55:[2,177],70:[2,177],75:[2,177],83:[2,177],88:[2,177],90:[2,177],99:[2,177],100:85,101:[1,63],102:[2,177],103:[1,64],106:86,107:[1,66],108:67,115:[2,177],123:[1,84],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[1,80],132:[1,81],133:[1,82],134:[1,83]},{1:[2,176],6:[2,176],25:[2,176],26:[2,176],47:[2,176],52:[2,176],55:[2,176],70:[2,176],75:[2,176],83:[2,176],88:[2,176],90:[2,176],99:[2,176],100:85,101:[1,63],102:[2,176],103:[1,64],106:86,107:[1,66],108:67,115:[2,176],123:[1,84],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[1,80],132:[1,81],133:[1,82],134:[1,83]},{1:[2,99],6:[2,99],25:[2,99],26:[2,99],47:[2,99],52:[2,99],55:[2,99],64:[2,99],65:[2,99],66:[2,99],68:[2,99],70:[2,99],71:[2,99],75:[2,99],81:[2,99],82:[2,99],83:[2,99],88:[2,99],90:[2,99],99:[2,99],101:[2,99],102:[2,99],103:[2,99],107:[2,99],115:[2,99],123:[2,99],125:[2,99],126:[2,99],129:[2,99],130:[2,99],131:[2,99],132:[2,99],133:[2,99],134:[2,99]},{1:[2,76],6:[2,76],25:[2,76],26:[2,76],38:[2,76],47:[2,76],52:[2,76],55:[2,76],64:[2,76],65:[2,76],66:[2,76],68:[2,76],70:[2,76],71:[2,76],75:[2,76],77:[2,76],81:[2,76],82:[2,76],83:[2,76],88:[2,76],90:[2,76],99:[2,76],101:[2,76],102:[2,76],103:[2,76],107:[2,76],115:[2,76],123:[2,76],125:[2,76],126:[2,76],127:[2,76],128:[2,76],129:[2,76],130:[2,76],131:[2,76],132:[2,76],133:[2,76],134:[2,76],135:[2,76]},{1:[2,77],6:[2,77],25:[2,77],26:[2,77],38:[2,77],47:[2,77],52:[2,77],55:[2,77],64:[2,77],65:[2,77],66:[2,77],68:[2,77],70:[2,77],71:[2,77],75:[2,77],77:[2,77],81:[2,77],82:[2,77],83:[2,77],88:[2,77],90:[2,77],99:[2,77],101:[2,77],102:[2,77],103:[2,77],107:[2,77],115:[2,77],123:[2,77],125:[2,77],126:[2,77],127:[2,77],128:[2,77],129:[2,77],130:[2,77],131:[2,77],132:[2,77],133:[2,77],134:[2,77],135:[2,77]},{1:[2,78],6:[2,78],25:[2,78],26:[2,78],38:[2,78],47:[2,78],52:[2,78],55:[2,78],64:[2,78],65:[2,78],66:[2,78],68:[2,78],70:[2,78],71:[2,78],75:[2,78],77:[2,78],81:[2,78],82:[2,78],83:[2,78],88:[2,78],90:[2,78],99:[2,78],101:[2,78],102:[2,78],103:[2,78],107:[2,78],115:[2,78],123:[2,78],125:[2,78],126:[2,78],127:[2,78],128:[2,78],129:[2,78],130:[2,78],131:[2,78],132:[2,78],133:[2,78],134:[2,78],135:[2,78]},{70:[1,234]},{55:[1,189],70:[2,83],89:235,90:[1,188],100:85,101:[1,63],103:[1,64],106:86,107:[1,66],108:67,123:[1,84],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[1,80],132:[1,81],133:[1,82],134:[1,83]},{70:[2,84]},{8:236,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{12:[2,112],28:[2,112],30:[2,112],31:[2,112],33:[2,112],34:[2,112],35:[2,112],36:[2,112],43:[2,112],44:[2,112],45:[2,112],49:[2,112],50:[2,112],70:[2,112],73:[2,112],76:[2,112],80:[2,112],85:[2,112],86:[2,112],87:[2,112],93:[2,112],97:[2,112],98:[2,112],101:[2,112],103:[2,112],105:[2,112],107:[2,112],116:[2,112],122:[2,112],124:[2,112],125:[2,112],126:[2,112],127:[2,112],128:[2,112]},{12:[2,113],28:[2,113],30:[2,113],31:[2,113],33:[2,113],34:[2,113],35:[2,113],36:[2,113],43:[2,113],44:[2,113],45:[2,113],49:[2,113],50:[2,113],70:[2,113],73:[2,113],76:[2,113],80:[2,113],85:[2,113],86:[2,113],87:[2,113],93:[2,113],97:[2,113],98:[2,113],101:[2,113],103:[2,113],105:[2,113],107:[2,113],116:[2,113],122:[2,113],124:[2,113],125:[2,113],126:[2,113],127:[2,113],128:[2,113]},{1:[2,82],6:[2,82],25:[2,82],26:[2,82],38:[2,82],47:[2,82],52:[2,82],55:[2,82],64:[2,82],65:[2,82],66:[2,82],68:[2,82],70:[2,82],71:[2,82],75:[2,82],77:[2,82],81:[2,82],82:[2,82],83:[2,82],88:[2,82],90:[2,82],99:[2,82],101:[2,82],102:[2,82],103:[2,82],107:[2,82],115:[2,82],123:[2,82],125:[2,82],126:[2,82],127:[2,82],128:[2,82],129:[2,82],130:[2,82],131:[2,82],132:[2,82],133:[2,82],134:[2,82],135:[2,82]},{1:[2,100],6:[2,100],25:[2,100],26:[2,100],47:[2,100],52:[2,100],55:[2,100],64:[2,100],65:[2,100],66:[2,100],68:[2,100],70:[2,100],71:[2,100],75:[2,100],81:[2,100],82:[2,100],83:[2,100],88:[2,100],90:[2,100],99:[2,100],101:[2,100],102:[2,100],103:[2,100],107:[2,100],115:[2,100],123:[2,100],125:[2,100],126:[2,100],129:[2,100],130:[2,100],131:[2,100],132:[2,100],133:[2,100],134:[2,100]},{1:[2,34],6:[2,34],25:[2,34],26:[2,34],47:[2,34],52:[2,34],55:[2,34],70:[2,34],75:[2,34],83:[2,34],88:[2,34],90:[2,34],99:[2,34],100:85,101:[2,34],102:[2,34],103:[2,34],106:86,107:[2,34],108:67,115:[2,34],123:[2,34],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[1,80],132:[1,81],133:[1,82],134:[1,83]},{8:237,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{8:238,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{1:[2,105],6:[2,105],25:[2,105],26:[2,105],47:[2,105],52:[2,105],55:[2,105],64:[2,105],65:[2,105],66:[2,105],68:[2,105],70:[2,105],71:[2,105],75:[2,105],81:[2,105],82:[2,105],83:[2,105],88:[2,105],90:[2,105],99:[2,105],101:[2,105],102:[2,105],103:[2,105],107:[2,105],115:[2,105],123:[2,105],125:[2,105],126:[2,105],129:[2,105],130:[2,105],131:[2,105],132:[2,105],133:[2,105],134:[2,105]},{6:[2,51],25:[2,51],51:239,52:[1,222],83:[2,51]},{6:[2,123],25:[2,123],26:[2,123],52:[2,123],55:[1,240],83:[2,123],88:[2,123],100:85,101:[1,63],103:[1,64],106:86,107:[1,66],108:67,123:[1,84],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[1,80],132:[1,81],133:[1,82],134:[1,83]},{48:241,49:[1,58],50:[1,59]},{27:107,28:[1,71],42:108,53:242,54:106,56:109,57:110,73:[1,68],86:[1,111],87:[1,112]},{47:[2,57],52:[2,57]},{8:243,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{1:[2,193],6:[2,193],25:[2,193],26:[2,193],47:[2,193],52:[2,193],55:[2,193],70:[2,193],75:[2,193],83:[2,193],88:[2,193],90:[2,193],99:[2,193],100:85,101:[2,193],102:[2,193],103:[2,193],106:86,107:[2,193],108:67,115:[2,193],123:[2,193],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[1,80],132:[1,81],133:[1,82],134:[1,83]},{8:244,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{1:[2,195],6:[2,195],25:[2,195],26:[2,195],47:[2,195],52:[2,195],55:[2,195],70:[2,195],75:[2,195],83:[2,195],88:[2,195],90:[2,195],99:[2,195],100:85,101:[2,195],102:[2,195],103:[2,195],106:86,107:[2,195],108:67,115:[2,195],123:[2,195],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[1,80],132:[1,81],133:[1,82],134:[1,83]},{1:[2,175],6:[2,175],25:[2,175],26:[2,175],47:[2,175],52:[2,175],55:[2,175],70:[2,175],75:[2,175],83:[2,175],88:[2,175],90:[2,175],99:[2,175],101:[2,175],102:[2,175],103:[2,175],107:[2,175],115:[2,175],123:[2,175],125:[2,175],126:[2,175],129:[2,175],130:[2,175],131:[2,175],132:[2,175],133:[2,175],134:[2,175]},{8:245,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{1:[2,128],6:[2,128],25:[2,128],26:[2,128],47:[2,128],52:[2,128],55:[2,128],70:[2,128],75:[2,128],83:[2,128],88:[2,128],90:[2,128],95:[1,246],99:[2,128],101:[2,128],102:[2,128],103:[2,128],107:[2,128],115:[2,128],123:[2,128],125:[2,128],126:[2,128],129:[2,128],130:[2,128],131:[2,128],132:[2,128],133:[2,128],134:[2,128]},{5:247,25:[1,5]},{27:248,28:[1,71]},{117:249,119:212,120:[1,213]},{26:[1,250],118:[1,251],119:252,120:[1,213]},{26:[2,168],118:[2,168],120:[2,168]},{8:254,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],92:253,93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{1:[2,93],5:255,6:[2,93],25:[1,5],26:[2,93],47:[2,93],52:[2,93],55:[2,93],70:[2,93],75:[2,93],83:[2,93],88:[2,93],90:[2,93],99:[2,93],100:85,101:[1,63],102:[2,93],103:[1,64],106:86,107:[1,66],108:67,115:[2,93],123:[2,93],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[1,80],132:[1,81],133:[1,82],134:[1,83]},{1:[2,96],6:[2,96],25:[2,96],26:[2,96],47:[2,96],52:[2,96],55:[2,96],70:[2,96],75:[2,96],83:[2,96],88:[2,96],90:[2,96],99:[2,96],101:[2,96],102:[2,96],103:[2,96],107:[2,96],115:[2,96],123:[2,96],125:[2,96],126:[2,96],129:[2,96],130:[2,96],131:[2,96],132:[2,96],133:[2,96],134:[2,96]},{8:256,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{1:[2,133],6:[2,133],25:[2,133],26:[2,133],47:[2,133],52:[2,133],55:[2,133],64:[2,133],65:[2,133],66:[2,133],68:[2,133],70:[2,133],71:[2,133],75:[2,133],81:[2,133],82:[2,133],83:[2,133],88:[2,133],90:[2,133],99:[2,133],101:[2,133],102:[2,133],103:[2,133],107:[2,133],115:[2,133],123:[2,133],125:[2,133],126:[2,133],129:[2,133],130:[2,133],131:[2,133],132:[2,133],133:[2,133],134:[2,133]},{6:[1,72],26:[1,257]},{8:258,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{6:[2,63],12:[2,113],25:[2,63],28:[2,113],30:[2,113],31:[2,113],33:[2,113],34:[2,113],35:[2,113],36:[2,113],43:[2,113],44:[2,113],45:[2,113],49:[2,113],50:[2,113],52:[2,63],73:[2,113],76:[2,113],80:[2,113],85:[2,113],86:[2,113],87:[2,113],88:[2,63],93:[2,113],97:[2,113],98:[2,113],101:[2,113],103:[2,113],105:[2,113],107:[2,113],116:[2,113],122:[2,113],124:[2,113],125:[2,113],126:[2,113],127:[2,113],128:[2,113]},{6:[1,260],25:[1,261],88:[1,259]},{6:[2,52],8:197,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,25:[2,52],26:[2,52],27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,58:145,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],83:[2,52],85:[1,56],86:[1,57],87:[1,55],88:[2,52],91:262,93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{6:[2,51],25:[2,51],26:[2,51],51:263,52:[1,222]},{1:[2,172],6:[2,172],25:[2,172],26:[2,172],47:[2,172],52:[2,172],55:[2,172],70:[2,172],75:[2,172],83:[2,172],88:[2,172],90:[2,172],99:[2,172],101:[2,172],102:[2,172],103:[2,172],107:[2,172],115:[2,172],118:[2,172],123:[2,172],125:[2,172],126:[2,172],129:[2,172],130:[2,172],131:[2,172],132:[2,172],133:[2,172],134:[2,172]},{8:264,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{8:265,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{113:[2,151],114:[2,151]},{27:156,28:[1,71],56:157,57:158,73:[1,68],87:[1,112],112:266},{1:[2,157],6:[2,157],25:[2,157],26:[2,157],47:[2,157],52:[2,157],55:[2,157],70:[2,157],75:[2,157],83:[2,157],88:[2,157],90:[2,157],99:[2,157],100:85,101:[2,157],102:[1,267],103:[2,157],106:86,107:[2,157],108:67,115:[1,268],123:[2,157],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[1,80],132:[1,81],133:[1,82],134:[1,83]},{1:[2,158],6:[2,158],25:[2,158],26:[2,158],47:[2,158],52:[2,158],55:[2,158],70:[2,158],75:[2,158],83:[2,158],88:[2,158],90:[2,158],99:[2,158],100:85,101:[2,158],102:[1,269],103:[2,158],106:86,107:[2,158],108:67,115:[2,158],123:[2,158],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[1,80],132:[1,81],133:[1,82],134:[1,83]},{6:[1,271],25:[1,272],75:[1,270]},{6:[2,52],11:165,25:[2,52],26:[2,52],27:166,28:[1,71],29:167,30:[1,69],31:[1,70],39:273,40:164,42:168,44:[1,46],75:[2,52],86:[1,111]},{8:274,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,25:[1,275],27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{1:[2,81],6:[2,81],25:[2,81],26:[2,81],38:[2,81],47:[2,81],52:[2,81],55:[2,81],64:[2,81],65:[2,81],66:[2,81],68:[2,81],70:[2,81],71:[2,81],75:[2,81],77:[2,81],81:[2,81],82:[2,81],83:[2,81],88:[2,81],90:[2,81],99:[2,81],101:[2,81],102:[2,81],103:[2,81],107:[2,81],115:[2,81],123:[2,81],125:[2,81],126:[2,81],127:[2,81],128:[2,81],129:[2,81],130:[2,81],131:[2,81],132:[2,81],133:[2,81],134:[2,81],135:[2,81]},{8:276,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,70:[2,116],73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{70:[2,117],100:85,101:[1,63],103:[1,64],106:86,107:[1,66],108:67,123:[1,84],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[1,80],132:[1,81],133:[1,82],134:[1,83]},{1:[2,35],6:[2,35],25:[2,35],26:[2,35],47:[2,35],52:[2,35],55:[2,35],70:[2,35],75:[2,35],83:[2,35],88:[2,35],90:[2,35],99:[2,35],100:85,101:[2,35],102:[2,35],103:[2,35],106:86,107:[2,35],108:67,115:[2,35],123:[2,35],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[1,80],132:[1,81],133:[1,82],134:[1,83]},{26:[1,277],100:85,101:[1,63],103:[1,64],106:86,107:[1,66],108:67,123:[1,84],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[1,80],132:[1,81],133:[1,82],134:[1,83]},{6:[1,260],25:[1,261],83:[1,278]},{6:[2,63],25:[2,63],26:[2,63],52:[2,63],83:[2,63],88:[2,63]},{5:279,25:[1,5]},{47:[2,55],52:[2,55]},{47:[2,58],52:[2,58],100:85,101:[1,63],103:[1,64],106:86,107:[1,66],108:67,123:[1,84],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[1,80],132:[1,81],133:[1,82],134:[1,83]},{26:[1,280],100:85,101:[1,63],103:[1,64],106:86,107:[1,66],108:67,123:[1,84],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[1,80],132:[1,81],133:[1,82],134:[1,83]},{5:281,25:[1,5],100:85,101:[1,63],103:[1,64],106:86,107:[1,66],108:67,123:[1,84],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[1,80],132:[1,81],133:[1,82],134:[1,83]},{5:282,25:[1,5]},{1:[2,129],6:[2,129],25:[2,129],26:[2,129],47:[2,129],52:[2,129],55:[2,129],70:[2,129],75:[2,129],83:[2,129],88:[2,129],90:[2,129],99:[2,129],101:[2,129],102:[2,129],103:[2,129],107:[2,129],115:[2,129],123:[2,129],125:[2,129],126:[2,129],129:[2,129],130:[2,129],131:[2,129],132:[2,129],133:[2,129],134:[2,129]},{5:283,25:[1,5]},{26:[1,284],118:[1,285],119:252,120:[1,213]},{1:[2,166],6:[2,166],25:[2,166],26:[2,166],47:[2,166],52:[2,166],55:[2,166],70:[2,166],75:[2,166],83:[2,166],88:[2,166],90:[2,166],99:[2,166],101:[2,166],102:[2,166],103:[2,166],107:[2,166],115:[2,166],123:[2,166],125:[2,166],126:[2,166],129:[2,166],130:[2,166],131:[2,166],132:[2,166],133:[2,166],134:[2,166]},{5:286,25:[1,5]},{26:[2,169],118:[2,169],120:[2,169]},{5:287,25:[1,5],52:[1,288]},{25:[2,125],52:[2,125],100:85,101:[1,63],103:[1,64],106:86,107:[1,66],108:67,123:[1,84],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[1,80],132:[1,81],133:[1,82],134:[1,83]},{1:[2,94],6:[2,94],25:[2,94],26:[2,94],47:[2,94],52:[2,94],55:[2,94],70:[2,94],75:[2,94],83:[2,94],88:[2,94],90:[2,94],99:[2,94],101:[2,94],102:[2,94],103:[2,94],107:[2,94],115:[2,94],123:[2,94],125:[2,94],126:[2,94],129:[2,94],130:[2,94],131:[2,94],132:[2,94],133:[2,94],134:[2,94]},{1:[2,97],5:289,6:[2,97],25:[1,5],26:[2,97],47:[2,97],52:[2,97],55:[2,97],70:[2,97],75:[2,97],83:[2,97],88:[2,97],90:[2,97],99:[2,97],100:85,101:[1,63],102:[2,97],103:[1,64],106:86,107:[1,66],108:67,115:[2,97],123:[2,97],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[1,80],132:[1,81],133:[1,82],134:[1,83]},{99:[1,290]},{88:[1,291],100:85,101:[1,63],103:[1,64],106:86,107:[1,66],108:67,123:[1,84],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[1,80],132:[1,81],133:[1,82],134:[1,83]},{1:[2,111],6:[2,111],25:[2,111],26:[2,111],38:[2,111],47:[2,111],52:[2,111],55:[2,111],64:[2,111],65:[2,111],66:[2,111],68:[2,111],70:[2,111],71:[2,111],75:[2,111],81:[2,111],82:[2,111],83:[2,111],88:[2,111],90:[2,111],99:[2,111],101:[2,111],102:[2,111],103:[2,111],107:[2,111],113:[2,111],114:[2,111],115:[2,111],123:[2,111],125:[2,111],126:[2,111],129:[2,111],130:[2,111],131:[2,111],132:[2,111],133:[2,111],134:[2,111]},{8:197,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,58:145,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],91:292,93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{8:197,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,25:[1,144],27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,58:145,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],84:293,85:[1,56],86:[1,57],87:[1,55],91:143,93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{6:[2,119],25:[2,119],26:[2,119],52:[2,119],83:[2,119],88:[2,119]},{6:[1,260],25:[1,261],26:[1,294]},{1:[2,136],6:[2,136],25:[2,136],26:[2,136],47:[2,136],52:[2,136],55:[2,136],70:[2,136],75:[2,136],83:[2,136],88:[2,136],90:[2,136],99:[2,136],100:85,101:[1,63],102:[2,136],103:[1,64],106:86,107:[1,66],108:67,115:[2,136],123:[2,136],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[1,80],132:[1,81],133:[1,82],134:[1,83]},{1:[2,138],6:[2,138],25:[2,138],26:[2,138],47:[2,138],52:[2,138],55:[2,138],70:[2,138],75:[2,138],83:[2,138],88:[2,138],90:[2,138],99:[2,138],100:85,101:[1,63],102:[2,138],103:[1,64],106:86,107:[1,66],108:67,115:[2,138],123:[2,138],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[1,80],132:[1,81],133:[1,82],134:[1,83]},{113:[2,156],114:[2,156]},{8:295,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{8:296,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{8:297,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{1:[2,85],6:[2,85],25:[2,85],26:[2,85],38:[2,85],47:[2,85],52:[2,85],55:[2,85],64:[2,85],65:[2,85],66:[2,85],68:[2,85],70:[2,85],71:[2,85],75:[2,85],81:[2,85],82:[2,85],83:[2,85],88:[2,85],90:[2,85],99:[2,85],101:[2,85],102:[2,85],103:[2,85],107:[2,85],113:[2,85],114:[2,85],115:[2,85],123:[2,85],125:[2,85],126:[2,85],129:[2,85],130:[2,85],131:[2,85],132:[2,85],133:[2,85],134:[2,85]},{11:165,27:166,28:[1,71],29:167,30:[1,69],31:[1,70],39:298,40:164,42:168,44:[1,46],86:[1,111]},{6:[2,86],11:165,25:[2,86],26:[2,86],27:166,28:[1,71],29:167,30:[1,69],31:[1,70],39:163,40:164,42:168,44:[1,46],52:[2,86],74:299,86:[1,111]},{6:[2,88],25:[2,88],26:[2,88],52:[2,88],75:[2,88]},{6:[2,38],25:[2,38],26:[2,38],52:[2,38],75:[2,38],100:85,101:[1,63],103:[1,64],106:86,107:[1,66],108:67,123:[1,84],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[1,80],132:[1,81],133:[1,82],134:[1,83]},{8:300,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{70:[2,115],100:85,101:[1,63],103:[1,64],106:86,107:[1,66],108:67,123:[1,84],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[1,80],132:[1,81],133:[1,82],134:[1,83]},{1:[2,36],6:[2,36],25:[2,36],26:[2,36],47:[2,36],52:[2,36],55:[2,36],70:[2,36],75:[2,36],83:[2,36],88:[2,36],90:[2,36],99:[2,36],101:[2,36],102:[2,36],103:[2,36],107:[2,36],115:[2,36],123:[2,36],125:[2,36],126:[2,36],129:[2,36],130:[2,36],131:[2,36],132:[2,36],133:[2,36],134:[2,36]},{1:[2,106],6:[2,106],25:[2,106],26:[2,106],47:[2,106],52:[2,106],55:[2,106],64:[2,106],65:[2,106],66:[2,106],68:[2,106],70:[2,106],71:[2,106],75:[2,106],81:[2,106],82:[2,106],83:[2,106],88:[2,106],90:[2,106],99:[2,106],101:[2,106],102:[2,106],103:[2,106],107:[2,106],115:[2,106],123:[2,106],125:[2,106],126:[2,106],129:[2,106],130:[2,106],131:[2,106],132:[2,106],133:[2,106],134:[2,106]},{1:[2,47],6:[2,47],25:[2,47],26:[2,47],47:[2,47],52:[2,47],55:[2,47],70:[2,47],75:[2,47],83:[2,47],88:[2,47],90:[2,47],99:[2,47],101:[2,47],102:[2,47],103:[2,47],107:[2,47],115:[2,47],123:[2,47],125:[2,47],126:[2,47],129:[2,47],130:[2,47],131:[2,47],132:[2,47],133:[2,47],134:[2,47]},{1:[2,194],6:[2,194],25:[2,194],26:[2,194],47:[2,194],52:[2,194],55:[2,194],70:[2,194],75:[2,194],83:[2,194],88:[2,194],90:[2,194],99:[2,194],101:[2,194],102:[2,194],103:[2,194],107:[2,194],115:[2,194],123:[2,194],125:[2,194],126:[2,194],129:[2,194],130:[2,194],131:[2,194],132:[2,194],133:[2,194],134:[2,194]},{1:[2,173],6:[2,173],25:[2,173],26:[2,173],47:[2,173],52:[2,173],55:[2,173],70:[2,173],75:[2,173],83:[2,173],88:[2,173],90:[2,173],99:[2,173],101:[2,173],102:[2,173],103:[2,173],107:[2,173],115:[2,173],118:[2,173],123:[2,173],125:[2,173],126:[2,173],129:[2,173],130:[2,173],131:[2,173],132:[2,173],133:[2,173],134:[2,173]},{1:[2,130],6:[2,130],25:[2,130],26:[2,130],47:[2,130],52:[2,130],55:[2,130],70:[2,130],75:[2,130],83:[2,130],88:[2,130],90:[2,130],99:[2,130],101:[2,130],102:[2,130],103:[2,130],107:[2,130],115:[2,130],123:[2,130],125:[2,130],126:[2,130],129:[2,130],130:[2,130],131:[2,130],132:[2,130],133:[2,130],134:[2,130]},{1:[2,131],6:[2,131],25:[2,131],26:[2,131],47:[2,131],52:[2,131],55:[2,131],70:[2,131],75:[2,131],83:[2,131],88:[2,131],90:[2,131],95:[2,131],99:[2,131],101:[2,131],102:[2,131],103:[2,131],107:[2,131],115:[2,131],123:[2,131],125:[2,131],126:[2,131],129:[2,131],130:[2,131],131:[2,131],132:[2,131],133:[2,131],134:[2,131]},{1:[2,164],6:[2,164],25:[2,164],26:[2,164],47:[2,164],52:[2,164],55:[2,164],70:[2,164],75:[2,164],83:[2,164],88:[2,164],90:[2,164],99:[2,164],101:[2,164],102:[2,164],103:[2,164],107:[2,164],115:[2,164],123:[2,164],125:[2,164],126:[2,164],129:[2,164],130:[2,164],131:[2,164],132:[2,164],133:[2,164],134:[2,164]},{5:301,25:[1,5]},{26:[1,302]},{6:[1,303],26:[2,170],118:[2,170],120:[2,170]},{8:304,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{1:[2,98],6:[2,98],25:[2,98],26:[2,98],47:[2,98],52:[2,98],55:[2,98],70:[2,98],75:[2,98],83:[2,98],88:[2,98],90:[2,98],99:[2,98],101:[2,98],102:[2,98],103:[2,98],107:[2,98],115:[2,98],123:[2,98],125:[2,98],126:[2,98],129:[2,98],130:[2,98],131:[2,98],132:[2,98],133:[2,98],134:[2,98]},{1:[2,134],6:[2,134],25:[2,134],26:[2,134],47:[2,134],52:[2,134],55:[2,134],64:[2,134],65:[2,134],66:[2,134],68:[2,134],70:[2,134],71:[2,134],75:[2,134],81:[2,134],82:[2,134],83:[2,134],88:[2,134],90:[2,134],99:[2,134],101:[2,134],102:[2,134],103:[2,134],107:[2,134],115:[2,134],123:[2,134],125:[2,134],126:[2,134],129:[2,134],130:[2,134],131:[2,134],132:[2,134],133:[2,134],134:[2,134]},{1:[2,114],6:[2,114],25:[2,114],26:[2,114],47:[2,114],52:[2,114],55:[2,114],64:[2,114],65:[2,114],66:[2,114],68:[2,114],70:[2,114],71:[2,114],75:[2,114],81:[2,114],82:[2,114],83:[2,114],88:[2,114],90:[2,114],99:[2,114],101:[2,114],102:[2,114],103:[2,114],107:[2,114],115:[2,114],123:[2,114],125:[2,114],126:[2,114],129:[2,114],130:[2,114],131:[2,114],132:[2,114],133:[2,114],134:[2,114]},{6:[2,120],25:[2,120],26:[2,120],52:[2,120],83:[2,120],88:[2,120]},{6:[2,51],25:[2,51],26:[2,51],51:305,52:[1,222]},{6:[2,121],25:[2,121],26:[2,121],52:[2,121],83:[2,121],88:[2,121]},{1:[2,159],6:[2,159],25:[2,159],26:[2,159],47:[2,159],52:[2,159],55:[2,159],70:[2,159],75:[2,159],83:[2,159],88:[2,159],90:[2,159],99:[2,159],100:85,101:[2,159],102:[2,159],103:[2,159],106:86,107:[2,159],108:67,115:[1,306],123:[2,159],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[1,80],132:[1,81],133:[1,82],134:[1,83]},{1:[2,161],6:[2,161],25:[2,161],26:[2,161],47:[2,161],52:[2,161],55:[2,161],70:[2,161],75:[2,161],83:[2,161],88:[2,161],90:[2,161],99:[2,161],100:85,101:[2,161],102:[1,307],103:[2,161],106:86,107:[2,161],108:67,115:[2,161],123:[2,161],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[1,80],132:[1,81],133:[1,82],134:[1,83]},{1:[2,160],6:[2,160],25:[2,160],26:[2,160],47:[2,160],52:[2,160],55:[2,160],70:[2,160],75:[2,160],83:[2,160],88:[2,160],90:[2,160],99:[2,160],100:85,101:[2,160],102:[2,160],103:[2,160],106:86,107:[2,160],108:67,115:[2,160],123:[2,160],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[1,80],132:[1,81],133:[1,82],134:[1,83]},{6:[2,89],25:[2,89],26:[2,89],52:[2,89],75:[2,89]},{6:[2,51],25:[2,51],26:[2,51],51:308,52:[1,232]},{26:[1,309],100:85,101:[1,63],103:[1,64],106:86,107:[1,66],108:67,123:[1,84],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[1,80],132:[1,81],133:[1,82],134:[1,83]},{26:[1,310]},{1:[2,167],6:[2,167],25:[2,167],26:[2,167],47:[2,167],52:[2,167],55:[2,167],70:[2,167],75:[2,167],83:[2,167],88:[2,167],90:[2,167],99:[2,167],101:[2,167],102:[2,167],103:[2,167],107:[2,167],115:[2,167],123:[2,167],125:[2,167],126:[2,167],129:[2,167],130:[2,167],131:[2,167],132:[2,167],133:[2,167],134:[2,167]},{26:[2,171],118:[2,171],120:[2,171]},{25:[2,126],52:[2,126],100:85,101:[1,63],103:[1,64],106:86,107:[1,66],108:67,123:[1,84],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[1,80],132:[1,81],133:[1,82],134:[1,83]},{6:[1,260],25:[1,261],26:[1,311]},{8:312,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{8:313,9:115,10:20,11:21,12:[1,22],13:8,14:9,15:10,16:11,17:12,18:13,19:14,20:15,21:16,22:17,23:18,24:19,27:60,28:[1,71],29:49,30:[1,69],31:[1,70],32:24,33:[1,50],34:[1,51],35:[1,52],36:[1,53],37:23,42:61,43:[1,45],44:[1,46],45:[1,29],48:30,49:[1,58],50:[1,59],56:47,57:48,59:36,61:25,62:26,63:27,73:[1,68],76:[1,43],80:[1,28],85:[1,56],86:[1,57],87:[1,55],93:[1,38],97:[1,44],98:[1,54],100:39,101:[1,63],103:[1,64],104:40,105:[1,65],106:41,107:[1,66],108:67,116:[1,42],121:37,122:[1,62],124:[1,31],125:[1,32],126:[1,33],127:[1,34],128:[1,35]},{6:[1,271],25:[1,272],26:[1,314]},{6:[2,39],25:[2,39],26:[2,39],52:[2,39],75:[2,39]},{1:[2,165],6:[2,165],25:[2,165],26:[2,165],47:[2,165],52:[2,165],55:[2,165],70:[2,165],75:[2,165],83:[2,165],88:[2,165],90:[2,165],99:[2,165],101:[2,165],102:[2,165],103:[2,165],107:[2,165],115:[2,165],123:[2,165],125:[2,165],126:[2,165],129:[2,165],130:[2,165],131:[2,165],132:[2,165],133:[2,165],134:[2,165]},{6:[2,122],25:[2,122],26:[2,122],52:[2,122],83:[2,122],88:[2,122]},{1:[2,162],6:[2,162],25:[2,162],26:[2,162],47:[2,162],52:[2,162],55:[2,162],70:[2,162],75:[2,162],83:[2,162],88:[2,162],90:[2,162],99:[2,162],100:85,101:[2,162],102:[2,162],103:[2,162],106:86,107:[2,162],108:67,115:[2,162],123:[2,162],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[1,80],132:[1,81],133:[1,82],134:[1,83]},{1:[2,163],6:[2,163],25:[2,163],26:[2,163],47:[2,163],52:[2,163],55:[2,163],70:[2,163],75:[2,163],83:[2,163],88:[2,163],90:[2,163],99:[2,163],100:85,101:[2,163],102:[2,163],103:[2,163],106:86,107:[2,163],108:67,115:[2,163],123:[2,163],125:[1,78],126:[1,77],129:[1,76],130:[1,79],131:[1,80],132:[1,81],133:[1,82],134:[1,83]},{6:[2,90],25:[2,90],26:[2,90],52:[2,90],75:[2,90]}],
defaultActions: {58:[2,49],59:[2,50],73:[2,3],92:[2,104],186:[2,84]},
parseError: function parseError(str, hash) {
    throw new Error(str);
},
parse: function parse(input) {
    var self = this,
        stack = [0],
        vstack = [null], // semantic value stack
        lstack = [], // location stack
        table = this.table,
        yytext = '',
        yylineno = 0,
        yyleng = 0,
        recovering = 0,
        TERROR = 2,
        EOF = 1;

    //this.reductionCount = this.shiftCount = 0;

    this.lexer.setInput(input);
    this.lexer.yy = this.yy;
    this.yy.lexer = this.lexer;
    if (typeof this.lexer.yylloc == 'undefined')
        this.lexer.yylloc = {};
    var yyloc = this.lexer.yylloc;
    lstack.push(yyloc);

    if (typeof this.yy.parseError === 'function')
        this.parseError = this.yy.parseError;

    function popStack (n) {
        stack.length = stack.length - 2*n;
        vstack.length = vstack.length - n;
        lstack.length = lstack.length - n;
    }

    function lex() {
        var token;
        token = self.lexer.lex() || 1; // $end = 1
        // if token isn't its numeric value, convert
        if (typeof token !== 'number') {
            token = self.symbols_[token] || token;
        }
        return token;
    };

    var symbol, preErrorSymbol, state, action, a, r, yyval={},p,len,newState, expected;
    while (true) {
        // retreive state number from top of stack
        state = stack[stack.length-1];

        // use default actions if available
        if (this.defaultActions[state]) {
            action = this.defaultActions[state];
        } else {
            if (symbol == null)
                symbol = lex();
            // read action for current state and first input
            action = table[state] && table[state][symbol];
        }

        // handle parse error
        if (typeof action === 'undefined' || !action.length || !action[0]) {

            if (!recovering) {
                // Report error
                expected = [];
                for (p in table[state]) if (this.terminals_[p] && p > 2) {
                    expected.push("'"+this.terminals_[p]+"'");
                }
                var errStr = '';
                if (this.lexer.showPosition) {
                    errStr = 'Parse error on line '+(yylineno+1)+":\n"+this.lexer.showPosition()+'\nExpecting '+expected.join(', ');
                } else {
                    errStr = 'Parse error on line '+(yylineno+1)+": Unexpected " +
                                  (symbol == 1 /*EOF*/ ? "end of input" :
                                              ("'"+(this.terminals_[symbol] || symbol)+"'"));
                }
                this.parseError(errStr,
                    {text: this.lexer.match, token: this.terminals_[symbol] || symbol, line: this.lexer.yylineno, loc: yyloc, expected: expected});
            }

            // just recovered from another error
            if (recovering == 3) {
                if (symbol == EOF) {
                    throw new Error(errStr || 'Parsing halted.');
                }

                // discard current lookahead and grab another
                yyleng = this.lexer.yyleng;
                yytext = this.lexer.yytext;
                yylineno = this.lexer.yylineno;
                yyloc = this.lexer.yylloc;
                symbol = lex();
            }

            // try to recover from error
            while (1) {
                // check for error recovery rule in this state
                if ((TERROR.toString()) in table[state]) {
                    break;
                }
                if (state == 0) {
                    throw new Error(errStr || 'Parsing halted.');
                }
                popStack(1);
                state = stack[stack.length-1];
            }

            preErrorSymbol = symbol; // save the lookahead token
            symbol = TERROR;         // insert generic error symbol as new lookahead
            state = stack[stack.length-1];
            action = table[state] && table[state][TERROR];
            recovering = 3; // allow 3 real symbols to be shifted before reporting a new error
        }

        // this shouldn't happen, unless resolve defaults are off
        if (action[0] instanceof Array && action.length > 1) {
            throw new Error('Parse Error: multiple actions possible at state: '+state+', token: '+symbol);
        }

        switch (action[0]) {

            case 1: // shift
                //this.shiftCount++;

                stack.push(symbol);
                vstack.push(this.lexer.yytext);
                lstack.push(this.lexer.yylloc);
                stack.push(action[1]); // push state
                symbol = null;
                if (!preErrorSymbol) { // normal execution/no error
                    yyleng = this.lexer.yyleng;
                    yytext = this.lexer.yytext;
                    yylineno = this.lexer.yylineno;
                    yyloc = this.lexer.yylloc;
                    if (recovering > 0)
                        recovering--;
                } else { // error just occurred, resume old lookahead f/ before error
                    symbol = preErrorSymbol;
                    preErrorSymbol = null;
                }
                break;

            case 2: // reduce
                //this.reductionCount++;

                len = this.productions_[action[1]][1];

                // perform semantic action
                yyval.$ = vstack[vstack.length-len]; // default to $$ = $1
                // default location, uses first token for firsts, last for lasts
                yyval._$ = {
                    first_line: lstack[lstack.length-(len||1)].first_line,
                    last_line: lstack[lstack.length-1].last_line,
                    first_column: lstack[lstack.length-(len||1)].first_column,
                    last_column: lstack[lstack.length-1].last_column
                };
                r = this.performAction.call(yyval, yytext, yyleng, yylineno, this.yy, action[1], vstack, lstack);

                if (typeof r !== 'undefined') {
                    return r;
                }

                // pop off stack
                if (len) {
                    stack = stack.slice(0,-1*len*2);
                    vstack = vstack.slice(0, -1*len);
                    lstack = lstack.slice(0, -1*len);
                }

                stack.push(this.productions_[action[1]][0]);    // push nonterminal (reduce)
                vstack.push(yyval.$);
                lstack.push(yyval._$);
                // goto new state = table[STATE][NONTERMINAL]
                newState = table[stack[stack.length-2]][stack[stack.length-1]];
                stack.push(newState);
                break;

            case 3: // accept
                return true;
        }

    }

    return true;
}};
return parser;
})();
if (typeof require !== 'undefined' && typeof exports !== 'undefined') {
exports.parser = parser;
exports.parse = function () { return parser.parse.apply(parser, arguments); }
exports.main = function commonjsMain(args) {
    if (!args[1])
        throw new Error('Usage: '+args[0]+' FILE');
    if (typeof process !== 'undefined') {
        var source = require('fs').readFileSync(require('path').join(process.cwd(), args[1]), "utf8");
    } else {
        var cwd = require("file").path(require("file").cwd());
        var source = cwd.join(args[1]).read({charset: "utf-8"});
    }
    return exports.parser.parse(source);
}
if (typeof module !== 'undefined' && require.main === module) {
  exports.main(typeof process !== 'undefined' ? process.argv.slice(1) : require("system").args);
}
}
};require['./scope'] = new function() {
  var exports = this;
  (function() {
  var Scope, extend, last, _ref;

  _ref = require('./helpers'), extend = _ref.extend, last = _ref.last;

  exports.Scope = Scope = (function() {

    Scope.root = null;

    function Scope(parent, expressions, method) {
      this.parent = parent;
      this.expressions = expressions;
      this.method = method;
      this.variables = [
        {
          name: 'arguments',
          type: 'arguments'
        }
      ];
      this.positions = {};
      if (!this.parent) Scope.root = this;
    }

    Scope.prototype.add = function(name, type, immediate) {
      if (this.shared && !immediate) return this.parent.add(name, type, immediate);
      if (Object.prototype.hasOwnProperty.call(this.positions, name)) {
        return this.variables[this.positions[name]].type = type;
      } else {
        return this.positions[name] = this.variables.push({
          name: name,
          type: type
        }) - 1;
      }
    };

    Scope.prototype.find = function(name, options) {
      if (this.check(name, options)) return true;
      this.add(name, 'var');
      return false;
    };

    Scope.prototype.parameter = function(name) {
      if (this.shared && this.parent.check(name, true)) return;
      return this.add(name, 'param');
    };

    Scope.prototype.check = function(name, immediate) {
      var found, _ref2;
      found = !!this.type(name);
      if (found || immediate) return found;
      return !!((_ref2 = this.parent) != null ? _ref2.check(name) : void 0);
    };

    Scope.prototype.temporary = function(name, index) {
      if (name.length > 1) {
        return '_' + name + (index > 1 ? index : '');
      } else {
        return '_' + (index + parseInt(name, 36)).toString(36).replace(/\d/g, 'a');
      }
    };

    Scope.prototype.type = function(name) {
      var v, _i, _len, _ref2;
      _ref2 = this.variables;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        v = _ref2[_i];
        if (v.name === name) return v.type;
      }
      return null;
    };

    Scope.prototype.freeVariable = function(name, reserve) {
      var index, temp;
      if (reserve == null) reserve = true;
      index = 0;
      while (this.check((temp = this.temporary(name, index)))) {
        index++;
      }
      if (reserve) this.add(temp, 'var', true);
      return temp;
    };

    Scope.prototype.assign = function(name, value) {
      this.add(name, {
        value: value,
        assigned: true
      }, true);
      return this.hasAssignments = true;
    };

    Scope.prototype.hasDeclarations = function() {
      return !!this.declaredVariables().length;
    };

    Scope.prototype.declaredVariables = function() {
      var realVars, tempVars, v, _i, _len, _ref2;
      realVars = [];
      tempVars = [];
      _ref2 = this.variables;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        v = _ref2[_i];
        if (v.type === 'var') {
          (v.name.charAt(0) === '_' ? tempVars : realVars).push(v.name);
        }
      }
      return realVars.sort().concat(tempVars.sort());
    };

    Scope.prototype.assignedVariables = function() {
      var v, _i, _len, _ref2, _results;
      _ref2 = this.variables;
      _results = [];
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        v = _ref2[_i];
        if (v.type.assigned) _results.push("" + v.name + " = " + v.type.value);
      }
      return _results;
    };

    return Scope;

  })();

}).call(this);

};require['./nodes'] = new function() {
  var exports = this;
  (function() {
  var Access, Arr, Assign, Base, Block, Call, Class, Closure, Code, Comment, Existence, Extends, For, IDENTIFIER, IDENTIFIER_STR, IS_STRING, If, In, Index, LEVEL_ACCESS, LEVEL_COND, LEVEL_LIST, LEVEL_OP, LEVEL_PAREN, LEVEL_TOP, Literal, METHOD_DEF, NEGATE, NO, Obj, Op, Param, Parens, RESERVED, Range, Return, SIMPLENUM, Scope, Slice, Splat, Switch, TAB, THIS, Throw, Try, UTILITIES, Value, While, YES, compact, del, ends, extend, flatten, last, merge, multident, starts, unfoldSoak, utility, _ref,
    __hasProp = Object.prototype.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; },
    __indexOf = Array.prototype.indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  Scope = require('./scope').Scope;

  RESERVED = require('./lexer').RESERVED;

  _ref = require('./helpers'), compact = _ref.compact, flatten = _ref.flatten, extend = _ref.extend, merge = _ref.merge, del = _ref.del, starts = _ref.starts, ends = _ref.ends, last = _ref.last;

  exports.extend = extend;

  YES = function() {
    return true;
  };

  NO = function() {
    return false;
  };

  THIS = function() {
    return this;
  };

  NEGATE = function() {
    this.negated = !this.negated;
    return this;
  };

  exports.Base = Base = (function() {

    function Base() {}

    Base.prototype.compile = function(o, lvl) {
      var node;
      o = extend({}, o);
      if (lvl) o.level = lvl;
      node = this.unfoldSoak(o) || this;
      node.tab = o.indent;
      if (o.level === LEVEL_TOP || !node.isStatement(o)) {
        return node.compileNode(o);
      } else {
        return node.compileClosure(o);
      }
    };

    Base.prototype.compileClosure = function(o) {
      if (this.jumps()) {
        throw SyntaxError('cannot use a pure statement in an expression.');
      }
      o.sharedScope = true;
      return Closure.wrap(this).compileNode(o);
    };

    Base.prototype.cache = function(o, level, reused) {
      var ref, sub;
      if (!this.isComplex()) {
        ref = level ? this.compile(o, level) : this;
        return [ref, ref];
      } else {
        ref = new Literal(reused || o.scope.freeVariable('ref'));
        sub = new Assign(ref, this);
        if (level) {
          return [sub.compile(o, level), ref.value];
        } else {
          return [sub, ref];
        }
      }
    };

    Base.prototype.compileLoopReference = function(o, name) {
      var src, tmp;
      src = tmp = this.compile(o, LEVEL_LIST);
      if (!((-Infinity < +src && +src < Infinity) || IDENTIFIER.test(src) && o.scope.check(src, true))) {
        src = "" + (tmp = o.scope.freeVariable(name)) + " = " + src;
      }
      return [src, tmp];
    };

    Base.prototype.makeReturn = function(res) {
      var me;
      me = this.unwrapAll();
      if (res) {
        return new Call(new Literal("" + res + ".push"), [me]);
      } else {
        return new Return(me);
      }
    };

    Base.prototype.contains = function(pred) {
      var contains;
      contains = false;
      this.traverseChildren(false, function(node) {
        if (pred(node)) {
          contains = true;
          return false;
        }
      });
      return contains;
    };

    Base.prototype.containsType = function(type) {
      return this instanceof type || this.contains(function(node) {
        return node instanceof type;
      });
    };

    Base.prototype.lastNonComment = function(list) {
      var i;
      i = list.length;
      while (i--) {
        if (!(list[i] instanceof Comment)) return list[i];
      }
      return null;
    };

    Base.prototype.toString = function(idt, name) {
      var tree;
      if (idt == null) idt = '';
      if (name == null) name = this.constructor.name;
      tree = '\n' + idt + name;
      if (this.soak) tree += '?';
      this.eachChild(function(node) {
        return tree += node.toString(idt + TAB);
      });
      return tree;
    };

    Base.prototype.eachChild = function(func) {
      var attr, child, _i, _j, _len, _len2, _ref2, _ref3;
      if (!this.children) return this;
      _ref2 = this.children;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        attr = _ref2[_i];
        if (this[attr]) {
          _ref3 = flatten([this[attr]]);
          for (_j = 0, _len2 = _ref3.length; _j < _len2; _j++) {
            child = _ref3[_j];
            if (func(child) === false) return this;
          }
        }
      }
      return this;
    };

    Base.prototype.traverseChildren = function(crossScope, func) {
      return this.eachChild(function(child) {
        if (func(child) === false) return false;
        return child.traverseChildren(crossScope, func);
      });
    };

    Base.prototype.invert = function() {
      return new Op('!', this);
    };

    Base.prototype.unwrapAll = function() {
      var node;
      node = this;
      while (node !== (node = node.unwrap())) {
        continue;
      }
      return node;
    };

    Base.prototype.children = [];

    Base.prototype.isStatement = NO;

    Base.prototype.jumps = NO;

    Base.prototype.isComplex = YES;

    Base.prototype.isChainable = NO;

    Base.prototype.isAssignable = NO;

    Base.prototype.unwrap = THIS;

    Base.prototype.unfoldSoak = NO;

    Base.prototype.assigns = NO;

    return Base;

  })();

  exports.Block = Block = (function(_super) {

    __extends(Block, _super);

    function Block(nodes) {
      this.expressions = compact(flatten(nodes || []));
    }

    Block.prototype.children = ['expressions'];

    Block.prototype.push = function(node) {
      this.expressions.push(node);
      return this;
    };

    Block.prototype.pop = function() {
      return this.expressions.pop();
    };

    Block.prototype.unshift = function(node) {
      this.expressions.unshift(node);
      return this;
    };

    Block.prototype.unwrap = function() {
      if (this.expressions.length === 1) {
        return this.expressions[0];
      } else {
        return this;
      }
    };

    Block.prototype.isEmpty = function() {
      return !this.expressions.length;
    };

    Block.prototype.isStatement = function(o) {
      var exp, _i, _len, _ref2;
      _ref2 = this.expressions;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        exp = _ref2[_i];
        if (exp.isStatement(o)) return true;
      }
      return false;
    };

    Block.prototype.jumps = function(o) {
      var exp, _i, _len, _ref2;
      _ref2 = this.expressions;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        exp = _ref2[_i];
        if (exp.jumps(o)) return exp;
      }
    };

    Block.prototype.makeReturn = function(res) {
      var expr, len;
      len = this.expressions.length;
      while (len--) {
        expr = this.expressions[len];
        if (!(expr instanceof Comment)) {
          this.expressions[len] = expr.makeReturn(res);
          if (expr instanceof Return && !expr.expression) {
            this.expressions.splice(len, 1);
          }
          break;
        }
      }
      return this;
    };

    Block.prototype.compile = function(o, level) {
      if (o == null) o = {};
      if (o.scope) {
        return Block.__super__.compile.call(this, o, level);
      } else {
        return this.compileRoot(o);
      }
    };

    Block.prototype.compileNode = function(o) {
      var code, codes, node, top, _i, _len, _ref2;
      this.tab = o.indent;
      top = o.level === LEVEL_TOP;
      codes = [];
      _ref2 = this.expressions;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        node = _ref2[_i];
        node = node.unwrapAll();
        node = node.unfoldSoak(o) || node;
        if (node instanceof Block) {
          codes.push(node.compileNode(o));
        } else if (top) {
          node.front = true;
          code = node.compile(o);
          codes.push(node.isStatement(o) ? code : "" + this.tab + code + ";");
        } else {
          codes.push(node.compile(o, LEVEL_LIST));
        }
      }
      if (top) {
        if (this.spaced) {
          return "\n" + (codes.join('\n\n')) + "\n";
        } else {
          return codes.join('\n');
        }
      }
      code = codes.join(', ') || 'void 0';
      if (codes.length > 1 && o.level >= LEVEL_LIST) {
        return "(" + code + ")";
      } else {
        return code;
      }
    };

    Block.prototype.compileRoot = function(o) {
      var code, exp, i, prelude, preludeExps, rest;
      o.indent = o.bare ? '' : TAB;
      o.scope = new Scope(null, this, null);
      o.level = LEVEL_TOP;
      this.spaced = true;
      prelude = "";
      if (!o.bare) {
        preludeExps = (function() {
          var _len, _ref2, _results;
          _ref2 = this.expressions;
          _results = [];
          for (i = 0, _len = _ref2.length; i < _len; i++) {
            exp = _ref2[i];
            if (!(exp.unwrap() instanceof Comment)) break;
            _results.push(exp);
          }
          return _results;
        }).call(this);
        rest = this.expressions.slice(preludeExps.length);
        this.expressions = preludeExps;
        if (preludeExps.length) {
          prelude = "" + (this.compileNode(merge(o, {
            indent: ''
          }))) + "\n";
        }
        this.expressions = rest;
      }
      code = this.compileWithDeclarations(o);
      if (o.bare) return code;
      return "" + prelude + "(function() {\n" + code + "\n}).call(this);\n";
    };

    Block.prototype.compileWithDeclarations = function(o) {
      var assigns, code, declars, exp, i, post, rest, scope, spaced, _len, _ref2, _ref3, _ref4;
      code = post = '';
      _ref2 = this.expressions;
      for (i = 0, _len = _ref2.length; i < _len; i++) {
        exp = _ref2[i];
        exp = exp.unwrap();
        if (!(exp instanceof Comment || exp instanceof Literal)) break;
      }
      o = merge(o, {
        level: LEVEL_TOP
      });
      if (i) {
        rest = this.expressions.splice(i, 9e9);
        _ref3 = [this.spaced, false], spaced = _ref3[0], this.spaced = _ref3[1];
        _ref4 = [this.compileNode(o), spaced], code = _ref4[0], this.spaced = _ref4[1];
        this.expressions = rest;
      }
      post = this.compileNode(o);
      scope = o.scope;
      if (scope.expressions === this) {
        declars = o.scope.hasDeclarations();
        assigns = scope.hasAssignments;
        if (declars || assigns) {
          if (i) code += '\n';
          code += "" + this.tab + "var ";
          if (declars) code += scope.declaredVariables().join(', ');
          if (assigns) {
            if (declars) code += ",\n" + (this.tab + TAB);
            code += scope.assignedVariables().join(",\n" + (this.tab + TAB));
          }
          code += ';\n';
        }
      }
      return code + post;
    };

    Block.wrap = function(nodes) {
      if (nodes.length === 1 && nodes[0] instanceof Block) return nodes[0];
      return new Block(nodes);
    };

    return Block;

  })(Base);

  exports.Literal = Literal = (function(_super) {

    __extends(Literal, _super);

    function Literal(value) {
      this.value = value;
    }

    Literal.prototype.makeReturn = function() {
      if (this.isStatement()) {
        return this;
      } else {
        return Literal.__super__.makeReturn.apply(this, arguments);
      }
    };

    Literal.prototype.isAssignable = function() {
      return IDENTIFIER.test(this.value);
    };

    Literal.prototype.isStatement = function() {
      var _ref2;
      return (_ref2 = this.value) === 'break' || _ref2 === 'continue' || _ref2 === 'debugger';
    };

    Literal.prototype.isComplex = NO;

    Literal.prototype.assigns = function(name) {
      return name === this.value;
    };

    Literal.prototype.jumps = function(o) {
      if (this.value === 'break' && !((o != null ? o.loop : void 0) || (o != null ? o.block : void 0))) {
        return this;
      }
      if (this.value === 'continue' && !(o != null ? o.loop : void 0)) return this;
    };

    Literal.prototype.compileNode = function(o) {
      var code, _ref2, _ref3;
      code = this.isUndefined ? o.level >= LEVEL_ACCESS ? '(void 0)' : 'void 0' : this.value === 'this' ? ((_ref2 = o.scope.method) != null ? _ref2.bound : void 0) ? o.scope.method.context : this.value : this.value.reserved && ((_ref3 = "" + this.value) !== 'eval' && _ref3 !== 'arguments') ? "\"" + this.value + "\"" : this.value;
      if (this.isStatement()) {
        return "" + this.tab + code + ";";
      } else {
        return code;
      }
    };

    Literal.prototype.toString = function() {
      return ' "' + this.value + '"';
    };

    return Literal;

  })(Base);

  exports.Return = Return = (function(_super) {

    __extends(Return, _super);

    function Return(expr) {
      if (expr && !expr.unwrap().isUndefined) this.expression = expr;
    }

    Return.prototype.children = ['expression'];

    Return.prototype.isStatement = YES;

    Return.prototype.makeReturn = THIS;

    Return.prototype.jumps = THIS;

    Return.prototype.compile = function(o, level) {
      var expr, _ref2;
      expr = (_ref2 = this.expression) != null ? _ref2.makeReturn() : void 0;
      if (expr && !(expr instanceof Return)) {
        return expr.compile(o, level);
      } else {
        return Return.__super__.compile.call(this, o, level);
      }
    };

    Return.prototype.compileNode = function(o) {
      return this.tab + ("return" + [this.expression ? " " + (this.expression.compile(o, LEVEL_PAREN)) : void 0] + ";");
    };

    return Return;

  })(Base);

  exports.Value = Value = (function(_super) {

    __extends(Value, _super);

    function Value(base, props, tag) {
      if (!props && base instanceof Value) return base;
      this.base = base;
      this.properties = props || [];
      if (tag) this[tag] = true;
      return this;
    }

    Value.prototype.children = ['base', 'properties'];

    Value.prototype.add = function(props) {
      this.properties = this.properties.concat(props);
      return this;
    };

    Value.prototype.hasProperties = function() {
      return !!this.properties.length;
    };

    Value.prototype.isArray = function() {
      return !this.properties.length && this.base instanceof Arr;
    };

    Value.prototype.isComplex = function() {
      return this.hasProperties() || this.base.isComplex();
    };

    Value.prototype.isAssignable = function() {
      return this.hasProperties() || this.base.isAssignable();
    };

    Value.prototype.isSimpleNumber = function() {
      return this.base instanceof Literal && SIMPLENUM.test(this.base.value);
    };

    Value.prototype.isAtomic = function() {
      var node, _i, _len, _ref2;
      _ref2 = this.properties.concat(this.base);
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        node = _ref2[_i];
        if (node.soak || node instanceof Call) return false;
      }
      return true;
    };

    Value.prototype.isStatement = function(o) {
      return !this.properties.length && this.base.isStatement(o);
    };

    Value.prototype.assigns = function(name) {
      return !this.properties.length && this.base.assigns(name);
    };

    Value.prototype.jumps = function(o) {
      return !this.properties.length && this.base.jumps(o);
    };

    Value.prototype.isObject = function(onlyGenerated) {
      if (this.properties.length) return false;
      return (this.base instanceof Obj) && (!onlyGenerated || this.base.generated);
    };

    Value.prototype.isSplice = function() {
      return last(this.properties) instanceof Slice;
    };

    Value.prototype.unwrap = function() {
      if (this.properties.length) {
        return this;
      } else {
        return this.base;
      }
    };

    Value.prototype.cacheReference = function(o) {
      var base, bref, name, nref;
      name = last(this.properties);
      if (this.properties.length < 2 && !this.base.isComplex() && !(name != null ? name.isComplex() : void 0)) {
        return [this, this];
      }
      base = new Value(this.base, this.properties.slice(0, -1));
      if (base.isComplex()) {
        bref = new Literal(o.scope.freeVariable('base'));
        base = new Value(new Parens(new Assign(bref, base)));
      }
      if (!name) return [base, bref];
      if (name.isComplex()) {
        nref = new Literal(o.scope.freeVariable('name'));
        name = new Index(new Assign(nref, name.index));
        nref = new Index(nref);
      }
      return [base.add(name), new Value(bref || base.base, [nref || name])];
    };

    Value.prototype.compileNode = function(o) {
      var code, prop, props, _i, _len;
      this.base.front = this.front;
      props = this.properties;
      code = this.base.compile(o, props.length ? LEVEL_ACCESS : null);
      if ((this.base instanceof Parens || props.length) && SIMPLENUM.test(code)) {
        code = "" + code + ".";
      }
      for (_i = 0, _len = props.length; _i < _len; _i++) {
        prop = props[_i];
        code += prop.compile(o);
      }
      return code;
    };

    Value.prototype.unfoldSoak = function(o) {
      var result,
        _this = this;
      if (this.unfoldedSoak != null) return this.unfoldedSoak;
      result = (function() {
        var fst, i, ifn, prop, ref, snd, _len, _ref2;
        if (ifn = _this.base.unfoldSoak(o)) {
          Array.prototype.push.apply(ifn.body.properties, _this.properties);
          return ifn;
        }
        _ref2 = _this.properties;
        for (i = 0, _len = _ref2.length; i < _len; i++) {
          prop = _ref2[i];
          if (!prop.soak) continue;
          prop.soak = false;
          fst = new Value(_this.base, _this.properties.slice(0, i));
          snd = new Value(_this.base, _this.properties.slice(i));
          if (fst.isComplex()) {
            ref = new Literal(o.scope.freeVariable('ref'));
            fst = new Parens(new Assign(ref, fst));
            snd.base = ref;
          }
          return new If(new Existence(fst), snd, {
            soak: true
          });
        }
        return null;
      })();
      return this.unfoldedSoak = result || false;
    };

    return Value;

  })(Base);

  exports.Comment = Comment = (function(_super) {

    __extends(Comment, _super);

    function Comment(comment) {
      this.comment = comment;
    }

    Comment.prototype.isStatement = YES;

    Comment.prototype.makeReturn = THIS;

    Comment.prototype.compileNode = function(o, level) {
      var code;
      code = '/*' + multident(this.comment, this.tab) + ("\n" + this.tab + "*/");
      if ((level || o.level) === LEVEL_TOP) code = o.indent + code;
      return code;
    };

    return Comment;

  })(Base);

  exports.Call = Call = (function(_super) {

    __extends(Call, _super);

    function Call(variable, args, soak) {
      this.args = args != null ? args : [];
      this.soak = soak;
      this.isNew = false;
      this.isSuper = variable === 'super';
      this.variable = this.isSuper ? null : variable;
    }

    Call.prototype.children = ['variable', 'args'];

    Call.prototype.newInstance = function() {
      var base, _ref2;
      base = ((_ref2 = this.variable) != null ? _ref2.base : void 0) || this.variable;
      if (base instanceof Call && !base.isNew) {
        base.newInstance();
      } else {
        this.isNew = true;
      }
      return this;
    };

    Call.prototype.superReference = function(o) {
      var accesses, method, name;
      method = o.scope.method;
      if (!method) throw SyntaxError('cannot call super outside of a function.');
      name = method.name;
      if (name == null) {
        throw SyntaxError('cannot call super on an anonymous function.');
      }
      if (method.klass) {
        accesses = [new Access(new Literal('__super__'))];
        if (method.static) accesses.push(new Access(new Literal('constructor')));
        accesses.push(new Access(new Literal(name)));
        return (new Value(new Literal(method.klass), accesses)).compile(o);
      } else {
        return "" + name + ".__super__.constructor";
      }
    };

    Call.prototype.unfoldSoak = function(o) {
      var call, ifn, left, list, rite, _i, _len, _ref2, _ref3;
      if (this.soak) {
        if (this.variable) {
          if (ifn = unfoldSoak(o, this, 'variable')) return ifn;
          _ref2 = new Value(this.variable).cacheReference(o), left = _ref2[0], rite = _ref2[1];
        } else {
          left = new Literal(this.superReference(o));
          rite = new Value(left);
        }
        rite = new Call(rite, this.args);
        rite.isNew = this.isNew;
        left = new Literal("typeof " + (left.compile(o)) + " === \"function\"");
        return new If(left, new Value(rite), {
          soak: true
        });
      }
      call = this;
      list = [];
      while (true) {
        if (call.variable instanceof Call) {
          list.push(call);
          call = call.variable;
          continue;
        }
        if (!(call.variable instanceof Value)) break;
        list.push(call);
        if (!((call = call.variable.base) instanceof Call)) break;
      }
      _ref3 = list.reverse();
      for (_i = 0, _len = _ref3.length; _i < _len; _i++) {
        call = _ref3[_i];
        if (ifn) {
          if (call.variable instanceof Call) {
            call.variable = ifn;
          } else {
            call.variable.base = ifn;
          }
        }
        ifn = unfoldSoak(o, call, 'variable');
      }
      return ifn;
    };

    Call.prototype.filterImplicitObjects = function(list) {
      var node, nodes, obj, prop, properties, _i, _j, _len, _len2, _ref2;
      nodes = [];
      for (_i = 0, _len = list.length; _i < _len; _i++) {
        node = list[_i];
        if (!((typeof node.isObject === "function" ? node.isObject() : void 0) && node.base.generated)) {
          nodes.push(node);
          continue;
        }
        obj = null;
        _ref2 = node.base.properties;
        for (_j = 0, _len2 = _ref2.length; _j < _len2; _j++) {
          prop = _ref2[_j];
          if (prop instanceof Assign || prop instanceof Comment) {
            if (!obj) nodes.push(obj = new Obj(properties = [], true));
            properties.push(prop);
          } else {
            nodes.push(prop);
            obj = null;
          }
        }
      }
      return nodes;
    };

    Call.prototype.compileNode = function(o) {
      var arg, args, code, _ref2;
      if ((_ref2 = this.variable) != null) _ref2.front = this.front;
      if (code = Splat.compileSplattedArray(o, this.args, true)) {
        return this.compileSplat(o, code);
      }
      args = this.filterImplicitObjects(this.args);
      args = ((function() {
        var _i, _len, _results;
        _results = [];
        for (_i = 0, _len = args.length; _i < _len; _i++) {
          arg = args[_i];
          _results.push(arg.compile(o, LEVEL_LIST));
        }
        return _results;
      })()).join(', ');
      if (this.isSuper) {
        return this.superReference(o) + (".call(this" + (args && ', ' + args) + ")");
      } else {
        return (this.isNew ? 'new ' : '') + this.variable.compile(o, LEVEL_ACCESS) + ("(" + args + ")");
      }
    };

    Call.prototype.compileSuper = function(args, o) {
      return "" + (this.superReference(o)) + ".call(this" + (args.length ? ', ' : '') + args + ")";
    };

    Call.prototype.compileSplat = function(o, splatArgs) {
      var base, fun, idt, name, ref;
      if (this.isSuper) {
        return "" + (this.superReference(o)) + ".apply(this, " + splatArgs + ")";
      }
      if (this.isNew) {
        idt = this.tab + TAB;
        return "(function(func, args, ctor) {\n" + idt + "ctor.prototype = func.prototype;\n" + idt + "var child = new ctor, result = func.apply(child, args);\n" + idt + "return typeof result === \"object\" ? result : child;\n" + this.tab + "})(" + (this.variable.compile(o, LEVEL_LIST)) + ", " + splatArgs + ", function() {})";
      }
      base = new Value(this.variable);
      if ((name = base.properties.pop()) && base.isComplex()) {
        ref = o.scope.freeVariable('ref');
        fun = "(" + ref + " = " + (base.compile(o, LEVEL_LIST)) + ")" + (name.compile(o));
      } else {
        fun = base.compile(o, LEVEL_ACCESS);
        if (SIMPLENUM.test(fun)) fun = "(" + fun + ")";
        if (name) {
          ref = fun;
          fun += name.compile(o);
        } else {
          ref = 'null';
        }
      }
      return "" + fun + ".apply(" + ref + ", " + splatArgs + ")";
    };

    return Call;

  })(Base);

  exports.Extends = Extends = (function(_super) {

    __extends(Extends, _super);

    function Extends(child, parent) {
      this.child = child;
      this.parent = parent;
    }

    Extends.prototype.children = ['child', 'parent'];

    Extends.prototype.compile = function(o) {
      return new Call(new Value(new Literal(utility('extends'))), [this.child, this.parent]).compile(o);
    };

    return Extends;

  })(Base);

  exports.Access = Access = (function(_super) {

    __extends(Access, _super);

    function Access(name, tag) {
      this.name = name;
      this.name.asKey = true;
      this.soak = tag === 'soak';
    }

    Access.prototype.children = ['name'];

    Access.prototype.compile = function(o) {
      var name;
      name = this.name.compile(o);
      if (IDENTIFIER.test(name)) {
        return "." + name;
      } else {
        return "[" + name + "]";
      }
    };

    Access.prototype.isComplex = NO;

    return Access;

  })(Base);

  exports.Index = Index = (function(_super) {

    __extends(Index, _super);

    function Index(index) {
      this.index = index;
    }

    Index.prototype.children = ['index'];

    Index.prototype.compile = function(o) {
      return "[" + (this.index.compile(o, LEVEL_PAREN)) + "]";
    };

    Index.prototype.isComplex = function() {
      return this.index.isComplex();
    };

    return Index;

  })(Base);

  exports.Range = Range = (function(_super) {

    __extends(Range, _super);

    Range.prototype.children = ['from', 'to'];

    function Range(from, to, tag) {
      this.from = from;
      this.to = to;
      this.exclusive = tag === 'exclusive';
      this.equals = this.exclusive ? '' : '=';
    }

    Range.prototype.compileVariables = function(o) {
      var step, _ref2, _ref3, _ref4, _ref5;
      o = merge(o, {
        top: true
      });
      _ref2 = this.from.cache(o, LEVEL_LIST), this.fromC = _ref2[0], this.fromVar = _ref2[1];
      _ref3 = this.to.cache(o, LEVEL_LIST), this.toC = _ref3[0], this.toVar = _ref3[1];
      if (step = del(o, 'step')) {
        _ref4 = step.cache(o, LEVEL_LIST), this.step = _ref4[0], this.stepVar = _ref4[1];
      }
      _ref5 = [this.fromVar.match(SIMPLENUM), this.toVar.match(SIMPLENUM)], this.fromNum = _ref5[0], this.toNum = _ref5[1];
      if (this.stepVar) return this.stepNum = this.stepVar.match(SIMPLENUM);
    };

    Range.prototype.compileNode = function(o) {
      var cond, condPart, from, gt, idx, known, lt, stepPart, to, varPart, _ref2, _ref3;
      if (!this.fromVar) this.compileVariables(o);
      if (!o.index) return this.compileArray(o);
      known = this.fromNum && this.toNum;
      idx = del(o, 'index');
      varPart = "" + idx + " = " + this.fromC;
      if (this.toC !== this.toVar) varPart += ", " + this.toC;
      if (this.step !== this.stepVar) varPart += ", " + this.step;
      _ref2 = ["" + idx + " <" + this.equals, "" + idx + " >" + this.equals], lt = _ref2[0], gt = _ref2[1];
      condPart = this.stepNum ? +this.stepNum > 0 ? "" + lt + " " + this.toVar : "" + gt + " " + this.toVar : known ? ((_ref3 = [+this.fromNum, +this.toNum], from = _ref3[0], to = _ref3[1], _ref3), from <= to ? "" + lt + " " + to : "" + gt + " " + to) : (cond = "" + this.fromVar + " <= " + this.toVar, "" + cond + " ? " + lt + " " + this.toVar + " : " + gt + " " + this.toVar);
      stepPart = this.stepVar ? "" + idx + " += " + this.stepVar : known ? from <= to ? "" + idx + "++" : "" + idx + "--" : "" + cond + " ? " + idx + "++ : " + idx + "--";
      return "" + varPart + "; " + condPart + "; " + stepPart;
    };

    Range.prototype.compileArray = function(o) {
      var args, body, cond, hasArgs, i, idt, post, pre, range, result, vars, _i, _ref2, _ref3, _results;
      if (this.fromNum && this.toNum && Math.abs(this.fromNum - this.toNum) <= 20) {
        range = (function() {
          _results = [];
          for (var _i = _ref2 = +this.fromNum, _ref3 = +this.toNum; _ref2 <= _ref3 ? _i <= _ref3 : _i >= _ref3; _ref2 <= _ref3 ? _i++ : _i--){ _results.push(_i); }
          return _results;
        }).apply(this);
        if (this.exclusive) range.pop();
        return "[" + (range.join(', ')) + "]";
      }
      idt = this.tab + TAB;
      i = o.scope.freeVariable('i');
      result = o.scope.freeVariable('results');
      pre = "\n" + idt + result + " = [];";
      if (this.fromNum && this.toNum) {
        o.index = i;
        body = this.compileNode(o);
      } else {
        vars = ("" + i + " = " + this.fromC) + (this.toC !== this.toVar ? ", " + this.toC : '');
        cond = "" + this.fromVar + " <= " + this.toVar;
        body = "var " + vars + "; " + cond + " ? " + i + " <" + this.equals + " " + this.toVar + " : " + i + " >" + this.equals + " " + this.toVar + "; " + cond + " ? " + i + "++ : " + i + "--";
      }
      post = "{ " + result + ".push(" + i + "); }\n" + idt + "return " + result + ";\n" + o.indent;
      hasArgs = function(node) {
        return node != null ? node.contains(function(n) {
          return n instanceof Literal && n.value === 'arguments' && !n.asKey;
        }) : void 0;
      };
      if (hasArgs(this.from) || hasArgs(this.to)) args = ', arguments';
      return "(function() {" + pre + "\n" + idt + "for (" + body + ")" + post + "}).apply(this" + (args != null ? args : '') + ")";
    };

    return Range;

  })(Base);

  exports.Slice = Slice = (function(_super) {

    __extends(Slice, _super);

    Slice.prototype.children = ['range'];

    function Slice(range) {
      this.range = range;
      Slice.__super__.constructor.call(this);
    }

    Slice.prototype.compileNode = function(o) {
      var compiled, from, fromStr, to, toStr, _ref2;
      _ref2 = this.range, to = _ref2.to, from = _ref2.from;
      fromStr = from && from.compile(o, LEVEL_PAREN) || '0';
      compiled = to && to.compile(o, LEVEL_ACCESS);
      if (to && !(!this.range.exclusive && +compiled === -1)) {
        toStr = ', ' + (this.range.exclusive ? compiled : SIMPLENUM.test(compiled) ? (+compiled + 1).toString() : "" + compiled + " + 1 || 9e9");
      }
      return ".slice(" + fromStr + (toStr || '') + ")";
    };

    return Slice;

  })(Base);

  exports.Obj = Obj = (function(_super) {

    __extends(Obj, _super);

    function Obj(props, generated) {
      this.generated = generated != null ? generated : false;
      this.objects = this.properties = props || [];
    }

    Obj.prototype.children = ['properties'];

    Obj.prototype.compileNode = function(o) {
      var i, idt, indent, join, lastNoncom, node, obj, prop, props, _i, _len;
      props = this.properties;
      if (!props.length) return (this.front ? '({})' : '{}');
      if (this.generated) {
        for (_i = 0, _len = props.length; _i < _len; _i++) {
          node = props[_i];
          if (node instanceof Value) {
            throw new Error('cannot have an implicit value in an implicit object');
          }
        }
      }
      idt = o.indent += TAB;
      lastNoncom = this.lastNonComment(this.properties);
      props = (function() {
        var _len2, _results;
        _results = [];
        for (i = 0, _len2 = props.length; i < _len2; i++) {
          prop = props[i];
          join = i === props.length - 1 ? '' : prop === lastNoncom || prop instanceof Comment ? '\n' : ',\n';
          indent = prop instanceof Comment ? '' : idt;
          if (prop instanceof Value && prop["this"]) {
            prop = new Assign(prop.properties[0].name, prop, 'object');
          }
          if (!(prop instanceof Comment)) {
            if (!(prop instanceof Assign)) prop = new Assign(prop, prop, 'object');
            (prop.variable.base || prop.variable).asKey = true;
          }
          _results.push(indent + prop.compile(o, LEVEL_TOP) + join);
        }
        return _results;
      })();
      props = props.join('');
      obj = "{" + (props && '\n' + props + '\n' + this.tab) + "}";
      if (this.front) {
        return "(" + obj + ")";
      } else {
        return obj;
      }
    };

    Obj.prototype.assigns = function(name) {
      var prop, _i, _len, _ref2;
      _ref2 = this.properties;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        prop = _ref2[_i];
        if (prop.assigns(name)) return true;
      }
      return false;
    };

    return Obj;

  })(Base);

  exports.Arr = Arr = (function(_super) {

    __extends(Arr, _super);

    function Arr(objs) {
      this.objects = objs || [];
    }

    Arr.prototype.children = ['objects'];

    Arr.prototype.filterImplicitObjects = Call.prototype.filterImplicitObjects;

    Arr.prototype.compileNode = function(o) {
      var code, obj, objs;
      if (!this.objects.length) return '[]';
      o.indent += TAB;
      objs = this.filterImplicitObjects(this.objects);
      if (code = Splat.compileSplattedArray(o, objs)) return code;
      code = ((function() {
        var _i, _len, _results;
        _results = [];
        for (_i = 0, _len = objs.length; _i < _len; _i++) {
          obj = objs[_i];
          _results.push(obj.compile(o, LEVEL_LIST));
        }
        return _results;
      })()).join(', ');
      if (code.indexOf('\n') >= 0) {
        return "[\n" + o.indent + code + "\n" + this.tab + "]";
      } else {
        return "[" + code + "]";
      }
    };

    Arr.prototype.assigns = function(name) {
      var obj, _i, _len, _ref2;
      _ref2 = this.objects;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        obj = _ref2[_i];
        if (obj.assigns(name)) return true;
      }
      return false;
    };

    return Arr;

  })(Base);

  exports.Class = Class = (function(_super) {

    __extends(Class, _super);

    function Class(variable, parent, body) {
      this.variable = variable;
      this.parent = parent;
      this.body = body != null ? body : new Block;
      this.boundFuncs = [];
      this.body.classBody = true;
    }

    Class.prototype.children = ['variable', 'parent', 'body'];

    Class.prototype.determineName = function() {
      var decl, tail;
      if (!this.variable) return null;
      decl = (tail = last(this.variable.properties)) ? tail instanceof Access && tail.name.value : this.variable.base.value;
      return decl && (decl = IDENTIFIER.test(decl) && decl);
    };

    Class.prototype.setContext = function(name) {
      return this.body.traverseChildren(false, function(node) {
        if (node.classBody) return false;
        if (node instanceof Literal && node.value === 'this') {
          return node.value = name;
        } else if (node instanceof Code) {
          node.klass = name;
          if (node.bound) return node.context = name;
        }
      });
    };

    Class.prototype.addBoundFunctions = function(o) {
      var bvar, lhs, _i, _len, _ref2, _results;
      if (this.boundFuncs.length) {
        _ref2 = this.boundFuncs;
        _results = [];
        for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
          bvar = _ref2[_i];
          lhs = (new Value(new Literal("this"), [new Access(bvar)])).compile(o);
          _results.push(this.ctor.body.unshift(new Literal("" + lhs + " = " + (utility('bind')) + "(" + lhs + ", this)")));
        }
        return _results;
      }
    };

    Class.prototype.addProperties = function(node, name, o) {
      var assign, base, exprs, func, props;
      props = node.base.properties.slice(0);
      exprs = (function() {
        var _results;
        _results = [];
        while (assign = props.shift()) {
          if (assign instanceof Assign) {
            base = assign.variable.base;
            delete assign.context;
            func = assign.value;
            if (base.value === 'constructor') {
              if (this.ctor) {
                throw new Error('cannot define more than one constructor in a class');
              }
              if (func.bound) {
                throw new Error('cannot define a constructor as a bound function');
              }
              if (func instanceof Code) {
                assign = this.ctor = func;
              } else {
                this.externalCtor = o.scope.freeVariable('class');
                assign = new Assign(new Literal(this.externalCtor), func);
              }
            } else {
              if (assign.variable["this"]) {
                func.static = true;
                if (func.bound) func.context = name;
              } else {
                assign.variable = new Value(new Literal(name), [new Access(new Literal('prototype')), new Access(base)]);
                if (func instanceof Code && func.bound) {
                  this.boundFuncs.push(base);
                  func.bound = false;
                }
              }
            }
          }
          _results.push(assign);
        }
        return _results;
      }).call(this);
      return compact(exprs);
    };

    Class.prototype.walkBody = function(name, o) {
      var _this = this;
      return this.traverseChildren(false, function(child) {
        var exps, i, node, _len, _ref2;
        if (child instanceof Class) return false;
        if (child instanceof Block) {
          _ref2 = exps = child.expressions;
          for (i = 0, _len = _ref2.length; i < _len; i++) {
            node = _ref2[i];
            if (node instanceof Value && node.isObject(true)) {
              exps[i] = _this.addProperties(node, name, o);
            }
          }
          return child.expressions = exps = flatten(exps);
        }
      });
    };

    Class.prototype.ensureConstructor = function(name) {
      if (!this.ctor) {
        this.ctor = new Code;
        if (this.parent) {
          this.ctor.body.push(new Literal("" + name + ".__super__.constructor.apply(this, arguments)"));
        }
        if (this.externalCtor) {
          this.ctor.body.push(new Literal("" + this.externalCtor + ".apply(this, arguments)"));
        }
        this.body.expressions.unshift(this.ctor);
      }
      this.ctor.ctor = this.ctor.name = name;
      this.ctor.klass = null;
      return this.ctor.noReturn = true;
    };

    Class.prototype.compileNode = function(o) {
      var call, decl, klass, lname, name;
      decl = this.determineName();
      name = decl || this.name || '_Class';
      if (name.reserved) name = "_" + name;
      lname = new Literal(name);
      this.setContext(name);
      this.walkBody(name, o);
      this.ensureConstructor(name);
      this.body.spaced = true;
      if (!(this.ctor instanceof Code)) this.body.expressions.unshift(this.ctor);
      this.body.expressions.push(lname);
      this.addBoundFunctions(o);
      call = Closure.wrap(this.body);
      if (this.parent) {
        this.superClass = new Literal(o.scope.freeVariable('super', false));
        this.body.expressions.unshift(new Extends(lname, this.superClass));
        call.args.push(this.parent);
        call.variable.params.push(new Param(this.superClass));
      }
      klass = new Parens(call, true);
      if (this.variable) klass = new Assign(this.variable, klass);
      return klass.compile(o);
    };

    return Class;

  })(Base);

  exports.Assign = Assign = (function(_super) {

    __extends(Assign, _super);

    function Assign(variable, value, context, options) {
      this.variable = variable;
      this.value = value;
      this.context = context;
      this.param = options && options.param;
      this.subpattern = options && options.subpattern;
    }

    Assign.prototype.children = ['variable', 'value'];

    Assign.prototype.isStatement = function(o) {
      return (o != null ? o.level : void 0) === LEVEL_TOP && (this.context != null) && __indexOf.call(this.context, "?") >= 0;
    };

    Assign.prototype.assigns = function(name) {
      return this[this.context === 'object' ? 'value' : 'variable'].assigns(name);
    };

    Assign.prototype.unfoldSoak = function(o) {
      return unfoldSoak(o, this, 'variable');
    };

    Assign.prototype.compileNode = function(o) {
      var isValue, match, name, val, varBase, _ref2, _ref3, _ref4, _ref5;
      if (isValue = this.variable instanceof Value) {
        if (this.variable.isArray() || this.variable.isObject()) {
          return this.compilePatternMatch(o);
        }
        if (this.variable.isSplice()) return this.compileSplice(o);
        if ((_ref2 = this.context) === '||=' || _ref2 === '&&=' || _ref2 === '?=') {
          return this.compileConditional(o);
        }
      }
      name = this.variable.compile(o, LEVEL_LIST);
      if (!this.context) {
        if (!(varBase = this.variable.unwrapAll()).isAssignable()) {
          throw SyntaxError("\"" + (this.variable.compile(o)) + "\" cannot be assigned.");
        }
        if (!(typeof varBase.hasProperties === "function" ? varBase.hasProperties() : void 0)) {
          if (this.param) {
            o.scope.add(name, 'var');
          } else {
            o.scope.find(name);
          }
        }
      }
      if (this.value instanceof Code && (match = METHOD_DEF.exec(name))) {
        if (match[1]) this.value.klass = match[1];
        this.value.name = (_ref3 = (_ref4 = (_ref5 = match[2]) != null ? _ref5 : match[3]) != null ? _ref4 : match[4]) != null ? _ref3 : match[5];
      }
      val = this.value.compile(o, LEVEL_LIST);
      if (this.context === 'object') return "" + name + ": " + val;
      val = name + (" " + (this.context || '=') + " ") + val;
      if (o.level <= LEVEL_LIST) {
        return val;
      } else {
        return "(" + val + ")";
      }
    };

    Assign.prototype.compilePatternMatch = function(o) {
      var acc, assigns, code, i, idx, isObject, ivar, name, obj, objects, olen, ref, rest, splat, top, val, value, vvar, _len, _ref2, _ref3, _ref4, _ref5, _ref6, _ref7, _ref8;
      top = o.level === LEVEL_TOP;
      value = this.value;
      objects = this.variable.base.objects;
      if (!(olen = objects.length)) {
        code = value.compile(o);
        if (o.level >= LEVEL_OP) {
          return "(" + code + ")";
        } else {
          return code;
        }
      }
      isObject = this.variable.isObject();
      if (top && olen === 1 && !((obj = objects[0]) instanceof Splat)) {
        if (obj instanceof Assign) {
          _ref2 = obj, (_ref3 = _ref2.variable, idx = _ref3.base), obj = _ref2.value;
        } else {
          if (obj.base instanceof Parens) {
            _ref4 = new Value(obj.unwrapAll()).cacheReference(o), obj = _ref4[0], idx = _ref4[1];
          } else {
            idx = isObject ? obj["this"] ? obj.properties[0].name : obj : new Literal(0);
          }
        }
        acc = IDENTIFIER.test(idx.unwrap().value || 0);
        value = new Value(value);
        value.properties.push(new (acc ? Access : Index)(idx));
        if (_ref5 = obj.unwrap().value, __indexOf.call(['arguments', 'eval'].concat(RESERVED), _ref5) >= 0) {
          throw new SyntaxError("assignment to a reserved word: " + (obj.compile(o)) + " = " + (value.compile(o)));
        }
        return new Assign(obj, value, null, {
          param: this.param
        }).compile(o, LEVEL_TOP);
      }
      vvar = value.compile(o, LEVEL_LIST);
      assigns = [];
      splat = false;
      if (!IDENTIFIER.test(vvar) || this.variable.assigns(vvar)) {
        assigns.push("" + (ref = o.scope.freeVariable('ref')) + " = " + vvar);
        vvar = ref;
      }
      for (i = 0, _len = objects.length; i < _len; i++) {
        obj = objects[i];
        idx = i;
        if (isObject) {
          if (obj instanceof Assign) {
            _ref6 = obj, (_ref7 = _ref6.variable, idx = _ref7.base), obj = _ref6.value;
          } else {
            if (obj.base instanceof Parens) {
              _ref8 = new Value(obj.unwrapAll()).cacheReference(o), obj = _ref8[0], idx = _ref8[1];
            } else {
              idx = obj["this"] ? obj.properties[0].name : obj;
            }
          }
        }
        if (!splat && obj instanceof Splat) {
          name = obj.name.unwrap().value;
          obj = obj.unwrap();
          val = "" + olen + " <= " + vvar + ".length ? " + (utility('slice')) + ".call(" + vvar + ", " + i;
          if (rest = olen - i - 1) {
            ivar = o.scope.freeVariable('i');
            val += ", " + ivar + " = " + vvar + ".length - " + rest + ") : (" + ivar + " = " + i + ", [])";
          } else {
            val += ") : []";
          }
          val = new Literal(val);
          splat = "" + ivar + "++";
        } else {
          name = obj.unwrap().value;
          if (obj instanceof Splat) {
            obj = obj.name.compile(o);
            throw new SyntaxError("multiple splats are disallowed in an assignment: " + obj + "...");
          }
          if (typeof idx === 'number') {
            idx = new Literal(splat || idx);
            acc = false;
          } else {
            acc = isObject && IDENTIFIER.test(idx.unwrap().value || 0);
          }
          val = new Value(new Literal(vvar), [new (acc ? Access : Index)(idx)]);
        }
        if ((name != null) && __indexOf.call(['arguments', 'eval'].concat(RESERVED), name) >= 0) {
          throw new SyntaxError("assignment to a reserved word: " + (obj.compile(o)) + " = " + (val.compile(o)));
        }
        assigns.push(new Assign(obj, val, null, {
          param: this.param,
          subpattern: true
        }).compile(o, LEVEL_LIST));
      }
      if (!(top || this.subpattern)) assigns.push(vvar);
      code = assigns.join(', ');
      if (o.level < LEVEL_LIST) {
        return code;
      } else {
        return "(" + code + ")";
      }
    };

    Assign.prototype.compileConditional = function(o) {
      var left, rite, _ref2;
      _ref2 = this.variable.cacheReference(o), left = _ref2[0], rite = _ref2[1];
      if (__indexOf.call(this.context, "?") >= 0) o.isExistentialEquals = true;
      return new Op(this.context.slice(0, -1), left, new Assign(rite, this.value, '=')).compile(o);
    };

    Assign.prototype.compileSplice = function(o) {
      var code, exclusive, from, fromDecl, fromRef, name, to, valDef, valRef, _ref2, _ref3, _ref4;
      _ref2 = this.variable.properties.pop().range, from = _ref2.from, to = _ref2.to, exclusive = _ref2.exclusive;
      name = this.variable.compile(o);
      _ref3 = (from != null ? from.cache(o, LEVEL_OP) : void 0) || ['0', '0'], fromDecl = _ref3[0], fromRef = _ref3[1];
      if (to) {
        if ((from != null ? from.isSimpleNumber() : void 0) && to.isSimpleNumber()) {
          to = +to.compile(o) - +fromRef;
          if (!exclusive) to += 1;
        } else {
          to = to.compile(o, LEVEL_ACCESS) + ' - ' + fromRef;
          if (!exclusive) to += ' + 1';
        }
      } else {
        to = "9e9";
      }
      _ref4 = this.value.cache(o, LEVEL_LIST), valDef = _ref4[0], valRef = _ref4[1];
      code = "[].splice.apply(" + name + ", [" + fromDecl + ", " + to + "].concat(" + valDef + ")), " + valRef;
      if (o.level > LEVEL_TOP) {
        return "(" + code + ")";
      } else {
        return code;
      }
    };

    return Assign;

  })(Base);

  exports.Code = Code = (function(_super) {

    __extends(Code, _super);

    function Code(params, body, tag) {
      this.params = params || [];
      this.body = body || new Block;
      this.bound = tag === 'boundfunc';
      if (this.bound) this.context = '_this';
    }

    Code.prototype.children = ['params', 'body'];

    Code.prototype.isStatement = function() {
      return !!this.ctor;
    };

    Code.prototype.jumps = NO;

    Code.prototype.compileNode = function(o) {
      var code, exprs, i, idt, lit, p, param, ref, splats, v, val, vars, wasEmpty, _i, _j, _k, _len, _len2, _len3, _len4, _ref2, _ref3, _ref4, _ref5, _ref6;
      o.scope = new Scope(o.scope, this.body, this);
      o.scope.shared = del(o, 'sharedScope');
      o.indent += TAB;
      delete o.bare;
      vars = [];
      exprs = [];
      _ref2 = this.params;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        param = _ref2[_i];
        if (!param.splat) continue;
        _ref3 = this.params;
        for (_j = 0, _len2 = _ref3.length; _j < _len2; _j++) {
          p = _ref3[_j];
          if (p.name.value) o.scope.add(p.name.value, 'var', true);
        }
        splats = new Assign(new Value(new Arr((function() {
          var _k, _len3, _ref4, _results;
          _ref4 = this.params;
          _results = [];
          for (_k = 0, _len3 = _ref4.length; _k < _len3; _k++) {
            p = _ref4[_k];
            _results.push(p.asReference(o));
          }
          return _results;
        }).call(this))), new Value(new Literal('arguments')));
        break;
      }
      _ref4 = this.params;
      for (_k = 0, _len3 = _ref4.length; _k < _len3; _k++) {
        param = _ref4[_k];
        if (param.isComplex()) {
          val = ref = param.asReference(o);
          if (param.value) val = new Op('?', ref, param.value);
          exprs.push(new Assign(new Value(param.name), val, '=', {
            param: true
          }));
        } else {
          ref = param;
          if (param.value) {
            lit = new Literal(ref.name.value + ' == null');
            val = new Assign(new Value(param.name), param.value, '=');
            exprs.push(new If(lit, val));
          }
        }
        if (!splats) vars.push(ref);
      }
      wasEmpty = this.body.isEmpty();
      if (splats) exprs.unshift(splats);
      if (exprs.length) {
        (_ref5 = this.body.expressions).unshift.apply(_ref5, exprs);
      }
      if (!splats) {
        for (i = 0, _len4 = vars.length; i < _len4; i++) {
          v = vars[i];
          o.scope.parameter(vars[i] = v.compile(o));
        }
      }
      if (!(wasEmpty || this.noReturn)) this.body.makeReturn();
      if (this.bound) {
        if ((_ref6 = o.scope.parent.method) != null ? _ref6.bound : void 0) {
          this.bound = this.context = o.scope.parent.method.context;
        } else if (!this.static) {
          o.scope.parent.assign('_this', 'this');
        }
      }
      idt = o.indent;
      code = 'function';
      if (this.ctor) code += ' ' + this.name;
      code += '(' + vars.join(', ') + ') {';
      if (!this.body.isEmpty()) {
        code += "\n" + (this.body.compileWithDeclarations(o)) + "\n" + this.tab;
      }
      code += '}';
      if (this.ctor) return this.tab + code;
      if (this.front || (o.level >= LEVEL_ACCESS)) {
        return "(" + code + ")";
      } else {
        return code;
      }
    };

    Code.prototype.traverseChildren = function(crossScope, func) {
      if (crossScope) {
        return Code.__super__.traverseChildren.call(this, crossScope, func);
      }
    };

    return Code;

  })(Base);

  exports.Param = Param = (function(_super) {

    __extends(Param, _super);

    function Param(name, value, splat) {
      this.name = name;
      this.value = value;
      this.splat = splat;
    }

    Param.prototype.children = ['name', 'value'];

    Param.prototype.compile = function(o) {
      return this.name.compile(o, LEVEL_LIST);
    };

    Param.prototype.asReference = function(o) {
      var node;
      if (this.reference) return this.reference;
      node = this.name;
      if (node["this"]) {
        node = node.properties[0].name;
        if (node.value.reserved) node = new Literal('_' + node.value);
      } else if (node.isComplex()) {
        node = new Literal(o.scope.freeVariable('arg'));
      }
      node = new Value(node);
      if (this.splat) node = new Splat(node);
      return this.reference = node;
    };

    Param.prototype.isComplex = function() {
      return this.name.isComplex();
    };

    return Param;

  })(Base);

  exports.Splat = Splat = (function(_super) {

    __extends(Splat, _super);

    Splat.prototype.children = ['name'];

    Splat.prototype.isAssignable = YES;

    function Splat(name) {
      this.name = name.compile ? name : new Literal(name);
    }

    Splat.prototype.assigns = function(name) {
      return this.name.assigns(name);
    };

    Splat.prototype.compile = function(o) {
      if (this.index != null) {
        return this.compileParam(o);
      } else {
        return this.name.compile(o);
      }
    };

    Splat.prototype.unwrap = function() {
      return this.name;
    };

    Splat.compileSplattedArray = function(o, list, apply) {
      var args, base, code, i, index, node, _len;
      index = -1;
      while ((node = list[++index]) && !(node instanceof Splat)) {
        continue;
      }
      if (index >= list.length) return '';
      if (list.length === 1) {
        code = list[0].compile(o, LEVEL_LIST);
        if (apply) return code;
        return "" + (utility('slice')) + ".call(" + code + ")";
      }
      args = list.slice(index);
      for (i = 0, _len = args.length; i < _len; i++) {
        node = args[i];
        code = node.compile(o, LEVEL_LIST);
        args[i] = node instanceof Splat ? "" + (utility('slice')) + ".call(" + code + ")" : "[" + code + "]";
      }
      if (index === 0) {
        return args[0] + (".concat(" + (args.slice(1).join(', ')) + ")");
      }
      base = (function() {
        var _i, _len2, _ref2, _results;
        _ref2 = list.slice(0, index);
        _results = [];
        for (_i = 0, _len2 = _ref2.length; _i < _len2; _i++) {
          node = _ref2[_i];
          _results.push(node.compile(o, LEVEL_LIST));
        }
        return _results;
      })();
      return "[" + (base.join(', ')) + "].concat(" + (args.join(', ')) + ")";
    };

    return Splat;

  })(Base);

  exports.While = While = (function(_super) {

    __extends(While, _super);

    function While(condition, options) {
      this.condition = (options != null ? options.invert : void 0) ? condition.invert() : condition;
      this.guard = options != null ? options.guard : void 0;
    }

    While.prototype.children = ['condition', 'guard', 'body'];

    While.prototype.isStatement = YES;

    While.prototype.makeReturn = function(res) {
      if (res) {
        return While.__super__.makeReturn.apply(this, arguments);
      } else {
        this.returns = !this.jumps({
          loop: true
        });
        return this;
      }
    };

    While.prototype.addBody = function(body) {
      this.body = body;
      return this;
    };

    While.prototype.jumps = function() {
      var expressions, node, _i, _len;
      expressions = this.body.expressions;
      if (!expressions.length) return false;
      for (_i = 0, _len = expressions.length; _i < _len; _i++) {
        node = expressions[_i];
        if (node.jumps({
          loop: true
        })) return node;
      }
      return false;
    };

    While.prototype.compileNode = function(o) {
      var body, code, rvar, set;
      o.indent += TAB;
      set = '';
      body = this.body;
      if (body.isEmpty()) {
        body = '';
      } else {
        if (this.returns) {
          body.makeReturn(rvar = o.scope.freeVariable('results'));
          set = "" + this.tab + rvar + " = [];\n";
        }
        if (this.guard) {
          if (body.expressions.length > 1) {
            body.expressions.unshift(new If((new Parens(this.guard)).invert(), new Literal("continue")));
          } else {
            if (this.guard) body = Block.wrap([new If(this.guard, body)]);
          }
        }
        body = "\n" + (body.compile(o, LEVEL_TOP)) + "\n" + this.tab;
      }
      code = set + this.tab + ("while (" + (this.condition.compile(o, LEVEL_PAREN)) + ") {" + body + "}");
      if (this.returns) code += "\n" + this.tab + "return " + rvar + ";";
      return code;
    };

    return While;

  })(Base);

  exports.Op = Op = (function(_super) {
    var CONVERSIONS, INVERSIONS;

    __extends(Op, _super);

    function Op(op, first, second, flip) {
      var call;
      if (op === 'in') return new In(first, second);
      if (op === 'do') {
        call = new Call(first, first.params || []);
        call["do"] = true;
        return call;
      }
      if (op === 'new') {
        if (first instanceof Call && !first["do"] && !first.isNew) {
          return first.newInstance();
        }
        if (first instanceof Code && first.bound || first["do"]) {
          first = new Parens(first);
        }
      }
      this.operator = CONVERSIONS[op] || op;
      this.first = first;
      this.second = second;
      this.flip = !!flip;
      return this;
    }

    CONVERSIONS = {
      '==': '===',
      '!=': '!==',
      'of': 'in'
    };

    INVERSIONS = {
      '!==': '===',
      '===': '!=='
    };

    Op.prototype.children = ['first', 'second'];

    Op.prototype.isSimpleNumber = NO;

    Op.prototype.isUnary = function() {
      return !this.second;
    };

    Op.prototype.isComplex = function() {
      var _ref2;
      return !(this.isUnary() && ((_ref2 = this.operator) === '+' || _ref2 === '-')) || this.first.isComplex();
    };

    Op.prototype.isChainable = function() {
      var _ref2;
      return (_ref2 = this.operator) === '<' || _ref2 === '>' || _ref2 === '>=' || _ref2 === '<=' || _ref2 === '===' || _ref2 === '!==';
    };

    Op.prototype.invert = function() {
      var allInvertable, curr, fst, op, _ref2;
      if (this.isChainable() && this.first.isChainable()) {
        allInvertable = true;
        curr = this;
        while (curr && curr.operator) {
          allInvertable && (allInvertable = curr.operator in INVERSIONS);
          curr = curr.first;
        }
        if (!allInvertable) return new Parens(this).invert();
        curr = this;
        while (curr && curr.operator) {
          curr.invert = !curr.invert;
          curr.operator = INVERSIONS[curr.operator];
          curr = curr.first;
        }
        return this;
      } else if (op = INVERSIONS[this.operator]) {
        this.operator = op;
        if (this.first.unwrap() instanceof Op) this.first.invert();
        return this;
      } else if (this.second) {
        return new Parens(this).invert();
      } else if (this.operator === '!' && (fst = this.first.unwrap()) instanceof Op && ((_ref2 = fst.operator) === '!' || _ref2 === 'in' || _ref2 === 'instanceof')) {
        return fst;
      } else {
        return new Op('!', this);
      }
    };

    Op.prototype.unfoldSoak = function(o) {
      var _ref2;
      return ((_ref2 = this.operator) === '++' || _ref2 === '--' || _ref2 === 'delete') && unfoldSoak(o, this, 'first');
    };

    Op.prototype.compileNode = function(o) {
      var code, isChain;
      isChain = this.isChainable() && this.first.isChainable();
      if (!isChain) this.first.front = this.front;
      if (this.isUnary()) return this.compileUnary(o);
      if (isChain) return this.compileChain(o);
      if (this.operator === '?') return this.compileExistence(o);
      code = this.first.compile(o, LEVEL_OP) + ' ' + this.operator + ' ' + this.second.compile(o, LEVEL_OP);
      if (o.level <= LEVEL_OP) {
        return code;
      } else {
        return "(" + code + ")";
      }
    };

    Op.prototype.compileChain = function(o) {
      var code, fst, shared, _ref2;
      _ref2 = this.first.second.cache(o), this.first.second = _ref2[0], shared = _ref2[1];
      fst = this.first.compile(o, LEVEL_OP);
      code = "" + fst + " " + (this.invert ? '&&' : '||') + " " + (shared.compile(o)) + " " + this.operator + " " + (this.second.compile(o, LEVEL_OP));
      return "(" + code + ")";
    };

    Op.prototype.compileExistence = function(o) {
      var fst, ref;
      if (this.first.isComplex() && o.level > LEVEL_TOP) {
        ref = new Literal(o.scope.freeVariable('ref'));
        fst = new Parens(new Assign(ref, this.first));
      } else {
        fst = this.first;
        ref = fst;
      }
      return new If(new Existence(fst), ref, {
        type: 'if'
      }).addElse(this.second).compile(o);
    };

    Op.prototype.compileUnary = function(o) {
      var op, parts, plusMinus;
      parts = [op = this.operator];
      plusMinus = op === '+' || op === '-';
      if ((op === 'new' || op === 'typeof' || op === 'delete') || plusMinus && this.first instanceof Op && this.first.operator === op) {
        parts.push(' ');
      }
      if ((plusMinus && this.first instanceof Op) || (op === 'new' && this.first.isStatement(o))) {
        this.first = new Parens(this.first);
      }
      parts.push(this.first.compile(o, LEVEL_OP));
      if (this.flip) parts.reverse();
      return parts.join('');
    };

    Op.prototype.toString = function(idt) {
      return Op.__super__.toString.call(this, idt, this.constructor.name + ' ' + this.operator);
    };

    return Op;

  })(Base);

  exports.In = In = (function(_super) {

    __extends(In, _super);

    function In(object, array) {
      this.object = object;
      this.array = array;
    }

    In.prototype.children = ['object', 'array'];

    In.prototype.invert = NEGATE;

    In.prototype.compileNode = function(o) {
      var hasSplat, obj, _i, _len, _ref2;
      if (this.array instanceof Value && this.array.isArray()) {
        _ref2 = this.array.base.objects;
        for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
          obj = _ref2[_i];
          if (!(obj instanceof Splat)) continue;
          hasSplat = true;
          break;
        }
        if (!hasSplat) return this.compileOrTest(o);
      }
      return this.compileLoopTest(o);
    };

    In.prototype.compileOrTest = function(o) {
      var cmp, cnj, i, item, ref, sub, tests, _ref2, _ref3;
      if (this.array.base.objects.length === 0) return "" + (!!this.negated);
      _ref2 = this.object.cache(o, LEVEL_OP), sub = _ref2[0], ref = _ref2[1];
      _ref3 = this.negated ? [' !== ', ' && '] : [' === ', ' || '], cmp = _ref3[0], cnj = _ref3[1];
      tests = (function() {
        var _len, _ref4, _results;
        _ref4 = this.array.base.objects;
        _results = [];
        for (i = 0, _len = _ref4.length; i < _len; i++) {
          item = _ref4[i];
          _results.push((i ? ref : sub) + cmp + item.compile(o, LEVEL_ACCESS));
        }
        return _results;
      }).call(this);
      tests = tests.join(cnj);
      if (o.level < LEVEL_OP) {
        return tests;
      } else {
        return "(" + tests + ")";
      }
    };

    In.prototype.compileLoopTest = function(o) {
      var code, ref, sub, _ref2;
      _ref2 = this.object.cache(o, LEVEL_LIST), sub = _ref2[0], ref = _ref2[1];
      code = utility('indexOf') + (".call(" + (this.array.compile(o, LEVEL_LIST)) + ", " + ref + ") ") + (this.negated ? '< 0' : '>= 0');
      if (sub === ref) return code;
      code = sub + ', ' + code;
      if (o.level < LEVEL_LIST) {
        return code;
      } else {
        return "(" + code + ")";
      }
    };

    In.prototype.toString = function(idt) {
      return In.__super__.toString.call(this, idt, this.constructor.name + (this.negated ? '!' : ''));
    };

    return In;

  })(Base);

  exports.Try = Try = (function(_super) {

    __extends(Try, _super);

    function Try(attempt, error, recovery, ensure) {
      this.attempt = attempt;
      this.error = error;
      this.recovery = recovery;
      this.ensure = ensure;
    }

    Try.prototype.children = ['attempt', 'recovery', 'ensure'];

    Try.prototype.isStatement = YES;

    Try.prototype.jumps = function(o) {
      var _ref2;
      return this.attempt.jumps(o) || ((_ref2 = this.recovery) != null ? _ref2.jumps(o) : void 0);
    };

    Try.prototype.makeReturn = function(res) {
      if (this.attempt) this.attempt = this.attempt.makeReturn(res);
      if (this.recovery) this.recovery = this.recovery.makeReturn(res);
      return this;
    };

    Try.prototype.compileNode = function(o) {
      var catchPart, ensurePart, errorPart, tryPart;
      o.indent += TAB;
      errorPart = this.error ? " (" + (this.error.compile(o)) + ") " : ' ';
      tryPart = this.attempt.compile(o, LEVEL_TOP);
      catchPart = this.recovery ? (!o.scope.check(this.error.value) ? o.scope.add(this.error.value, 'param') : void 0, " catch" + errorPart + "{\n" + (this.recovery.compile(o, LEVEL_TOP)) + "\n" + this.tab + "}") : !(this.ensure || this.recovery) ? ' catch (_error) {}' : void 0;
      ensurePart = this.ensure ? " finally {\n" + (this.ensure.compile(o, LEVEL_TOP)) + "\n" + this.tab + "}" : '';
      return "" + this.tab + "try {\n" + tryPart + "\n" + this.tab + "}" + (catchPart || '') + ensurePart;
    };

    return Try;

  })(Base);

  exports.Throw = Throw = (function(_super) {

    __extends(Throw, _super);

    function Throw(expression) {
      this.expression = expression;
    }

    Throw.prototype.children = ['expression'];

    Throw.prototype.isStatement = YES;

    Throw.prototype.jumps = NO;

    Throw.prototype.makeReturn = THIS;

    Throw.prototype.compileNode = function(o) {
      return this.tab + ("throw " + (this.expression.compile(o)) + ";");
    };

    return Throw;

  })(Base);

  exports.Existence = Existence = (function(_super) {

    __extends(Existence, _super);

    function Existence(expression) {
      this.expression = expression;
    }

    Existence.prototype.children = ['expression'];

    Existence.prototype.invert = NEGATE;

    Existence.prototype.compileNode = function(o) {
      var cmp, cnj, code, _ref2;
      this.expression.front = this.front;
      code = this.expression.compile(o, LEVEL_OP);
      if (IDENTIFIER.test(code) && !o.scope.check(code)) {
        _ref2 = this.negated ? ['===', '||'] : ['!==', '&&'], cmp = _ref2[0], cnj = _ref2[1];
        code = "typeof " + code + " " + cmp + " \"undefined\" " + cnj + " " + code + " " + cmp + " null";
      } else {
        code = "" + code + " " + (this.negated ? '==' : '!=') + " null";
      }
      if (o.level <= LEVEL_COND) {
        return code;
      } else {
        return "(" + code + ")";
      }
    };

    return Existence;

  })(Base);

  exports.Parens = Parens = (function(_super) {

    __extends(Parens, _super);

    function Parens(body) {
      this.body = body;
    }

    Parens.prototype.children = ['body'];

    Parens.prototype.unwrap = function() {
      return this.body;
    };

    Parens.prototype.isComplex = function() {
      return this.body.isComplex();
    };

    Parens.prototype.compileNode = function(o) {
      var bare, code, expr;
      expr = this.body.unwrap();
      if (expr instanceof Value && expr.isAtomic()) {
        expr.front = this.front;
        return expr.compile(o);
      }
      code = expr.compile(o, LEVEL_PAREN);
      bare = o.level < LEVEL_OP && (expr instanceof Op || expr instanceof Call || (expr instanceof For && expr.returns));
      if (bare) {
        return code;
      } else {
        return "(" + code + ")";
      }
    };

    return Parens;

  })(Base);

  exports.For = For = (function(_super) {

    __extends(For, _super);

    function For(body, source) {
      var _ref2;
      this.source = source.source, this.guard = source.guard, this.step = source.step, this.name = source.name, this.index = source.index;
      this.body = Block.wrap([body]);
      this.own = !!source.own;
      this.object = !!source.object;
      if (this.object) {
        _ref2 = [this.index, this.name], this.name = _ref2[0], this.index = _ref2[1];
      }
      if (this.index instanceof Value) {
        throw SyntaxError('index cannot be a pattern matching expression');
      }
      this.range = this.source instanceof Value && this.source.base instanceof Range && !this.source.properties.length;
      this.pattern = this.name instanceof Value;
      if (this.range && this.index) {
        throw SyntaxError('indexes do not apply to range loops');
      }
      if (this.range && this.pattern) {
        throw SyntaxError('cannot pattern match over range loops');
      }
      this.returns = false;
    }

    For.prototype.children = ['body', 'source', 'guard', 'step'];

    For.prototype.compileNode = function(o) {
      var body, defPart, forPart, forVarPart, guardPart, idt1, index, ivar, lastJumps, lvar, name, namePart, ref, resultPart, returnResult, rvar, scope, source, stepPart, stepvar, svar, varPart, _ref2;
      body = Block.wrap([this.body]);
      lastJumps = (_ref2 = last(body.expressions)) != null ? _ref2.jumps() : void 0;
      if (lastJumps && lastJumps instanceof Return) this.returns = false;
      source = this.range ? this.source.base : this.source;
      scope = o.scope;
      name = this.name && this.name.compile(o, LEVEL_LIST);
      index = this.index && this.index.compile(o, LEVEL_LIST);
      if (name && !this.pattern) {
        scope.find(name, {
          immediate: true
        });
      }
      if (index) {
        scope.find(index, {
          immediate: true
        });
      }
      if (this.returns) rvar = scope.freeVariable('results');
      ivar = (this.range ? name : index) || scope.freeVariable('i');
      if (this.step && !this.range) stepvar = scope.freeVariable("step");
      if (this.pattern) name = ivar;
      varPart = '';
      guardPart = '';
      defPart = '';
      idt1 = this.tab + TAB;
      if (this.range) {
        forPart = source.compile(merge(o, {
          index: ivar,
          step: this.step
        }));
      } else {
        svar = this.source.compile(o, LEVEL_LIST);
        if ((name || this.own) && !IDENTIFIER.test(svar)) {
          defPart = "" + this.tab + (ref = scope.freeVariable('ref')) + " = " + svar + ";\n";
          svar = ref;
        }
        if (name && !this.pattern) {
          namePart = "" + name + " = " + svar + "[" + ivar + "]";
        }
        if (!this.object) {
          lvar = scope.freeVariable('len');
          forVarPart = ("" + ivar + " = 0, " + lvar + " = " + svar + ".length") + (this.step ? ", " + stepvar + " = " + (this.step.compile(o, LEVEL_OP)) : '');
          stepPart = this.step ? "" + ivar + " += " + stepvar : "" + ivar + "++";
          forPart = "" + forVarPart + "; " + ivar + " < " + lvar + "; " + stepPart;
        }
      }
      if (this.returns) {
        resultPart = "" + this.tab + rvar + " = [];\n";
        returnResult = "\n" + this.tab + "return " + rvar + ";";
        body.makeReturn(rvar);
      }
      if (this.guard) {
        if (body.expressions.length > 1) {
          body.expressions.unshift(new If((new Parens(this.guard)).invert(), new Literal("continue")));
        } else {
          if (this.guard) body = Block.wrap([new If(this.guard, body)]);
        }
      }
      if (this.pattern) {
        body.expressions.unshift(new Assign(this.name, new Literal("" + svar + "[" + ivar + "]")));
      }
      defPart += this.pluckDirectCall(o, body);
      if (namePart) varPart = "\n" + idt1 + namePart + ";";
      if (this.object) {
        forPart = "" + ivar + " in " + svar;
        if (this.own) {
          guardPart = "\n" + idt1 + "if (!" + (utility('hasProp')) + ".call(" + svar + ", " + ivar + ")) continue;";
        }
      }
      body = body.compile(merge(o, {
        indent: idt1
      }), LEVEL_TOP);
      if (body) body = '\n' + body + '\n';
      return "" + defPart + (resultPart || '') + this.tab + "for (" + forPart + ") {" + guardPart + varPart + body + this.tab + "}" + (returnResult || '');
    };

    For.prototype.pluckDirectCall = function(o, body) {
      var base, defs, expr, fn, idx, ref, val, _len, _ref2, _ref3, _ref4, _ref5, _ref6, _ref7;
      defs = '';
      _ref2 = body.expressions;
      for (idx = 0, _len = _ref2.length; idx < _len; idx++) {
        expr = _ref2[idx];
        expr = expr.unwrapAll();
        if (!(expr instanceof Call)) continue;
        val = expr.variable.unwrapAll();
        if (!((val instanceof Code) || (val instanceof Value && ((_ref3 = val.base) != null ? _ref3.unwrapAll() : void 0) instanceof Code && val.properties.length === 1 && ((_ref4 = (_ref5 = val.properties[0].name) != null ? _ref5.value : void 0) === 'call' || _ref4 === 'apply')))) {
          continue;
        }
        fn = ((_ref6 = val.base) != null ? _ref6.unwrapAll() : void 0) || val;
        ref = new Literal(o.scope.freeVariable('fn'));
        base = new Value(ref);
        if (val.base) _ref7 = [base, val], val.base = _ref7[0], base = _ref7[1];
        body.expressions[idx] = new Call(base, expr.args);
        defs += this.tab + new Assign(ref, fn).compile(o, LEVEL_TOP) + ';\n';
      }
      return defs;
    };

    return For;

  })(While);

  exports.Switch = Switch = (function(_super) {

    __extends(Switch, _super);

    function Switch(subject, cases, otherwise) {
      this.subject = subject;
      this.cases = cases;
      this.otherwise = otherwise;
    }

    Switch.prototype.children = ['subject', 'cases', 'otherwise'];

    Switch.prototype.isStatement = YES;

    Switch.prototype.jumps = function(o) {
      var block, conds, _i, _len, _ref2, _ref3, _ref4;
      if (o == null) {
        o = {
          block: true
        };
      }
      _ref2 = this.cases;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        _ref3 = _ref2[_i], conds = _ref3[0], block = _ref3[1];
        if (block.jumps(o)) return block;
      }
      return (_ref4 = this.otherwise) != null ? _ref4.jumps(o) : void 0;
    };

    Switch.prototype.makeReturn = function(res) {
      var pair, _i, _len, _ref2, _ref3;
      _ref2 = this.cases;
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        pair = _ref2[_i];
        pair[1].makeReturn(res);
      }
      if (res) {
        this.otherwise || (this.otherwise = new Block([new Literal('void 0')]));
      }
      if ((_ref3 = this.otherwise) != null) _ref3.makeReturn(res);
      return this;
    };

    Switch.prototype.compileNode = function(o) {
      var block, body, code, cond, conditions, expr, i, idt1, idt2, _i, _len, _len2, _ref2, _ref3, _ref4, _ref5;
      idt1 = o.indent + TAB;
      idt2 = o.indent = idt1 + TAB;
      code = this.tab + ("switch (" + (((_ref2 = this.subject) != null ? _ref2.compile(o, LEVEL_PAREN) : void 0) || false) + ") {\n");
      _ref3 = this.cases;
      for (i = 0, _len = _ref3.length; i < _len; i++) {
        _ref4 = _ref3[i], conditions = _ref4[0], block = _ref4[1];
        _ref5 = flatten([conditions]);
        for (_i = 0, _len2 = _ref5.length; _i < _len2; _i++) {
          cond = _ref5[_i];
          if (!this.subject) cond = cond.invert();
          code += idt1 + ("case " + (cond.compile(o, LEVEL_PAREN)) + ":\n");
        }
        if (body = block.compile(o, LEVEL_TOP)) code += body + '\n';
        if (i === this.cases.length - 1 && !this.otherwise) break;
        expr = this.lastNonComment(block.expressions);
        if (expr instanceof Return || (expr instanceof Literal && expr.jumps() && expr.value !== 'debugger')) {
          continue;
        }
        code += idt2 + 'break;\n';
      }
      if (this.otherwise && this.otherwise.expressions.length) {
        code += idt1 + ("default:\n" + (this.otherwise.compile(o, LEVEL_TOP)) + "\n");
      }
      return code + this.tab + '}';
    };

    return Switch;

  })(Base);

  exports.If = If = (function(_super) {

    __extends(If, _super);

    function If(condition, body, options) {
      this.body = body;
      if (options == null) options = {};
      this.condition = options.type === 'unless' ? condition.invert() : condition;
      this.elseBody = null;
      this.isChain = false;
      this.soak = options.soak;
    }

    If.prototype.children = ['condition', 'body', 'elseBody'];

    If.prototype.bodyNode = function() {
      var _ref2;
      return (_ref2 = this.body) != null ? _ref2.unwrap() : void 0;
    };

    If.prototype.elseBodyNode = function() {
      var _ref2;
      return (_ref2 = this.elseBody) != null ? _ref2.unwrap() : void 0;
    };

    If.prototype.addElse = function(elseBody) {
      if (this.isChain) {
        this.elseBodyNode().addElse(elseBody);
      } else {
        this.isChain = elseBody instanceof If;
        this.elseBody = this.ensureBlock(elseBody);
      }
      return this;
    };

    If.prototype.isStatement = function(o) {
      var _ref2;
      return (o != null ? o.level : void 0) === LEVEL_TOP || this.bodyNode().isStatement(o) || ((_ref2 = this.elseBodyNode()) != null ? _ref2.isStatement(o) : void 0);
    };

    If.prototype.jumps = function(o) {
      var _ref2;
      return this.body.jumps(o) || ((_ref2 = this.elseBody) != null ? _ref2.jumps(o) : void 0);
    };

    If.prototype.compileNode = function(o) {
      if (this.isStatement(o)) {
        return this.compileStatement(o);
      } else {
        return this.compileExpression(o);
      }
    };

    If.prototype.makeReturn = function(res) {
      if (res) {
        this.elseBody || (this.elseBody = new Block([new Literal('void 0')]));
      }
      this.body && (this.body = new Block([this.body.makeReturn(res)]));
      this.elseBody && (this.elseBody = new Block([this.elseBody.makeReturn(res)]));
      return this;
    };

    If.prototype.ensureBlock = function(node) {
      if (node instanceof Block) {
        return node;
      } else {
        return new Block([node]);
      }
    };

    If.prototype.compileStatement = function(o) {
      var body, bodyc, child, cond, exeq, ifPart, _ref2;
      child = del(o, 'chainChild');
      exeq = del(o, 'isExistentialEquals');
      if (exeq) {
        return new If(this.condition.invert(), this.elseBodyNode(), {
          type: 'if'
        }).compile(o);
      }
      cond = this.condition.compile(o, LEVEL_PAREN);
      o.indent += TAB;
      body = this.ensureBlock(this.body);
      bodyc = body.compile(o);
      if (1 === ((_ref2 = body.expressions) != null ? _ref2.length : void 0) && !this.elseBody && !child && bodyc && cond && -1 === (bodyc.indexOf('\n')) && 80 > cond.length + bodyc.length) {
        return "" + this.tab + "if (" + cond + ") " + (bodyc.replace(/^\s+/, ''));
      }
      if (bodyc) bodyc = "\n" + bodyc + "\n" + this.tab;
      ifPart = "if (" + cond + ") {" + bodyc + "}";
      if (!child) ifPart = this.tab + ifPart;
      if (!this.elseBody) return ifPart;
      return ifPart + ' else ' + (this.isChain ? (o.indent = this.tab, o.chainChild = true, this.elseBody.unwrap().compile(o, LEVEL_TOP)) : "{\n" + (this.elseBody.compile(o, LEVEL_TOP)) + "\n" + this.tab + "}");
    };

    If.prototype.compileExpression = function(o) {
      var alt, body, code, cond;
      cond = this.condition.compile(o, LEVEL_COND);
      body = this.bodyNode().compile(o, LEVEL_LIST);
      alt = this.elseBodyNode() ? this.elseBodyNode().compile(o, LEVEL_LIST) : 'void 0';
      code = "" + cond + " ? " + body + " : " + alt;
      if (o.level >= LEVEL_COND) {
        return "(" + code + ")";
      } else {
        return code;
      }
    };

    If.prototype.unfoldSoak = function() {
      return this.soak && this;
    };

    return If;

  })(Base);

  Closure = {
    wrap: function(expressions, statement, noReturn) {
      var args, call, func, mentionsArgs, meth;
      if (expressions.jumps()) return expressions;
      func = new Code([], Block.wrap([expressions]));
      args = [];
      if ((mentionsArgs = expressions.contains(this.literalArgs)) || expressions.contains(this.literalThis)) {
        meth = new Literal(mentionsArgs ? 'apply' : 'call');
        args = [new Literal('this')];
        if (mentionsArgs) args.push(new Literal('arguments'));
        func = new Value(func, [new Access(meth)]);
      }
      func.noReturn = noReturn;
      call = new Call(func, args);
      if (statement) {
        return Block.wrap([call]);
      } else {
        return call;
      }
    },
    literalArgs: function(node) {
      return node instanceof Literal && node.value === 'arguments' && !node.asKey;
    },
    literalThis: function(node) {
      return (node instanceof Literal && node.value === 'this' && !node.asKey) || (node instanceof Code && node.bound);
    }
  };

  unfoldSoak = function(o, parent, name) {
    var ifn;
    if (!(ifn = parent[name].unfoldSoak(o))) return;
    parent[name] = ifn.body;
    ifn.body = new Value(parent);
    return ifn;
  };

  UTILITIES = {
    "extends": function() {
      return "function(child, parent) { for (var key in parent) { if (" + (utility('hasProp')) + ".call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; }";
    },
    bind: function() {
      return 'function(fn, me){ return function(){ return fn.apply(me, arguments); }; }';
    },
    indexOf: function() {
      return "Array.prototype.indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; }";
    },
    hasProp: function() {
      return 'Object.prototype.hasOwnProperty';
    },
    slice: function() {
      return 'Array.prototype.slice';
    }
  };

  LEVEL_TOP = 1;

  LEVEL_PAREN = 2;

  LEVEL_LIST = 3;

  LEVEL_COND = 4;

  LEVEL_OP = 5;

  LEVEL_ACCESS = 6;

  TAB = '  ';

  IDENTIFIER_STR = "[$A-Za-z_\\x7f-\\uffff][$\\w\\x7f-\\uffff]*";

  IDENTIFIER = RegExp("^" + IDENTIFIER_STR + "$");

  SIMPLENUM = /^[+-]?\d+$/;

  METHOD_DEF = RegExp("^(?:(" + IDENTIFIER_STR + ")\\.prototype(?:\\.(" + IDENTIFIER_STR + ")|\\[(\"(?:[^\\\\\"\\r\\n]|\\\\.)*\"|'(?:[^\\\\'\\r\\n]|\\\\.)*')\\]|\\[(0x[\\da-fA-F]+|\\d*\\.?\\d+(?:[eE][+-]?\\d+)?)\\]))|(" + IDENTIFIER_STR + ")$");

  IS_STRING = /^['"]/;

  utility = function(name) {
    var ref;
    ref = "__" + name;
    Scope.root.assign(ref, UTILITIES[name]());
    return ref;
  };

  multident = function(code, tab) {
    code = code.replace(/\n/g, '$&' + tab);
    return code.replace(/\s+$/, '');
  };

}).call(this);

};require['./coffee-script'] = new function() {
  var exports = this;
  (function() {
  var Lexer, RESERVED, compile, fs, lexer, parser, path, vm, _ref,
    __hasProp = Object.prototype.hasOwnProperty;

  fs = require('fs');

  path = require('path');

  _ref = require('./lexer'), Lexer = _ref.Lexer, RESERVED = _ref.RESERVED;

  parser = require('./parser').parser;

  vm = require('vm');

  if (require.extensions) {
    require.extensions['.coffee'] = function(module, filename) {
      var content;
      content = compile(fs.readFileSync(filename, 'utf8'), {
        filename: filename
      });
      return module._compile(content, filename);
    };
  } else if (require.registerExtension) {
    require.registerExtension('.coffee', function(content) {
      return compile(content);
    });
  }

  exports.VERSION = '1.2.0';

  exports.RESERVED = RESERVED;

  exports.helpers = require('./helpers');

  exports.compile = compile = function(code, options) {
    var merge;
    if (options == null) options = {};
    merge = exports.helpers.merge;
    try {
      return (parser.parse(lexer.tokenize(code))).compile(merge({}, options));
    } catch (err) {
      if (options.filename) {
        err.message = "In " + options.filename + ", " + err.message;
      }
      throw err;
    }
  };

  exports.tokens = function(code, options) {
    return lexer.tokenize(code, options);
  };

  exports.nodes = function(source, options) {
    if (typeof source === 'string') {
      return parser.parse(lexer.tokenize(source, options));
    } else {
      return parser.parse(source);
    }
  };

  exports.run = function(code, options) {
    var mainModule;
    mainModule = require.main;
    mainModule.filename = process.argv[1] = options.filename ? fs.realpathSync(options.filename) : '.';
    mainModule.moduleCache && (mainModule.moduleCache = {});
    mainModule.paths = require('module')._nodeModulePaths(path.dirname(options.filename));
    if (path.extname(mainModule.filename) !== '.coffee' || require.extensions) {
      return mainModule._compile(compile(code, options), mainModule.filename);
    } else {
      return mainModule._compile(code, mainModule.filename);
    }
  };

  exports.eval = function(code, options) {
    var Module, Script, js, k, o, r, sandbox, v, _i, _len, _module, _ref2, _ref3, _require;
    if (options == null) options = {};
    if (!(code = code.trim())) return;
    Script = vm.Script;
    if (Script) {
      if (options.sandbox != null) {
        if (options.sandbox instanceof Script.createContext().constructor) {
          sandbox = options.sandbox;
        } else {
          sandbox = Script.createContext();
          _ref2 = options.sandbox;
          for (k in _ref2) {
            if (!__hasProp.call(_ref2, k)) continue;
            v = _ref2[k];
            sandbox[k] = v;
          }
        }
        sandbox.global = sandbox.root = sandbox.GLOBAL = sandbox;
      } else {
        sandbox = global;
      }
      sandbox.__filename = options.filename || 'eval';
      sandbox.__dirname = path.dirname(sandbox.__filename);
      if (!(sandbox !== global || sandbox.module || sandbox.require)) {
        Module = require('module');
        sandbox.module = _module = new Module(options.modulename || 'eval');
        sandbox.require = _require = function(path) {
          return Module._load(path, _module, true);
        };
        _module.filename = sandbox.__filename;
        _ref3 = Object.getOwnPropertyNames(require);
        for (_i = 0, _len = _ref3.length; _i < _len; _i++) {
          r = _ref3[_i];
          if (r !== 'paths') _require[r] = require[r];
        }
        _require.paths = _module.paths = Module._nodeModulePaths(process.cwd());
        _require.resolve = function(request) {
          return Module._resolveFilename(request, _module);
        };
      }
    }
    o = {};
    for (k in options) {
      if (!__hasProp.call(options, k)) continue;
      v = options[k];
      o[k] = v;
    }
    o.bare = true;
    js = compile(code, o);
    if (sandbox === global) {
      return vm.runInThisContext(js);
    } else {
      return vm.runInContext(js, sandbox);
    }
  };

  lexer = new Lexer;

  parser.lexer = {
    lex: function() {
      var tag, _ref2;
      _ref2 = this.tokens[this.pos++] || [''], tag = _ref2[0], this.yytext = _ref2[1], this.yylineno = _ref2[2];
      return tag;
    },
    setInput: function(tokens) {
      this.tokens = tokens;
      return this.pos = 0;
    },
    upcomingInput: function() {
      return "";
    }
  };

  parser.yy = require('./nodes');

}).call(this);

};require['./browser'] = new function() {
  var exports = this;
  (function() {
  var CoffeeScript, runScripts;

  CoffeeScript = require('./coffee-script');

  CoffeeScript.require = require;

  CoffeeScript.eval = function(code, options) {
    return eval(CoffeeScript.compile(code, options));
  };

  CoffeeScript.run = function(code, options) {
    if (options == null) options = {};
    options.bare = true;
    return Function(CoffeeScript.compile(code, options))();
  };

  if (typeof window === "undefined" || window === null) return;

  CoffeeScript.load = function(url, callback) {
    var xhr;
    xhr = new (window.ActiveXObject || XMLHttpRequest)('Microsoft.XMLHTTP');
    xhr.open('GET', url, true);
    if ('overrideMimeType' in xhr) xhr.overrideMimeType('text/plain');
    xhr.onreadystatechange = function() {
      var _ref;
      if (xhr.readyState === 4) {
        if ((_ref = xhr.status) === 0 || _ref === 200) {
          CoffeeScript.run(xhr.responseText);
        } else {
          throw new Error("Could not load " + url);
        }
        if (callback) return callback();
      }
    };
    return xhr.send(null);
  };

  runScripts = function() {
    var coffees, execute, index, length, s, scripts;
    scripts = document.getElementsByTagName('script');
    coffees = (function() {
      var _i, _len, _results;
      _results = [];
      for (_i = 0, _len = scripts.length; _i < _len; _i++) {
        s = scripts[_i];
        if (s.type === 'text/coffeescript') _results.push(s);
      }
      return _results;
    })();
    index = 0;
    length = coffees.length;
    (execute = function() {
      var script;
      script = coffees[index++];
      if ((script != null ? script.type : void 0) === 'text/coffeescript') {
        if (script.src) {
          return CoffeeScript.load(script.src, execute);
        } else {
          CoffeeScript.run(script.innerHTML);
          return execute();
        }
      }
    })();
    return null;
  };

  if (window.addEventListener) {
    addEventListener('DOMContentLoaded', runScripts, false);
  } else {
    attachEvent('onload', runScripts);
  }

}).call(this);

};
    return require['./coffee-script'];
  }();

  if (typeof define === 'function' && define.amd) {
  //   define[NOTE: Added so it doesn't match regex /define\(/](function() { return CoffeeScript; });
  } else {
    root.CoffeeScript = CoffeeScript;
  }
}(this));
