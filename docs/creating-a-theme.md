{{{
"title": "Creating a Theme"
}}}

# Creating a Theme

## Overview

* Explain the difference between ui themes and syntax themes

## Getting Started

* What do I need to install?
  * Atom - to edit text
  * Git - to track and distribute your themes
* What do I need to know?
  * CSS/LESS - as that's what themes are written in
* Is there an example I can start from?
  * Yes, you can clone https://github.com/atom/solarized-dark-syntax

# Create a minimal syntax theme

```bash
cd ~/.atom/packages
mkdir my-theme
cd my-theme
git init
mkdir stylesheets
cat > package.json <<END
{
  "name": "theme-rainbow",
  "theme": true,
  "stylesheets": [
    'included-first.less',
    'included-second.less'
  ]
  "version": "0.0.1",
  "description": "Rainbows are beautiful",
  "repository": {
    "type": "git",
    "url": "https://github.com/atom/theme-rainbow.git"
  },
  "bugs": {
    "url": "https://github.com/atom/theme-rainbow/issues"
  },
  "engines": {
    "atom": "~>1.0"
  }
}
END

cat > stylesheets/included-first.less <<END
@import "ui-variables";

.editor {
  color: fade(@text-color, 20%);
}
END

cat > stylesheets/included-second.less <<END
@import "ui-colors";

.editor {
  color: fade(@text-color, 80%);
}
END
```

### Important points

* Notice the theme attribute in the package.json file. This is specific to Atom
  and required for all theme packages. Otherwise they won't be displayed in the
  theme chooser.
* Notice the stylesheets attribute. If have multiple stylesheets and their order
  is meaningful than you should specify their relative pathnames here. Otherwise
  all css or less files will be loaded alphabetically from the stylesheets
  folder.
* Notice the ui-variables require. If you'd like to make your theme adapt to the
  users choosen ui theme, these variables allow you to create your own colors
  based on them.

## Create a minimal ui theme

* Needs to have a file called ui-variables and it must contain the following
  variables:
    * A list of variables from @benogle's theme refactor.
