var utils = {
  /* Like Python's |range|, but without |step|. */
  range: function(start, stop) {
    if (stop === undefined) {
      stop = start;
      start = 0;
    }

    var result = new Array(Math.max(0, stop - start));
    for (var i = 0, j = start; j < stop; i++, j++) {
      result[i] = j;
    }
    return result;
  },

  find: function(array, callback) {
    var length = array.length;
    for (var i = 0; i < length; i++) {
      if (callback(array[i])) {
        return array[i];
      }
    }
  },

  indexOf: function(array, callback) {
    var length = array.length;
    for (var i = 0; i < length; i++) {
      if (callback(array[i])) {
        return i;
      }
    }
    return -1;
  },

  contains: function(array, value) {
    /*
     * Stupid IE does not have Array.prototype.indexOf, otherwise this function
     * would be a one-liner.
     */
    var length = array.length;
    for (var i = 0; i < length; i++) {
      if (array[i] === value) {
        return true;
      }
    }
    return false;
  },

  each: function(array, callback) {
    var length = array.length;
    for (var i = 0; i < length; i++) {
      callback(array[i], i);
    }
  },

  map: function(array, callback) {
    var result = [];
    var length = array.length;
    for (var i = 0; i < length; i++) {
      result[i] = callback(array[i], i);
    }
    return result;
  },

  pluck: function(array, key) {
    return utils.map(array, function (e) { return e[key]; });
  },

  keys: function(object) {
    var result = [];
    for (var key in object) {
      result.push(key);
    }
    return result;
  },

  values: function(object) {
    var result = [];
    for (var key in object) {
      result.push(object[key]);
    }
    return result;
  },

  clone: function(object) {
    var result = {};
    for (var key in object) {
      result[key] = object[key];
    }
    return result;
  },

  defaults: function(object, defaults) {
    for (var key in defaults) {
      if (!(key in object)) {
        object[key] = defaults[key];
      }
    }
  },

  /*
   * The code needs to be in sync with the code template in the compilation
   * function for "action" nodes.
   */
  subclass: function(child, parent) {
    function ctor() { this.constructor = child; }
    ctor.prototype = parent.prototype;
    child.prototype = new ctor();
  },

  /*
   * Returns a string padded on the left to a desired length with a character.
   *
   * The code needs to be in sync with the code template in the compilation
   * function for "action" nodes.
   */
  padLeft: function(input, padding, length) {
    var result = input;

    var padLength = length - input.length;
    for (var i = 0; i < padLength; i++) {
      result = padding + result;
    }

    return result;
  },

  /*
   * Returns an escape sequence for given character. Uses \x for characters <=
   * 0xFF to save space, \u for the rest.
   *
   * The code needs to be in sync with the code template in the compilation
   * function for "action" nodes.
   */
  escape: function(ch) {
    var charCode = ch.charCodeAt(0);
    var escapeChar;
    var length;

    if (charCode <= 0xFF) {
      escapeChar = 'x';
      length = 2;
    } else {
      escapeChar = 'u';
      length = 4;
    }

    return '\\' + escapeChar + utils.padLeft(charCode.toString(16).toUpperCase(), '0', length);
  },

  /*
   * Surrounds the string with quotes and escapes characters inside so that the
   * result is a valid JavaScript string.
   *
   * The code needs to be in sync with the code template in the compilation
   * function for "action" nodes.
   */
  quote: function(s) {
    /*
     * ECMA-262, 5th ed., 7.8.4: All characters may appear literally in a string
     * literal except for the closing quote character, backslash, carriage
     * return, line separator, paragraph separator, and line feed. Any character
     * may appear in the form of an escape sequence.
     *
     * For portability, we also escape escape all control and non-ASCII
     * characters. Note that "\0" and "\v" escape sequences are not used because
     * JSHint does not like the first and IE the second.
     */
    return '"' + s
      .replace(/\\/g, '\\\\')  // backslash
      .replace(/"/g, '\\"')    // closing quote character
      .replace(/\x08/g, '\\b') // backspace
      .replace(/\t/g, '\\t')   // horizontal tab
      .replace(/\n/g, '\\n')   // line feed
      .replace(/\f/g, '\\f')   // form feed
      .replace(/\r/g, '\\r')   // carriage return
      .replace(/[\x00-\x07\x0B\x0E-\x1F\x80-\uFFFF]/g, utils.escape)
      + '"';
  },

  /*
   * Escapes characters inside the string so that it can be used as a list of
   * characters in a character class of a regular expression.
   */
  quoteForRegexpClass: function(s) {
    /*
     * Based on ECMA-262, 5th ed., 7.8.5 & 15.10.1.
     *
     * For portability, we also escape escape all control and non-ASCII
     * characters.
     */
    return s
      .replace(/\\/g, '\\\\')  // backslash
      .replace(/\//g, '\\/')   // closing slash
      .replace(/\]/g, '\\]')   // closing bracket
      .replace(/\^/g, '\\^')   // caret
      .replace(/-/g,  '\\-')   // dash
      .replace(/\0/g, '\\0')   // null
      .replace(/\t/g, '\\t')   // horizontal tab
      .replace(/\n/g, '\\n')   // line feed
      .replace(/\v/g, '\\x0B') // vertical tab
      .replace(/\f/g, '\\f')   // form feed
      .replace(/\r/g, '\\r')   // carriage return
      .replace(/[\x01-\x08\x0E-\x1F\x80-\uFFFF]/g, utils.escape);
  },

  /*
   * Builds a node visitor -- a function which takes a node and any number of
   * other parameters, calls an appropriate function according to the node type,
   * passes it all its parameters and returns its value. The functions for
   * various node types are passed in a parameter to |buildNodeVisitor| as a
   * hash.
   */
  buildNodeVisitor: function(functions) {
    return function(node) {
      return functions[node.type].apply(null, arguments);
    };
  },

  findRuleByName: function(ast, name) {
    return utils.find(ast.rules, function(r) { return r.name === name; });
  },

  indexOfRuleByName: function(ast, name) {
    return utils.indexOf(ast.rules, function(r) { return r.name === name; });
  }
};

module.exports = utils;
