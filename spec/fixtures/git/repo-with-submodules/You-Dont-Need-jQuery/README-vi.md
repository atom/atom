## Bạn không cần jQuery nữa đâu

Ngày nay, môi trường lập trình front-end phát triển rất nhanh chóng, các trình duyệt hiện đại đã cung cấp các API đủ tốt để làm việc với DOM/BOM. Bạn không còn cần phải học về jQuery nữa. Đồng thời, nhờ sự ra đời của các thư viện như React, Angular và Vue đã khiến cho việc can thiệp trực tiếp vào DOM trở thành một việc không tốt. jQuery đã không còn quan trọng như trước nữa. Bài viết này tổng hợp những cách để thay thế các hàm của jQuery bằng các hàm được hỗ trợ bởi trình duyệt, và hó cũng hoạt động trên IE 10+

## Danh mục

1. [Query Selector](#query-selector)
1. [CSS & Style](#css--style)
1. [Thao tác với DOM](#thao-tác-với-dom)
1. [Ajax](#ajax)
1. [Events](#events)
1. [Hàm tiện ích](#hàm-tiện-ích)
1. [Ngôn ngữ khác](#ngôn-ngữ-khác)
1. [Các trình duyệt hỗ trợ](#các-trình-duyệt-hỗ-trợ)

## Query Selector

Đối với những selector phổ biến như class, id hoặc thuộc tính thì chúng ta có thể sử dụng `document.querySelector` hoặc `document.querySelectorAll` để thay thế cho jQuery selector. Sự khác biệt của hai hàm này là ở chỗ:

* `document.querySelector` trả về element đầu tiên được tìm thấy
* `document.querySelectorAll` trả về tất cả các element được tìm thấy dưới dạng một instance của NodeList. Nó có thể được convert qua array bằng cách `[].slice.call(document.querySelectorAll(selector) || []);`
* Nếu không có element nào được tìm thấy, thì jQuery sẽ trả về một array rỗng `[]` trong khi đó DOM API sẽ trả về `null`. Hãy chú ý đến Null Pointer Exception. Bạn có thể sử dụng toán tử `||` để đặt giá trị default nếu như không có element nào được tìm thấy, ví dụ như `document.querySelectorAll(selector) || []`

> Chú ý : `document.querySelector` và `document.querySelectorAll` hoạt động khá **CHẬM**, hãy thử dùng `getElementById`, `document.getElementsByClassName` hoặc `document.getElementsByTagName` nếu bạn muốn đạt hiệu suất tốt hơn.

- [1.0](#1.0) <a name='1.0'></a> Query bằng selector

  ```js
  // jQuery
  $('selector');

  // Native
  document.querySelectorAll('selector');
  ```

- [1.1](#1.1) <a name='1.1'></a> Query bằng class

  ```js
  // jQuery
  $('.class');

  // Native
  document.querySelectorAll('.class');

  // hoặc
  document.getElementsByClassName('class');
  ```

- [1.2](#1.2) <a name='1.2'></a> Query bằng id

  ```js
  // jQuery
  $('#id');

  // Native
  document.querySelector('#id');

  // hoặc
  document.getElementById('id');
  ```

- [1.3](#1.3) <a name='1.3'></a> Query bằng thuộc tính

  ```js
  // jQuery
  $('a[target=_blank]');

  // Native
  document.querySelectorAll('a[target=_blank]');
  ```

- [1.4](#1.4) <a name='1.4'></a> Tìm bất cứ gì.

  + Tìm node

    ```js
    // jQuery
    $el.find('li');

    // Native
    el.querySelectorAll('li');
    ```

  + Tìm body

    ```js
    // jQuery
    $('body');

    // Native
    document.body;
    ```

  + lấy thuộc tính

    ```js
    // jQuery
    $el.attr('foo');

    // Native
    e.getAttribute('foo');
    ```

  + Lấy giá trị của thuộc tính `data`

    ```js
    // jQuery
    $el.data('foo');

    // Native
    // using getAttribute
    el.getAttribute('data-foo');
    // you can also use `dataset` if only need to support IE 11+
    el.dataset['foo'];
    ```

- [1.5](#1.5) <a name='1.5'></a> Tìm element cùng level/trước/sau

  + Element cùng level

    ```js
    // jQuery
    $el.siblings();

    // Native
    [].filter.call(el.parentNode.children, function(child) {
      return child !== el;
    });
    ```

  + Element ở phía trước

    ```js
    // jQuery
    $el.prev();

    // Native
    el.previousElementSibling;

    ```

  + Element ở phía sau

    ```js
    // next
    $el.next();
    el.nextElementSibling;
    ```

- [1.6](#1.6) <a name='1.6'></a> Element gần nhất

  Trả về element đầu tiên có selector khớp với yêu cầu khi duyệt từ element hiện tại trở lên tới document.

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

- [1.7](#1.7) <a name='1.7'></a> Tìm parent

  Truy ngược một cách đệ quy tổ tiên của element hiện tại, cho đến khi tìm được một element tổ tiên ( element cần tìm ) mà element đó là con trực tiếp của element khớp với selector được cung cấp, Return lại element cần tìm đó.

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

  + Lấy index của e.currentTarget trong danh sách các element khớp với selector `.radio`

    ```js
    // jQuery
    $(e.currentTarget).index('.radio');

    // Native
    [].indexOf.call(document.querySelectAll('.radio'), e.currentTarget);
    ```

- [1.9](#1.9) <a name='1.9'></a> Nội dung Iframe

  `$('iframe').contents()` trả về thuộc tính `contentDocument` của iframe được tìm thấy

  + Nọi dung iframe

    ```js
    // jQuery
    $iframe.contents();

    // Native
    iframe.contentDocument;
    ```

  + Query Iframe

    ```js
    // jQuery
    $iframe.contents().find('.css');

    // Native
    iframe.contentDocument.querySelectorAll('.css');
    ```

**[⬆ Trở về đầu](#danh-mục)**

## CSS & Style

- [2.1](#2.1) <a name='2.1'></a> CSS

  + Lấy style

    ```js
    // jQuery
    $el.css("color");

    // Native
    // NOTE: Bug đã được biết, sẽ trả về 'auto' nếu giá trị của style là 'auto'
    const win = el.ownerDocument.defaultView;
    // null means not return presudo styles
    win.getComputedStyle(el, null).color;
    ```

  + Đặt style

    ```js
    // jQuery
    $el.css({ color: "#ff0011" });

    // Native
    el.style.color = '#ff0011';
    ```

  + Lấy/Đặt Nhiều style

    Nếu bạn muốn đặt nhiều style một lần, bạn có thể sẽ thích phương thức [setStyles](https://github.com/oneuijs/oui-dom-utils/blob/master/src/index.js#L194) trong thư viện oui-dom-utils.


  + Thêm class và element

    ```js
    // jQuery
    $el.addClass(className);

    // Native
    el.classList.add(className);
    ```

  + Loại bỏ class class ra khỏi element

    ```js
    // jQuery
    $el.removeClass(className);

    // Native
    el.classList.remove(className);
    ```

  + Kiểm tra xem element có class nào đó hay không

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

- [2.2](#2.2) <a name='2.2'></a> Chiều rộng, chiều cao

  Về mặt lý thuyết thì chiều rộng và chiều cao giống như nhau trong cả jQuery và DOM API:

  + Chiều rộng của window

    ```js
    // window height
    $(window).height();
    // trừ đi scrollbar
    window.document.documentElement.clientHeight;
    // Tính luôn scrollbar
    window.innerHeight;
    ```

  + Chiều cao của Document

    ```js
    // jQuery
    $(document).height();

    // Native
    document.documentElement.scrollHeight;
    ```

  + Chiều cao của element

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
    // chính xác tới số nguyên（khi có thuộc tính `box-sizing` là `border-box`, nó là `height`; khi box-sizing là `content-box`, nó là `height + padding + border`）
    el.clientHeight;
    // Chính xác tới số thập phân（khi `box-sizing` là `border-box`, nó là `height`; khi `box-sizing` là `content-box`, nó là `height + padding + border`）
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

**[⬆ Trở về đầu](#danh-mục)**

## Thao tác với DOM

- [3.1](#3.1) <a name='3.1'></a> Loại bỏ
  ```js
  // jQuery
  $el.remove();

  // Native
  el.parentNode.removeChild(el);
  ```

- [3.2](#3.2) <a name='3.2'></a> Text

  + Lấy text

    ```js
    // jQuery
    $el.text();

    // Native
    el.textContent;
    ```

  + Đặt giá trị text

    ```js
    // jQuery
    $el.text(string);

    // Native
    el.textContent = string;
    ```

- [3.3](#3.3) <a name='3.3'></a> HTML

  + Lấy HTML

    ```js
    // jQuery
    $el.html();

    // Native
    el.innerHTML;
    ```

  + Đặt giá trị HTML

    ```js
    // jQuery
    $el.html(htmlString);

    // Native
    el.innerHTML = htmlString;
    ```

- [3.4](#3.4) <a name='3.4'></a> Append

  append một element sau element con cuối cùng của element cha

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

  Chèn một node vào trước element được query.

  ```js
  // jQuery
  $newEl.insertBefore(queryString);

  // Native
  const target = document.querySelector(queryString);
  target.parentNode.insertBefore(newEl, target);
  ```

- [3.7](#3.7) <a name='3.7'></a> insertAfter

  Chèn node vào sau element được query

  ```js
  // jQuery
  $newEl.insertAfter(queryString);

  // Native
  const target = document.querySelector(queryString);
  target.parentNode.insertBefore(newEl, target.nextSibling);
  ```

**[⬆ Trở về đầu](#danh-mục)**

## Ajax

Thay thế bằng [fetch](https://github.com/camsong/fetch-ie8) và [fetch-jsonp](https://github.com/camsong/fetch-jsonp)

**[⬆ Trở về đầu](#danh-mục)**

## Events

Để có một sự thay thế đầy đủ nhất, bạn nên sử dụng https://github.com/oneuijs/oui-dom-events

- [5.1](#5.1) <a name='5.1'></a> Bind event bằng on

  ```js
  // jQuery
  $el.on(eventName, eventHandler);

  // Native
  el.addEventListener(eventName, eventHandler);
  ```

- [5.2](#5.2) <a name='5.2'></a> Unbind event bằng off

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

**[⬆ Trở về đầu](#danh-mục)**

## Hàm tiện ích

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
  string.trim();
  ```

- [6.3](#6.3) <a name='6.3'></a> Object Assign

  Mở rộng, sử dụng object.assign https://github.com/ljharb/object.assign

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

**[⬆ Trở về đầu](#danh-mục)**

## Ngôn ngữ khác

* [한국어](./README.ko-KR.md)
* [简体中文](./README.zh-CN.md)
* [Bahasa Melayu](./README-my.md)
* [Português(PT-BR)](./README.pt-BR.md)
* [Tiếng Việt Nam](./README-vi.md)
* [Русский](./README-ru.md)
* [Türkçe](./README-tr.md)

## Các trình duyệt hỗ trợ

![Chrome](https://raw.github.com/alrra/browser-logos/master/chrome/chrome_48x48.png) | ![Firefox](https://raw.github.com/alrra/browser-logos/master/firefox/firefox_48x48.png) | ![IE](https://raw.github.com/alrra/browser-logos/master/internet-explorer/internet-explorer_48x48.png) | ![Opera](https://raw.github.com/alrra/browser-logos/master/opera/opera_48x48.png) | ![Safari](https://raw.github.com/alrra/browser-logos/master/safari/safari_48x48.png)
--- | --- | --- | --- | --- |
Latest ✔ | Latest ✔ | 10+ ✔ | Latest ✔ | 6.1+ ✔ |

# Giấy phép

MIT
