{{{
"title": "Creating Packages"
}}}

# package.json format

The following keys are available to your package's _package.json_ manifest file:

- `main` (**Required**): the path to the CoffeeScript file that's the entry point
to your package
- `stylesheets` (**Optional**): an Array of Strings identifying the order of the
stylesheets your package needs to load. If not specified, stylesheets in the _stylesheets_
directory are added alphabetically.
- `keymaps`(**Optional**): an Array of Strings identifying the order of the
key mappings your package needs to load. If not specified, mappings in the _keymaps_
directory are added alphabetically.
- `snippets` (**Optional**): an Array of Strings identifying the order of the
snippets your package needs to load. If not specified, snippets in the _snippets_
directory are added alphabetically.
- `activationEvents` (**Optional**): an Array of Strings identifying events that
trigger your package's activation. You can delay the loading of your package until
one of these events is trigged.
