## Non hai bisogno di jQuery

Il mondo del Frontend si evolve rapidamente oggigiorno, i browsers moderni hanno gia' implementato un'ampia gamma di DOM/BOM API soddisfacenti. Non dobbiamo imparare jQuery dalle fondamenta per la manipolazione del DOM o di eventi. Nel frattempo, grazie al prevalicare di librerie per il frontend come React, Angular a Vue, manipolare il DOM direttamente diventa un anti-pattern, di consequenza jQuery non e' mai stato meno importante. Questo progetto sommarizza la maggior parte dei metodi e implementazioni alternative a jQuery, con il supporto di IE 10+.

## Tabella contenuti

1. [Query Selector](#query-selector)
1. [CSS & Style](#css--style)
1. [Manipolazione DOM](#manipolazione-dom)
1. [Ajax](#ajax)
1. [Eventi](#eventi)
1. [Utilities](#utilities)
1. [Alternative](#alternative)
1. [Traduzioni](#traduzioni)
1. [Supporto Browsers](#supporto-browsers)

## Query Selector

Al posto di comuni selettori come class, id o attributi possiamo usare `document.querySelector` o `document.querySelectorAll` per sostituzioni. La differenza risiede in:
* `document.querySelector` restituisce il primo elemento combiaciante
* `document.querySelectorAll` restituisce tutti gli elementi combiacianti della NodeList. Puo' essere convertito in Array usando `[].slice.call(document.querySelectorAll(selector) || []);`
* Se nessun elemento combiacia, jQuery restituitirebbe `[]` li' dove il DOM API ritornera' `null`. Prestate attenzione al Null Pointer Exception. Potete anche usare `||` per settare valori di default se non trovato, come `document.querySelectorAll(selector) || []`

> Notare: `document.querySelector` e `document.querySelectorAll` sono abbastanza **SLOW**, provate ad usare `getElementById`, `document.getElementsByClassName` o `document.getElementsByTagName` se volete avere un bonus in termini di performance.

- [1.0](#1.0) <a name='1.0'></a> Query da selettore

  ```js
  // jQuery
  $('selector');

  // Nativo
  document.querySelectorAll('selector');
  ```

- [1.1](#1.1) <a name='1.1'></a> Query da classe

  ```js
  // jQuery
  $('.class');

  // Nativo
  document.querySelectorAll('.class');

  // or
  document.getElementsByClassName('class');
  ```

- [1.2](#1.2) <a name='1.2'></a> Query da id

  ```js
  // jQuery
  $('#id');

  // Nativo
  document.querySelector('#id');

  // o
  document.getElementById('id');
  ```

- [1.3](#1.3) <a name='1.3'></a> Query da attributo

  ```js
  // jQuery
  $('a[target=_blank]');

  // Nativo
  document.querySelectorAll('a[target=_blank]');
  ```

- [1.4](#1.4) <a name='1.4'></a> Trovare qualcosa.

  + Trovare nodes

    ```js
    // jQuery
    $el.find('li');

    // Nativo
    el.querySelectorAll('li');
    ```

  + Trovare body

    ```js
    // jQuery
    $('body');

    // Nativo
    document.body;
    ```

  + Trovare Attributi

    ```js
    // jQuery
    $el.attr('foo');

    // Nativo
    e.getAttribute('foo');
    ```

  + Trovare attributo data

    ```js
    // jQuery
    $el.data('foo');

    // Nativo
    // using getAttribute
    el.getAttribute('data-foo');
    // potete usare `dataset` solo se supportate IE 11+
    el.dataset['foo'];
    ```

- [1.5](#1.5) <a name='1.5'></a> Fratelli/Precedento/Successivo Elemento

  + Elementi fratelli

    ```js
    // jQuery
    $el.siblings();

    // Nativo
    [].filter.call(el.parentNode.children, function(child) {
      return child !== el;
    });
    ```

  + Elementi precedenti

    ```js
    // jQuery
    $el.prev();

    // Nativo
    el.previousElementSibling;
    ```

  + Elementi successivi

    ```js
    // jQuery
    $el.next();

    // Nativo
    el.nextElementSibling;
    ```

- [1.6](#1.6) <a name='1.6'></a> Il piu' vicino

  Restituisce il primo elementi combiaciante il selettore fornito, attraversando dall'elemento corrente fino al document .

  ```js
  // jQuery
  $el.closest(queryString);
  
  // Nativo - Solo ultimo, NO IE
  el.closest(selector);

  // Nativo - IE10+ 
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

- [1.7](#1.7) <a name='1.7'></a> Fino a parenti

  Ottiene il parente di ogni elemento nel set corrente di elementi combiacianti, fino a ma non incluso, l'elemento combiaciante il selettorer, DOM node, o jQuery object.

  ```js
  // jQuery
  $el.parentsUntil(selector, filter);

  // Nativo
  function parentsUntil(el, selector, filter) {
    const result = [];
    const matchesSelector = el.matches || el.webkitMatchesSelector || el.mozMatchesSelector || el.msMatchesSelector;

    // il match parte dal parente
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

    // Nativo
    [].indexOf.call(document.querySelectAll('.radio'), e.currentTarget);
    ```

- [1.9](#1.9) <a name='1.9'></a> Iframe Contents

  `$('iframe').contents()` restituisce `contentDocument` per questo specifico iframe

  + Iframe contenuti

    ```js
    // jQuery
    $iframe.contents();

    // Nativo
    iframe.contentDocument;
    ```

  + Iframe Query

    ```js
    // jQuery
    $iframe.contents().find('.css');

    // Nativo
    iframe.contentDocument.querySelectorAll('.css');
    ```

**[⬆ back to top](#table-of-contents)**

## CSS & Style

- [2.1](#2.1) <a name='2.1'></a> CSS

  + Ottenere style

    ```js
    // jQuery
    $el.css("color");

    // Nativo
    // NOTA: Bug conosciuto, restituira' 'auto' se il valore di style e' 'auto'
    const win = el.ownerDocument.defaultView;
    // null significa che non restituira' lo psuedo style
    win.getComputedStyle(el, null).color;
    ```

  + Settare style

    ```js
    // jQuery
    $el.css({ color: "#ff0011" });

    // Nativo
    el.style.color = '#ff0011';
    ```

  + Ottenere/Settare Styles

    Nota che se volete settare styles multipli in una sola volta, potete riferire [setStyles](https://github.com/oneuijs/oui-dom-utils/blob/master/src/index.js#L194) metodo in oui-dom-utils package.


  + Aggiungere classe

    ```js
    // jQuery
    $el.addClass(className);

    // Nativo
    el.classList.add(className);
    ```

  + Rimouvere class

    ```js
    // jQuery
    $el.removeClass(className);

    // Nativo
    el.classList.remove(className);
    ```

  + has class

    ```js
    // jQuery
    $el.hasClass(className);

    // Nativo
    el.classList.contains(className);
    ```

  + Toggle class

    ```js
    // jQuery
    $el.toggleClass(className);

    // Nativo
    el.classList.toggle(className);
    ```

- [2.2](#2.2) <a name='2.2'></a> Width & Height

  Width e Height sono teoricamente identici, prendendo Height come esempio:

  + Window height

    ```js
    // window height
    $(window).height();
    // senza scrollbar, si comporta comporta jQuery
    window.document.documentElement.clientHeight;
    // con scrollbar
    window.innerHeight;
    ```

  + Document height

    ```js
    // jQuery
    $(document).height();

    // Nativo
    document.documentElement.scrollHeight;
    ```

  + Element height

    ```js
    // jQuery
    $el.height();

    // Nativo
    function getHeight(el) {
      const styles = this.getComputedStyles(el);
      const height = el.offsetHeight;
      const borderTopWidth = parseFloat(styles.borderTopWidth);
      const borderBottomWidth = parseFloat(styles.borderBottomWidth);
      const paddingTop = parseFloat(styles.paddingTop);
      const paddingBottom = parseFloat(styles.paddingBottom);
      return height - borderBottomWidth - borderTopWidth - paddingTop - paddingBottom;
    }
    // preciso a intero（quando `border-box`, e' `height`; quando `content-box`, e' `height + padding + border`）
    el.clientHeight;
    // preciso a decimale（quando `border-box`, e' `height`; quando `content-box`, e' `height + padding + border`）
    el.getBoundingClientRect().height;
    ```

- [2.3](#2.3) <a name='2.3'></a> Position & Offset

  + Position

    ```js
    // jQuery
    $el.position();

    // Nativo
    { left: el.offsetLeft, top: el.offsetTop }
    ```

  + Offset

    ```js
    // jQuery
    $el.offset();

    // Nativo
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

  // Nativo
  (document.documentElement && document.documentElement.scrollTop) || document.body.scrollTop;
  ```

**[⬆ back to top](#table-of-contents)**

## Manipolazione DOM

- [3.1](#3.1) <a name='3.1'></a> Remove
  ```js
  // jQuery
  $el.remove();

  // Nativo
  el.parentNode.removeChild(el);
  ```

- [3.2](#3.2) <a name='3.2'></a> Text

  + Get text

    ```js
    // jQuery
    $el.text();

    // Nativo
    el.textContent;
    ```

  + Set text

    ```js
    // jQuery
    $el.text(string);

    // Nativo
    el.textContent = string;
    ```

- [3.3](#3.3) <a name='3.3'></a> HTML

  + Ottenere HTML

    ```js
    // jQuery
    $el.html();

    // Nativo
    el.innerHTML;
    ```

  + Settare HTML

    ```js
    // jQuery
    $el.html(htmlString);

    // Nativo
    el.innerHTML = htmlString;
    ```

- [3.4](#3.4) <a name='3.4'></a> Append

  appendere elemento figlio dopo l'ultimo elemento figlio del genitore

  ```js
  // jQuery
  $el.append("<div id='container'>hello</div>");

  // Nativo
  el.insertAdjacentHTML("beforeend","<div id='container'>hello</div>");
  ```

- [3.5](#3.5) <a name='3.5'></a> Prepend

  ```js
  // jQuery
  $el.prepend("<div id='container'>hello</div>");

  // Nativo
  el.insertAdjacentHTML("afterbegin","<div id='container'>hello</div>");
  ```

- [3.6](#3.6) <a name='3.6'></a> insertBefore

  Inserire un nuovo node dopo l'elmento selezionato

  ```js
  // jQuery
  $newEl.insertBefore(queryString);

  // Nativo
  const target = document.querySelector(queryString);
  target.parentNode.insertBefore(newEl, target);
  ```

- [3.7](#3.7) <a name='3.7'></a> insertAfter

  Insert a new node after the selected elements

  ```js
  // jQuery
  $newEl.insertAfter(queryString);

  // Nativo
  const target = document.querySelector(queryString);
  target.parentNode.insertBefore(newEl, target.nextSibling);
  ```

- [3.8](#3.8) <a name='3.8'></a> is

  Restituisce `true` se combacia con l'elemento selezionato

  ```js
  // jQuery - Notare `is` funziona anche con `function` o `elements` non di importanza qui
  $el.is(selector);

  // Nativo
  el.matches(selector);
  ```
  
**[⬆ back to top](#table-of-contents)**

## Ajax

Sostituire con [fetch](https://github.com/camsong/fetch-ie8) and [fetch-jsonp](https://github.com/camsong/fetch-jsonp)

**[⬆ back to top](#table-of-contents)**

## Eventi

Per una completa sostituzione con namespace e delegation, riferire a https://github.com/oneuijs/oui-dom-events

- [5.1](#5.1) <a name='5.1'></a> Bind un evento con on

  ```js
  // jQuery
  $el.on(eventName, eventHandler);

  // Nativo
  el.addEventListener(eventName, eventHandler);
  ```

- [5.2](#5.2) <a name='5.2'></a> Unbind an event with off

  ```js
  // jQuery
  $el.off(eventName, eventHandler);

  // Nativo
  el.removeEventListener(eventName, eventHandler);
  ```

- [5.3](#5.3) <a name='5.3'></a> Trigger

  ```js
  // jQuery
  $(el).trigger('custom-event', {key1: 'data'});

  // Nativo
  if (window.CustomEvent) {
    const event = new CustomEvent('custom-event', {detail: {key1: 'data'}});
  } else {
    const event = document.createEvent('CustomEvent');
    event.initCustomEvent('custom-event', true, true, {key1: 'data'});
  }

  el.dispatchEvent(event);
  ```

**[⬆ back to top](#table-of-contents)**

## Utilities

- [6.1](#6.1) <a name='6.1'></a> isArray

  ```js
  // jQuery
  $.isArray(range);

  // Nativo
  Array.isArray(range);
  ```

- [6.2](#6.2) <a name='6.2'></a> Trim

  ```js
  // jQuery
  $.trim(string);

  // Nativo
  string.trim();
  ```

- [6.3](#6.3) <a name='6.3'></a> Object Assign

  Extend, usa object.assign polyfill https://github.com/ljharb/object.assign

  ```js
  // jQuery
  $.extend({}, defaultOpts, opts);

  // Nativo
  Object.assign({}, defaultOpts, opts);
  ```

- [6.4](#6.4) <a name='6.4'></a> Contains

  ```js
  // jQuery
  $.contains(el, child);

  // Nativo
  el !== child && el.contains(child);
  ```

**[⬆ back to top](#table-of-contents)**

## Alternative

* [Forse non hai bisogno di jQuery](http://youmightnotneedjquery.com/) - Esempi di come creare eventi comuni, elementi, ajax etc usando puramente javascript.
* [npm-dom](http://github.com/npm-dom) e [webmodules](http://github.com/webmodules) - Organizzazione dove puoi trovare moduli per il DOM individuale su NPM

## Traduzioni

* [한국어](./README.ko-KR.md)
* [简体中文](./README.zh-CN.md)
* [Bahasa Melayu](./README-my.md)
* [Bahasa Indonesia](./README-id.md)
* [Português(PT-BR)](./README.pt-BR.md)
* [Tiếng Việt Nam](./README-vi.md)
* [Español](./README-es.md)
* [Italiano](./README-it.md)
* [Türkçe](./README-tr.md)

## Supporto Browsers

![Chrome](https://raw.github.com/alrra/browser-logos/master/chrome/chrome_48x48.png) | ![Firefox](https://raw.github.com/alrra/browser-logos/master/firefox/firefox_48x48.png) | ![IE](https://raw.github.com/alrra/browser-logos/master/internet-explorer/internet-explorer_48x48.png) | ![Opera](https://raw.github.com/alrra/browser-logos/master/opera/opera_48x48.png) | ![Safari](https://raw.github.com/alrra/browser-logos/master/safari/safari_48x48.png)
--- | --- | --- | --- | --- |
Ultimo ✔ | Ultimo ✔ | 10+ ✔ | Ultimo ✔ | 6.1+ ✔ |

# Licenza

MIT
