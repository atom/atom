'use strict'

jasmine.JQuery = function() {}

jasmine.JQuery.browserTagCaseIndependentHtml = function(html) {
  var div = document.createElement('div')
  div.innerHTML = html
  return div.innerHTML
}

jasmine.JQuery.elementToString = function(element) {
  if (element instanceof HTMLElement) {
    return element.outerHTML
  } else {
    return element.html()
  }
}

jasmine.JQuery.matchersClass = {}

var jQueryMatchers = {
  toHaveClass: function(className) {
    if (this.actual instanceof HTMLElement) {
      return this.actual.classList.contains(className)
    } else {
      return this.actual.hasClass(className)
    }
  },

  toBeVisible: function() {
    if (this.actual instanceof HTMLElement) {
      return this.actual.offsetWidth !== 0 || this.actual.offsetHeight !== 0
    } else {
      return this.actual.is(':visible')
    }
  },

  toBeHidden: function() {
    if (this.actual instanceof HTMLElement) {
      return this.actual.offsetWidth === 0 && this.actual.offsetHeight === 0
    } else {
      return this.actual.is(':hidden')
    }
  },

  toBeSelected: function() {
    if (this.actual instanceof HTMLElement) {
      return this.actual.selected
    } else {
      return this.actual.is(':selected')
    }
  },

  toBeChecked: function() {
    if (this.actual instanceof HTMLElement) {
      return this.actual.checked
    } else {
      return this.actual.is(':checked')
    }
  },

  toBeEmpty: function() {
    if (this.actual instanceof HTMLElement) {
      return this.actual.innerHTML === ''
    } else {
      return this.actual.is(':empty')
    }
  },

  toExist: function() {
    if (this.actual instanceof HTMLElement) {
      return true
    } else if (this.actual) {
      return this.actual.size() > 0
    } else {
      return false
    }
  },

  toHaveAttr: function(attributeName, expectedAttributeValue) {
    var actualAttributeValue
    if (this.actual instanceof HTMLElement) {
      actualAttributeValue = this.actual.getAttribute(attributeName)
    } else {
      actualAttributeValue = this.actual.attr(attributeName)
    }

    return hasProperty(actualAttributeValue, expectedAttributeValue)
  },

  toHaveId: function(id) {
    if (this.actual instanceof HTMLElement) {
      return this.actual.getAttribute('id') == id
    } else {
      return this.actual.attr('id') == id
    }
  },

  toHaveHtml: function(html) {
    var actualHTML
    if (this.actual instanceof HTMLElement) {
      actualHTML = this.actual.innerHTML
    } else {
      actualHTML = this.actual.html()
    }

    return actualHTML == jasmine.JQuery.browserTagCaseIndependentHtml(html)
  },

  toHaveText: function(text) {
    var actualText
    if (this.actual instanceof HTMLElement) {
      actualText = this.actual.textContent
    } else {
      actualText = this.actual.text()
    }

    if (text && typeof text.test === 'function') {
      return text.test(actualText)
    } else {
      return actualText == text
    }
  },

  toHaveValue: function(value) {
    if (this.actual instanceof HTMLElement) {
      return this.actual.value == value
    } else {
      return this.actual.val() == value
    }
  },

  toHaveData: function(key, expectedValue) {
    if (this.actual instanceof HTMLElement) {
      var camelCaseKey
      for (var part of key.split('-')) {
        if (camelCaseKey) {
          camelCaseKey += part[0].toUpperCase() + part.substring(1)
        } else {
          camelCaseKey = part
        }
      }
      return hasProperty(this.actual.dataset[camelCaseKey], expectedValue)
    } else {
      return hasProperty(this.actual.data(key), expectedValue)
    }
  },

  toMatchSelector: function(selector) {
    if (this.actual instanceof HTMLElement) {
      return this.actual.matches(selector)
    } else {
      return this.actual.is(selector)
    }
  },

  toContain: function(contained) {
    if (this.actual instanceof HTMLElement) {
      if (typeof contained === 'string') {
        return this.actual.querySelector(contained)
      } else {
        return this.actual.contains(contained)
      }
    } else {
      return this.actual.find(contained).size() > 0
    }
  },

  toBeDisabled: function(selector){
    if (this.actual instanceof HTMLElement) {
      return this.actual.disabled
    } else {
      return this.actual.is(':disabled')
    }
  },

  // tests the existence of a specific event binding
  toHandle: function(eventName) {
    var events = this.actual.data("events")
    return events && events[eventName].length > 0
  },

  // tests the existence of a specific event binding + handler
  toHandleWith: function(eventName, eventHandler) {
    var stack = this.actual.data("events")[eventName]
    var i
    for (i = 0; i < stack.length; i++) {
      if (stack[i].handler == eventHandler) {
        return true
      }
    }
    return false
  }
}

var hasProperty = function(actualValue, expectedValue) {
  if (expectedValue === undefined) {
    return actualValue !== undefined
  }
  return actualValue == expectedValue
}

var bindMatcher = function(methodName) {
  var builtInMatcher = jasmine.Matchers.prototype[methodName]

  jasmine.JQuery.matchersClass[methodName] = function() {
    if (this.actual && this.actual.jquery || this.actual instanceof HTMLElement) {
      var result = jQueryMatchers[methodName].apply(this, arguments)
      this.actual = jasmine.JQuery.elementToString(this.actual)
      return result
    }

    if (builtInMatcher) {
      return builtInMatcher.apply(this, arguments)
    }

    return false
  }
}

for(var methodName in jQueryMatchers) {
  bindMatcher(methodName)
}

beforeEach(function() {
  this.addMatchers(jasmine.JQuery.matchersClass)
})
