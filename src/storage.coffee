module.exports =
class Storage
  @get: (key, defaultValue) ->
    try
      value = JSON.parse(localStorage[key] ? null) ? defaultValue
    catch error
      error.message += "\nGetting #{key}"
      console.error(error)

    value

  @set: (key, value) ->
    if value == undefined
      delete localStorage[key]
    else
      localStorage[key] = JSON.stringify(value.valueOf())
