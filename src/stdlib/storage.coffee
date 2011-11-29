module.exports =
class Storage
  storagePath: (require.resolve '~/.atom/.storage')

  get: (key, defaultValue=null) ->
   try
     value = @storage().valueForKeyPath key
     @toJS value or defaultValue
   catch error
     error.message += "\nGetting #{key}"
     console.error(error)

  set: (key, value) ->
    keys = key.split '.'
    parent = storage = @storage()
    for key in keys.slice 0, -1
      parent[key] = {} unless parent[key]
      parent = parent[key]

    parent[keys.slice -1] = value
    storage.writeToFile_atomically @storagePath, true

  storage: ->
    storage = OSX.NSMutableDictionary.dictionaryWithContentsOfFile @storagePath
    storage ?= OSX.NSMutableDictionary.dictionary

  toJS: (value) ->
    if not value or not value.isKindOfClass
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