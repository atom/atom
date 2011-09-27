![](https://img.skitch.com/20110828-e6a2sk5mqewpfnxb3eeuef112d.png)

# Futuristic Text Editing

There are two things we are developing: a framework which lets you write Cocoa applications in CoffeeScript, HTML, and CSS utilizing the power of JSCocoa, and a highly extensible text editor built using that framework and Ace.

Let's call the framework "Radfish" and the text editor "Atomicity".


# Radfish

Our framework wraps the Cocoa APIs in idiomatic CoffeeScript using JSCocoa allowing you to write desktop applications using web technologies.

## Radfish Classes

**AtomApp** `Objective-C`

Handles delegation of Cocoa level details (intercepting events, creating `WebView`s). Event's are always send to the active `AtomWindowController`, inactive `AtomWindowController` don't get any messages.

**AtomWindowController** `Objective-C`

 Contains the `WebView` which `JSCocoa` uses. Each `AtomWindowController` has it's own instance of `Radfish`

**Radfish**

Holds all the information, keybindings, plugins. This is subclassed by your application.

**View**

Never used on it's own, a super class that contains code for specialized views.

**Pane extends View**

Has a position.

**Modal extends View**

Represents a Facebox.

**Plugin**

Modules with `startup` and `shutdown` functions. They can also have `description`, `url` properties, and `author` properties. The `url` property should point to the homepage, not an update url.

## Radfish Applications

A Radfish application is a subclass of `Radfish` that has two functions: `startup` and `shutdown`.

When a Radfish application starts up, plugins and keyboard bindings will be setup. It's up to you to create windows or do whatever.

Your `startup` function is executed in `JSCocoa`'s context, which is much more like a traditional browser environment: there's a `window` object, a `document` method, a DOM, etc. Normal web libraries such as jQuery work just fine in a `JSCocoa` context. Each `Radfish` instance is separate, they do not share the `window` object. In other words, traditional JavaScript globals are local to each `RadFish` instance.

Before shutting down, your application's `shutdown` method is called. The application won't shut down until this function returns.

Since we're developing these two products side by side, the `app` directory is our application. The `framework` directory is our Radfish source code.

# Atomicity

When Atomicity's `startup` function is called, we check storage for positions and URLs of previous windows then recreate them if any are found. If none are found, we open the code for the app itself as a project.

## Atomicity Classes

**App extends Ratfish**
Contains the `baseURL` and `openURLs` 

**Browser**

Represents a web page.

**Editor**

Represents text. Knows whether it uses tabs or spaces, and if spaces how many.

**Project**

Tree the represents `App`'s `baseURL` and `openURLs`

**Tabs**

Represents open buffers

