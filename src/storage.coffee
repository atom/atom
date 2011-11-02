module.exports =
class Storage
  @get: (key, defaultValue) ->
    try
      object = JSON.parse(localStorage[key] ? "{}")
    catch error
      error.message += "\nGetting #{key}"
      console.error(error)

    object ? defaultValue

  @set: (key, value) ->
    if value == undefined
      delete localStorage[key]
    else
      localStorage[key] = JSON.stringify(value.valueOf())
