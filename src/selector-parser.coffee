selectorCache = null
testElement = null

exports.validateSelector = (selector) ->
  return if exports.isSelectorValid(selector)

  error = new Error("'#{selector}' is not a valid selector")
  error.code = 'EBADSELECTOR'
  throw error

exports.isSelectorValid = (selector) ->
  selectorCache ?= {}
  cachedValue = selectorCache[selector]
  return cachedValue if cachedValue?

  testElement ?= document.createElement('div')
  try
    testElement.webkitMatchesSelector(selector)
    selectorCache[selector] = true
    true
  catch selectorError
    selectorCache[selector] = false
    false
