# CSS Naming Convention


This is Atom's naming convention for creating UI in Atom and Atom packages. It's close to [BEM/SUIT](https://github.com/suitcss/suit/blob/master/doc/naming-conventions.md), but slightly customized for Atom's use case.


## Example

Below the commit box as a possible example:

```html
<div class='github-CommitBox'>
  <div class='github-CommitBox-editor'></div>
  <footer class='github-CommitBox-footer'>
    <button class='github-CommitBox-button'>Commit to sm-branch</button>
    <div class='github-CommitBox-counter is-warning'>50</div>
  </footer>
</div>
```

And when styled in Less:

```less
.github {
  &-CommitBox {

    &-editor {}

    &-footer {}

    &-button {}

    &-counter {
      background: red;

      &.is-warning {
        color: black;
      }
    }
  }
}
```

## Breakdown

Here another example:

```html
<button class='
  github-CommitBox-commitButton
  github-CommitBox-commitButton--primary
  is-disabled
'>
```

And now let's break it down into all the different parts.

```html
<button class='
  namespace-ComponentName-childElement 
  namespace-ComponentName-childElement--modifier
  is-state
'>
```


### Namespace

`github`-CommitBox

Every class starts with a namespace, in Atom's case it's the __package name__. Since packages are unique (well, at least for all the packages published on atom.io), it avoids style conflicts. Using a namespace like this makes sure that no styles __leak out__. And even more importantly that no styles __leak in__.

The namespace for Atom core ([atom/atom](https://github.com/atom/atom-ui)) is `core`-ComponentName.

Atom's [UI library](https://github.com/atom/atom-ui) is the only exception that doesn't use a namespace. All components start with the `ComponentName`. For example `Button`, `Checkbox`.

> Note: If multiple words are needed, camelCase is used: `myPackage`-Component.


### Component

github-`CommitBox`

Components are building blocks of a package. They can be small or large. Components can also contain other components. It's more about seeing what belongs together.

Components can also share the same elements. A pattern often found is that a new Component starts where a childElement ends. 

```html
<ul class="github-List">
  <li class="github-List-item github-Commit">
    <label class="github-Commit-message"></label>
    <span class="github-Commit-time"></span>
  </li>
</ul>
```

In this example, `github-List-item` is responsible for the "container" and layout styles. `github-Commit` is responsible for the "content" inside.

> Note: Components use PascalCase. This makes it easy to spot them in the markup. For example in `settings-List-item`, it's easy to see that the component is `List` and not `settings` or `item`.


### Child element

github-CommitBox-`commitButton`

Elements that are part of a component are appended to the component's class name with a single dash (`-`).

> Note: If multiple words are needed, camelCase is used: github-CommitBox`-commitButton`.


### Modifier

github-CommitBox-commitButton`--primary`

Modifiers are used if a component is very similar to the default component but varies slightly. Like has a different color. Modifiers use a double dash `--` to distinguish them from components and child elements.

> Note: If multiple words are needed, camelCase is used: github-CommitBox-commitButton`--primaryColor`.


### States

github-CommitBox-commitButton `is-disabled`

States are prefixed with a short verb, like `is-` or `has-`. Since these class names probably get used in many different places, it should never be styled stand-alone and always be a chained selector.

```less
.is-disabled {
  // nope
}
.github-CommitBox-commitButton.is-disabled {
  // yep
}
```

> Note: If multiple words are needed, camelCase is used: `has-collapsedItems`.



## More guidelines

- Styling elements (like `div`) should be avoided. This makes it easier to switch elements, like from a `<button>` to `<a>`.
- No utility classes. Themes and user styles can only override CSS but not change the markup. Therefore having utility classes doesn't make as much sense once you override them.
- Avoid using existing CSS classes to reference elements in the DOM. That way when the markup changes, functionality and specs will less likely break. Instead use `ref` attributes (`ref="commitButton"`).
- Avoid changing modifiers at runtime. If you're in need, consider turning the modifier class into a state. For example if you often want to switch a default button to a primary button, change the `github-CommitBox-commitButton--primary` modifier class into a `is-primary` state instead. Since state classes are decoupled from components, it's easier to reuse that state class even if the component changes later.


## Benefits

- Just by looking at a class in the DevTools you already get a lot of information about where the source can be found (what package, what component). What relationship each element has (parent/child). What class names are states and might be changed/removed. There should be less "what does this class do" moments.
- Reduces specificity. Mostly there is just a single class. Two when using states. This reduces the specificity war when trying to override styles in packages and `styles.less`.
- Using a single class makes it easier to change the markup later. Once a selector like `.class > div > .class` is in the wild, removing the `div` later would break the styling.
- Easier to refactor/move code around because you can see what class belongs to what component.


## Concerns

### Class names get quite long

Only in the DOM. During authoring in Less class names can be split into different parts and glued together with `&`.

```less
.github {
  &-CommitBox {
    // styles
    &-editor {
      // styles
    }
  }
}
```

will output as

```less
.github-CommitBox {
  // styles
}
.github-CommitBox-editor {
  // styles
}
```

Child elements might also be styled as components. Especially in smaller packages or when components should be shared inside a package. For example `github-CommitBox-commitButton` could just be `github-Button` if that button doesn't need any special styles even tough it's part of the the `CommitBox` component.

### I don't like nesting selectors

The whole selector can of course also be written without nesting. One benefit for not nesting selectors is that they can be easier searched for.

```less
.github-CommitBox { /* styles */ }

.github-CommitBox-editor { /* styles */ }

.github-CommitBox-footer { /* styles */ }
```
