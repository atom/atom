(function() {

jasmine.JQuery = function() {};

jasmine.JQuery.browserTagCaseIndependentHtml = function(html) {
  var div = document.createElement('div');
  div.innerHTML = html
  return div.innerHTML
};

jasmine.JQuery.elementToString = function(element) {
  if (element instanceof HTMLElement) {
    return element.outerHTML
  } else {
    return element.html()
  }
};

jasmine.JQuery.matchersClass = {};

(function(){
  var jQueryMatchers = {
    toHaveClass: function(className) {
      debugger
      if (this.actual instanceof HTMLElement) {
        return this.actual.classList.contains(className)
      } else {
        return this.actual.hasClass(className);
      }
    },

    toBeVisible: function() {
      return this.actual.is(':visible');
    },

    toBeHidden: function() {
      return this.actual.is(':hidden');
    },

    toBeSelected: function() {
      return this.actual.is(':selected');
    },

    toBeChecked: function() {
      return this.actual.is(':checked');
    },

    toBeEmpty: function() {
      return this.actual.is(':empty');
    },

    toExist: function() {
      if (this.actual instanceof HTMLElement) {
        return true
      } else {
        return this.actual.size() > 0;
      }
    },

    toHaveAttr: function(attributeName, expectedAttributeValue) {
      var actualAttributeValue;
      if (this.actual instanceof HTMLElement) {
        actualAttributeValue = this.actual.getAttribute(attributeName)
      } else {
        actualAttributeValue = this.actual.attr(attributeName)
      }

      return hasProperty(actualAttributeValue, expectedAttributeValue);
    },

    toHaveId: function(id) {
      if (this.actual instanceof HTMLElement) {
        return this.actual.getAttribute('id') == id
      } else {
        return this.actual.attr('id') == id;
      }
    },

    toHaveHtml: function(html) {
      var actualHTML;
      if (this.actual instanceof HTMLElement) {
        actualHTML = this.actual.outerHTML
      } else {
        actualHTML = this.actual.html()
      }

      return actualHTML == jasmine.JQuery.browserTagCaseIndependentHtml(html);
    },

    toHaveText: function(text) {
      var actualText;
      if (this.actual instanceof HTMLElement) {
        actualText = this.actual.textContent
      } else {
        actualText = this.actual.text()
      }

      if (text && typeof text.test === 'function') {
        return text.test(actualText);
      } else {
        return actualText == text;
      }
    },

    toHaveValue: function(value) {
      return this.actual.val() == value;
    },

    toHaveData: function(key, expectedValue) {
      return hasProperty(this.actual.data(key), expectedValue);
    },

    toMatchSelector: function(selector) {
      return this.actual.is(selector);
    },

    toContain: function(selector) {
      return this.actual.find(selector).size() > 0;
    },

    toBeDisabled: function(selector){
      return this.actual.is(':disabled');
    },

    // tests the existence of a specific event binding
    toHandle: function(eventName) {
      var events = this.actual.data("events");
      return events && events[eventName].length > 0;
    },

    // tests the existence of a specific event binding + handler
    toHandleWith: function(eventName, eventHandler) {
      var stack = this.actual.data("events")[eventName];
      var i;
      for (i = 0; i < stack.length; i++) {
        if (stack[i].handler == eventHandler) {
          return true;
        }
      }
      return false;
    }
  };

  jQueryMatchers.toExist.supportsBareElements = true
  jQueryMatchers.toHaveClass.supportsBareElements = true
  jQueryMatchers.toHaveText.supportsBareElements = true
  jQueryMatchers.toHaveId.supportsBareElements = true
  jQueryMatchers.toHaveAttr.supportsBareElements = true
  jQueryMatchers.toHaveHtml.supportsBareElements = true

  var hasProperty = function(actualValue, expectedValue) {
    if (expectedValue === undefined) {
      return actualValue !== undefined;
    }
    return actualValue == expectedValue;
  };

  var bindMatcher = function(methodName) {
    var builtInMatcher = jasmine.Matchers.prototype[methodName];

    jasmine.JQuery.matchersClass[methodName] = function() {
      if (this.actual && this.actual.jquery || this.actual instanceof HTMLElement && jQueryMatchers[methodName].supportsBareElements) {
        var result = jQueryMatchers[methodName].apply(this, arguments);
        this.actual = jasmine.JQuery.elementToString(this.actual);
        return result;
      }

      if (builtInMatcher) {
        return builtInMatcher.apply(this, arguments);
      }

      return false;
    };
  };

  for(var methodName in jQueryMatchers) {
    bindMatcher(methodName);
  }
})();

beforeEach(function() {
  this.addMatchers(jasmine.JQuery.matchersClass);
});
})();
