# API Ideas


#
# Chrome
#

# View hierarchy
#
# App:    has many Windows
# Window: has many Panes, contains a Document model
# Pane:   has 0 or more Panes
#
# Model hieerarcy
#
# Document: holds all the data!

App =
  windows: []
  activeWindow: null

class Window
  panes: []
  document: null
  activePane: null

class Pane
  subPanes: []
  window: null
  activeSubPane: null

class Document
  window: null
