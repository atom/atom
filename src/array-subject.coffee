Rx = require 'rx'

module.exports =
class ArraySubject extends Rx.Observable
  constructor: (@array) ->
    @observers = []
    super (observer) ->
      observer.onNext(element) for element in @array.slice()
      @observers.push(observer)
      Rx.Disposable.create =>
        @observers.splice(@observers.indexOf(observer), 1)

  onNext: (element) ->
    for observer in @observers.slice()
      observer.onNext(element)
