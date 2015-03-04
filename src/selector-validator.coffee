selectorCache = null
testElement = null

# Parses CSS selectors and memoizes their validity so each selector will only
# be parsed once.
exports.isSelectorValid = (selector) ->
  selectorCache ?= {}
  cachedValue = selectorCache[selector]
  return cachedValue if cachedValue?

  testElement ?= document.createElement('div')
  try
    # querySelector appears to be faster than webkitMatchesSelector
    # http://jsperf.com/query-vs-matches
    testElement.querySelector(selector)
    selectorCache[selector] = true
    true
  catch selectorError
    selectorCache[selector] = false
    false

# Parse the given CSS selector and throw an error if it is invalid.
exports.validateSelector = (selector) ->
  return if exports.isSelectorValid(selector)

  error = new Error("'#{selector}' is not a valid selector")
  error.code = 'EBADSELECTOR'
  throw error
