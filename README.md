![](https://img.skitch.com/20110828-e6a2sk5mqewpfnxb3eeuef112d.png)

# Futuristic Text Editing

There are two things we are developing: a framework which lets you write Cocoa applications in CoffeeScript, HTML, and CSS utilizing the power of JSCocoa, and a highly extensible text editor built using that framework and Ace.

Let's call the framework "Radfish" and the text editor "Atomicity".


# Radfish

Our framework wraps the Cocoa APIs in idiomatic CoffeeScript using JSCocoa allowing you to write desktop applications using web technologies.

## Radflish Classes

**Application**

Represents the running application. Has methods that let you do Cocoa stuff, like open modals or panes that aren't tied to any one window. Also handles the menu bar.

**Window**

Represents an NSWindow.

**View**

ViewController. Represents a `<div>`. Each View can add keyboard shortcuts to the window that are active when it is shown. They can also add keyboard shortcuts to themselves that are active when they have focus.

The HTML a View represents is known as the Template.

**Pane**

Specialized View. Represents `<div class='pane'>`. Has a position.

**Modal**

Specialized View. Represents a Facebox.

**Keybinder**

Binds keyboard shortcuts to functions and executes them when needed.

**PluginManager**

Class that loads and activates plugins. Plugins are modules with `startup` and `shutdown` functions. They can also have `description`, `url` properties, and `author` properties. The `url` property should point to the homepage, not an update url.

## Radfish Applications

A Radfish application is a module that exports two functions: `startup` and `shutdown`.

When a Radfish application starts up, your application module's `startup` function is passed an Application instance. It's up to you to create windows or do whatever.

Your `startup` function is executed in the Application Context, which means it doesn't have a `window` global or the DOM available because there isn't one.

Windows execute code in a Window Context, which is much more like a traditional browser environment: there's a `window` object, a `document` method, a DOM, etc. Normal web libraries such as jQuery work just fine in a Window Context. Each Window Context is separate, they do not share the `window` object. In other words, traditional JavaScript globals are local to windows.

Before shutting down, your application module's `shutdown` function is called. The application won't shut down until this function returns.

Since we're developing these two products side by side, the `app` directory is the module for our Radfish application. The `framework` directory is our Radfish source code.


# Atomicity

When Atomicity's `startup` function is called, we check storage for positions and URLs of previous windows then recreate them if any are found. If none are found, we open the code for the app itself as a project.

## Atomicity Classes

**Browser**

Document that represents a web page.

**Editor**

Document that represents text. Knows whether it uses tabs or spaces, and if spaces how many.

**Project**

Document that represents a directory.

**BrowserPane**

Pane that browses the web. Some would call it a web browser.

**EditorPane**

Pane that manages the text editor. Ace powered. In it to win it.

**ProjectDrawerPane**

Pane that represents the project drawer.

**TabPane**

A pane. For tabs.
