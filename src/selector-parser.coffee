selectorCache = null
testElement = null

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
