Skip to content
Search or jump to…
Pull requests
Issues
Marketplace
Explore
 
@zakwarlord7 
Your account has been flagged.
Because of that, your profile is hidden from the public. If you believe this is a mistake, contact support to have your account status reviewed.
zakwarlord7
/
install
Public
Code
Issues
Pull requests
Actions
Projects
Wiki
Security
Insights
Settings
bitore.sig
 paradice
 trunk
@zakwarlord7
zakwarlord7 committed 1 hour ago 
1 parent cbd3c41 commit c76e074149580a71550b16077517e4e781775f59
Showing 1 changed file with 957 additions and 0 deletions.
 957  
README.md
@@ -1,2 +1,959 @@
Skip to content
Search or jump to…
Pull requests
Issues
Marketplace
Explore

@zakwarlord7 
Your account has been flagged.
Because of that, your profile is hidden from the public. If you believe this is a mistake, contact support to have your account status reviewed.
zakwarlord7
/
02100021
Public
Code
Issues
Pull requests
Actions
Projects
Wiki
Security
Insights
Settings
Create ci.yml
 paradice
 Trunk
@zakwarlord7
zakwarlord7 committed 16 hours ago 
1 parent 958b795 commit c5508cd0193c9ee1cdb965627a1b26f5b9f25092
Showing 1 changed file with 894 additions and 0 deletions.
 894  
.github/workflows/ci.yml
@@ -0,0 +1,894 @@
name: C/C++ CI

on:
  push:
    branches: [ "paradice" ]
  pull_request:
    branches: [ "paradice" ]

jobs:
  build:

    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v3
    - name: configure
      run: ./configure
    - name: make
      run: make
    - name: make check
      run: make check
    - name: make distcheck
      run: make distcheck
      Skip to content Visual Studio Code
Docs
Updates
Blog
API
Extensions
FAQ
Learn
Search Docs
Download VS CodeDownload
Version 1.71 is now available! Read about the new features and fixes from August.

Dismiss this update
Overview
SETUP
GET STARTED
USER GUIDE
SOURCE CONTROL
TERMINAL
LANGUAGES
Overview
JavaScript
JSON
HTML
CSS, SCSS and Less
TypeScript
Markdown
PowerShell
C++
Java
PHP
Python
Julia
R
Rust
Go
T-SQL
C#
.NET
NODE.JS / JAVASCRIPT
TYPESCRIPT
PYTHON
JAVA
C++
CONTAINERS
DATA SCIENCE
AZURE
REMOTE
JavaScript in Visual Studio Code
Visual Studio Code includes built-in JavaScript IntelliSense, debugging, formatting, code navigation, refactorings, and many other advanced language features.

Working with JavaScript in Visual Studio Code

Most of these features just work out of the box, while some may require basic configuration to get the best experience. This page summarizes the JavaScript features that VS Code ships with. Extensions from the VS Code Marketplace can augment or change most of these built-in features. For a more in-depth guide on how these features work and can be configured, see Working with JavaScript.

IntelliSense#
IntelliSense shows you intelligent code completion, hover information, and signature information so that you can write code more quickly and correctly.

VS Code provides IntelliSense within your JavaScript projects; for many npm libraries such as React, lodash, and express; and for other platforms such as node, serverless, or IoT.

See Working with JavaScript for information about VS Code's JavaScript IntelliSense, how to configure it, and help troubleshooting common IntelliSense problems.

JavaScript projects (jsconfig.json)#
A jsconfig.json file defines a JavaScript project in VS Code. While jsconfig.json files are not required, you will want to create one in cases such as:

If not all JavaScript files in your workspace should be considered part of a single JavaScript project. jsconfig.json files let you exclude some files from showing up in IntelliSense.
To ensure that a subset of JavaScript files in your workspace is treated as a single project. This is useful if you are working with legacy code that uses implicit globals dependencies instead of imports for dependencies.
If your workspace contains more than one project context, such as front-end and back-end JavaScript code. For multi-project workspaces, create a jsconfig.json at the root folder of each project.
You are using the TypeScript compiler to down-level compile JavaScript source code.
To define a basic JavaScript project, add a jsconfig.json at the root of your workspace:

{
  "compilerOptions": {
    "module": "commonjs",
    "target": "es6"
  },
  "exclude": ["node_modules"]
}
See Working with JavaScript for more advanced jsconfig.json configuration.

Tip: To check if a JavaScript file is part of JavaScript project, just open the file in VS Code and run the JavaScript: Go to Project Configuration command. This command opens the jsconfig.json that references the JavaScript file. A notification is shown if the file is not part of any jsconfig.json project.

Snippets#
VS Code includes basic JavaScript snippets that are suggested as you type;

There are many extensions that provide additional snippets, including snippets for popular frameworks such as Redux or Angular. You can even define your own snippets.

Tip: To disable snippets suggestions, set editor.snippetSuggestions to "none" in your settings file. The editor.snippetSuggestions setting also lets you change where snippets appear in the suggestions: at the top ("top"), at the bottom ("bottom"), or inlined ordered alphabetically ("inline"). The default is "inline".

JSDoc support#
VS Code understands many standard JSDoc annotations, and uses these annotations to provide rich IntelliSense. You can optionally even use the type information from JSDoc comments to type check your JavaScript.

Quickly create JSDoc comments for functions by typing /** before the function declaration, and select the JSDoc comment snippet suggestion:

To disable JSDoc comment suggestions, set "javascript.suggest.completeJSDocs": false.

Hover Information#
Hover over a JavaScript symbol to quickly see its type information and relevant documentation.

Hovering over a JavaScript variable to see its type information

The ⌘K ⌘I (Windows, Linux Ctrl+K Ctrl+I) keyboard shortcut shows this hover information at the current cursor position.

Signature Help#
As you write JavaScript function calls, VS Code shows information about the function signature and highlights the parameter that you are currently completing:

Signature help for some DOM methods

Signature help is shown automatically when you type a ( or , within a function call. Press ⇧⌘Space (Windows, Linux Ctrl+Shift+Space) to manually trigger signature help.

Auto imports#
Automatic imports speed up coding by suggesting available variables throughout your project and its dependencies. When you select one of these suggestions, VS Code automatically adds an import for it to the top of the file.

Just start typing to see suggestions for all available JavaScript symbols in your current project. Auto import suggestions show where they will be imported from:

Global symbols are shown in the suggestion list

If you choose one of these auto import suggestions, VS Code adds an import for it.

In this example, VS Code adds an import for Button from material-ui to the top of the file:

After selecting a symbol from a different file, an import is added for it automatically

To disable auto imports, set "javascript.suggest.autoImports" to false.

Tip: VS Code tries to infer the best import style to use. You can explicitly configure the preferred quote style and path style for imports added to your code with the javascript.preferences.quoteStyle and javascript.preferences.importModuleSpecifier settings.

Formatting#
VS Code's built-in JavaScript formatter provides basic code formatting with reasonable defaults.

The javascript.format.* settings configure the built-in formatter. Or, if the built-in formatter is getting in the way, set "javascript.format.enable" to false to disable it.

For more specialized code formatting styles, try installing one of the JavaScript formatting extensions from the Marketplace.

JSX and auto closing tags#
All of VS Code's JavaScript features also work with JSX:

JSX IntelliSense

You can use JSX syntax in both normal *.js files and in *.jsx files.

VS Code also includes JSX-specific features such as autoclosing of JSX tags:

Set "javascript.autoClosingTags" to false to disable JSX tag closing.

Code navigation#
Code navigation lets you quickly navigate JavaScript projects.

Go to Definition F12 - Go to the source code of a symbol definition.
Peek Definition ⌥F12 (Windows Alt+F12, Linux Ctrl+Shift+F10) - Bring up a Peek window that shows the definition of a symbol.
Go to References ⇧F12 (Windows, Linux Shift+F12) - Show all references to a symbol.
Go to Type Definition - Go to the type that defines a symbol. For an instance of a class, this will reveal the class itself instead of where the instance is defined.
You can navigate via symbol search using the Go to Symbol commands from the Command Palette (⇧⌘P (Windows, Linux Ctrl+Shift+P)).

Go to Symbol in File ⇧⌘O (Windows, Linux Ctrl+Shift+O)
Go to Symbol in Workspace ⌘T (Windows, Linux Ctrl+T)
Rename#
Press F2 to rename the symbol under the cursor across your JavaScript project:

Renaming a variable

Refactoring#
VS Code includes some handy refactorings for JavaScript such as Extract function and Extract constant. Just select the source code you'd like to extract and then click on the lightbulb in the gutter or press (⌘. (Windows, Linux Ctrl+.)) to see available refactorings.

JavaScript refactoring

Available refactorings include:

Extract to method or function.
Extract to constant.
Convert between named imports and namespace imports.
Move to new file.
See Refactorings for more information about refactorings and how you can configure keyboard shortcuts for individual refactorings.

Unused variables and unreachable code#
Unused JavaScript code, such the else block of an if statement that is always true or an unreferenced import, is faded out in the editor:

Unreachable source code faded out

You can quickly remove this unused code by placing the cursor on it and triggering the Quick Fix command (⌘. (Windows, Linux Ctrl+.)) or clicking on the lightbulb.

To disable fading out of unused code, set "editor.showUnused" to false. You can also disable fading of unused code only in JavaScript by setting:

"[javascript]": {
    "editor.showUnused":  false
},
"[javascriptreact]": {
    "editor.showUnused":  false
},
Organize Imports#
The Organize Imports Source Action sorts the imports in a JavaScript file and removes any unused imports:

You can run Organize Imports from the Source Action context menu or with the ⇧⌥O (Windows, Linux Shift+Alt+O) keyboard shortcut.

Organize imports can also be done automatically when you save a JavaScript file by setting:

"editor.codeActionsOnSave": {
    "source.organizeImports": true
}
Code Actions on Save#
The editor.codeActionsOnSave setting lets you configure a set of Code Actions that are run when a file is saved. For example, you can enable organize imports on save by setting:

// On save, run both fixAll and organizeImports source actions
"editor.codeActionsOnSave": {
    "source.fixAll": true,
    "source.organizeImports": true,
}
You can also set editor.codeActionsOnSave to an array of Code Actions to execute in order.

Here are some source actions:

"organizeImports" - Enables organize imports on save.
"fixAll" - Auto Fix on Save computes all possible fixes in one round (for all providers including ESLint).
"fixAll.eslint" - Auto Fix only for ESLint.
"addMissingImports" - Adds all missing imports on save.
See Node.js/JavaScript for more information.

Code suggestions#
VS Code automatically suggests some common code simplifications such as converting a chain of .then calls on a promise to use async and await

Set "javascript.suggestionActions.enabled" to false to disable suggestions.

Inlay hints#
Inlay hints add additional inline information to source code to help you understand what the code does.

Parameter name inlay hints show the names of parameters in function calls:

Parameter name inlay hints

This can help you understand the meaning of each argument at a glance, which is especially helpful for functions that take Boolean flags or have parameters that are easy to mix up.

To enable parameter name hints, set javascript.inlayHints.parameterNames. There are three possible values:

none — Disable parameter inlay hints.
literals — Only show inlay hints for literals (string, number, Boolean).
all — Show inlay hints for all arguments.
Variable type inlay hints show the types of variables that don't have explicit type annotations.

Setting: javascript.inlayHints.variableTypes.enabled

Variable type inlay hints

Property type inlay hints show the type of class properties that don't have an explicit type annotation.

Setting: javascript.inlayHints.propertyDeclarationTypes.enabled

Property type inlay hints

Parameter type hints show the types of implicitly typed parameters.

Setting: javascript.inlayHints.parameterTypes.enabled

Parameter type inlay hints

Return type inlay hints show the return types of functions that don't have an explicit type annotation.

Setting: javascript.inlayHints.functionLikeReturnTypes.enabled

Return type inlay hints

References CodeLens#
The JavaScript references CodeLens displays an inline count of reference for classes, methods, properties, and exported objects:

JavaScript references CodeLens

To enable the references CodeLens, set "javascript.referencesCodeLens.enabled" to true.

Click on the reference count to quickly browse a list of references:

JavaScript references CodeLens peek

Update imports on file move#
When you move or rename a file that is imported by other files in your JavaScript project, VS Code can automatically update all import paths that reference the moved file:

The javascript.updateImportsOnFileMove.enabled setting controls this behavior. Valid settings values are:

"prompt" - The default. Asks if paths should be updated for each file move.
"always" - Always automatically update paths.
"never" - Do not update paths automatically and do not prompt.
Linters#
Linters provides warnings for suspicious looking code. While VS Code does not include a built-in JavaScript linter, many JavaScript linter extensions available in the marketplace.

ESLint
ESLint
22.5M
dbaeumer
Integrates ESLint JavaScript into VS Code.
jshint
jshint
2.2M
dbaeumer
Integrates JSHint into VS Code. JSHint is a linter for JavaScript
Flow Language Support
Flow Language Support
563.0K
flowtype
Flow support for VS Code
StandardJS - JavaScript Standard Style (old version)
StandardJS - JavaScript Standard Style (old version)
439.0K
chenxsan
Integrates JavaScript Standard Style into VS Code.
Tip: This list is dynamically queried from the VS Code Marketplace. Read the description and reviews to decide if the extension is right for you.

Type checking#
You can leverage some of TypeScript's advanced type checking and error reporting functionality in regular JavaScript files too. This is a great way to catch common programming mistakes. These type checks also enable some exciting Quick Fixes for JavaScript, including Add missing import and Add missing property.

Using type checking and Quick Fixes in a JavaScript file

TypeScript tried to infer types in .js files the same way it does in .ts files. When types cannot be inferred, they can be specified explicitly with JSDoc comments. You can read more about how TypeScript uses JSDoc for JavaScript type checking in Working with JavaScript.

Type checking of JavaScript is optional and opt-in. Existing JavaScript validation tools such as ESLint can be used alongside built-in type checking functionality.

Debugging#
VS Code comes with great debugging support for JavaScript. Set breakpoints, inspect objects, navigate the call stack, and execute code in the Debug Console. See the Debugging topic to learn more.

Debug client side#
You can debug your client-side code using a browser debugger such as our built-in debugger for Edge and Chrome, or the Debugger for Firefox.

Debug server side#
Debug Node.js in VS Code using the built-in debugger. Setup is easy and there is a Node.js debugging tutorial to help you.

debug data inspection

Popular extensions#
VS Code ships with excellent support for JavaScript but you can additionally install debuggers, snippets, linters, and other JavaScript tools through extensions.

Prettier - Code formatter
Prettier - Code formatter
25.1M
esbenp
Code formatter using prettier
IntelliCode
IntelliCode
22.5M
VisualStudioExptTeam
AI-assisted development
JavaScript (ES6) code snippets
JavaScript (ES6) code snippets
9.7M
xabikos
Code snippets for JavaScript in ES6 syntax
Babel JavaScript
Babel JavaScript
1.9M
mgmcdermott
VSCode syntax highlighting for today's JavaScript
Tip: The extensions shown above are dynamically queried. Click on an extension tile above to read the description and reviews to decide which extension is best for you. See more in the Marketplace.

Next steps#
Read on to find out about:

Working with JavaScript - More detailed information about VS Code's JavaScript support and how to troubleshoot common issues.
jsconfig.json - Detailed description of the jsconfig.json project file.
IntelliSense - Learn more about IntelliSense and how to use it effectively for your language.
Debugging - Learn how to set up debugging for your application.
Node.js - A walkthrough to create an Express Node.js application.
TypeScript - VS Code has great support for TypeScript, which brings structure and strong typing to your JavaScript code.
Common questions#
Does VS Code support JSX and React Native?#
VS Code supports JSX and React Native. You will get IntelliSense for React/JSX and React Native from automatically downloaded type declaration (typings) files from the npmjs type declaration file repository. Additionally, you can install the popular React Native extension from the Marketplace.

To enable ES6 import statements for React Native, you need to set the allowSyntheticDefaultImports compiler option to true. This tells the compiler to create synthetic default members and you get IntelliSense. React Native uses Babel behind the scenes to create the proper run-time code with default members. If you also want to do debugging of React Native code, you can install the React Native Extension.

Does VS Code support the Dart programming language and the Flutter framework?#
Yes, there are VS Code extensions for both Dart and Flutter development. You can learn more at the Flutter.dev documentation.

IntelliSense is not working for external libraries#
Automatic Type Acquisition works for dependencies downloaded by npm (specified in package.json), Bower (specified in bower.json), and for many of the most common libraries listed in your folder structure (for example jquery-3.1.1.min.js).

ES6 Style imports are not working.

When you want to use ES6 style imports but some type declaration (typings) files do not yet use ES6 style exports, then set the TypeScript compiler option allowSyntheticDefaultImports to true.

{
  "compilerOptions": {
    "module": "commonjs",
    "target": "es6",
    // This is the line you want to add
    "allowSyntheticDefaultImports": true
  },
  "exclude": ["node_modules", "**/node_modules/*"]
}
Can I debug minified/uglified JavaScript?#
Yes, you can. You can see this working using JavaScript source maps in the Node.js Debugging topic.

How do I disable Syntax Validation when using non-ES6 constructs?#
Some users want to use syntax constructs like the proposed pipeline (|>) operator. However, these are currently not supported by VS Code's JavaScript language service and are flagged as errors. For users who still want to use these future features, we provide the javascript.validate.enable setting.

With javascript.validate.enable: false, you disable all built-in syntax checking. If you do this, we recommend that you use a linter like ESLint to validate your source code.

Can I use other JavaScript tools like Flow?#
Yes, but some of Flow's language features such as type and error checking may interfere with VS Code's built-in JavaScript support. To learn how to disable VS Code's built-in JavaScript support, see Disable JavaScript support.

Was this documentation helpful?
Yes, this page was helpfulNo, this page was not helpful
9/1/2022
IN THIS ARTICLE THERE ARE 25 SECTIONSIN THIS ARTICLE
IntelliSense
JavaScript projects (jsconfig.json)
Snippets
JSDoc support
Hover Information
Signature Help
Auto imports
Formatting
JSX and auto closing tags
Code navigation
Rename
Refactoring
Unused variables and unreachable code
Organize Imports
Code Actions on Save
Code suggestions
Inlay hints
References CodeLens
Update imports on file move
Linters
Type checking
Debugging
Popular extensions
Next steps
Common questions
TwitterTweet this link
RSSSubscribe
StackoverflowAsk questions
TwitterFollow @code
GitHubRequest features
IssuesReport issues
YouTubeWatch videos
Hello from Seattle. Follow @code Support Privacy Terms of Use License 
Microsoft homepage© 2022 Microsoft
:Publish::
:Launch::
Release::
Deployee: repositories'@zakwarlord7/zakwarlord7 :
document :
notification :
e-mail :ZACHRY T WOOD<zachryiixixiiwood'@gmail.com>
Skip to content Visual Studio Code
Docs
Updates
Blog
API
Extensions
FAQ
Learn
Search Docs
Download VS CodeDownload
Version 1.71 is now available! Read about the new features and fixes from August.

Dismiss this update
Overview
SETUP
GET STARTED
USER GUIDE
SOURCE CONTROL
TERMINAL
LANGUAGES
Overview
JavaScript
JSON
HTML
CSS, SCSS and Less
TypeScript
Markdown
PowerShell
C++
Java
PHP
Python
Julia
R
Rust
Go
T-SQL
C#
.NET
NODE.JS / JAVASCRIPT
TYPESCRIPT
PYTHON
JAVA
C++
CONTAINERS
DATA SCIENCE
AZURE
REMOTE
JavaScript in Visual Studio Code
Visual Studio Code includes built-in JavaScript IntelliSense, debugging, formatting, code navigation, refactorings, and many other advanced language features.

Working with JavaScript in Visual Studio Code

Most of these features just work out of the box, while some may require basic configuration to get the best experience. This page summarizes the JavaScript features that VS Code ships with. Extensions from the VS Code Marketplace can augment or change most of these built-in features. For a more in-depth guide on how these features work and can be configured, see Working with JavaScript.

IntelliSense#
IntelliSense shows you intelligent code completion, hover information, and signature information so that you can write code more quickly and correctly.

VS Code provides IntelliSense within your JavaScript projects; for many npm libraries such as React, lodash, and express; and for other platforms such as node, serverless, or IoT.

See Working with JavaScript for information about VS Code's JavaScript IntelliSense, how to configure it, and help troubleshooting common IntelliSense problems.

JavaScript projects (jsconfig.json)#
A jsconfig.json file defines a JavaScript project in VS Code. While jsconfig.json files are not required, you will want to create one in cases such as:

If not all JavaScript files in your workspace should be considered part of a single JavaScript project. jsconfig.json files let you exclude some files from showing up in IntelliSense.
To ensure that a subset of JavaScript files in your workspace is treated as a single project. This is useful if you are working with legacy code that uses implicit globals dependencies instead of imports for dependencies.
If your workspace contains more than one project context, such as front-end and back-end JavaScript code. For multi-project workspaces, create a jsconfig.json at the root folder of each project.
You are using the TypeScript compiler to down-level compile JavaScript source code.
To define a basic JavaScript project, add a jsconfig.json at the root of your workspace:

{
  "compilerOptions": {
    "module": "commonjs",
    "target": "es6"
  },
  "exclude": ["node_modules"]
}
See Working with JavaScript for more advanced jsconfig.json configuration.

Tip: To check if a JavaScript file is part of JavaScript project, just open the file in VS Code and run the JavaScript: Go to Project Configuration command. This command opens the jsconfig.json that references the JavaScript file. A notification is shown if the file is not part of any jsconfig.json project.

Snippets#
VS Code includes basic JavaScript snippets that are suggested as you type;

There are many extensions that provide additional snippets, including snippets for popular frameworks such as Redux or Angular. You can even define your own snippets.

Tip: To disable snippets suggestions, set editor.snippetSuggestions to "none" in your settings file. The editor.snippetSuggestions setting also lets you change where snippets appear in the suggestions: at the top ("top"), at the bottom ("bottom"), or inlined ordered alphabetically ("inline"). The default is "inline".

JSDoc support#
VS Code understands many standard JSDoc annotations, and uses these annotations to provide rich IntelliSense. You can optionally even use the type information from JSDoc comments to type check your JavaScript.

Quickly create JSDoc comments for functions by typing /** before the function declaration, and select the JSDoc comment snippet suggestion:

To disable JSDoc comment suggestions, set "javascript.suggest.completeJSDocs": false.

Hover Information#
Hover over a JavaScript symbol to quickly see its type information and relevant documentation.

Hovering over a JavaScript variable to see its type information

The ⌘K ⌘I (Windows, Linux Ctrl+K Ctrl+I) keyboard shortcut shows this hover information at the current cursor position.

Signature Help#
As you write JavaScript function calls, VS Code shows information about the function signature and highlights the parameter that you are currently completing:

Signature help for some DOM methods

Signature help is shown automatically when you type a ( or , within a function call. Press ⇧⌘Space (Windows, Linux Ctrl+Shift+Space) to manually trigger signature help.

Auto imports#
Automatic imports speed up coding by suggesting available variables throughout your project and its dependencies. When you select one of these suggestions, VS Code automatically adds an import for it to the top of the file.

Just start typing to see suggestions for all available JavaScript symbols in your current project. Auto import suggestions show where they will be imported from:

Global symbols are shown in the suggestion list

If you choose one of these auto import suggestions, VS Code adds an import for it.

In this example, VS Code adds an import for Button from material-ui to the top of the file:

After selecting a symbol from a different file, an import is added for it automatically

To disable auto imports, set "javascript.suggest.autoImports" to false.

Tip: VS Code tries to infer the best import style to use. You can explicitly configure the preferred quote style and path style for imports added to your code with the javascript.preferences.quoteStyle and javascript.preferences.importModuleSpecifier settings.

Formatting#
VS Code's built-in JavaScript formatter provides basic code formatting with reasonable defaults.

The javascript.format.* settings configure the built-in formatter. Or, if the built-in formatter is getting in the way, set "javascript.format.enable" to false to disable it.

For more specialized code formatting styles, try installing one of the JavaScript formatting extensions from the Marketplace.

JSX and auto closing tags#
All of VS Code's JavaScript features also work with JSX:

JSX IntelliSense

You can use JSX syntax in both normal *.js files and in *.jsx files.

VS Code also includes JSX-specific features such as autoclosing of JSX tags:

Set "javascript.autoClosingTags" to false to disable JSX tag closing.

Code navigation#
Code navigation lets you quickly navigate JavaScript projects.

Go to Definition F12 - Go to the source code of a symbol definition.
Peek Definition ⌥F12 (Windows Alt+F12, Linux Ctrl+Shift+F10) - Bring up a Peek window that shows the definition of a symbol.
Go to References ⇧F12 (Windows, Linux Shift+F12) - Show all references to a symbol.
Go to Type Definition - Go to the type that defines a symbol. For an instance of a class, this will reveal the class itself instead of where the instance is defined.
You can navigate via symbol search using the Go to Symbol commands from the Command Palette (⇧⌘P (Windows, Linux Ctrl+Shift+P)).

Go to Symbol in File ⇧⌘O (Windows, Linux Ctrl+Shift+O)
Go to Symbol in Workspace ⌘T (Windows, Linux Ctrl+T)
Rename#
Press F2 to rename the symbol under the cursor across your JavaScript project:

Renaming a variable

Refactoring#
VS Code includes some handy refactorings for JavaScript such as Extract function and Extract constant. Just select the source code you'd like to extract and then click on the lightbulb in the gutter or press (⌘. (Windows, Linux Ctrl+.)) to see available refactorings.

JavaScript refactoring

Available refactorings include:

Extract to method or function.
Extract to constant.
Convert between named imports and namespace imports.
Move to new file.
See Refactorings for more information about refactorings and how you can configure keyboard shortcuts for individual refactorings.

Unused variables and unreachable code#
Unused JavaScript code, such the else block of an if statement that is always true or an unreferenced import, is faded out in the editor:

Unreachable source code faded out

You can quickly remove this unused code by placing the cursor on it and triggering the Quick Fix command (⌘. (Windows, Linux Ctrl+.)) or clicking on the lightbulb.

To disable fading out of unused code, set "editor.showUnused" to false. You can also disable fading of unused code only in JavaScript by setting:

"[javascript]": {
    "editor.showUnused":  false
},
"[javascriptreact]": {
    "editor.showUnused":  false
},
Organize Imports#
The Organize Imports Source Action sorts the imports in a JavaScript file and removes any unused imports:

You can run Organize Imports from the Source Action context menu or with the ⇧⌥O (Windows, Linux Shift+Alt+O) keyboard shortcut.

Organize imports can also be done automatically when you save a JavaScript file by setting:

"editor.codeActionsOnSave": {
    "source.organizeImports": true
}
Code Actions on Save#
The editor.codeActionsOnSave setting lets you configure a set of Code Actions that are run when a file is saved. For example, you can enable organize imports on save by setting:

// On save, run both fixAll and organizeImports source actions
"editor.codeActionsOnSave": {
    "source.fixAll": true,
    "source.organizeImports": true,
}
You can also set editor.codeActionsOnSave to an array of Code Actions to execute in order.

Here are some source actions:

"organizeImports" - Enables organize imports on save.
"fixAll" - Auto Fix on Save computes all possible fixes in one round (for all providers including ESLint).
"fixAll.eslint" - Auto Fix only for ESLint.
"addMissingImports" - Adds all missing imports on save.
See Node.js/JavaScript for more information.

Code suggestions#
VS Code automatically suggests some common code simplifications such as converting a chain of .then calls on a promise to use async and await

Set "javascript.suggestionActions.enabled" to false to disable suggestions.

Inlay hints#
Inlay hints add additional inline information to source code to help you understand what the code does.

Parameter name inlay hints show the names of parameters in function calls:

Parameter name inlay hints

This can help you understand the meaning of each argument at a glance, which is especially helpful for functions that take Boolean flags or have parameters that are easy to mix up.

To enable parameter name hints, set javascript.inlayHints.parameterNames. There are three possible values:

none — Disable parameter inlay hints.
literals — Only show inlay hints for literals (string, number, Boolean).
all — Show inlay hints for all arguments.
Variable type inlay hints show the types of variables that don't have explicit type annotations.

Setting: javascript.inlayHints.variableTypes.enabled

Variable type inlay hints

Property type inlay hints show the type of class properties that don't have an explicit type annotation.

Setting: javascript.inlayHints.propertyDeclarationTypes.enabled

Property type inlay hints

Parameter type hints show the types of implicitly typed parameters.

Setting: javascript.inlayHints.parameterTypes.enabled

Parameter type inlay hints

Return type inlay hints show the return types of functions that don't have an explicit type annotation.

Setting: javascript.inlayHints.functionLikeReturnTypes.enabled

Return type inlay hints

References CodeLens#
The JavaScript references CodeLens displays an inline count of reference for classes, methods, properties, and exported objects:

JavaScript references CodeLens

To enable the references CodeLens, set "javascript.referencesCodeLens.enabled" to true.

Click on the reference count to quickly browse a list of references:

JavaScript references CodeLens peek

Update imports on file move#
When you move or rename a file that is imported by other files in your JavaScript project, VS Code can automatically update all import paths that reference the moved file:

The javascript.updateImportsOnFileMove.enabled setting controls this behavior. Valid settings values are:

"prompt" - The default. Asks if paths should be updated for each file move.
"always" - Always automatically update paths.
"never" - Do not update paths automatically and do not prompt.
Linters#
Linters provides warnings for suspicious looking code. While VS Code does not include a built-in JavaScript linter, many JavaScript linter extensions available in the marketplace.

ESLint
ESLint
22.5M
dbaeumer
Integrates ESLint JavaScript into VS Code.
jshint
jshint
2.2M
dbaeumer
Integrates JSHint into VS Code. JSHint is a linter for JavaScript
Flow Language Support
Flow Language Support
563.0K
flowtype
Flow support for VS Code
StandardJS - JavaScript Standard Style (old version)
StandardJS - JavaScript Standard Style (old version)
439.0K
chenxsan
Integrates JavaScript Standard Style into VS Code.
Tip: This list is dynamically queried from the VS Code Marketplace. Read the description and reviews to decide if the extension is right for you.

Type checking#
You can leverage some of TypeScript's advanced type checking and error reporting functionality in regular JavaScript files too. This is a great way to catch common programming mistakes. These type checks also enable some exciting Quick Fixes for JavaScript, including Add missing import and Add missing property.

Using type checking and Quick Fixes in a JavaScript file

TypeScript tried to infer types in .js files the same way it does in .ts files. When types cannot be inferred, they can be specified explicitly with JSDoc comments. You can read more about how TypeScript uses JSDoc for JavaScript type checking in Working with JavaScript.

Type checking of JavaScript is optional and opt-in. Existing JavaScript validation tools such as ESLint can be used alongside built-in type checking functionality.

Debugging#
VS Code comes with great debugging support for JavaScript. Set breakpoints, inspect objects, navigate the call stack, and execute code in the Debug Console. See the Debugging topic to learn more.

Debug client side#
You can debug your client-side code using a browser debugger such as our built-in debugger for Edge and Chrome, or the Debugger for Firefox.

Debug server side#
Debug Node.js in VS Code using the built-in debugger. Setup is easy and there is a Node.js debugging tutorial to help you.

debug data inspection

Popular extensions#
VS Code ships with excellent support for JavaScript but you can additionally install debuggers, snippets, linters, and other JavaScript tools through extensions.

Prettier - Code formatter
Prettier - Code formatter
25.1M
esbenp
Code formatter using prettier
IntelliCode
IntelliCode
22.5M
VisualStudioExptTeam
AI-assisted development
JavaScript (ES6) code snippets
JavaScript (ES6) code snippets
9.7M
xabikos
Code snippets for JavaScript in ES6 syntax
Babel JavaScript
Babel JavaScript
1.9M
mgmcdermott
VSCode syntax highlighting for today's JavaScript
Tip: The extensions shown above are dynamically queried. Click on an extension tile above to read the description and reviews to decide which extension is best for you. See more in the Marketplace.

Next steps#
Read on to find out about:

Working with JavaScript - More detailed information about VS Code's JavaScript support and how to troubleshoot common issues.
jsconfig.json - Detailed description of the jsconfig.json project file.
IntelliSense - Learn more about IntelliSense and how to use it effectively for your language.
Debugging - Learn how to set up debugging for your application.
Node.js - A walkthrough to create an Express Node.js application.
TypeScript - VS Code has great support for TypeScript, which brings structure and strong typing to your JavaScript code.
Common questions#
Does VS Code support JSX and React Native?#
VS Code supports JSX and React Native. You will get IntelliSense for React/JSX and React Native from automatically downloaded type declaration (typings) files from the npmjs type declaration file repository. Additionally, you can install the popular React Native extension from the Marketplace.

To enable ES6 import statements for React Native, you need to set the allowSyntheticDefaultImports compiler option to true. This tells the compiler to create synthetic default members and you get IntelliSense. React Native uses Babel behind the scenes to create the proper run-time code with default members. If you also want to do debugging of React Native code, you can install the React Native Extension.

Does VS Code support the Dart programming language and the Flutter framework?#
Yes, there are VS Code extensions for both Dart and Flutter development. You can learn more at the Flutter.dev documentation.

IntelliSense is not working for external libraries#
Automatic Type Acquisition works for dependencies downloaded by npm (specified in package.json), Bower (specified in bower.json), and for many of the most common libraries listed in your folder structure (for example jquery-3.1.1.min.js).

ES6 Style imports are not working.

When you want to use ES6 style imports but some type declaration (typings) files do not yet use ES6 style exports, then set the TypeScript compiler option allowSyntheticDefaultImports to true.

{
  "compilerOptions": {
    "module": "commonjs",
    "target": "es6",
    // This is the line you want to add
    "allowSyntheticDefaultImports": true
  },
  "exclude": ["node_modules", "**/node_modules/*"]
}
Can I debug minified/uglified JavaScript?#
Yes, you can. You can see this working using JavaScript source maps in the Node.js Debugging topic.

How do I disable Syntax Validation when using non-ES6 constructs?#
Some users want to use syntax constructs like the proposed pipeline (|>) operator. However, these are currently not supported by VS Code's JavaScript language service and are flagged as errors. For users who still want to use these future features, we provide the javascript.validate.enable setting.

With javascript.validate.enable: false, you disable all built-in syntax checking. If you do this, we recommend that you use a linter like ESLint to validate your source code.

Can I use other JavaScript tools like Flow?#
Yes, but some of Flow's language features such as type and error checking may interfere with VS Code's built-in JavaScript support. To learn how to disable VS Code's built-in JavaScript support, see Disable JavaScript support.

Was this documentation helpful?
Yes, this page was helpfulNo, this page was not helpful
9/1/2022
IN THIS ARTICLE THERE ARE 25 SECTIONSIN THIS ARTICLE
IntelliSense
JavaScript projects (jsconfig.json)
Snippets
JSDoc support
Hover Information
Signature Help
Auto imports
Formatting
JSX and auto closing tags
Code navigation
Rename
Refactoring
Unused variables and unreachable code
Organize Imports
Code Actions on Save
Code suggestions
Inlay hints
References CodeLens
Update imports on file move
Linters
Type checking
Debugging
Popular extensions
Next steps
Common questions
TwitterTweet this link
RSSSubscribe
StackoverflowAsk questions
TwitterFollow @code
GitHubRequest features
IssuesReport issues
YouTubeWatch videos
Hello from Seattle. Follow @code Support Privacy Terms of Use License 
Microsoft homepage© 2022 Microsoft
0 comments on commit c5508cd
@zakwarlord7

Add heading textAdd bold text, <Ctrl+b>Add italic text, <Ctrl+i>
Add a quote, <Ctrl+Shift+.>Add code, <Ctrl+e>Add a link, <Ctrl+k>
Add a bulleted list, <Ctrl+Shift+8>Add a numbered list, <Ctrl+Shift+7>Add a task list, <Ctrl+Shift+l>
Directly mention a user or team
Reference an issue, pull request, or discussion
Add saved reply
Leave a comment
No file chosen
Attach files by dragging & dropping, selecting or pasting them.
Styling with Markdown is supported
 You’re receiving notifications because you’re watching this repository.
Footer
© 2022 GitHub, Inc.
Footer navigation
Terms
Privacy
Security
Status
Docs
Contact GitHub
Pricing
API
Training
Blog
About
Create ci.yml · zakwarlord7/02100021@c5508cd
Web searchCopy
# install
intuit.yml
0 comments on commit c76e074
@zakwarlord7
 
Add heading textAdd bold text, <Ctrl+b>Add italic text, <Ctrl+i>
Add a quote, <Ctrl+Shift+.>Add code, <Ctrl+e>Add a link, <Ctrl+k>
Add a bulleted list, <Ctrl+Shift+8>Add a numbered list, <Ctrl+Shift+7>Add a task list, <Ctrl+Shift+l>
Directly mention a user or team
Reference an issue, pull request, or discussion
Add saved reply
Leave a comment
No file chosen
Attach files by dragging & dropping, selecting or pasting them.
Styling with Markdown is supported
 You’re receiving notifications because you’re watching this repository.
Footer
© 2022 GitHub, Inc.
Footer navigation
Terms
Privacy
Security
Status
Docs
Contact GitHub
Pricing
API
Training
Blog
About
