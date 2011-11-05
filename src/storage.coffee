module.exports =
class Storage
  @get: (key, defaultValue) ->
   try
     value = OSX.NSApp.storageGet_defaultValue(key, defaultValue)
     @toJS value
   catch error
     error.message += "\nGetting #{key}"
     console.error(error)

  @set: (key, value) ->
    OSX.NSApp.storageSet_value key, value

  @toJS: (value) ->
    if not value
      value
    else if value.isKindOfClass OSX.NSDictionary.class
      dict = {}
      dict[k.valueOf()] = @toJS v for k, v of value
      dict
    else if value.isKindOfClass OSX.NSArray.class
      array = []
      array.push @toJS v for v in value
      array
    else
      value.valueOf()
