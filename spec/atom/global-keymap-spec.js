(function() {
  var $, GlobalKeymap;
  GlobalKeymap = require('global-keymap');
  $ = require('jquery');
  describe("GlobalKeymap", function() {
    var fragment, keymap;
    fragment = null;
    keymap = null;
    beforeEach(function() {
      keymap = new GlobalKeymap;
      return fragment = $("<div class=\"command-mode\">\n  <div class=\"child-node\">\n    <div class=\"grandchild-node\"/>\n  </div>\n</div>");
    });
    describe(".handleKeyEvent(event)", function() {
      var deleteCharHandler, insertCharHandler;
      deleteCharHandler = null;
      insertCharHandler = null;
      beforeEach(function() {
        keymap.bindKeys('.command-mode', {
          'x': 'deleteChar'
        });
        keymap.bindKeys('.insert-mode', {
          'x': 'insertChar'
        });
        deleteCharHandler = jasmine.createSpy('deleteCharHandler');
        insertCharHandler = jasmine.createSpy('insertCharHandler');
        fragment.on('deleteChar', deleteCharHandler);
        return fragment.on('insertChar', insertCharHandler);
      });
      describe("when no binding matches the event", function() {
        return it("returns true, so the event continues to propagate", function() {
          return expect(keymap.handleKeyEvent(keypressEvent('0', {
            target: fragment[0]
          }))).toBeTruthy();
        });
      });
      describe("when the event's target node matches a selector with a matching binding", function() {
        return it("triggers the command event associated with that binding on the target node and returns false", function() {
          var commandEvent, event, result;
          result = keymap.handleKeyEvent(keypressEvent('x', {
            target: fragment[0]
          }));
          expect(result).toBe(false);
          expect(deleteCharHandler).toHaveBeenCalled();
          expect(insertCharHandler).not.toHaveBeenCalled();
          deleteCharHandler.reset();
          fragment.removeClass('command-mode').addClass('insert-mode');
          event = keypressEvent('x', {
            target: fragment[0]
          });
          keymap.handleKeyEvent(event);
          expect(deleteCharHandler).not.toHaveBeenCalled();
          expect(insertCharHandler).toHaveBeenCalled();
          commandEvent = insertCharHandler.argsForCall[0][0];
          expect(commandEvent.keyEvent).toBe(event);
          return expect(event.char).toBe('x');
        });
      });
      describe("when the event's target node *descends* from a selector with a matching binding", function() {
        return it("triggers the command event associated with that binding on the target node and returns false", function() {
          var result, target;
          target = fragment.find('.child-node')[0];
          result = keymap.handleKeyEvent(keypressEvent('x', {
            target: target
          }));
          expect(result).toBe(false);
          expect(deleteCharHandler).toHaveBeenCalled();
          expect(insertCharHandler).not.toHaveBeenCalled();
          deleteCharHandler.reset();
          fragment.removeClass('command-mode').addClass('insert-mode');
          keymap.handleKeyEvent(keypressEvent('x', {
            target: target
          }));
          expect(deleteCharHandler).not.toHaveBeenCalled();
          return expect(insertCharHandler).toHaveBeenCalled();
        });
      });
      describe("when the event's target node descends from multiple nodes that match selectors with a binding", function() {
        return it("only triggers bindings on selectors associated with the closest ancestor node", function() {
          var fooHandler, target;
          keymap.bindKeys('.child-node', {
            'x': 'foo'
          });
          fooHandler = jasmine.createSpy('fooHandler');
          fragment.on('foo', fooHandler);
          target = fragment.find('.grandchild-node')[0];
          keymap.handleKeyEvent(keypressEvent('x', {
            target: target
          }));
          expect(fooHandler).toHaveBeenCalled();
          expect(deleteCharHandler).not.toHaveBeenCalled();
          return expect(insertCharHandler).not.toHaveBeenCalled();
        });
      });
      return describe("when the event bubbles to a node that matches multiple selectors", function() {
        describe("when the matching selectors differ in specificity", function() {
          return it("triggers the binding for the most specific selector", function() {
            var barHandler, bazHandler, fooHandler, target;
            keymap.bindKeys('div .child-node', {
              'x': 'foo'
            });
            keymap.bindKeys('.command-mode .child-node', {
              'x': 'baz'
            });
            keymap.bindKeys('.child-node', {
              'x': 'bar'
            });
            fooHandler = jasmine.createSpy('fooHandler');
            barHandler = jasmine.createSpy('barHandler');
            bazHandler = jasmine.createSpy('bazHandler');
            fragment.on('foo', fooHandler);
            fragment.on('bar', barHandler);
            fragment.on('baz', bazHandler);
            target = fragment.find('.grandchild-node')[0];
            keymap.handleKeyEvent(keypressEvent('x', {
              target: target
            }));
            expect(fooHandler).not.toHaveBeenCalled();
            expect(barHandler).not.toHaveBeenCalled();
            return expect(bazHandler).toHaveBeenCalled();
          });
        });
        return describe("when the matching selectors have the same specificity", function() {
          return it("triggers the bindings for the most recently declared selector", function() {
            var barHandler, bazHandler, fooHandler, target;
            keymap.bindKeys('.child-node', {
              'x': 'foo',
              'y': 'baz'
            });
            keymap.bindKeys('.child-node', {
              'x': 'bar'
            });
            fooHandler = jasmine.createSpy('fooHandler');
            barHandler = jasmine.createSpy('barHandler');
            bazHandler = jasmine.createSpy('bazHandler');
            fragment.on('foo', fooHandler);
            fragment.on('bar', barHandler);
            fragment.on('baz', bazHandler);
            target = fragment.find('.grandchild-node')[0];
            keymap.handleKeyEvent(keypressEvent('x', {
              target: target
            }));
            expect(barHandler).toHaveBeenCalled();
            expect(fooHandler).not.toHaveBeenCalled();
            keymap.handleKeyEvent(keypressEvent('y', {
              target: target
            }));
            return expect(bazHandler).toHaveBeenCalled();
          });
        });
      });
    });
    return fdescribe(".bindAllKeys(fn)", function() {
      it("calls given fn when selector matches", function() {
        var event, handler, target;
        handler = jasmine.createSpy('handler');
        keymap.bindAllKeys('.child-node', handler);
        target = fragment.find('.grandchild-node')[0];
        event = keypressEvent('y', {
          target: target
        });
        keymap.handleKeyEvent(event);
        return expect(handler).toHaveBeenCalledWith(event);
      });
      describe("when the handler function returns a command string", function() {
        return it("triggers the command event on the target and stops propagating the event", function() {
          var barHandler, fooHandler;
          keymap.bindKeys('*', {
            'x': 'foo'
          });
          keymap.bindAllKeys('*', function() {
            return 'bar';
          });
          fooHandler = jasmine.createSpy('fooHandler');
          barHandler = jasmine.createSpy('barHandler');
          fragment.on('foo', fooHandler);
          fragment.on('bar', barHandler);
          keymap.handleKeyEvent(keydownEvent('x'));
          expect(fooHandler).not.toHaveBeenCalled();
          return expect(barHandler).toHaveBeenCalled();
        });
      });
      describe("when the handler function returns false", function() {
        return it("stops propagating the event", function() {
          var fooHandler;
          keymap.bindKeys('*', {
            'x': 'foo'
          });
          keymap.bindAllKeys('*', function() {
            return false;
          });
          fooHandler = jasmine.createSpy('fooHandler');
          fragment.on('foo', fooHandler);
          keymap.handleKeyEvent(keydownEvent('x'));
          return expect(fooHandler).not.toHaveBeenCalled();
        });
      });
      return describe("when the handler function returns anything other than a string or false", function() {
        return it("continues to propagate the event", function() {
          var fooHandler, target;
          keymap.bindKeys('*', {
            'x': 'foo'
          });
          keymap.bindAllKeys('*', function() {
            return;
          });
          fooHandler = jasmine.createSpy('fooHandler');
          fragment.on('foo', fooHandler);
          target = fragment.find('.child-node')[0];
          keymap.handleKeyEvent(keydownEvent('x', {
            target: target
          }));
          return expect(fooHandler).toHaveBeenCalled();
        });
      });
    });
  });
}).call(this);
