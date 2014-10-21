# Scoped Settings, Scopes and Scope Descriptors

Atom supports language-specific settings. You can soft wrap only Markdown files, or set the tab length to 4 in Python files.

Language-specific settings are a subset of something more general we call "scoped settings". Scoped settings allow targeting down to a specific syntax token type. For example, you could conceivably set a setting to target only Ruby comments, only code inside Markdown files, or even only JavaScript function names.

## Scope names in syntax tokens

Each token in the editor has a collection of scope names. For example, the aformentioned JavaScript function name might have the scope names `function` and `name`. An open paren might have the scope names `punctuation`, `parameters`, `begin`.

Scope names work just like CSS classes. In fact, in the editor, scope names are attached to a token's DOM node as CSS classes.

Take this piece of JavaScript:

```js
function functionName() {
  console.log('Log it out');
}
```

In the dev tools, the first line's markup looks like this.

![screen shot 2014-10-14 at 11 21 35 am](https://cloud.githubusercontent.com/assets/69169/4634321/2b1b923c-53cf-11e4-9268-6e57bcb14ec8.png)

All the class names on the spans are scope names. Any scope name can be used to target a setting's value.

## Scope Selectors

Scope selectors allow you to target specific tokens just like a CSS selector targets specific nodes in the DOM. Some examples:

```coffee
'.source.js' # selects all javascript tokens
'.source.js .function.name' # selects all javascript function names
'.function.name' # selects all function names in any language
```

[Config::set][config-set] accepts a `scopeSelector`. If you'd like to set a setting for JavaScript function names, you can give it the js function name `scopeSelector`:

```coffee
atom.config.set('.source.js .function.name', 'my-package.my-setting', 'special value')
```

## Scope Descriptors

A scope descriptor is an [Object][scope-descriptor] that wraps an `Array` of
`String`s. The Array describes a path from the root of the syntax tree to a
token including _all_ scope names for the entire path.

In our JavaScript example above, a scope descriptor for the function name token would be:

```coffee
['source.js', 'meta.function.js', 'entity.name.function.js']
```

[Config::get][config-get] accepts a `scopeDescriptor`. You can get the value for your setting scoped to JavaScript function names via:

```coffee
scopeDescriptor = ['source.js', 'meta.function.js', 'entity.name.function.js']
value = atom.config.get(scopeDescriptor, 'my-package.my-setting')
```

But, you do not need to generate scope descriptors by hand. There are a couple methods available to get the scope descriptor from the editor:

* [Editor::getRootScopeDescriptor][editor-getRootScopeDescriptor] to get the language's descriptor. eg. `[".source.js"]`
* [Editor::scopeDescriptorForBufferPosition][editor-scopeDescriptorForBufferPosition] to get the descriptor at a specific position in the buffer.
* [Cursor::getScopeDescriptor][cursor-getScopeDescriptor] to get a cursor's descriptor based on position. eg. if the cursor were in the name of the method in our example it would return `["source.js", "meta.function.js", "entity.name.function.js"]`

Let's revisit our example using these methods:

```coffee
editor = atom.workspace.getActiveTextEditor()
cursor = editor.getLastCursor()
valueAtCursor = atom.config.get(cursor.getScopeDescriptor(), 'my-package.my-setting')
valueForLanguage = atom.config.get(editor.getRootScopeDescriptor(), 'my-package.my-setting')
```


[config]:https://atom.io/docs/api/latest/Config
[config-get]:https://atom.io/docs/api/latest/Config#instance-get
[config-set]:https://atom.io/docs/api/latest/Config#instance-set
[config-observe]:https://atom.io/docs/api/latest/Config#instance-observe

[editor-getRootScopeDescriptor]:https://atom.io/docs/api/latest/TextEditor#instance-getRootScopeDescriptor
[editor-scopeDescriptorForBufferPosition]:https://atom.io/docs/api/latest/TextEditor#instance-scopeDescriptorForBufferPosition

[cursor-getScopeDescriptor]:https://atom.io/docs/api/latest/Cursor#instance-getScopeDescriptor
[scope-descriptor]:https://atom.io/docs/api/latest/ScopeDescriptor
