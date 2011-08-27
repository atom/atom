/* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is DomTemplate.
 *
 * The Initial Developer of the Original Code is Mozilla.
 * Portions created by the Initial Developer are Copyright (C) 2009
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   Joe Walker (jwalker@mozilla.com) (original author)
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either the GNU General Public License Version 2 or later (the "GPL"), or
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the MPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL, the GPL or the LGPL.
 *
 * ***** END LICENSE BLOCK ***** */

define(function(require, exports, module) {


// WARNING: do not 'use_strict' without reading the notes in envEval;

/**
 * A templater that allows one to quickly template DOM nodes.
 */
function Templater() {
  this.scope = [];
};

/**
 * Recursive function to walk the tree processing the attributes as it goes.
 * @param node the node to process. If you pass a string in instead of a DOM
 * element, it is assumed to be an id for use with document.getElementById()
 * @param data the data to use for node processing.
 */
Templater.prototype.processNode = function(node, data) {
  if (typeof node === 'string') {
    node = document.getElementById(node);
  }
  if (data === null || data === undefined) {
    data = {};
  }
  this.scope.push(node.nodeName + (node.id ? '#' + node.id : ''));
  try {
    // Process attributes
    if (node.attributes && node.attributes.length) {
      // We need to handle 'foreach' and 'if' first because they might stop
      // some types of processing from happening, and foreach must come first
      // because it defines new data on which 'if' might depend.
      if (node.hasAttribute('foreach')) {
        this.processForEach(node, data);
        return;
      }
      if (node.hasAttribute('if')) {
        if (!this.processIf(node, data)) {
          return;
        }
      }
      // Only make the node available once we know it's not going away
      data.__element = node;
      // It's good to clean up the attributes when we've processed them,
      // but if we do it straight away, we mess up the array index
      var attrs = Array.prototype.slice.call(node.attributes);
      for (var i = 0; i < attrs.length; i++) {
        var value = attrs[i].value;
        var name = attrs[i].name;
        this.scope.push(name);
        try {
          if (name === 'save') {
            // Save attributes are a setter using the node
            value = this.stripBraces(value);
            this.property(value, data, node);
            node.removeAttribute('save');
          } else if (name.substring(0, 2) === 'on') {
            // Event registration relies on property doing a bind
            value = this.stripBraces(value);
            var func = this.property(value, data);
            if (typeof func !== 'function') {
              this.handleError('Expected ' + value +
                ' to resolve to a function, but got ' + typeof func);
            }
            node.removeAttribute(name);
            var capture = node.hasAttribute('capture' + name.substring(2));
            node.addEventListener(name.substring(2), func, capture);
            if (capture) {
              node.removeAttribute('capture' + name.substring(2));
            }
          } else {
            // Replace references in all other attributes
            var self = this;
            var newValue = value.replace(/\$\{[^}]*\}/g, function(path) {
              return self.envEval(path.slice(2, -1), data, value);
            });
            // Remove '_' prefix of attribute names so the DOM won't try
            // to use them before we've processed the template
            if (name.charAt(0) === '_') {
              node.removeAttribute(name);
              node.setAttribute(name.substring(1), newValue);
            } else if (value !== newValue) {
              attrs[i].value = newValue;
            }
          }
        } finally {
          this.scope.pop();
        }
      }
    }

    // Loop through our children calling processNode. First clone them, so the
    // set of nodes that we visit will be unaffected by additions or removals.
    var childNodes = Array.prototype.slice.call(node.childNodes);
    for (var j = 0; j < childNodes.length; j++) {
      this.processNode(childNodes[j], data);
    }

    if (node.nodeType === Node.TEXT_NODE) {
      this.processTextNode(node, data);
    }
  } finally {
    this.scope.pop();
  }
};

/**
 * Handle <x if="${...}">
 * @param node An element with an 'if' attribute
 * @param data The data to use with envEval
 * @returns true if processing should continue, false otherwise
 */
Templater.prototype.processIf = function(node, data) {
  this.scope.push('if');
  try {
    var originalValue = node.getAttribute('if');
    var value = this.stripBraces(originalValue);
    var recurse = true;
    try {
      var reply = this.envEval(value, data, originalValue);
      recurse = !!reply;
    } catch (ex) {
      this.handleError('Error with \'' + value + '\'', ex);
      recurse = false;
    }
    if (!recurse) {
      node.parentNode.removeChild(node);
    }
    node.removeAttribute('if');
    return recurse;
  } finally {
    this.scope.pop();
  }
};

/**
 * Handle <x foreach="param in ${array}"> and the special case of
 * <loop foreach="param in ${array}">
 * @param node An element with a 'foreach' attribute
 * @param data The data to use with envEval
 */
Templater.prototype.processForEach = function(node, data) {
  this.scope.push('foreach');
  try {
    var originalValue = node.getAttribute('foreach');
    var value = originalValue;

    var paramName = 'param';
    if (value.charAt(0) === '$') {
      // No custom loop variable name. Use the default: 'param'
      value = this.stripBraces(value);
    } else {
      // Extract the loop variable name from 'NAME in ${ARRAY}'
      var nameArr = value.split(' in ');
      paramName = nameArr[0].trim();
      value = this.stripBraces(nameArr[1].trim());
    }
    node.removeAttribute('foreach');
    try {
      var self = this;
      // Process a single iteration of a loop
      var processSingle = function(member, clone, ref) {
        ref.parentNode.insertBefore(clone, ref);
        data[paramName] = member;
        self.processNode(clone, data);
        delete data[paramName];
      };

      // processSingle is no good for <loop> nodes where we want to work on
      // the childNodes rather than the node itself
      var processAll = function(scope, member) {
        self.scope.push(scope);
        try {
          if (node.nodeName === 'LOOP') {
            for (var i = 0; i < node.childNodes.length; i++) {
              var clone = node.childNodes[i].cloneNode(true);
              processSingle(member, clone, node);
            }
          } else {
            var clone = node.cloneNode(true);
            clone.removeAttribute('foreach');
            processSingle(member, clone, node);
          }
        } finally {
          self.scope.pop();
        }
      };

      var reply = this.envEval(value, data, originalValue);
      if (Array.isArray(reply)) {
        reply.forEach(function(data, i) {
          processAll('' + i, data);
        }, this);
      } else {
        for (var param in reply) {
          if (reply.hasOwnProperty(param)) {
            processAll(param, param);
          }
        }
      }
      node.parentNode.removeChild(node);
    } catch (ex) {
      this.handleError('Error with \'' + value + '\'', ex);
    }
  } finally {
    this.scope.pop();
  }
};

/**
 * Take a text node and replace it with another text node with the ${...}
 * sections parsed out. We replace the node by altering node.parentNode but
 * we could probably use a DOM Text API to achieve the same thing.
 * @param node The Text node to work on
 * @param data The data to use in calls to envEval
 */
Templater.prototype.processTextNode = function(node, data) {
  // Replace references in other attributes
  var value = node.data;
  // We can't use the string.replace() with function trick (see generic
  // attribute processing in processNode()) because we need to support
  // functions that return DOM nodes, so we can't have the conversion to a
  // string.
  // Instead we process the string as an array of parts. In order to split
  // the string up, we first replace '${' with '\uF001$' and '}' with '\uF002'
  // We can then split using \uF001 or \uF002 to get an array of strings
  // where scripts are prefixed with $.
  // \uF001 and \uF002 are just unicode chars reserved for private use.
  value = value.replace(/\$\{([^}]*)\}/g, '\uF001$$$1\uF002');
  var parts = value.split(/\uF001|\uF002/);
  if (parts.length > 1) {
    parts.forEach(function(part) {
      if (part === null || part === undefined || part === '') {
        return;
      }
      if (part.charAt(0) === '$') {
        part = this.envEval(part.slice(1), data, node.data);
      }
      // It looks like this was done a few lines above but see envEval
      if (part === null) {
        part = "null";
      }
      if (part === undefined) {
        part = "undefined";
      }
      // if (isDOMElement(part)) { ... }
      if (typeof part.cloneNode !== 'function') {
        part = node.ownerDocument.createTextNode(part.toString());
      }
      node.parentNode.insertBefore(part, node);
    }, this);
    node.parentNode.removeChild(node);
  }
};

/**
 * Warn of string does not begin '${' and end '}'
 * @param str the string to check.
 * @return The string stripped of ${ and }, or untouched if it does not match
 */
Templater.prototype.stripBraces = function(str) {
  if (!str.match(/\$\{.*\}/g)) {
    this.handleError('Expected ' + str + ' to match ${...}');
    return str;
  }
  return str.slice(2, -1);
};

/**
 * Combined getter and setter that works with a path through some data set.
 * For example:
 * <ul>
 * <li>property('a.b', { a: { b: 99 }}); // returns 99
 * <li>property('a', { a: { b: 99 }}); // returns { b: 99 }
 * <li>property('a', { a: { b: 99 }}, 42); // returns 99 and alters the
 * input data to be { a: { b: 42 }}
 * </ul>
 * @param path An array of strings indicating the path through the data, or
 * a string to be cut into an array using <tt>split('.')</tt>
 * @param data An object to look in for the <tt>path</tt> argument
 * @param newValue (optional) If defined, this value will replace the
 * original value for the data at the path specified.
 * @return The value pointed to by <tt>path</tt> before any
 * <tt>newValue</tt> is applied.
 */
Templater.prototype.property = function(path, data, newValue) {
  this.scope.push(path);
  try {
    if (typeof path === 'string') {
      path = path.split('.');
    }
    var value = data[path[0]];
    if (path.length === 1) {
      if (newValue !== undefined) {
        data[path[0]] = newValue;
      }
      if (typeof value === 'function') {
        return function() {
          return value.apply(data, arguments);
        };
      }
      return value;
    }
    if (!value) {
      this.handleError('Can\'t find path=' + path);
      return null;
    }
    return this.property(path.slice(1), value, newValue);
  } finally {
    this.scope.pop();
  }
};

/**
 * Like eval, but that creates a context of the variables in <tt>env</tt> in
 * which the script is evaluated.
 * WARNING: This script uses 'with' which is generally regarded to be evil.
 * The alternative is to create a Function at runtime that takes X parameters
 * according to the X keys in the env object, and then call that function using
 * the values in the env object. This is likely to be slow, but workable.
 * @param script The string to be evaluated.
 * @param env The environment in which to eval the script.
 * @param context Optional debugging string in case of failure
 * @return The return value of the script, or the error message if the script
 * execution failed.
 */
Templater.prototype.envEval = function(script, env, context) {
  with (env) {
    try {
      this.scope.push(context);
      return eval(script);
    } catch (ex) {
      this.handleError('Template error evaluating \'' + script + '\'', ex);
      return script;
    } finally {
      this.scope.pop();
    }
  }
};

/**
 * A generic way of reporting errors, for easy overloading in different
 * environments.
 * @param message the error message to report.
 * @param ex optional associated exception.
 */
Templater.prototype.handleError = function(message, ex) {
  this.logError(message);
  this.logError('In: ' + this.scope.join(' > '));
  if (ex) {
    this.logError(ex);
  }
};


/**
 * A generic way of reporting errors, for easy overloading in different
 * environments.
 * @param message the error message to report.
 */
Templater.prototype.logError = function(message) {
  window.console && window.console.log && console.log(message);
};

exports.Templater = Templater;


});
