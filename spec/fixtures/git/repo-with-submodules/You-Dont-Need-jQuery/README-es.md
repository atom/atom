
> #### You Don't Need jQuery

Tú no necesitas jQuery
---
El desarrollo Frontend evoluciona día a día, y los navegadores modernos ya han implementado nativamente APIs para trabajar con DOM/BOM, las cuales son muy buenas, por lo que definitivamente no es necesario aprender jQuery desde cero para manipular el DOM. En la actualidad, gracias al surgimiento de librerías frontend como React, Angular y Vue, manipular el DOM es contrario a los patrones establecidos, y jQuery se ha vuelto menos importante. Este proyecto resume la mayoría de métodos alternativos a jQuery, pero de forma nativa con soporte IE 10+.

## Tabla de Contenidos

1. [Query Selector](#query-selector)
1. [CSS & Estilo](#css--estilo)
1. [Manipulación DOM](#manipulación-dom)
1. [Ajax](#ajax)
1. [Eventos](#eventos)
1. [Utilidades](#utilidades)
1. [Traducción](#traducción)
1. [Soporte de Navegadores](#soporte-de-navegadores)


## Query Selector

En lugar de los selectores comunes como clase, id o atributos podemos usar `document.querySelector` o `document.querySelectorAll` como alternativas. Las diferencias radican en:
* `document.querySelector` devuelve el primer elemento que cumpla con la condición
* `document.querySelectorAll` devuelve todos los elementos que cumplen con la condición en forma de NodeList. Puede ser convertido a Array usando `[].slice.call(document.querySelectorAll(selector) || []);`
* Si ningún elemento cumple con la condición, jQuery retornaría `[]` mientras la API DOM retornaría `null`. Nótese el NullPointerException. Se puede usar `||` para establecer el valor por defecto al no encontrar elementos, como en `document.querySelectorAll(selector) || []`

> Notice: `document.querySelector` and `document.querySelectorAll` are quite **SLOW**, try to use `getElementById`, `document.getElementsByClassName` o `document.getElementsByTagName` if you want to Obtener a performance bonus.

- [1.0](#1.0) <a name='1.0'></a> Buscar por selector

  ```js
  // jQuery
  $('selector');

  // Nativo
  document.querySelectorAll('selector');
  ```

- [1.1](#1.1) <a name='1.1'></a> Buscar por Clase

  ```js
  // jQuery
  $('.class');

  // Nativo
  document.querySelectorAll('.class');

  // Forma alternativa
  document.getElementsByClassName('class');
  ```

- [1.2](#1.2) <a name='1.2'></a> Buscar por id

  ```js
  // jQuery
  $('#id');

  // Nativo
  document.querySelector('#id');

  // Forma alternativa
  document.getElementById('id');
  ```

- [1.3](#1.3) <a name='1.3'></a> Buscar por atributo

  ```js
  // jQuery
  $('a[target=_blank]');

  // Nativo
  document.querySelectorAll('a[target=_blank]');
  ```

- [1.4](#1.4) <a name='1.4'></a> Buscar

  + Buscar nodos

    ```js
    // jQuery
    $el.find('li');

    // Nativo
    el.querySelectorAll('li');
    ```

  + Buscar "body"

    ```js
    // jQuery
    $('body');

    // Nativo
    document.body;
    ```

  + Buscar Atributo

    ```js
    // jQuery
    $el.attr('foo');

    // Nativo
    e.getAttribute('foo');
    ```

  + Buscar atributo "data"

    ```js
    // jQuery
    $el.data('foo');

    // Nativo
    // Usando getAttribute
    el.getAttribute('data-foo');
    // También puedes utilizar `dataset` desde IE 11+
    el.dataset['foo'];
    ```

- [1.5](#1.5) <a name='1.5'></a> Elementos Hermanos/Previos/Siguientes

  + Elementos hermanos

    ```js
    // jQuery
    $el.siblings();

    // Nativo
    [].filter.call(el.parentNode.children, function(child) {
      return child !== el;
    });
    ```

  + Elementos previos

    ```js
    // jQuery
    $el.prev();

    // Nativo
    el.previousElementSibling;
    ```

  + Elementos siguientes

    ```js
    // jQuery
    $el.next();

    // Nativo
    el.nextElementSibling;
    ```

- [1.6](#1.6) <a name='1.6'></a> Closest

  Retorna el elemento más cercano que coincida con la condición, partiendo desde el nodo actual hasta document.

  ```js
  // jQuery
  $el.closest(queryString);

  // Nativo
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

  Obtiene los ancestros de cada elemento en el set actual de elementos que cumplan con la condición, sin incluir el actual

  ```js
  // jQuery
  $el.parentsUntil(selector, filter);

  // Nativo
  function parentsUntil(el, selector, filter) {
    const result = [];
    const matchesSelector = el.matches || el.webkitMatchesSelector || el.mozMatchesSelector || el.msMatchesSelector;

    // Partir desde el elemento padre
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

- [1.8](#1.8) <a name='1.8'></a> Formularios

  + Input/Textarea

    ```js
    // jQuery
    $('#my-input').val();

    // Nativo
    document.querySelector('#my-input').value;
    ```

  + Obtener el índice de e.currentTarget en `.radio`

    ```js
    // jQuery
    $(e.currentTarget).index('.radio');

    // Nativo
    [].indexOf.call(document.querySelectAll('.radio'), e.currentTarget);
    ```

- [1.9](#1.9) <a name='1.9'></a> Contenidos de Iframe

  `$('iframe').contents()` devuelve `contentDocument` para este iframe específico

  + Contenidos de Iframe

    ```js
    // jQuery
    $iframe.contents();

    // Nativo
    iframe.contentDocument;
    ```

  + Buscar dentro de un Iframe

    ```js
    // jQuery
    $iframe.contents().find('.css');

    // Nativo
    iframe.contentDocument.querySelectorAll('.css');
    ```

**[⬆ volver al inicio](#tabla-de-contenidos)**

## CSS & Estilo

- [2.1](#2.1) <a name='2.1'></a> CSS

  + Obtener Estilo

    ```js
    // jQuery
    $el.css("color");

    // Nativo
    // NOTA: Bug conocido, retornará 'auto' si el valor de estilo es 'auto'
    const win = el.ownerDocument.defaultView;
    // null significa que no tiene pseudo estilos
    win.getComputedStyle(el, null).color;
    ```

  + Establecer style

    ```js
    // jQuery
    $el.css({ color: "#ff0011" });

    // Nativo
    el.style.color = '#ff0011';
    ```

  + Obtener/Establecer Estilos

    Nótese que si se desea establecer múltiples estilos a la vez, se puede utilizar el método [setStyles](https://github.com/oneuijs/oui-dom-utils/blob/master/src/index.js#L194) en el paquete oui-dom-utils.

  + Agregar clase

    ```js
    // jQuery
    $el.addClass(className);

    // Nativo
    el.classList.add(className);
    ```

  + Quitar Clase

    ```js
    // jQuery
    $el.removeClass(className);

    // Nativo
    el.classList.remove(className);
    ```

  + Consultar si tiene clase

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

  Ancho y Alto son teóricamente idénticos. Usaremos el Alto como ejemplo:

  + Alto de Ventana

    ```js
    // alto de ventana
    $(window).height();
    // Sin scrollbar, se comporta como jQuery
    window.document.documentElement.clientHeight;
    // Con scrollbar
    window.innerHeight;
    ```

  + Alto de Documento

    ```js
    // jQuery
    $(document).height();

    // Nativo
    document.documentElement.scrollHeight;
    ```

  + Alto de Elemento

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
    // Precisión de integer（when `border-box`, it's `height`; when `content-box`, it's `height + padding + border`）
    el.clientHeight;
    // Precisión de decimal（when `border-box`, it's `height`; when `content-box`, it's `height + padding + border`）
    el.getBoundingClientRect().height;
    ```

- [2.3](#2.3) <a name='2.3'></a> Posición & Offset

  + Posición

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

- [2.4](#2.4) <a name='2.4'></a> Posición del Scroll Vertical

  ```js
  // jQuery
  $(window).scrollTop();

  // Nativo
  (document.documentElement && document.documentElement.scrollTop) || document.body.scrollTop;
  ```

**[⬆ volver al inicio](#tabla-de-contenidos)**

## Manipulación DOM

- [3.1](#3.1) <a name='3.1'></a> Remove
  ```js
  // jQuery
  $el.remove();

  // Nativo
  el.parentNode.removeChild(el);
  ```

- [3.2](#3.2) <a name='3.2'></a> Text

  + Obtener Texto

    ```js
    // jQuery
    $el.text();

    // Nativo
    el.textContent;
    ```

  + Establecer Texto

    ```js
    // jQuery
    $el.text(string);

    // Nativo
    el.textContent = string;
    ```

- [3.3](#3.3) <a name='3.3'></a> HTML

  + Obtener HTML

    ```js
    // jQuery
    $el.html();

    // Nativo
    el.innerHTML;
    ```

  + Establecer HTML

    ```js
    // jQuery
    $el.html(htmlString);

    // Nativo
    el.innerHTML = htmlString;
    ```

- [3.4](#3.4) <a name='3.4'></a> Append

  Añadir elemento hijo después del último hijo del elemento padre

  ```js
  // jQuery
  $el.append("<div id='container'>hello</div>");

  // Nativo
  el.insertAdjacentHTML("beforeend","<div id='container'>hello</div>");
  ```

- [3.5](#3.5) <a name='3.5'></a> Prepend

  Añadir elemento hijo después del último hijo del elemento padre

  ```js
  // jQuery
  $el.prepend("<div id='container'>hello</div>");

  // Nativo
  el.insertAdjacentHTML("afterbegin","<div id='container'>hello</div>");
  ```

- [3.6](#3.6) <a name='3.6'></a> insertBefore

  Insertar un nuevo nodo antes del primero de los elementos seleccionados

  ```js
  // jQuery
  $newEl.insertBefore(queryString);

  // Nativo
  const target = document.querySelector(queryString);
  target.parentNode.insertBefore(newEl, target);
  ```

- [3.7](#3.7) <a name='3.7'></a> insertAfter

  Insertar un nuevo nodo después de los elementos seleccionados

  ```js
  // jQuery
  $newEl.insertAfter(queryString);

  // Nativo
  const target = document.querySelector(queryString);
  target.parentNode.insertBefore(newEl, target.nextSibling);
  ```

**[⬆ volver al inicio](#tabla-de-contenidos)**

## Ajax

Reemplazar con [fetch](https://github.com/camsong/fetch-ie8) y [fetch-jsonp](https://github.com/camsong/fetch-jsonp)
+[Fetch API](https://fetch.spec.whatwg.org/) es el nuevo estándar quue reemplaza a XMLHttpRequest para efectuar peticiones AJAX. Funciona en Chrome y Firefox, como también es posible usar un polyfill en otros navegadores.
+
+Es una buena alternativa utilizar [github/fetch](http://github.com/github/fetch) en IE9+ o [fetch-ie8](https://github.com/camsong/fetch-ie8/) en IE8+, [fetch-jsonp](https://github.com/camsong/fetch-jsonp) para efectuar peticiones JSONP.
**[⬆ volver al inicio](#tabla-de-contenidos)**

## Eventos

Para un reemplazo completo con namespace y delegación, utilizar https://github.com/oneuijs/oui-dom-events

- [5.1](#5.1) <a name='5.1'></a> Asignar un evento con "on"

  ```js
  // jQuery
  $el.on(eventName, eventHandler);

  // Nativo
  el.addEventListener(eventName, eventHandler);
  ```

- [5.2](#5.2) <a name='5.2'></a> Desasignar un evento con "off"

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

**[⬆ volver al inicio](#tabla-de-contenidos)**

## Utilidades

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

  Utilizar polyfill para object.assign https://github.com/ljharb/object.assign

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

**[⬆ volver al inicio](#tabla-de-contenidos)**

## Traducción

* [한국어](./README.ko-KR.md)
* [简体中文](./README.zh-CN.md)
* [Bahasa Melayu](./README-my.md)
* [Bahasa Indonesia](./README-id.md)
* [Português(PT-BR)](./README.pt-BR.md)
* [Tiếng Việt Nam](./README-vi.md)
* [Español](./README-es.md)
* [Русский](./README-ru.md)
* [Türkçe](./README-tr.md)

## Soporte de Navegadores

![Chrome](https://raw.github.com/alrra/browser-logos/master/chrome/chrome_48x48.png) | ![Firefox](https://raw.github.com/alrra/browser-logos/master/firefox/firefox_48x48.png) | ![IE](https://raw.github.com/alrra/browser-logos/master/internet-explorer/internet-explorer_48x48.png) | ![Opera](https://raw.github.com/alrra/browser-logos/master/opera/opera_48x48.png) | ![Safari](https://raw.github.com/alrra/browser-logos/master/safari/safari_48x48.png)
--- | --- | --- | --- | --- |
Última ✔ | Última ✔ | 10+ ✔ | Última ✔ | 6.1+ ✔ |

# Licencia

MIT
