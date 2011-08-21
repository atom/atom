# API Ideas


#
# Chrome
#

# Our view hierarchy is:
#
#    App has many Windows
# Window has many Tabs
#    Tab has many Panes
#   Pane has one  Document

App =
  windows: []
  activeWindow: null

class Window
  tabs: []
  activeTab: null

class Tab
  window: null
  panes: []
  activePane: null

class Pane
  window: null
  tab: null
  document: null

# Documents currently contain either
# an editor (ace) or browser (webview).
class Document
  window: null
  tab: null
  pane: null
  editor: null
  browser: null


#
# stdlib
#

$ = jQuery
_ = Underscore

# System functions based on http://nodejs.org/docs/v0.5.4/api/events.html

# Globals:
# http://nodejs.org/docs/v0.5.4/api/globals.html
# (Everything except Buffer and process)

# console:
# http://nodejs.org/docs/v0.5.4/api/stdio.html

# timers:
# http://nodejs.org/docs/v0.5.4/api/timers.html

# fs:
# http://nodejs.org/docs/v0.5.4/api/fs.html

# path:
# http://nodejs.org/docs/v0.5.4/api/path.html

# url:
# http://nodejs.org/docs/v0.5.4/api/url.html

# querystring:
# http://nodejs.org/docs/v0.5.4/api/querystring.html

# assert:
# http://nodejs.org/docs/v0.5.4/api/assert.html

# child processes:
# http://nodejs.org/docs/v0.5.4/api/child_processes.html

# events?