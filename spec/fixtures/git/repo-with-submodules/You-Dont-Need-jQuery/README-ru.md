## Вам не нужен jQuery

В наше время среда фронт энд разработки быстро развивается, современные браузеры уже реализовали значимую часть DOM/BOM APIs и это хорошо. Вам не нужно изучать jQuery с нуля для манипуляцией DOM'ом или обектами событий. В то же время, благодаря лидирующим фронт энд библиотекам, таким как React, Angular и Vue, манипуляция DOM'ом напрямую становится противо шаблонной, jQuery никогда не был менее важен. Этот проект суммирует большинство альтернатив методов jQuery в нативном исполнении с поддержкой IE 10+.

## Содержание

1. [Query Selector](#query-selector)
1. [CSS & Style](#css--style)
1. [Манипуляция DOM](#Манипуляции-dom)
1. [Ajax](#ajax)
1. [События](#События)
1. [Утилиты](#Утилиты)
1. [Альтернативы](#Альтернативы)
1. [Переводы](#Переводы)
1. [Поддержка браузеров](#Поддержка-браузеров)

## Query Selector
Для часто используемых селекторов, таких как class, id или attribute мы можем использовать `document.querySelector` или `document.querySelectorAll` для замены. Разница такова:
* `document.querySelector` возвращает первый совпавший элемент
* `document.querySelectorAll` возвращает все совспавшие элементы как  коллекцию узлов(NodeList). Его можно конвертировать в массив используя `[].slice.call(document.querySelectorAll(selector) || []);`
* Если никакие элементы не совпадут, jQuery вернет `[]` где DOM API вернет `null`. Обратите внимание на указатель исключения  Null (Null Pointer Exception). Вы так же можете использовать `||` для установки значения по умолчанию если не было найдемо совпадений `document.querySelectorAll(selector) || []`

> Заметка: `document.querySelector` и `document.querySelectorAll` достаточно **МЕДЛЕННЫ**, старайтесь использовать `getElementById`, `document.getElementsByClassName` или `document.getElementsByTagName` если хотите улучшить производительность.

- [1.0](#1.0) <a name='1.0'></a> Query by selector

  ```js
  // jQuery
  $('selector');

  // Нативно
  document.querySelectorAll('selector');
  ```

- [1.1](#1.1) <a name='1.1'></a> Запрос по классу

  ```js
  // jQuery
  $('.class');

  // Нативно
  document.querySelectorAll('.class');

  // или
  document.getElementsByClassName('class');
  ```

- [1.2](#1.2) <a name='1.2'></a> Запрос по ID

  ```js
  // jQuery
  $('#id');

  // Нативно
  document.querySelector('#id');

  // или
  document.getElementById('id');
  ```

- [1.3](#1.3) <a name='1.3'></a> Запрос по атрибуту

  ```js
  // jQuery
  $('a[target=_blank]');

  // Нативно
  document.querySelectorAll('a[target=_blank]');
  ```

- [1.4](#1.4) <a name='1.4'></a> Найти среди потомков

  + Найти nodes

    ```js
    // jQuery
    $el.find('li');

    // Нативно
    el.querySelectorAll('li');
    ```

  + Найти body

    ```js
    // jQuery
    $('body');

    // Нативно
    document.body;
    ```

  + Найти атрибуты

    ```js
    // jQuery
    $el.attr('foo');

    // Нативно
    e.getAttribute('foo');
    ```

  + Найти data attribute

    ```js
    // jQuery
    $el.data('foo');

    // Нативно
    // используя getAttribute
    el.getAttribute('data-foo');
    // также можно использовать `dataset`, если не требуется поддержка ниже IE 11.
    el.dataset['foo'];
    ```

- [1.5](#1.5) <a name='1.5'></a> Родственные/Предыдущие/Следующие Элементы

  + Родственные элементы

    ```js
    // jQuery
    $el.siblings();

    // Нативно
    [].filter.call(el.parentNode.children, function(child) {
      return child !== el;
    });
    ```

  + Предыдущие элементы

    ```js
    // jQuery
    $el.prev();

    // Нативно
    el.previousElementSibling;
    ```

  + Следующие элементы

    ```js
    // jQuery
    $el.next();

    // Нативно
    el.nextElementSibling;
    ```

- [1.6](#1.6) <a name='1.6'></a> Closest

  Возвращает первый совпавший элемент по предоставленному селектору, обоходя от текущего элементы до документа.

  ```js
  // jQuery
  $el.closest(queryString);
  
  // Нативно - Only latest, NO IE
  el.closest(selector);

  // Нативно - IE10+ 
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

- [1.7](#1.7) <a name='1.7'></a> Родители до

  Получить родителей кажого элемента в текущем сете совпавших элементов, но не включая элемент совпавший с селектором, узел DOM'а, или объект jQuery.

  ```js
  // jQuery
  $el.parentsUntil(selector, filter);

  // Нативно
  function parentsUntil(el, selector, filter) {
    const result = [];
    const matchesSelector = el.matches || el.webkitMatchesSelector || el.mozMatchesSelector || el.msMatchesSelector;

    // Совпадать начиная от родителя
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

- [1.8](#1.8) <a name='1.8'></a> От

  + Input/Textarea

    ```js
    // jQuery
    $('#my-input').val();

    // Нативно
    document.querySelector('#my-input').value;
    ```

  + получить индекс e.currentTarget между `.radio`

    ```js
    // jQuery
    $(e.currentTarget).index('.radio');

    // Нативно
    [].indexOf.call(document.querySelectAll('.radio'), e.currentTarget);
    ```

- [1.9](#1.9) <a name='1.9'></a> Контент Iframe

  `$('iframe').contents()` возвращает `contentDocument` для именно этого iframe

  + Контент Iframe

    ```js
    // jQuery
    $iframe.contents();

    // Нативно
    iframe.contentDocument;
    ```

  + Iframe Query

    ```js
    // jQuery
    $iframe.contents().find('.css');

    // Нативно
    iframe.contentDocument.querySelectorAll('.css');
    ```

**[⬆ Наверх](#Содержание)**

## CSS & Style

- [2.1](#2.1) <a name='2.1'></a> CSS

  + Получить стиль

    ```js
    // jQuery
    $el.css("color");

    // Нативно
    // ЗАМЕТКА: Известная ошика, возвращает 'auto' если значение стиля 'auto'
    const win = el.ownerDocument.defaultView;
    // null означает не возвращать псевдостили
    win.getComputedStyle(el, null).color;
    ```

  + Присвоение style

    ```js
    // jQuery
    $el.css({ color: "#ff0011" });

    // Нативно
    el.style.color = '#ff0011';
    ```

  + Получение/Присвоение стилей

    Заметьте что если вы хотите присвоить несколько стилей за раз, вы можете сослаться на [setStyles](https://github.com/oneuijs/oui-dom-utils/blob/master/src/index.js#L194) метод в oui-dom-utils package.


  + Добавить класс

    ```js
    // jQuery
    $el.addClass(className);

    // Нативно
    el.classList.add(className);
    ```

  + Удалить class

    ```js
    // jQuery
    $el.removeClass(className);

    // Нативно
    el.classList.remove(className);
    ```

  + Имеет класс

    ```js
    // jQuery
    $el.hasClass(className);

    // Нативно
    el.classList.contains(className);
    ```

  + Переключать класс

    ```js
    // jQuery
    $el.toggleClass(className);

    // Нативно
    el.classList.toggle(className);
    ```

- [2.2](#2.2) <a name='2.2'></a> Ширина и Высота

  Ширина и высота теоритечески идентичны, например возьмем высоту:

  + высота окна

    ```js
    // Высота окна
    $(window).height();
    // без скроллбара, ведет себя как jQuery
    window.document.documentElement.clientHeight;
    // вместе с скроллбаром
    window.innerHeight;
    ```

  + высота документа

    ```js
    // jQuery
    $(document).height();

    // Нативно
    document.documentElement.scrollHeight;
    ```

  + Высота элемента

    ```js
    // jQuery
    $el.height();

    // Нативно
    function getHeight(el) {
      const styles = this.getComputedStyles(el);
      const height = el.offsetHeight;
      const borderTopWidth = parseFloat(styles.borderTopWidth);
      const borderBottomWidth = parseFloat(styles.borderBottomWidth);
      const paddingTop = parseFloat(styles.paddingTop);
      const paddingBottom = parseFloat(styles.paddingBottom);
      return height - borderBottomWidth - borderTopWidth - paddingTop - paddingBottom;
    }
    // С точностью до целого числа（когда `border-box`, это `height`; когда `content-box`, это `height + padding + border`）
    el.clientHeight;
    // с точностью до десятых（когда `border-box`, это `height`; когда `content-box`, это `height + padding + border`）
    el.getBoundingClientRect().height;
    ```

- [2.3](#2.3) <a name='2.3'></a> Позиция и смещение

  + Позиция

    ```js
    // jQuery
    $el.position();

    // Нативно
    { left: el.offsetLeft, top: el.offsetTop }
    ```

  + Смещение

    ```js
    // jQuery
    $el.offset();

    // Нативно
    function getOffset (el) {
      const box = el.getBoundingClientRect();

      return {
        top: box.top + window.pageYOffset - document.documentElement.clientTop,
        left: box.left + window.pageXOffset - document.documentElement.clientLeft
      }
    }
    ```

- [2.4](#2.4) <a name='2.4'></a> Прокрутка вверх

  ```js
  // jQuery
  $(window).scrollTop();

  // Нативно
  (document.documentElement && document.documentElement.scrollTop) || document.body.scrollTop;
  ```

**[⬆ Наверх](#Содержание)**

## Манипуляции DOM

- [3.1](#3.1) <a name='3.1'></a> Remove
  ```js
  // jQuery
  $el.remove();

  // Нативно
  el.parentNode.removeChild(el);
  ```

- [3.2](#3.2) <a name='3.2'></a> Текст

  + Получить текст

    ```js
    // jQuery
    $el.text();

    // Нативно
    el.textContent;
    ```

  + Присвоить текст 

    ```js
    // jQuery
    $el.text(string);

    // Нативно
    el.textContent = string;
    ```

- [3.3](#3.3) <a name='3.3'></a> HTML

  + Получить HTML

    ```js
    // jQuery
    $el.html();

    // Нативно
    el.innerHTML;
    ```

  + Присвоить HTML

    ```js
    // jQuery
    $el.html(htmlString);

    // Нативно
    el.innerHTML = htmlString;
    ```

- [3.4](#3.4) <a name='3.4'></a> Append

  Добавление элемента ребенка после последнего ребенка элемента родителя

  ```js
  // jQuery
  $el.append("<div id='container'>hello</div>");

  // Нативно
  el.insertAdjacentHTML("beforeend","<div id='container'>hello</div>");
  ```

- [3.5](#3.5) <a name='3.5'></a> Prepend

  ```js
  // jQuery
  $el.prepend("<div id='container'>hello</div>");

  // Нативно
  el.insertAdjacentHTML("afterbegin","<div id='container'>hello</div>");
  ```

- [3.6](#3.6) <a name='3.6'></a> insertBefore

  Вставка нового элемента перед выбранным элементом

  ```js
  // jQuery
  $newEl.insertBefore(queryString);

  // Нативно
  const target = document.querySelector(queryString);
  target.parentNode.insertBefore(newEl, target);
  ```

- [3.7](#3.7) <a name='3.7'></a> insertAfter

  Вставка новго элемента после выбранного элемента

  ```js
  // jQuery
  $newEl.insertAfter(queryString);

  // Нативно
  const target = document.querySelector(queryString);
  target.parentNode.insertBefore(newEl, target.nextSibling);
  ```

- [3.8](#3.8) <a name='3.8'></a> is

  Возвращает `true` если  совпадает с селектором запроса

  ```js
  // jQuery - заметьте что `is` так же работает с `function` или `elements` которые не имют к этому отношения
  $el.is(selector);

  // Нативно
  el.matches(selector);
  ```
  
**[⬆ Наверх](#Содержание)**

## Ajax

Заменить с [fetch](https://github.com/camsong/fetch-ie8) и [fetch-jsonp](https://github.com/camsong/fetch-jsonp)

**[⬆ Наверх](#Содержание)**

## События

Для полной замены с пространством имен и делегация, сослаться на [oui-dom-events](https://github.com/oneuijs/oui-dom-events)

- [5.1](#5.1) <a name='5.1'></a> Связать событие используя on

  ```js
  // jQuery
  $el.on(eventName, eventHandler);

  // Нативно
  el.addEventListener(eventName, eventHandler);
  ```

- [5.2](#5.2) <a name='5.2'></a> Отвязать событие используя off

  ```js
  // jQuery
  $el.off(eventName, eventHandler);

  // Нативно
  el.removeEventListener(eventName, eventHandler);
  ```

- [5.3](#5.3) <a name='5.3'></a> Trigger

  ```js
  // jQuery
  $(el).trigger('custom-event', {key1: 'data'});

  // Нативно
  if (window.CustomEvent) {
    const event = new CustomEvent('custom-event', {detail: {key1: 'data'}});
  } else {
    const event = document.createEvent('CustomEvent');
    event.initCustomEvent('custom-event', true, true, {key1: 'data'});
  }

  el.dispatchEvent(event);
  ```

**[⬆ Наверх](#Содержание)**

## Утилиты

- [6.1](#6.1) <a name='6.1'></a> isArray

  ```js
  // jQuery
  $.isArray(range);

  // Нативно
  Array.isArray(range);
  ```

- [6.2](#6.2) <a name='6.2'></a> Trim

  ```js
  // jQuery
  $.trim(string);

  // Нативно
  string.trim();
  ```

- [6.3](#6.3) <a name='6.3'></a> Назначение объекта

  Дополнительно, используйте полифил object.assign https://github.com/ljharb/object.assign

  ```js
  // jQuery
  $.extend({}, defaultOpts, opts);

  // Нативно
  Object.assign({}, defaultOpts, opts);
  ```

- [6.4](#6.4) <a name='6.4'></a> Contains

  ```js
  // jQuery
  $.contains(el, child);

  // Нативно
  el !== child && el.contains(child);
  ```

**[⬆ Наверх](#Содержание)**

## Альтернативы

* [You Might Not Need jQuery](http://youmightnotneedjquery.com/) - Примеры как исполняются частые события, элементы, ajax и тд с ванильным javascript.
* [npm-dom](http://github.com/npm-dom) и [webmodules](http://github.com/webmodules) - Отдельные DOM модули можно найти на NPM

## Переводы

* [한국어](./README.ko-KR.md)
* [简体中文](./README.zh-CN.md)
* [Bahasa Melayu](./README-my.md)
* [Bahasa Indonesia](./README-id.md)
* [Português(PT-BR)](./README.pt-BR.md)
* [Tiếng Việt Nam](./README-vi.md)
* [Español](./README-es.md)
* [Русский](./README-ru.md)
* [Türkçe](./README-tr.md)

## Поддержка браузеров

![Chrome](https://raw.github.com/alrra/browser-logos/master/chrome/chrome_48x48.png) | ![Firefox](https://raw.github.com/alrra/browser-logos/master/firefox/firefox_48x48.png) | ![IE](https://raw.github.com/alrra/browser-logos/master/internet-explorer/internet-explorer_48x48.png) | ![Opera](https://raw.github.com/alrra/browser-logos/master/opera/opera_48x48.png) | ![Safari](https://raw.github.com/alrra/browser-logos/master/safari/safari_48x48.png)
--- | --- | --- | --- | --- |
Latest ✔ | Latest ✔ | 10+ ✔ | Latest ✔ | 6.1+ ✔ |

# License

MIT
