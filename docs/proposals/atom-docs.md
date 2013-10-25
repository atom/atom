## Atom Documentation Format

This document describes our documentation format, which is markdown with
a few rules.

### Philosophy

1. Method and argument names **should** clearly communicate its use.
1. Use documentation to enhance and not correct method/argument names.

#### Basic

In some cases all that's required is a single line. **Do not** feel
obligated to write more because we have a format.

```markdown
# Private: Returns the number of pixels from the top of the screen.
```

* **Each method should declare whether it's public or private by using `Public:`
or `Private:`** prefix.
* Following the colon, there should be a short description (that isn't redundant with the
method name).
* Documentation should be hard wrapped to 80 columns.

### Public vs Private

If a method is public it can be used by other classes (and possibly by
the public API). The appropriate steps should be taken to minimize the impact
when changing public methods. In some cases that might mean adding an
appropriate release note. In other cases it might mean doing the legwork to
ensure all affected packages are updated.

#### Complex

For complex methods it's necessary to explain exactly what arguments
are required and how different inputs effect the operation of the
function.

The idea is to communicate things that the API user might not know about,
so repeating information that can be gleaned from the method or argument names
is not useful.

```markdown
# Private: Determine the accelerator for a given command.
#
# * command:
#   The name of the command.
# * keystrokesByCommand:
#   An {Object} whose keys are commands and the values are Arrays containing
#   the keystrokes.
# * options:
#     + accelerators:
#       Boolean to determine whether accelerators should be shown.
#
# Returns a String containing the keystroke in a format that can be interpreted
# by atom shell to provide nice icons where available.
#
# Raises an Exception if no window is available.
```

* Use curly brackets `{}` to provide links to other classes.
* Use `+` for the options list.
