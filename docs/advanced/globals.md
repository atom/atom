# Globals

Atom exposes several services through singleton objects accessible via the
`atom` global:

* atom
  * workspace:
      Manipulate and query the state of the user interface for the current
      window. Open editors, manipulate panes.
  * project:
      Access the directory associated with the current window. Load editors,
      perform project-wide searches, register custom openers for special file
      types.
  * config:
      Read, write, and observe user configuration settings.
  * keymap:
      Add and query the currently active keybindings.
  * deserializers:
      Deserialize instances from their state objects and register deserializers.
  * packages:
      Activate, deactivate, and query user packages.
  * themes:
      Activate, deactivate, and query user themes.
  * contextMenu:
      Register context menus.
  * menu:
      Register application menus.
  * pasteboard:
      Read from and write to the system pasteboard.
  * syntax:
      Assign and query syntactically-scoped properties.
