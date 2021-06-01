const EventKit = require('event-kit');

module.exports = function listen(element, eventName, selector, handler) {
  const innerHandler = function(event) {
    if (selector) {
      var currentTarget = event.target;
      while (currentTarget) {
        if (currentTarget.matches && currentTarget.matches(selector)) {
          handler({
            type: event.type,
            currentTarget: currentTarget,
            target: event.target,
            preventDefault: function() {
              event.preventDefault();
            },
            originalEvent: event
          });
        }
        if (currentTarget === element) break;
        currentTarget = currentTarget.parentNode;
      }
    } else {
      handler({
        type: event.type,
        currentTarget: event.currentTarget,
        target: event.target,
        preventDefault: function() {
          event.preventDefault();
        },
        originalEvent: event
      });
    }
  };

  element.addEventListener(eventName, innerHandler);

  return new EventKit.Disposable(function() {
    element.removeEventListener(eventName, innerHandler);
  });
};
