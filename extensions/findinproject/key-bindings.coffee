findinproject:
  'cmd-shift-f': (findinproject) ->
    if term = prompt "Find in project:"
      window.open "findinproject://#{term}"