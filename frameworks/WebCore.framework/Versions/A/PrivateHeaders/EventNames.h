/*
 * Copyright (C) 2005, 2007 Apple Inc. All rights reserved.
 * Copyright (C) 2006 Jon Shier (jshier@iastate.edu)
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public License
 * along with this library; see the file COPYING.LIB.  If not, write to
 * the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 *
 */

#ifndef EventNames_h
#define EventNames_h

#include "EventInterfaces.h"
#include "EventTargetInterfaces.h"
#include "ThreadGlobalData.h"
#include <wtf/text/AtomicString.h>

namespace WebCore {

#define DOM_EVENT_NAMES_FOR_EACH(macro) \
    \
    macro(abort) \
    macro(beforecopy) \
    macro(beforecut) \
    macro(beforeload) \
    macro(beforepaste) \
    macro(beforeunload) \
    macro(blocked) \
    macro(blur) \
    macro(cached) \
    macro(change) \
    macro(checking) \
    macro(click) \
    macro(close) \
    macro(complete) \
    macro(compositionend) \
    macro(compositionstart) \
    macro(compositionupdate) \
    macro(connect) \
    macro(contextmenu) \
    macro(copy) \
    macro(cut) \
    macro(dblclick) \
    macro(devicemotion) \
    macro(deviceorientation) \
    macro(display) \
    macro(downloading) \
    macro(drag) \
    macro(dragend) \
    macro(dragenter) \
    macro(dragleave) \
    macro(dragover) \
    macro(dragstart) \
    macro(drop) \
    macro(error) \
    macro(focus) \
    macro(focusin) \
    macro(focusout) \
    macro(hashchange) \
    macro(input) \
    macro(invalid) \
    macro(keydown) \
    macro(keypress) \
    macro(keyup) \
    macro(load) \
    macro(loadstart) \
    macro(message) \
    macro(mousedown) \
    macro(mousemove) \
    macro(mouseout) \
    macro(mouseover) \
    macro(mouseup) \
    macro(mousewheel) \
    macro(noupdate) \
    macro(obsolete) \
    macro(offline) \
    macro(online) \
    macro(open) \
    macro(overflowchanged) \
    macro(pagehide) \
    macro(pageshow) \
    macro(paste) \
    macro(popstate) \
    macro(readystatechange) \
    macro(reset) \
    macro(resize) \
    macro(scroll) \
    macro(search) \
    macro(select) \
    macro(selectstart) \
    macro(selectionchange) \
    macro(storage) \
    macro(submit) \
    macro(textInput) \
    macro(unload) \
    macro(updateready) \
    macro(versionchange) \
    macro(webkitvisibilitychange) \
    macro(write) \
    macro(writeend) \
    macro(writestart) \
    macro(zoom) \
    \
    macro(DOMActivate) \
    macro(DOMFocusIn) \
    macro(DOMFocusOut) \
    macro(DOMAttrModified) \
    macro(DOMCharacterDataModified) \
    macro(DOMNodeInserted) \
    macro(DOMNodeInsertedIntoDocument) \
    macro(DOMNodeRemoved) \
    macro(DOMNodeRemovedFromDocument) \
    macro(DOMSubtreeModified) \
    macro(DOMContentLoaded) \
    \
    macro(webkitBeforeTextInserted) \
    macro(webkitEditableContentChanged) \
    \
    macro(canplay) \
    macro(canplaythrough) \
    macro(durationchange) \
    macro(emptied) \
    macro(ended) \
    macro(loadeddata) \
    macro(loadedmetadata) \
    macro(pause) \
    macro(play) \
    macro(playing) \
    macro(ratechange) \
    macro(seeked) \
    macro(seeking) \
    macro(timeupdate) \
    macro(volumechange) \
    macro(waiting) \
    \
    macro(addtrack) \
    macro(cuechange) \
    macro(enter) \
    macro(exit) \
    \
    macro(webkitbeginfullscreen) \
    macro(webkitendfullscreen) \
    \
    macro(webkitsourceopen) \
    macro(webkitsourceended) \
    macro(webkitsourceclose) \
    \
    macro(progress) \
    macro(stalled) \
    macro(suspend) \
    \
    macro(webkitAnimationEnd) \
    macro(webkitAnimationStart) \
    macro(webkitAnimationIteration) \
    \
    macro(webkitTransitionEnd) \
    \
    macro(orientationchange) \
    \
    macro(timeout) \
    \
    macro(touchstart) \
    macro(touchmove) \
    macro(touchend) \
    macro(touchcancel) \
    \
    macro(success) \
    \
    macro(loadend) \
    \
    macro(webkitfullscreenchange) \
    macro(webkitfullscreenerror) \
    \
    macro(webkitspeechchange) \
    \
    macro(webglcontextlost) \
    macro(webglcontextrestored) \
    macro(webglcontextcreationerror) \
    \
    macro(audioprocess) \
    \
    macro(connecting) \
    macro(addstream) \
    macro(removestream) \
    \
    macro(show) \
    \

// end of DOM_EVENT_NAMES_FOR_EACH

    class EventNames {
        WTF_MAKE_NONCOPYABLE(EventNames); WTF_MAKE_FAST_ALLOCATED;
        int dummy; // Needed to make initialization macro work.
        // Private to prevent accidental call to EventNames() instead of eventNames()
        EventNames();
        friend class ThreadGlobalData;

    public:
        #define DOM_EVENT_NAMES_DECLARE(name) AtomicString name##Event;
        DOM_EVENT_NAMES_FOR_EACH(DOM_EVENT_NAMES_DECLARE)
        #undef DOM_EVENT_NAMES_DECLARE

        #define DOM_EVENT_INTERFACE_DECLARE(name) AtomicString interfaceFor##name;
        DOM_EVENT_INTERFACES_FOR_EACH(DOM_EVENT_INTERFACE_DECLARE)
        DOM_EVENT_TARGET_INTERFACES_FOR_EACH(DOM_EVENT_INTERFACE_DECLARE)
        #undef DOM_EVENT_INTERFACE_DECLARE
    };

    inline EventNames& eventNames()
    {
        return threadGlobalData().eventNames();
    }

}

#endif
