# API Ideas


#
# Chrome
#

# View hierarchy
#
# App:    has many Windows
# Window: has many Plugins, contains a Document model
# Plugin: could have a Pane, or be headless
# Pane:   has 0 or more Panes
#
# Model hieerarcy
#
# Document: holds all the data!

App =
  windows: []
  activeWindow: null

class Window
  plugins: []
  document: null
  activePane: null

class Pane
  panes: []
  window: null
  activeSubPane: null

class Document
  window: null

class Plugin
  window: null
  
