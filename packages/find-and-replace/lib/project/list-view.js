const etch = require('etch');
const $ = etch.dom;

module.exports = class ListView {
  constructor({items, heightForItem, itemComponent, className}) {
    this.items = items;
    this.heightForItem = heightForItem;
    this.itemComponent = itemComponent;
    this.className = className;
    this.previousScrollTop = 0
    this.previousClientHeight = 0
    etch.initialize(this);
    etch.update(this);

    const resizeObserver = new ResizeObserver(() => etch.update(this));
    resizeObserver.observe(this.element);
    this.element.addEventListener('scroll', () => etch.update(this));
  }

  update({items, heightForItem, itemComponent, className} = {}) {
    if (items) this.items = items;
    if (heightForItem) this.heightForItem = heightForItem;
    if (itemComponent) this.itemComponent = itemComponent;
    if (className) this.className = className;
    return etch.update(this)
  }

  render() {
    console.error("Rendering listView")
    const children = [];
    let itemTopPosition = 0;

    let scrollTop = this.previousScrollTop
    let clientHeight = this.previousClientHeight

    if (this.element && this.element.clientHeight > 0) {
      scrollTop = this.element.scrollTop;
      clientHeight = this.element.clientHeight;
      this.previousScrollTop = scrollTop
      this.previousClientHeight = clientHeight
    }

    const scrollBottom = scrollTop + clientHeight;

    let i = 0;

    for (; i < this.items.length; i++) {
      let itemBottomPosition = itemTopPosition + this.heightForItem(this.items[i], i);
      if (itemBottomPosition > scrollTop) break;
      itemTopPosition = itemBottomPosition;
    }

    for (; i < this.items.length; i++) {
      const item = this.items[i];
      const itemHeight = this.heightForItem(this.items[i], i);
      children.push(
        $.div(
          {
            style: {
              position: 'absolute',
              height: `${itemHeight}px`,
              width: '100%',
              top: `${itemTopPosition}px`
            },
            key: i
          },
          etch.dom(this.itemComponent, {
            item: item,
            top: Math.max(0, scrollTop - itemTopPosition),
            bottom: Math.min(itemHeight, scrollBottom - itemTopPosition)
          })
        )
      );

      itemTopPosition += itemHeight;
      if (itemTopPosition >= scrollBottom) {
        i++
        break;
      }
    }
    for (; i < this.items.length; i++) {
      itemTopPosition += this.heightForItem(this.items[i], i);
    }

    console.error(`Rendering list view with ${this.items.length} items and ${children.length} children`);


    return $.div(
      {
        className: 'results-view-container',
        style: {
          position: 'relative',
          height: '100%',
          overflow: 'auto',
        }
      },
      $.ol(
        {
          ref: 'list',
          className: this.className,
          style: {height: `${itemTopPosition}px`}
        },
        ...children
      )
    );
  }
};
