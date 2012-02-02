#ifndef ColorChooserClient_h
#define ColorChooserClient_h

#if ENABLE(INPUT_COLOR)

#include "ColorChooser.h"
#include <wtf/OwnPtr.h>
#include <wtf/PassOwnPtr.h>

namespace WebCore {

class Color;

class ColorChooserClient {
public:
    virtual void didChooseColor(const Color&) = 0;
    virtual void didEndChooser() = 0;
};

} // namespace WebCore

#endif // ENABLE(INPUT_COLOR)

#endif // ColorChooserClient_h
