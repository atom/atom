## One Light UI theme

A light UI theme that adapts to most syntax themes.

![One light UI](https://cloud.githubusercontent.com/assets/378023/26246819/0826f04e-3cd6-11e7-98eb-cd94bc48b090.png)

> The font used in the screenshot is [Fira Mono](https://github.com/mozilla/Fira).


### Install

This theme comes bundled with Atom and can be activated by going to the __Settings > Themes__ section and selecting "One Light" from the __UI Themes__ drop-down menu.


### Settings

In the theme settings you can:

- Change the __Font Size__ to scale the whole UI up or down.
- Choose between 3 __Tab Sizing__ modes.
- Hide the  __dock buttons__.

To make changes, go to `Settings > Themes > One Light UI > Settings` or the cog icon next to the theme picker.


### Customize

It's also possible to resize only certain areas by adding the following to your `styles.less` (Use DevTools to find the right selectors):

```css
.theme-one-light-ui {
  .tab-bar { font-size: 18px; }
  .tree-view { font-size: 14px; }
  .status-bar { font-size: 12px; }
}
```


### FAQ

__Why do the colors change when I switch Syntax themes.__
This UI theme uses the same background color as the chosen syntax theme. If that syntax theme has a dark background color, it only uses its hue, but otherwise stays light. This lets you use light-dark combos.
