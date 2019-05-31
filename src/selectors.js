module.exports = { selectorMatchesAnyScope, matcherForSelector };

const { isSubset } = require('underscore-plus');

// Private: Parse a selector into parts.
//          If already parsed, returns the selector unmodified.
//
// * `selector` a {String|Array<String>} specifying what to match
// Returns selector parts, an {Array<String>}.
function parse(selector) {
  return typeof selector === 'string'
    ? selector.replace(/^\./, '').split('.')
    : selector;
}

const always = scope => true;

// Essential: Return a matcher function for a selector.
//
// * selector, a {String} selector
// Returns {(scope: String) -> Boolean}, a matcher function returning
// true iff the scope matches the selector.
function matcherForSelector(selector) {
  const parts = parse(selector);
  if (typeof parts === 'function') return parts;
  return selector ? scope => isSubset(parts, parse(scope)) : always;
}

// Essential: Return true iff the selector matches any provided scope.
//
// * {String} selector
// * {Array<String>} scopes
// Returns {Boolean} true if any scope matches the selector.
function selectorMatchesAnyScope(selector, scopes) {
  return !selector || scopes.some(matcherForSelector(selector));
}
