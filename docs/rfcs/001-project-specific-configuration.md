# Project-Specific Configuration

## Status

Proposed

## Summary

Add the ability to have project-specific settings that override the global settings in the `~/.atom/config.{cson,json}` file on a per-project basis.

## Motivation

People who use Atom often work on multiple projects. Sometimes these projects have very different requirements for code formatting, tools to use, or other features that will necessitate different configuration of the editing environment. Currently, if one needs different settings for different projects, one has to use a community package, use [editorconfig](http://editorconfig.org/) which has a limited set of configuration values, or resort to manually changing configuration each time one switches to a different project.

## Explanation

There are two configuration files: the global `~/.atom/config.cson` and the project-specific `atom-config.cson`. (Hereafter these two files will be referred to as the "global settings" and "project settings" respectively.) The project settings file is stored in the root directory of the project root.

When reading from the configuration using `atom.config.get()`, the contents of the two configuration files is merged using [`Object.assign`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/assign) or some similar mechanism, with the values in the project settings taking precedence over the global settings. For example:

```coffee
# Global settings contents
editor:
  fontFamily: "Helvetica"
  fontSize: 14
```

```coffee
# Project settings contents
editor:
  fontSize: 16
```

```javascript
let fontFamily = atom.config.get('editor.fontFamily')
console.log(`fontFamily = ${fontFamily}`)
// Outputs "fontFamily = Helvetica"

let fontSize = atom.config.get('editor.fontSize')
console.log(`fontSize = ${fontSize}`)
// Outputs "fontSize = 16"
```

When setting or unsetting a configuration value, `atom.config.set()` and `atom.config.unset()` will continue to work the way it always has unless the `project` key is set to `true` in the options parameter. For example:

```javascript
// Sets the global editor.fontSize value to 18
atom.config.set('editor.fontSize', 18)

// Sets the project editor.fontSize value to 22
atom.config.set('editor.fontSize', 22, {project: true})

// Unsets the project core.fileEncoding value, leaving the global one unchanged
atom.config.unset('core.fileEncoding', {project: true})
```

Setting a language-specific configuration can also be done at either the global or project setting level:

```javascript
// Sets the editor.tabLength setting to 4 for GitHub-flavored Markdown files globally
atom.config.set('editor.tabLength', 4, {scopeSelector: '.source.gfm'})

// Sets the editor.tabLength setting to 2 for GitHub-flavored Markdown files in this project
atom.config.set('editor.tabLength', 2, {project: true, scopeSelector: '.source.gfm'})
```

**Note:** [Behavior is undefined](https://blogs.msdn.microsoft.com/oldnewthing/20140627-00/?p=633) when there are multiple project roots that have `atom-config.cson` files whose individual values are different. For example, given a project that has two project roots "foo" and "bar" with project settings like the following:

```coffee
# Project settings contents for project root "foo"
editor:
  fontSize: 16
```

```coffee
# Project settings contents for project root "bar"
editor:
  fontSize: 22
```

```javascript
// What will be returned is not defined
let fontSize = atom.config.get('editor.fontSize')

// Will return the default of "utf8"
let fileEncoding = atom.config.get('core.fileEncoding')
```

Observing a configuration value will work similarly to reading a configuration value, largely unchanged except that change notifications may be raised when either the global or project setting is set, even if the merged value didn't change. For example:

```coffee
# Global settings contents
editor:
  fontSize: 14
```

```coffee
# Project settings contents
editor:
  fontSize: 16
```

```javascript
let fontSize = atom.config.get('editor.fontSize')
console.log(`fontSize = ${fontSize}`)
// "fontSize = 16" is output

atom.config.observe('editor.fontSize', (value) => { console.log(`fontSize = ${value}`) })
// "fontSize = 16" is output because observe calls the handler with the initial value

atom.config.set('editor.fontSize', 16)
// "fontSize = 16" is output even though the value that would be returned at this point is still `16`
```

## Drawbacks

It introduces complexity and some non-determinism into the Atom configuration system. This will cause an increased support burden from people who don't notice or don't understand the new system.

## Rationale and alternatives

This is the best system that I've come up with to achieve project-specific settings across the many times I've thought about it. (See [this topic on Discuss](https://discuss.atom.io/t/layered-configuration/9373) for some of my early thoughts.) There is currently a [PR open with a different solution,](https://github.com/atom/atom/pull/16654) but it introduces breaking changes for the configuration system. This proposed solution will work exactly as the current system does until someone adds a project settings file to their project. And even after they do that, all API calls will continue to work as they were expected to under the old system.

The impact of not doing this is continued fragmentation and patchwork solutions from community packages.

## Unresolved questions

* What should happen when there are multiple project roots and `atom.config.set('foo', 'bar', {project: true})` is called?
    * Should the value be set in the project settings file in **all** project roots?
    * Should the value be set in the project settings file in only the first project root?
* What should happen when a project root that contains project settings is added or removed?
* Is there a simple and performant way to implement `observe` so that the event is only raised when the merged value changes?
* Will we present a UI for setting project-specific configuration values in the Settings View? If so, how?
    * Does not need to be answered at this point, there was no UI for language-specific settings for a long time without problem
