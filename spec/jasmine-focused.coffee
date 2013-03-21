setGlobalFocusPriority = (priority) ->
  env = jasmine.getEnv()
  env.focusPriority = 1 unless env.focusPriority
  env.focusPriority = priority if priority > env.focusPriority

window.fdescribe = (description, specDefinitions, priority) ->
  priority = 1 unless priority
  setGlobalFocusPriority(priority)
  suite = describe(description, specDefinitions)
  suite.focusPriority = priority
  suite

window.ffdescribe = (description, specDefinitions) ->
  fdescribe(description, specDefinitions, 2)

window.fffdescribe = (description, specDefinitions) ->
  fdescribe(description, specDefinitions, 3)

window.fit = (description, definition, priority) ->
  priority = 1 unless priority
  setGlobalFocusPriority(priority)
  spec = it(description, definition)
  spec.focusPriority = priority
  spec

window.ffit = (description, specDefinitions) ->
  fit(description, specDefinitions, 2)

window.fffit = (description, specDefinitions) ->
  fit(description, specDefinitions, 3)
