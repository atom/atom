> #### You Don't Need jQuery

Você não precisa de jQuery
---

Ambientes Frontend evoluem rapidamente nos dias de hoje, navegadores modernos já implementaram uma grande parte das APIs DOM/BOM que são boas o suficiente. Nós não temos que aprender jQuery a partir do zero para manipulação do DOM ou eventos. Nesse meio tempo, graças a bibliotecas frontend como React, Angular e Vue, a manipulação direta do DOM torna-se um anti-padrão, jQuery é menos importante do que nunca. Este projeto resume a maioria das alternativas dos métodos jQuery em implementação nativa, com suporte ao IE 10+.

## Tabela de conteúdos

1. [Query Selector](#query-selector)
1. [CSS & Estilo](#css--estilo)
1. [Manipulação do DOM](#manipulação-do-dom)
1. [Ajax](#ajax)
1. [Eventos](#eventos)
1. [Utilitários](#utilitários)
1. [Suporte dos Navegadores](#suporte-dos-navegadores)

## Query Selector

No lugar de seletores comuns como classe, id ou atributo podemos usar `document.querySelector` ou `document.querySelectorAll` para substituição. As diferenças são:
* `document.querySelector` retorna o primeiro elemento correspondente
* `document.querySelectorAll` retorna todos os elementos correspondentes como NodeList. Pode ser convertido para Array usando `[].slice.call(document.querySelectorAll(selector) || []);`
* Se não tiver elementos correspondentes, jQuery retornaria `[]` considerando que a DOM API irá retornar `null`. Preste atenção ao Null Pointer Exception. Você também pode usar `||` para definir um valor padrão caso nenhum elemento seja encontrado, como `document.querySelectorAll(selector) || []`

> Aviso: `document.querySelector` e `document.querySelectorAll` são bastante **LENTOS**, tente usar `getElementById`, `document.getElementsByClassName` ou `document.getElementsByTagName` se você quer ter uma maior performance.

- [1.0](#1.0) <a name='1.0'></a> Query por seletor

  ```js
  // jQuery
  $('selector');

  // Nativo
  document.querySelectorAll('selector');
  ```

- [1.1](#1.1) <a name='1.1'></a> Query por classe

  ```js
  // jQuery
  $('.class');

  // Nativo
  document.querySelectorAll('.class');

  // ou
  document.getElementsByClassName('class');
  ```

- [1.2](#1.2) <a name='1.2'></a> Query por id

  ```js
  // jQuery
  $('#id');

  // Nativo
  document.querySelector('#id');

  // ou
  document.getElementById('id');
  ```

- [1.3](#1.3) <a name='1.3'></a> Query por atributo

  ```js
  // jQuery
  $('a[target=_blank]');

  // Nativo
  document.querySelectorAll('a[target=_blank]');
  ```

- [1.4](#1.4) <a name='1.4'></a> Find sth.

  + Busca por nós

    ```js
    // jQuery
    $el.find('li');

    // Nativo
    el.querySelectorAll('li');
    ```

  + Buscar `body`

    ```js
    // jQuery
    $('body');

    // Nativo
    document.body;
    ```

  + Buscar atributos

    ```js
    // jQuery
    $el.attr('foo');

    // Nativo
    e.getAttribute('foo');
    ```

  + Buscar atributos `data-`

    ```js
    // jQuery
    $el.data('foo');

    // Nativo
    // usando getAttribute
    el.getAttribute('data-foo');
    // você também pode usar `dataset` se você precisar suportar apenas IE 11+
    el.dataset['foo'];
    ```

- [1.5](#1.5) <a name='1.5'></a> Sibling/Previous/Next Elements

  + Sibling elements

    ```js
    // jQuery
    $el.siblings();

    // Nativo
    [].filter.call(el.parentNode.children, function(child) {
      return child !== el;
    });
    ```

  + Previous elements

    ```js
    // jQuery
    $el.prev();

    // Nativo
    el.previousElementSibling;

    ```

  + Next elements

    ```js
    // jQuery
    $el.next();

    // Nativo
    el.nextElementSibling;
    ```

- [1.6](#1.6) <a name='1.6'></a> Closest

  Retorna o primeiro elemento que corresponda ao seletor, partindo do elemento atual para o document.

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

  Obtém os ancestrais de cada elemento no atual conjunto de elementos combinados, mas não inclui o elemento correspondente pelo seletor, nó do DOM, ou objeto jQuery.

  ```js
  // jQuery
  $el.parentsUntil(selector, filter);

  // Nativo
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

    // Nativo
    document.querySelector('#my-input').value;
    ```

  + Obter o índice do e.currentTarget entre `.radio`

    ```js
    // jQuery
    $(e.currentTarget).index('.radio');

    // Nativo
    [].indexOf.call(document.querySelectAll('.radio'), e.currentTarget);
    ```

- [1.9](#1.9) <a name='1.9'></a> Iframe Contents

  `$('iframe').contents()` retorna `contentDocument` para este iframe específico

  + Iframe contents

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

**[⬆ ir para o topo](#tabela-de-conteúdos)**


## CSS & Estilo

- [2.1](#2.1) <a name='2.1'></a> CSS

  + Obter estilo

    ```js
    // jQuery
    $el.css("color");

    // Nativo
    // AVISO: Bug conhecido, irá retornar 'auto' se o valor do estilo for 'auto'
    const win = el.ownerDocument.defaultView;
    // null significa não retornar estilos
    win.getComputedStyle(el, null).color;
    ```

  + Definir Estilo

    ```js
    // jQuery
    $el.css({ color: "#ff0011" });

    // Nativo
    el.style.color = '#ff0011';
    ```

  + Get/Set Styles

    Observe que se você deseja setar vários estilos de uma vez, você pode optar por [setStyles](https://github.com/oneuijs/oui-dom-utils/blob/master/src/index.js#L194) método no pacote oui-dom-utils.


  + Adicionar classe

    ```js
    // jQuery
    $el.addClass(className);

    // Nativo
    el.classList.add(className);
    ```

  + Remover classe

    ```js
    // jQuery
    $el.removeClass(className);

    // Nativo
    el.classList.remove(className);
    ```

  + Verificar classe

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

- [2.2](#2.2) <a name='2.2'></a> Largura e Altura

  `width` e `height` são teoricamente idênticos, vamos pegar `height` como exemplo:

  + Altura da janela

    ```jsc
    // window height
    $(window).height();
    // sem scrollbar, se comporta como jQuery
    window.document.documentElement.clientHeight;
    // com scrollbar
    window.innerHeight;
    ```

  + Altura do Documento

    ```js
    // jQuery
    $(document).height();

    // Nativo
    document.documentElement.scrollHeight;
    ```

  + Altura do Elemento

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
    // preciso para inteiro（quando `border-box`, é `height`; quando `content-box`, é `height + padding + border`）
    el.clientHeight;
    // preciso para decimal（quando `border-box`, é `height`; quando `content-box`, é `height + padding + border`）
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

- [2.4](#2.4) <a name='2.4'></a> Rolar para o topo

  ```js
  // jQuery
  $(window).scrollTop();

  // Nativo
  (document.documentElement && document.documentElement.scrollTop) || document.body.scrollTop;
  ```

**[⬆ ir para o topo](#tabela-de-conteúdos)**

## Manipulação do Dom

- [3.1](#3.1) <a name='3.1'></a> Remover
  ```js
  // jQuery
  $el.remove();

  // Nativo
  el.parentNode.removeChild(el);
  ```

- [3.2](#3.2) <a name='3.2'></a> Texto

  + Obter texto

    ```js
    // jQuery
    $el.text();

    // Nativo
    el.textContent;
    ```

  + Definir texto

    ```js
    // jQuery
    $el.text(string);

    // Nativo
    el.textContent = string;
    ```

- [3.3](#3.3) <a name='3.3'></a> HTML

  + Obter HTML

    ```js
    // jQuery
    $el.html();

    // Nativo
    el.innerHTML;
    ```

  + Definir HTML

    ```js
    // jQuery
    $el.html(htmlString);

    // Nativo
    el.innerHTML = htmlString;
    ```

- [3.4](#3.4) <a name='3.4'></a> Append

  Incluir elemento filho após o último filho do elemento pai.

  ```js
  // jQuery
  $el.append("<div id='container'>hello</div>");

  // Nativo
  let newEl = document.createElement('div');
  newEl.setAttribute('id', 'container');
  newEl.innerHTML = 'hello';
  el.appendChild(newEl);
  ```

- [3.5](#3.5) <a name='3.5'></a> Prepend

  ```js
  // jQuery
  $el.prepend("<div id='container'>hello</div>");

  // Nativo
  let newEl = document.createElement('div');
  newEl.setAttribute('id', 'container');
  newEl.innerHTML = 'hello';
  el.insertBefore(newEl, el.firstChild);
  ```

- [3.6](#3.6) <a name='3.6'></a> insertBefore

  Insere um novo nó antes dos elementos selecionados.

  ```js
  // jQuery
  $newEl.insertBefore(queryString);

  // Nativo
  const target = document.querySelector(queryString);
  target.parentNode.insertBefore(newEl, target);
  ```

- [3.7](#3.7) <a name='3.7'></a> insertAfter

  Insere um novo nó após os elementos selecionados.

  ```js
  // jQuery
  $newEl.insertAfter(queryString);

  // Nativo
  const target = document.querySelector(queryString);
  target.parentNode.insertBefore(newEl, target.nextSibling);
  ```

**[⬆ ir para o topo](#tabela-de-conteúdos)**

## Ajax

Substitua por [fetch](https://github.com/camsong/fetch-ie8) e [fetch-jsonp](https://github.com/camsong/fetch-jsonp)

**[⬆ ir para o topo](#tabela-de-conteúdos)**

## Eventos

Para uma substituição completa com namespace e delegation, consulte https://github.com/oneuijs/oui-dom-events

- [5.1](#5.1) <a name='5.1'></a> `Bind` num evento com `on`

  ```js
  // jQuery
  $el.on(eventName, eventHandler);

  // Nativo
  el.addEventListener(eventName, eventHandler);
  ```

- [5.2](#5.2) <a name='5.2'></a> `Unbind` num evento com `off`

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

**[⬆ ir para o topo](#tabela-de-conteúdos)**

## Utilitários

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

  Use o polyfill `object.assign` para eetender um Object: https://github.com/ljharb/object.assign

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

**[⬆ ir para o topo](#tabela-de-conteúdos)**

## Suporte dos Navegadores

![Chrome](https://raw.github.com/alrra/browser-logos/master/chrome/chrome_48x48.png) | ![Firefox](https://raw.github.com/alrra/browser-logos/master/firefox/firefox_48x48.png) | ![IE](https://raw.github.com/alrra/browser-logos/master/internet-explorer/internet-explorer_48x48.png) | ![Opera](https://raw.github.com/alrra/browser-logos/master/opera/opera_48x48.png) | ![Safari](https://raw.github.com/alrra/browser-logos/master/safari/safari_48x48.png)
--- | --- | --- | --- | --- |
Latest ✔ | Latest ✔ | 10+ ✔ | Latest ✔ | 6.1+ ✔ |

# Licença

MIT
