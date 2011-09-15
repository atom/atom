// facebox 2.0
// MIT Licensed
// https://github.com/defunkt/facebox
(function($){

  // jQuery plugin
  //
  // $('a[rel*=facebox]').facebox()
  // $('.js-add-cc').facebox(function() {
  //   $('#facebox .js-thanks, #facebox .rule:first').hide()
  // })
  $.fn.facebox = function( callback ) {
    return this.live('click.facebox', function(){
      // rel="facebox.my-class" adds my-class to '#facebox .content'
      var contentClass = ( /facebox\.(\S+)/.exec(this.rel) || [] )[1]

      if ( callback )
        $(document).one('show.facebox', callback)

      $.facebox({ div: this.href }, contentClass)

      return false
    })
  }

  // The Real Deal
  //
  // $.facebox('<b>Cool!</b>')
  $.facebox = function( data, contentClass ) {
    if ( $('#facebox .fb-loading').length == 0 ) {
      show('<div class="fb-loading">&nbsp;</div>')
      $(document).trigger('loading.facebox')
    }

    $('#facebox .content').addClass(contentClass)

    if ( !data ) return

    // $.facebox('#info') => $.facebox({div: '#info'})
    if ( /^#/.test(data) )
      data = { div: data }

    // $.facebox('/some/url') => $.facebox({ajax: '/some/url' })
    if ( /^\//.test(data) )
      data = { ajax: data }

    var href = data.ajax || data.image || data.div
    if ( href ) {
      // div
      var div = /#.+$/.exec(href)
      if ( div ) {
        show( $(div[0]).html() )

      // image
      } else if ( data.image || /\.(png|jpe?g|gif)(\?\S*)?$/i.test(href) ) {
        var image = new Image
        image.onload = function() {
          show('<img src="' + image.src + '" />')
        }
        image.src = href

      // ajax
      } else {
        $.get(href, show)
      }
    }

    else if ( $.isFunction(data) )
      data()
    else
      show(data)
  }


  //
  // Default settings
  //

  var settings = $.facebox.settings = {
    opacity    : 0.2,
    overlay    : true,
    faceboxHTML: '<div id="facebox"><div class="popup"><div class="content"></div><a href="#" class="close inline">&nbsp;</a></div></div>'
  }


  //
  // Methods
  //

  // Close Facebox
  var close = $.facebox.close = function(){
    $(document).trigger('close.facebox')
    return false
  }

  // Show the Facebox
  function show( data ) {
    // Dim the lights
    if ( settings.overlay && !$('#facebox-overlay').is(':visible') ) {
      $('body').append('<div id="facebox-overlay"></div>')

      $('#facebox-overlay')
        .css('opacity', settings.opacity)
        .fadeIn(200)
        .click(close)
    }

    // Create the Facebox
    if ( $('#facebox').length == 0 ) {
      $('body').append( $(settings.faceboxHTML).hide() )
      $(document).trigger('setup.facebox')
    }

    // Make that money
    $('#facebox .content').html(data).show()

    // Position Facebox based on the user's scroll
    $('#facebox').show().css({
      top:	$(window).scrollTop() + ($(window).height() / 10),
      left:	$(window).width() / 2 - ($('#facebox .popup').outerWidth() / 2)
    })

    // Fire events if we're not loading.
    if ( $('.fb-loading:visible').length == 0 )
      $(document).trigger('show.facebox').trigger('reveal.facebox')
  }


  //
  // Bindings
  //

  $(document).bind('close.facebox', function(){
    $('#facebox').fadeOut(function(){
      $(this).remove()
      $(document).trigger('afterClose.facebox')
    })

    $('#facebox-overlay').fadeOut(200, function(){
      $(this).remove()
    })
  })

  $(document).one('show.facebox', function(){
    // Click on close image = Close Facebox
    $('#facebox .close').live('click', close)

    // ESC = Close Facebox
    $(document).bind('keydown.facebox', function(e){
      if ( e.keyCode == 27 && $('#facebox:visible').length ) close()
      return true
    })
  })
})(jQuery);
