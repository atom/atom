## jQuery'e İhtiyacınız Yok  [![Build Status](https://travis-ci.org/oneuijs/You-Dont-Need-jQuery.svg)](https://travis-ci.org/oneuijs/You-Dont-Need-jQuery)

Önyüz ortamları bugünlerde çok hızlı gelişiyor, öyle ki modern tarayıcılar DOM/DOM APİ'lere ait önemli gereklilikleri çoktan yerine getirdiler. DOM işleme ve olaylar için, en baştan jQuery ögrenmemize gerek kalmadı. Bu arada, üstünlükleri ile jQuery'i önemsizleştiren ve doğrudan DOM değişikliklerinin bir Anti-pattern olduğunu gösteren, React, Angular ve Vue gibi gelişmiş önyüz kütüphanelerine ayrıca teşekkür ederiz. Bu proje, IE10+ desteği ile coğunluğu jQuery yöntemlerine alternatif olan yerleşik uygulamaları içerir. 

## İçerik Tablosu

1. [Sorgu seçiciler](#sorgu-seçiciler)
1. [CSS & Stil](#css--stil)
1. [DOM düzenleme](#dom-düzenleme)
1. [Ajax](#ajax)
1. [Olaylar](#olaylar)
1. [Araçlar](#araçlar)
1. [Alternatifler](#alternatifler)
1. [Çeviriler](#Çeviriler)
1. [Tarayıcı desteği](#tarayıcı-desteği)

## Sorgu seçiciler

Yaygın olan class, id ve özellik seçiciler yerine, `document.querySelector` yada `document.querySelectorAll` kullanabiliriz. Ayrıldıkları nokta: 
* `document.querySelector` ilk seçilen öğeyi döndürür
* `document.querySelectorAll` Seçilen tüm öğeleri NodeList olarak geri döndürür. `[].slice.call(document.querySelectorAll(selector) || []);` kullanarak bir diziye dönüştürebilirsiniz. 
* Herhangi bir öğenin seçilememesi durumda ise, jQuery `[]` döndürürken, DOM API `null` döndürecektir. Null Pointer istisnası almamak için `||` ile varsayılan değere atama yapabilirsiniz, örnek: `document.querySelectorAll(selector) || []`

> Uyarı: `document.querySelector` ve `document.querySelectorAll` biraz **YAVAŞ** olabilir, Daha hızlısını isterseniz, `getElementById`, `document.getElementsByClassName` yada `document.getElementsByTagName` kullanabilirsiniz.

- [1.0](#1.0) <a name='1.0'></a> Seçici ile sorgu

  ```js
  // jQuery
  $('selector');

  // Yerleşik
  document.querySelectorAll('selector');
  ```

- [1.1](#1.1) <a name='1.1'></a> Sınıf ile sorgu

  ```js
  // jQuery
  $('.class');

  // Yerleşik
  document.querySelectorAll('.class');

  // yada
  document.getElementsByClassName('class');
  ```

- [1.2](#1.2) <a name='1.2'></a> Id ile sorgu

  ```js
  // jQuery
  $('#id');

  // Yerleşik
  document.querySelector('#id');

  // yada
  document.getElementById('id');
  ```

- [1.3](#1.3) <a name='1.3'></a> Özellik ile sorgu

  ```js
  // jQuery
  $('a[target=_blank]');

  // Yerleşik
  document.querySelectorAll('a[target=_blank]');
  ```

- [1.4](#1.4) <a name='1.4'></a> Öğe erişimi

  + Node'a erişim

    ```js
    // jQuery
    $el.find('li');

    // Yerleşik
    el.querySelectorAll('li');
    ```

  + Body'e erişim

    ```js
    // jQuery
    $('body');

    // Yerleşik
    document.body;
    ```

  + Özelliğe erişim

    ```js
    // jQuery
    $el.attr('foo');

    // Yerleşik
    el.getAttribute('foo');
    ```

  + Data özelliğine erişim

    ```js
    // jQuery
    $el.data('foo');

    // Yerleşik
    // getAttribute kullanarak
    el.getAttribute('data-foo');
    // Eğer  IE 11+ kullanıyor iseniz, `dataset` ile de erişebilirsiniz
    el.dataset['foo'];
    ```

- [1.5](#1.5) <a name='1.5'></a> Kardeş/Önceki/Sonraki öğeler

  + Kardeş öğeler

    ```js
    // jQuery
    $el.siblings();

    // Yerleşik
    [].filter.call(el.parentNode.children, function(child) {
      return child !== el;
    });
    ```

  + Önceki öğeler

    ```js
    // jQuery
    $el.prev();

    // Yerleşik
    el.previousElementSibling;
    ```

  + Sonraki öğeler

    ```js
    // jQuery
    $el.next();

    // Yerleşik
    el.nextElementSibling;
    ```

- [1.6](#1.6) <a name='1.6'></a> En yakın

  Verilen seçici ile eşleşen ilk öğeyi döndürür, geçerli öğeden başlayarak document'a kadar geçiş yapar.

  ```js
  // jQuery
  $el.closest(selector);
  
  // Yerleşik - Sadece en güncellerde, IE desteklemiyor
  el.closest(selector);

  // Yerleşik - IE10+ 
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

- [1.7](#1.7) <a name='1.7'></a> Önceki atalar

  Verilen seçici ile eşleşen öğe veya DOM node veya jQuery nesnesi hariç, mevcut öğe ile aradaki tüm önceki ataları bir set dahilinde verir.

  ```js
  // jQuery
  $el.parentsUntil(selector, filter);

  // Yerleşik
  function parentsUntil(el, selector, filter) {
    const result = [];
    const matchesSelector = el.matches || el.webkitMatchesSelector || el.mozMatchesSelector || el.msMatchesSelector;

    // eşleştirme, atadan başlar
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

    // Yerleşik
    document.querySelector('#my-input').value;
    ```

  + e.currentTarget ile `.radio` arasındaki dizini verir

    ```js
    // jQuery
    $(e.currentTarget).index('.radio');

    // Yerleşik
    [].indexOf.call(document.querySelectAll('.radio'), e.currentTarget);
    ```

- [1.9](#1.9) <a name='1.9'></a> Iframe İçeriği

  Mevcut Iframe için `$('iframe').contents()` yerine `contentDocument` döndürür.

  + Iframe İçeriği

    ```js
    // jQuery
    $iframe.contents();

    // Yerleşik
    iframe.contentDocument;
    ```

  + Iframe seçici

    ```js
    // jQuery
    $iframe.contents().find('.css');

    // Yerleşik
    iframe.contentDocument.querySelectorAll('.css');
    ```

**[⬆ üste dön](#İçerik-tablosu)**

## CSS & Stil

- [2.1](#2.1) <a name='2.1'></a> CSS

  + Stili verir

    ```js
    // jQuery
    $el.css("color");

    // Yerleşik
    // NOT: Bilinen bir hata, eğer stil değeri 'auto' ise 'auto' döndürür
    const win = el.ownerDocument.defaultView;
    // null sahte tipleri döndürmemesi için
    win.getComputedStyle(el, null).color;
    ```

  + Stil değiştir

    ```js
    // jQuery
    $el.css({ color: "#ff0011" });

    // Yerleşik
    el.style.color = '#ff0011';
    ```

  + Stil değeri al/değiştir

    Eğer aynı anda birden fazla stili değiştirmek istiyor iseniz, oui-dom-utils paketi içindeki [setStyles](https://github.com/oneuijs/oui-dom-utils/blob/master/src/index.js#L194) metoduna göz atınız.


  + Sınıf ekle

    ```js
    // jQuery
    $el.addClass(className);

    // Yerleşik
    el.classList.add(className);
    ```

  + Sınıf çıkart

    ```js
    // jQuery
    $el.removeClass(className);

    // Yerleşik
    el.classList.remove(className);
    ```

  + sınfı var mı?

    ```js
    // jQuery
    $el.hasClass(className);

    // Yerleşik
    el.classList.contains(className);
    ```

  + Sınfı takas et

    ```js
    // jQuery
    $el.toggleClass(className);

    // Yerleşik
    el.classList.toggle(className);
    ```

- [2.2](#2.2) <a name='2.2'></a> Genişlik ve Yükseklik

  Genişlik ve Yükseklik teorik olarak aynı şekilde, örnek olarak Yükseklik veriliyor
  
  + Window Yüksekliği

    ```js
    // window yüksekliği
    $(window).height();
    // kaydırma çubuğu olmaksızın, jQuery ile aynı
    window.document.documentElement.clientHeight;
    // kaydırma çubuğu ile birlikte
    window.innerHeight;
    ```

  + Document yüksekliği

    ```js
    // jQuery
    $(document).height();

    // Yerleşik
    document.documentElement.scrollHeight;
    ```

  + Öğe yüksekliği

    ```js
    // jQuery
    $el.height();

    // Yerleşik
    function getHeight(el) {
      const styles = this.getComputedStyles(el);
      const height = el.offsetHeight;
      const borderTopWidth = parseFloat(styles.borderTopWidth);
      const borderBottomWidth = parseFloat(styles.borderBottomWidth);
      const paddingTop = parseFloat(styles.paddingTop);
      const paddingBottom = parseFloat(styles.paddingBottom);
      return height - borderBottomWidth - borderTopWidth - paddingTop - paddingBottom;
    }
    // Tamsayı olarak daha doğru olanı（`border-box` iken, `height` esas; `content-box` ise, `height + padding + border` esas alınır）
    el.clientHeight;
    // Ondalık olarak daha doğru olanı（`border-box` iken, `height` esas; `content-box` ise, `height + padding + border` esas alınır）
    el.getBoundingClientRect().height;
    ```

- [2.3](#2.3) <a name='2.3'></a> Pozisyon ve Ara-Açıklığı

  + Pozisyon

    ```js
    // jQuery
    $el.position();

    // Yerleşik
    { left: el.offsetLeft, top: el.offsetTop }
    ```

  + Ara-Açıklığı

    ```js
    // jQuery
    $el.offset();

    // Yerleşik
    function getOffset (el) {
      const box = el.getBoundingClientRect();

      return {
        top: box.top + window.pageYOffset - document.documentElement.clientTop,
        left: box.left + window.pageXOffset - document.documentElement.clientLeft
      }
    }
    ```

- [2.4](#2.4) <a name='2.4'></a> Üste kaydır

  ```js
  // jQuery
  $(window).scrollTop();

  // Yerleşik
  (document.documentElement && document.documentElement.scrollTop) || document.body.scrollTop;
  ```

**[⬆ üste dön](#İçerik-tablosu)**

## DOM düzenleme

- [3.1](#3.1) <a name='3.1'></a> Çıkartma
  ```js
  // jQuery
  $el.remove();

  // Yerleşik
  el.parentNode.removeChild(el);
  ```

- [3.2](#3.2) <a name='3.2'></a> Metin

  + Get text

    ```js
    // jQuery
    $el.text();

    // Yerleşik
    el.textContent;
    ```

  + Set text

    ```js
    // jQuery
    $el.text(string);

    // Yerleşik
    el.textContent = string;
    ```

- [3.3](#3.3) <a name='3.3'></a> HTML

  + HTML'i alma

    ```js
    // jQuery
    $el.html();

    // Yerleşik
    el.innerHTML;
    ```

  + HTML atama

    ```js
    // jQuery
    $el.html(htmlString);

    // Yerleşik
    el.innerHTML = htmlString;
    ```

- [3.4](#3.4) <a name='3.4'></a> Sona ekleme

  Ata öğenin son çocuğundan sonra öğe ekleme

  ```js
  // jQuery
  $el.append("<div id='container'>hello</div>");

  // Yerleşik
  el.insertAdjacentHTML("beforeend","<div id='container'>hello</div>");
  ```

- [3.5](#3.5) <a name='3.5'></a> Öne ekleme

  ```js
  // jQuery
  $el.prepend("<div id='container'>hello</div>");

  // Yerleşik
  el.insertAdjacentHTML("afterbegin","<div id='container'>hello</div>");
  ```

- [3.6](#3.6) <a name='3.6'></a> Öncesine Ekleme

  Seçili öğeden önceki yere yeni öğe ekleme

  ```js
  // jQuery
  $newEl.insertBefore(queryString);

  // Yerleşik
  const target = document.querySelector(queryString);
  target.parentNode.insertBefore(newEl, target);
  ```

- [3.7](#3.7) <a name='3.7'></a> Sonrasına ekleme

  Seçili öğeden sonraki yere yeni öğe ekleme

  ```js
  // jQuery
  $newEl.insertAfter(queryString);

  // Yerleşik
  const target = document.querySelector(queryString);
  target.parentNode.insertBefore(newEl, target.nextSibling);
  ```

- [3.8](#3.8) <a name='3.8'></a> eşit mi?

  Sorgu seçici ile eşleşiyor ise `true` döner

  ```js
  // jQuery için not: `is` aynı zamanda `function` veya `elements` için de geçerlidir fakat burada bir önemi bulunmuyor
  $el.is(selector);

  // Yerleşik
  el.matches(selector);
  ```
- [3.9](#3.9) <a name='3.9'></a> Klonlama

  Mevcut öğenin bir derin kopyasını oluşturur

  ```js
  // jQuery 
  $el.clone(); 

  // Yerleşik
  el.cloneNode();
  
  // Derin kopya için, `true` parametresi kullanınız  
  ``` 
**[⬆ üste dön](#İçerik-tablosu)**

## Ajax

[Fetch API](https://fetch.spec.whatwg.org/) ajax için XMLHttpRequest yerine kullanan yeni standarttır. Chrome ve Firefox destekler,  eski tarayıcılar için polyfill kullanabilirsiniz.

IE9+ ve üstü için [github/fetch](http://github.com/github/fetch) yada IE8+ ve üstü için [fetch-ie8](https://github.com/camsong/fetch-ie8/), JSONP istekler için [fetch-jsonp](https://github.com/camsong/fetch-jsonp) deneyiniz.

**[⬆ üste dön](#İçerik-tablosu)**

## Olaylar

Namespace ve Delegasyon ile tam olarak değiştirmek için, https://github.com/oneuijs/oui-dom-events sayfasına bakınız  

- [5.1](#5.1) <a name='5.1'></a> on ile bir öğeye bağlama

  ```js
  // jQuery
  $el.on(eventName, eventHandler);

  // Yerleşik
  el.addEventListener(eventName, eventHandler);
  ```

- [5.2](#5.2) <a name='5.2'></a> off ile bir bağlamayı sonlandırma

  ```js
  // jQuery
  $el.off(eventName, eventHandler);

  // Yerleşik
  el.removeEventListener(eventName, eventHandler);
  ```

- [5.3](#5.3) <a name='5.3'></a> Tetikleyici

  ```js
  // jQuery
  $(el).trigger('custom-event', {key1: 'data'});

  // Yerleşik
  if (window.CustomEvent) {
    const event = new CustomEvent('custom-event', {detail: {key1: 'data'}});
  } else {
    const event = document.createEvent('CustomEvent');
    event.initCustomEvent('custom-event', true, true, {key1: 'data'});
  }

  el.dispatchEvent(event);
  ```

**[⬆ üste dön](#İçerik-tablosu)**

## Araçlar

- [6.1](#6.1) <a name='6.1'></a> isArray

  ```js
  // jQuery
  $.isArray(range);

  // Yerleşik
  Array.isArray(range);
  ```

- [6.2](#6.2) <a name='6.2'></a> Trim

  ```js
  // jQuery
  $.trim(string);

  // Yerleşik
  string.trim();
  ```

- [6.3](#6.3) <a name='6.3'></a> Nesne atama

  Türetmek için, object.assign polyfill'ini deneyiniz https://github.com/ljharb/object.assign

  ```js
  // jQuery
  $.extend({}, defaultOpts, opts);

  // Yerleşik
  Object.assign({}, defaultOpts, opts);
  ```

- [6.4](#6.4) <a name='6.4'></a> İçerme

  ```js
  // jQuery
  $.contains(el, child);

  // Yerleşik
  el !== child && el.contains(child);
  ```

**[⬆ üste dön](#İçerik-tablosu)**

## Alternatifler

* [jQuery'e İhtiyacınız Yok](http://youmightnotneedjquery.com/) - Yaygın olan olay, öğe ve ajax işlemlerinin yalın Javascript'teki karşılıklarına ait örnekler
* [npm-dom](http://github.com/npm-dom) ve [webmodules](http://github.com/webmodules) - NPM için ayrı DOM modül organizasyonları

## Çeviriler

* [한국어](./README.ko-KR.md)
* [简体中文](./README.zh-CN.md)
* [Bahasa Melayu](./README-my.md)
* [Bahasa Indonesia](./README-id.md)
* [Português(PT-BR)](./README.pt-BR.md)
* [Tiếng Việt Nam](./README-vi.md)
* [Español](./README-es.md)
* [Русский](./README-ru.md)
* [Türkçe](./README-tr.md)

## Tarayıcı Desteği

![Chrome](https://raw.github.com/alrra/browser-logos/master/chrome/chrome_48x48.png) | ![Firefox](https://raw.github.com/alrra/browser-logos/master/firefox/firefox_48x48.png) | ![IE](https://raw.github.com/alrra/browser-logos/master/internet-explorer/internet-explorer_48x48.png) | ![Opera](https://raw.github.com/alrra/browser-logos/master/opera/opera_48x48.png) | ![Safari](https://raw.github.com/alrra/browser-logos/master/safari/safari_48x48.png)
--- | --- | --- | --- | --- |
Latest ✔ | Latest ✔ | 10+ ✔ | Latest ✔ | 6.1+ ✔ |

# Lisans

MIT
