# Public: Measure how long a function takes to run.
#
# description - A {String} description that will be logged to the console when
#               the function completes.
# fn - A {Function} to measure the duration of.
#
# Returns the value returned by the given function.
window.measure = (description, fn) ->
  start = Date.now()
  value = fn()
  result = Date.now() - start
  console.log description, result
  value

# Public: Create a dev tools profile for a function.
#
# description - A {String} description that will be available in the Profiles
#               tab of the dev tools.
# fn - A {Function} to profile.
#
# Returns the value returned by the given function.
window.profile = (description, fn) ->
  measure description, ->
    console.profile(description)
    value = fn()
    console.profileEnd(description)
    value
