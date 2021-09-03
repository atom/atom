# Line Ending Selector package

![status bar tile](https://cloud.githubusercontent.com/assets/1305617/9274149/6b317568-4293-11e5-83ba-614a6c0d9890.png)

This is an [Atom](https://atom.io) package that displays the current line ending type of a file: `CRLF` (Windows), `LF` (Unix), or `Mixed` (both). It also lets you change the line ending of a file.

## To Use

When the package is activated it will show the current line ending of the file in the right side of the status-bar. If a new file is created the line ending will start with the system default: `CRLF` for Windows, `LF` for Mac and Linux, and `CR` for old-style Mac files. If a file contains multiple line-ending types it will display `Mixed`.

### Changing a File's Line Ending

You can click the line ending in the status-bar to open a modal with the line ending options. Selecting a different line ending will change each line of the file in the active editor.

![modal](https://cloud.githubusercontent.com/assets/1305617/9273907/2be5c136-4291-11e5-94af-65ece408eb12.png)

**Line Endings**

- `LF` is "\n"
- `CRLF` is "\r\n"

**Note:** Because the `CR` line ending style is not used in any modern operating system, this package only supports converting *from* `CR` line endings not to it.

### Atom Commands

You can also change a file's line endings by using or <kbd>cmd-shift-P</kbd> searching for these commands:

```text
line-ending-selector:convert-to-LF
line-ending-selector:convert-to-CRLF
```
