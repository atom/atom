# API Ideas


#
# Chrome
#

# Our view hierarchy is:
#
#    App has many Windows
# Window has many Panes
# Window has one Document

App =
  windows: []
  activeWindow: null

class Window
  panes: []
  activePane: null

class Pane
  window: null
  document: null

class Document
  window: null
  pane: null
