$ = require 'jquery'
_ = require 'underscore'

Modal  = require 'modal'

jQuery = $
require 'stringscore'

module.exports =
class ModalSelector extends Modal
  selectorHTML: '''
    <div id="modal-selector">
      <input type="search">
      <br>
      <ul class="list">
      </ul>
    </div>
  '''

  showing: false

  # The items to filter. An Array of {name:name, url:url} objects.
  list: []

  constructor: (@list) ->
    super @selectorHTML

    head  = $('head')[0]
    style = document.createElement 'style'
    rules = document.createTextNode @selectorCSS
    style.type = 'text/css'
    style.appendChild rules
    head.appendChild style

    $('#modal-selector input').live 'keydown', @onKeydown

  onKeydown: (e) =>
    keys = up: 38, down: 40, enter: 13

    if e.keyCode is keys.enter
      @openSelected()
      false
    else if e.keyCode is keys.up
      @moveUp()
    else if e.keyCode is keys.down
      @moveDown()
    else
      @filter()

  show: ->
    super
    @filter()

  filter: ->
    if query = $('#modal-selector input').val()
      items = @findMatchingItems query
    else
      items = @list
    $('#modal-selector ul').empty()
    for {name, url} in items[0..10]
      $('#modal-selector ul').append "<li data-url=#{url}>#{name}</li>"
    $('#modal-selector input').focus()
    $('#modal-selector li:first').addClass 'selected'

  findMatchingItems: (query) ->
    return [] if not query

    results = []
    for item in @list
      {name, url} = item
      score = name.score query
      if score > 0
        # Basename matches count for more.
        if not query.match '/'
          if name.match '/'
            score += name.replace(/^.*\//, '').score query
          else
            score *= 2
        results.push [score, item]

    sorted = results.sort (a, b) -> b[0] - a[0]
    _.map sorted, (el) -> el[1]

  openSelected: ->
    text = $('#modal-selector .selected').text()
    window.open _.find(@list, (item) -> item.name is text).url
    @toggle()

  moveUp: ->
    selected = $('#modal-selector .selected')
    if selected.prev().length
      selected.prev().addClass 'selected'
      selected.removeClass 'selected'

  moveDown: ->
    selected = $('#modal-selector .selected')
    if selected.next().length
      selected.next().addClass 'selected'
      selected.removeClass 'selected'

  selectorCSS: '''
#modal .content {
  background: #ededed;
  padding: 0;
}
#modal .close {
  display: none;
}
#modal-selector .list {
  height: 100px;
  overflow: hidden;
  padding: 10px 0;
}
#modal-selector input[type=search] {
  width: 95%;
  margin: 10px;
}

#modal .content {
  min-width: 200px;
  height: 100%;
  background-color: #DDE3EA;
  color: #000;
  border-right: 1px solid #B4B4B4;
  cursor: default;
  -webkit-user-select: none;
  overflow: auto;
}

#modal .content .cwd {
  padding-top: 5px;
  padding-left: 5px;
  font-weight: bold;
  color: #708193;
  text-transform: uppercase;
  text-shadow: 0 1px 0 rgba(255, 255, 255, 0.5);
}

#modal .content ul {
  margin: 0;
  padding-top: 2px;
  list-style-type: none;
}

#modal .content li {
  padding: 0;
  padding-left: 5px;
  line-height: 20px;
  font-size: 14px;
}

#modal .content li.selected {
  background-image: -webkit-gradient(linear,0% 0,0% 100%,from(#BCCBEB),to(#8094BB));
  border-top: 1px solid #A0AFCD;
  color: #fff;
  text-shadow: 0 1px 0 rgba(0, 0, 0, 0.5);
}
  '''