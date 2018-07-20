module.exports = {selectorMatchesAnyScope, matcherForSelector}

const _ = require('underscore-plus')

/**
 * Parse a selector into parts. If already parsed, returns the selector
 * unmodified.
 * 
 * @param {String|Array<String>} selector
 * @returns {Array<String>} selector parts
 */
function parse (selector) {
  return typeof selector === 'string'
    ? selector.replace(/^\./, '').split('.')
    : selector
}

const always = scope => true

/**
 * Return a matcher function for a selector.
 * 
 * @param {String} selector
 * @returns {(scope: String) -> Boolean} a matcher function
 */
function matcherForSelector (selector) {
  const parts = parse(selector)
  return selector
    ? scope => _.isSubset(parts, parse(scope))
    : always
}

/**
 * Return true iff the selector matches any provided scope.
 * 
 * @param {String} selector
 * @param {Array<String>} scopes
 * @returns {Boolean} true if any scope matches the selector
 */
function selectorMatchesAnyScope (selector, scopes) {
  return !selector || scopes.some(matcherForSelector(selector))
}
