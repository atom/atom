atom.open = (args...) ->
  @sendMessageToBrowserProcess('open', args)
