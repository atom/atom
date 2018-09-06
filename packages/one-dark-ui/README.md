## One Dark UI theme [![Build Status](https://travis-ci.org/atom/one-dark-ui.svg?branch=master)](https://travis-ci.org/atom/one-dark-ui)

A dark UI theme that adapts to most syntax themes.

![One dark UI](https://cloud.githubusercontent.com/assets/378023/26246818/08255b76-3cd6-11e7-9f6d-6ae3e16a89a9.png)

> The font used in the screenshot is [Fira Mono](https://github.com/mozilla/Fira).


### Install

This theme comes bundled with Atom and can be activated by going to the __Settings > Themes__ section and selecting "One Dark" from the __UI Themes__ drop-down menu.


### Settings

In the theme settings you can:

- Change the __Font Size__ to scale the whole UI up or down.
- Choose between 3 __Tab Sizing__ modes.
- Hide the  __dock buttons__.

To make changes, go to `Settings > Themes > One Dark UI > Settings` or the cog icon next to the theme picker.


### Customize

It's also possible to resize only certain areas by adding the following to your `styles.less` (Use DevTools to find the right selectors):

```css
.theme-one-dark-ui {
  .tab-bar { font-size: 18px; }
  .tree-view { font-size: 14px; }
  .status-bar { font-size: 12px; }
}
```


### FAQ

__Why do the colors change when I switch Syntax themes?__
This UI theme uses the same background color as the chosen syntax theme. If that syntax theme has a light background color, it only uses its hue, but otherwise stays dark. This lets you use dark-light combos.
