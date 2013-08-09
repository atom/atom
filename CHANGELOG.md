* Fixed: Atom failing to launch if the theme being used was not found

* Improved: Theme changes now immediately take effect
* Fixed: Wrap in quotes/parens now works in split panes
* Improved: Autocomplete now includes CSS property names and values
* Improved: Settings GUI is now a pane item
* Added: Support package filtering in Settings GUI
* Added: Dynamically load all config options in the Settings GUI
* Added: Ability to bookmark lines and navigate bookmarks
* Fixed: Error when inserting newlines in CSS
* Fixed: Folding all will fold comments as well
* Added: Ability to fold all code at a given indentation level

* Improved: cmd-n now opens a new tab and cmd-shift-n now opens a new window.
* Added: Inspect Element context menu
* Fixed: Save As dialog now defaults to directory path of current editor
* Fixed: Using toggle comment shortcut respects indentation level

* Fixed: Search never completing in the command panel

* Fixed: cmd-n now works when no windows are open

* Fixed: Error selecting a grammar for an untitled editor

* Added: j/k now can be used to navigate the tree view and archive editor

* Fixed: Atom can now be launched when ~/.atom/config.cson doesn't exist
* Added: Initial collaboration sessions
* Fixed: Empty lines being deleted via uppercase/downcase command
* Fixed: Keybindings not working when using non-English keyboard language
* Fixed: cmd-shift-p and cmd-alt-w not doing anything when pressed

* Improved: Use grunt (instead of rake) for build system
* Fixed: Java files not syntax highlighting correctly.
* Fixed: LESS/CSS now indents properly after hitting enter.
* Added: Support for browsing .tar.gz and .zip files in the editor
* Added: TODO/FIXME/CHANGED are now highlighted in comments.
* Fixed: Full screen state of windows is now persisted across restarts.
* Added: Makefile syntax highlighting now included.
* Added: Open fuzzy finder to specific line using colon suffix (i.e ':25')
* Fixed: Issues deleting and moving over certain UTF-8 characters
* Fixed: Tree view not properly highlighting or revealing for open images.
* Added: Packages can now be installed from the configuration UI.
* Fixed: .git folder now ignored by default when searching

* Fixed: Not being able to disable packages from configuration UI.
* Fixed: Fuzzy finder showing poor results for entered text
* Improved: App icon

* Fixed: Fuzzy finder being empty sometimes

* Improved: App icon
* Fixed: End of line invisibles rendering incorrectly with the indent guide
* Fixed: Updates not installing automatically on restart
* Fixed: Wrap guide not displaying
* Fixed: Error when saving with the markdown preview focused

* Fixed: Atom always running in dev mode
* Fixed: Crash when running in dev mode without a path to the Atom source

* Fixed: Freeze when editing a RoR class
* Added: meta-N to open a new untitled editor in the current window

* Fixed: Styling in command logger
* Added: XML and Ruby syntax highlighting in Markdown files
* Fixed: Error when editing files in a HEAD-less Git repository

* Fixed: Invisible characters not being visible when enabled
* Added: Editor gutter now displays Git status for lines

* Improved: Startup time
* Added: SQL bundle now included
* Added: PEG.js bundle now included
* Added: Hyperlinks can now be opened with ctrl-O
* Fixed: PHP syntax highlighting
