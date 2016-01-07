## Anda tidak memerlukan jQuery

Mutakhir ini perkembangan dalam persekitaran frontend berlaku begitu pesat sekali. Justeru itu kebanyakan pelayar moden telahpun menyediakan API yang memadai untuk pengaksesan DOM/BOM. Kita tak payah lagi belajar jQuery dari asas untuk memanipulasi DOM dan acara-acara. Projek ini menawarkan perlaksanaan alternatif kepada kebanyakan kaedah-kaedah jQuery yang menyokong IE 10+.

## Isi Kandungan

1. [Pemilihan elemen](#pemilihan-elemen)
1. [CSS & Penggayaan](#css-penggayaan)
1. [Manipulasi DOM](#manipulasi-dom)
1. [Ajax](#ajax)
1. [Events](#events)
1. [Utiliti](#utiliti)
1. [Terjemahan](#terjemahan)
1. [Browser Support](#browser-support)

## Pemilihan Elemen

Pemilihan elemen yang umum seperti class, id atau atribut, biasanya kita boleh pakai `document.querySelector` atau `document.querySelectorAll` sebagai ganti. Bezanya terletak pada
* `document.querySelector` akan mengembalikan elemen pertama sekali yang sepadan dijumpai
* `document.querySelectorAll` akan mengembalikan kesemua elemen yang sepadan dijumpai kedalam sebuah NodeList. Ia boleh ditukar kedalam bentuk array menggunakan `[].slice.call`
* Sekiranya tiada elemen yang sepadan dijumpai, jQuery akan mengembalikan `[]` dimana API DOM pula akan mengembalikan `null`. Sila ambil perhatian pada Null Pointer Exception

> AWAS: `document.querySelector` dan `document.querySelectorAll` agak **LEMBAB** berbanding `getElementById`, `document.getElementsByClassName` atau `document.getElementsByTagName` jika anda menginginkan bonus dari segi prestasi.

- [1.1](#1.1) <a name='1.1'></a> Pemilihan menggunakan class

  ```js
  // jQuery
  $('.css');

  // Native
  document.querySelectorAll('.css');
  ```

- [1.2](#1.2) <a name='1.2'></a> Pemilihan menggunakan id

  ```js
  // jQuery
  $('#id');

  // Native
  document.querySelector('#id');
  ```

- [1.3](#1.3) <a name='1.3'></a> Pemilihan menggunakan atribut

  ```js
  // jQuery
  $('a[target=_blank]');

  // Native
  document.querySelectorAll('a[target=_blank]');
  ```

- [1.4](#1.4) <a name='1.4'></a> Cari sth.

  + Find nodes

    ```js
    // jQuery
    $el.find('li');

    // Native
    el.querySelectorAll('li');
    ```

  + Cari body

    ```js
    // jQuery
    $('body');

    // Native
    document.body;
    ```

  + Cari Attribute

    ```js
    // jQuery
    $el.attr('foo');

    // Native
    e.getAttribute('foo');
    ```

  + Cari atribut data

    ```js
    // jQuery
    $el.data('foo');

    // Native
    // menggunakan getAttribute
    el.getAttribute('data-foo');
    // anda boleh juga gunakan `dataset` jika ingin pakai IE 11+
    el.dataset['foo'];
    ```

- [1.5](#1.5) <a name='1.5'></a> Sibling/Previous/Next Elements

  + Sibling elements

    ```js
    // jQuery
    $el.siblings();

    // Native
    [].filter.call(el.parentNode.children, function(child) {
      return child !== el;
    });
    ```

  + Previous elements

    ```js
    // jQuery
    $el.prev();

    // Native
    el.previousElementSibling;

    ```

  + Next elements

    ```js
    // next
    $el.next();
    el.nextElementSibling;
    ```

- [1.6](#1.6) <a name='1.6'></a> Closest

  Return the first matched element by provided selector, traversing from current element to document.

  ```js
  // jQuery
  $el.closest(queryString);

  // Native
  function closest(el, selector) {
    const matchesSelector = el.matches || el.webkitMatchesSelector || el.mozMatchesSelector || el.msMatchesSelector;

    while (el) {
      if (matchesSelector.call(el, selector)) {
        return el;
      } else {
        el = el.parentElement;
      }
    }
    return null;
  }
  ```

- [1.7](#1.7) <a name='1.7'></a> Parents Until

  Get the ancestors of each element in the current set of matched elements, up to but not including the element matched by the selector, DOM node, or jQuery object.

  ```js
  // jQuery
  $el.parentsUntil(selector, filter);

  // Native
  function parentsUntil(el, selector, filter) {
    const result = [];
    const matchesSelector = el.matches || el.webkitMatchesSelector || el.mozMatchesSelector || el.msMatchesSelector;

    // match start from parent
    el = el.parentElement;
    while (el && !matchesSelector.call(el, selector)) {
      if (!filter) {
        result.push(el);
      } else {
        if (matchesSelector.call(el, filter)) {
          result.push(el);
        }
      }
      el = el.parentElement;
    }
    return result;
  }
  ```

- [1.8](#1.8) <a name='1.8'></a> Form

  + Input/Textarea

    ```js
    // jQuery
    $('#my-input').val();

    // Native
    document.querySelector('#my-input').value;
    ```

  + Get index of e.currentTarget between `.radio`

    ```js
    // jQuery
    $(e.currentTarget).index('.radio');

    // Native
    [].indexOf.call(document.querySelectAll('.radio'), e.currentTarget);
    ```

- [1.9](#1.9) <a name='1.9'></a> Iframe Contents

  `$('iframe').contents()` returns `contentDocument` for this specific iframe

  + Iframe contents

    ```js
    // jQuery
    $iframe.contents();

    // Native
    iframe.contentDocument;
    ```

  + Iframe Query

    ```js
    // jQuery
    $iframe.contents().find('.css');

    // Native
    iframe.contentDocument.querySelectorAll('.css');
    ```

**[⬆ back to top](#table-of-contents)**

## CSS & Style

- [2.1](#2.1) <a name='2.1'></a> CSS

  + Get style

    ```js
    // jQuery
    $el.css("color");

    // Native
    // NOTE: Known bug, will return 'auto' if style value is 'auto'
    const win = el.ownerDocument.defaultView;
    // null means not return presudo styles
    win.getComputedStyle(el, null).color;
    ```

  + Set style

    ```js
    // jQuery
    $el.css({ color: "#ff0011" });

    // Native
    el.style.color = '#ff0011';
    ```

  + Get/Set Styles

    Note that if you want to set multiple styles once, you could refer to [setStyles](https://github.com/oneuijs/oui-dom-utils/blob/master/src/index.js#L194) method in oui-dom-utils package.


  + Add class

    ```js
    // jQuery
    $el.addClass(className);

    // Native
    el.classList.add(className);
    ```

  + Remove class

    ```js
    // jQuery
    $el.removeClass(className);

    // Native
    el.classList.remove(className);
    ```

  + has class

    ```js
    // jQuery
    $el.hasClass(className);

    // Native
    el.classList.contains(className);
    ```

  + Toggle class

    ```js
    // jQuery
    $el.toggleClass(className);

    // Native
    el.classList.toggle(className);
    ```

- [2.2](#2.2) <a name='2.2'></a> Width & Height

  Width and Height are theoretically identical, take Height as example:

  + Window height

    ```js
    // window height
    $(window).height();
    // without scrollbar, behaves like jQuery
    window.document.documentElement.clientHeight;
    // with scrollbar
    window.innerHeight;
    ```

  + Document height

    ```js
    // jQuery
    $(document).height();

    // Native
    document.documentElement.scrollHeight;
    ```

  + Element height

    ```js
    // jQuery
    $el.height();

    // Native
    function getHeight(el) {
      const styles = this.getComputedStyles(el);
      const height = el.offsetHeight;
      const borderTopWidth = parseFloat(styles.borderTopWidth);
      const borderBottomWidth = parseFloat(styles.borderBottomWidth);
      const paddingTop = parseFloat(styles.paddingTop);
      const paddingBottom = parseFloat(styles.paddingBottom);
      return height - borderBottomWidth - borderTopWidth - paddingTop - paddingBottom;
    }
    // accurate to integer（when `border-box`, it's `height`; when `content-box`, it's `height + padding + border`）
    el.clientHeight;
    // accurate to decimal（when `border-box`, it's `height`; when `content-box`, it's `height + padding + border`）
    el.getBoundingClientRect().height;
    ```

- [2.3](#2.3) <a name='2.3'></a> Position & Offset

  + Position

    ```js
    // jQuery
    $el.position();

    // Native
    { left: el.offsetLeft, top: el.offsetTop }
    ```

  + Offset

    ```js
    // jQuery
    $el.offset();

    // Native
    function getOffset (el) {
      const box = el.getBoundingClientRect();

      return {
        top: box.top + window.pageYOffset - document.documentElement.clientTop,
        left: box.left + window.pageXOffset - document.documentElement.clientLeft
      }
    }
    ```

- [2.4](#2.4) <a name='2.4'></a> Scroll Top

  ```js
  // jQuery
  $(window).scrollTop();

  // Native
  (document.documentElement && document.documentElement.scrollTop) || document.body.scrollTop;
  ```

**[⬆ back to top](#table-of-contents)**

## DOM Manipulation

- [3.1](#3.1) <a name='3.1'></a> Remove
  ```js
  // jQuery
  $el.remove();

  // Native
  el.parentNode.removeChild(el);
  ```

- [3.2](#3.2) <a name='3.2'></a> Text

  + Get text

    ```js
    // jQuery
    $el.text();

    // Native
    el.textContent;
    ```

  + Set text

    ```js
    // jQuery
    $el.text(string);

    // Native
    el.textContent = string;
    ```

- [3.3](#3.3) <a name='3.3'></a> HTML

  + Get HTML

    ```js
    // jQuery
    $el.html();

    // Native
    el.innerHTML;
    ```

  + Set HTML

    ```js
    // jQuery
    $el.html(htmlString);

    // Native
    el.innerHTML = htmlString;
    ```

- [3.4](#3.4) <a name='3.4'></a> Append

  append child element after the last child of parent element

  ```js
  // jQuery
  $el.append("<div id='container'>hello</div>");

  // Native
  let newEl = document.createElement('div');
  newEl.setAttribute('id', 'container');
  newEl.innerHTML = 'hello';
  el.appendChild(newEl);
  ```

- [3.5](#3.5) <a name='3.5'></a> Prepend

  ```js
  // jQuery
  $el.prepend("<div id='container'>hello</div>");

  // Native
  let newEl = document.createElement('div');
  newEl.setAttribute('id', 'container');
  newEl.innerHTML = 'hello';
  el.insertBefore(newEl, el.firstChild);
  ```

- [3.6](#3.6) <a name='3.6'></a> insertBefore

  Insert a new node before the selected elements

  ```js
  // jQuery
  $newEl.insertBefore(queryString);

  // Native
  const target = document.querySelector(queryString);
  target.parentNode.insertBefore(newEl, target);
  ```

- [3.7](#3.7) <a name='3.7'></a> insertAfter

  Insert a new node after the selected elements

  ```js
  // jQuery
  $newEl.insertAfter(queryString);

  // Native
  const target = document.querySelector(queryString);
  target.parentNode.insertBefore(newEl, target.nextSibling);
  ```

**[⬆ back to top](#table-of-contents)**

## Ajax

Replace with [fetch](https://github.com/camsong/fetch-ie8) and [fetch-jsonp](https://github.com/camsong/fetch-jsonp)

**[⬆ back to top](#table-of-contents)**

## Events

For a complete replacement with namespace and delegation, refer to https://github.com/oneuijs/oui-dom-events

- [5.1](#5.1) <a name='5.1'></a> Bind an event with on

  ```js
  // jQuery
  $el.on(eventName, eventHandler);

  // Native
  el.addEventListener(eventName, eventHandler);
  ```

- [5.2](#5.2) <a name='5.2'></a> Unbind an event with off

  ```js
  // jQuery
  $el.off(eventName, eventHandler);

  // Native
  el.removeEventListener(eventName, eventHandler);
  ```

- [5.3](#5.3) <a name='5.3'></a> Trigger

  ```js
  // jQuery
  $(el).trigger('custom-event', {key1: 'data'});

  // Native
  if (window.CustomEvent) {
    const event = new CustomEvent('custom-event', {detail: {key1: 'data'}});
  } else {
    const event = document.createEvent('CustomEvent');
    event.initCustomEvent('custom-event', true, true, {key1: 'data'});
  }

  el.dispatchEvent(event);
  ```

**[⬆ back to top](#table-of-contents)**

## Utility

- [6.1](#6.1) <a name='6.1'></a> isArray

  ```js
  // jQuery
  $.isArray(range);

  // Native
  Array.isArray(range);
  ```

- [6.2](#6.2) <a name='6.2'></a> Trim

  ```js
  // jQuery
  $.trim(string);

  // Native
  String.trim(string);
  ```

- [6.3](#6.3) <a name='6.3'></a> Object Assign

  Extend, use object.assign polyfill https://github.com/ljharb/object.assign

  ```js
  // jQuery
  $.extend({}, defaultOpts, opts);

  // Native
  Object.assign({}, defaultOpts, opts);
  ```

- [6.4](#6.4) <a name='6.4'></a> Contains

  ```js
  // jQuery
  $.contains(el, child);

  // Native
  el !== child && el.contains(child);
  ```

**[⬆ back to top](#table-of-contents)**

## Terjemahan

* [한국어](./README.ko-KR.md)
* [简体中文](./README.zh-CN.md)
* [English](./README.md)
* [Русский](./README-ru.md)
* [Türkçe](./README-tr.md)

## Sokongan Pelayar

![Chrome](https://raw.github.com/alrra/browser-logos/master/chrome/chrome_48x48.png) | ![Firefox](https://raw.github.com/alrra/browser-logos/master/firefox/firefox_48x48.png) | ![IE](https://raw.github.com/alrra/browser-logos/master/internet-explorer/internet-explorer_48x48.png) | ![Opera](https://raw.github.com/alrra/browser-logos/master/opera/opera_48x48.png) | ![Safari](https://raw.github.com/alrra/browser-logos/master/safari/safari_48x48.png)
--- | --- | --- | --- | --- |
Latest ✔ | Latest ✔ | 10+ ✔ | Latest ✔ | 6.1+ ✔ |

# Lesen

MIT
