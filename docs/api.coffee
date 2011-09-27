# API Ideas

# Radfish
class Radfish
  plugins: []
  keybindings: {}
  
class View =
  app: null
  
  html: ->
    # gets or creates the html for the view

class Pane extends View

class Modal extends View

class Plugin
  app: null
  
# Atomicity
class App extends Radfish
  baseURL: null
  openURLs: []

  startup: (@baseURL) ->
  
  shutdown: ->
    
  open: (path...) ->
    
  close: (paths...) ->
    
  save: (paths...) ->

class Editor
  app: null
  
class TreeView
  app: null
  
class Tabs
  app: null