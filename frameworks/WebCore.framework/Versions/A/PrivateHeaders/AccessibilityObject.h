/*
 * Copyright (C) 2008, 2009, 2011 Apple Inc. All rights reserved.
 * Copyright (C) 2008 Nuanti Ltd.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1.  Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 * 2.  Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 * 3.  Neither the name of Apple Computer, Inc. ("Apple") nor the names of
 *     its contributors may be used to endorse or promote products derived
 *     from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE AND ITS CONTRIBUTORS "AS IS" AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL APPLE OR ITS CONTRIBUTORS BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef AccessibilityObject_h
#define AccessibilityObject_h

#include "FloatQuad.h"
#include "LayoutTypes.h"
#include "VisiblePosition.h"
#include "VisibleSelection.h"
#include <wtf/Forward.h>
#include <wtf/RefPtr.h>
#include <wtf/Vector.h>

#if PLATFORM(MAC)
#include <wtf/RetainPtr.h>
#elif PLATFORM(WIN) && !OS(WINCE)
#include "AccessibilityObjectWrapperWin.h"
#include "COMPtr.h"
#elif PLATFORM(CHROMIUM)
#include "AccessibilityObjectWrapper.h"
#endif

#if PLATFORM(MAC)

typedef struct _NSRange NSRange;

OBJC_CLASS NSArray;
OBJC_CLASS NSAttributedString;
OBJC_CLASS NSData;
OBJC_CLASS NSMutableAttributedString;
OBJC_CLASS NSString;
OBJC_CLASS NSValue;
OBJC_CLASS NSView;
OBJC_CLASS WebAccessibilityObjectWrapper;

typedef WebAccessibilityObjectWrapper AccessibilityObjectWrapper;

#elif PLATFORM(GTK)
typedef struct _AtkObject AtkObject;
typedef struct _AtkObject AccessibilityObjectWrapper;
#else
class AccessibilityObjectWrapper;
#endif

namespace WebCore {

class AccessibilityObject;
class AXObjectCache;
class Element;
class Frame;
class FrameView;
class HTMLAnchorElement;
class HTMLAreaElement;
class IntPoint;
class IntSize;
class Node;
class Page;
class RenderObject;
class RenderListItem;
class ScrollableArea;
class VisibleSelection;
class Widget;

typedef unsigned AXID;

enum AccessibilityRole {
    AnnotationRole = 1,
    ApplicationRole,
    ApplicationAlertRole,
    ApplicationAlertDialogRole,
    ApplicationDialogRole,
    ApplicationLogRole,
    ApplicationMarqueeRole,
    ApplicationStatusRole,
    ApplicationTimerRole, 
    BrowserRole,
    BusyIndicatorRole,
    ButtonRole,
    CellRole, 
    CheckBoxRole,
    ColorWellRole,
    ColumnRole,
    ColumnHeaderRole,
    ComboBoxRole,
    DefinitionListTermRole,
    DefinitionListDefinitionRole,
    DirectoryRole,
    DisclosureTriangleRole,
    DivRole,
    DocumentRole,
    DocumentArticleRole,
    DocumentMathRole,
    DocumentNoteRole,
    DocumentRegionRole,            
    DrawerRole,
    EditableTextRole,
    FormRole,
    GridRole,
    GroupRole,
    GrowAreaRole,
    HeadingRole,
    HelpTagRole,
    IgnoredRole,
    ImageRole,
    ImageMapRole,
    ImageMapLinkRole,
    IncrementorRole,
    LabelRole,
    LandmarkApplicationRole,
    LandmarkBannerRole,
    LandmarkComplementaryRole,
    LandmarkContentInfoRole,
    LandmarkMainRole,
    LandmarkNavigationRole,
    LandmarkSearchRole,
    LinkRole,
    ListRole,
    ListBoxRole,
    ListBoxOptionRole,
    ListItemRole,
    ListMarkerRole,
    MatteRole,
    MenuRole,
    MenuBarRole,
    MenuButtonRole,
    MenuItemRole,
    MenuListPopupRole,
    MenuListOptionRole,
    OutlineRole,
    ParagraphRole,
    PopUpButtonRole,
    PresentationalRole,
    ProgressIndicatorRole,
    RadioButtonRole,
    RadioGroupRole,
    RowHeaderRole,
    RowRole,
    RulerRole,
    RulerMarkerRole,
    ScrollAreaRole,
    ScrollBarRole,
    SheetRole,
    SliderRole,
    SliderThumbRole,
    SpinButtonRole,
    SpinButtonPartRole,
    SplitGroupRole,
    SplitterRole,
    StaticTextRole,
    SystemWideRole,
    TabGroupRole,
    TabListRole,
    TabPanelRole,            
    TabRole,
    TableRole,
    TableHeaderContainerRole,
    TextAreaRole,
    TreeRole,
    TreeGridRole,
    TreeItemRole,
    TextFieldRole,
    ToolbarRole,
    UnknownRole,
    UserInterfaceTooltipRole,
    ValueIndicatorRole,            
    WebAreaRole,
    WebCoreLinkRole,
    WindowRole,
};

enum AccessibilityOrientation {
    AccessibilityOrientationVertical,
    AccessibilityOrientationHorizontal,
};
    
enum AccessibilityObjectInclusion {
    IncludeObject,
    IgnoreObject,
    DefaultBehavior,
};
    
enum AccessibilityButtonState {
    ButtonStateOff = 0,
    ButtonStateOn, 
    ButtonStateMixed,
};
    
enum AccessibilitySortDirection {
    SortDirectionNone,
    SortDirectionAscending,
    SortDirectionDescending,
};

enum AccessibilitySearchDirection {
    SearchDirectionNext = 1,
    SearchDirectionPrevious
};

enum AccessibilitySearchKey {
    AnyTypeSearchKey = 1,
    BlockquoteSameLevelSearchKey,
    BlockquoteSearchKey,
    BoldFontSearchKey,
    ButtonSearchKey,
    CheckBoxSearchKey,
    ControlSearchKey,
    DifferentTypeSearchKey,
    FontChangeSearchKey,
    FontColorChangeSearchKey,
    FrameSearchKey,
    GraphicSearchKey,
    HeadingLevel1SearchKey,
    HeadingLevel2SearchKey,
    HeadingLevel3SearchKey,
    HeadingLevel4SearchKey,
    HeadingLevel5SearchKey,
    HeadingLevel6SearchKey,
    HeadingSameLevelSearchKey,
    HeadingSearchKey,
    ItalicFontSearchKey,
    LandmarkSearchKey,
    LinkSearchKey,
    ListSearchKey,
    LiveRegionSearchKey,
    MisspelledWordSearchKey,
    PlainTextSearchKey,
    RadioGroupSearchKey,
    SameTypeSearchKey,
    StaticTextSearchKey,
    StyleChangeSearchKey,
    TableSameLevelSearchKey,
    TableSearchKey,
    TextFieldSearchKey,
    UnderlineSearchKey,
    UnvisitedLinkSearchKey,
    VisitedLinkSearchKey
};

struct AccessibilitySearchCriteria {
    AccessibilityObject* startObject;
    AccessibilitySearchDirection searchDirection;
    AccessibilitySearchKey searchKey;
    String* searchText;
    unsigned resultsLimit;
};

struct VisiblePositionRange {

    VisiblePosition start;
    VisiblePosition end;

    VisiblePositionRange() {}

    VisiblePositionRange(const VisiblePosition& s, const VisiblePosition& e)
        : start(s)
        , end(e)
    { }

    bool isNull() const { return start.isNull() || end.isNull(); }
};

struct PlainTextRange {
        
    unsigned start;
    unsigned length;
    
    PlainTextRange()
        : start(0)
        , length(0)
    { }
    
    PlainTextRange(unsigned s, unsigned l)
        : start(s)
        , length(l)
    { }
    
    bool isNull() const { return !start && !length; }
};

class AccessibilityObject : public RefCounted<AccessibilityObject> {
protected:
    AccessibilityObject();
    
public:
    virtual ~AccessibilityObject();
    virtual void detach();
        
    typedef Vector<RefPtr<AccessibilityObject> > AccessibilityChildrenVector;
    
    virtual bool isAccessibilityRenderObject() const { return false; }
    virtual bool isAccessibilityScrollbar() const { return false; }
    virtual bool isAccessibilityScrollView() const { return false; }
    
    bool accessibilityObjectContainsText(String *) const;
    
    virtual bool isAnchor() const { return false; }
    virtual bool isAttachment() const { return false; }
    virtual bool isHeading() const { return false; }
    virtual bool isLink() const { return false; }
    virtual bool isImage() const { return false; }
    virtual bool isNativeImage() const { return false; }
    virtual bool isImageButton() const { return false; }
    virtual bool isPasswordField() const { return false; }
    virtual bool isNativeTextControl() const { return false; }
    virtual bool isWebArea() const { return false; }
    virtual bool isCheckbox() const { return roleValue() == CheckBoxRole; }
    virtual bool isRadioButton() const { return roleValue() == RadioButtonRole; }
    virtual bool isListBox() const { return roleValue() == ListBoxRole; }
    virtual bool isMediaTimeline() const { return false; }
    virtual bool isMenuRelated() const { return false; }
    virtual bool isMenu() const { return false; }
    virtual bool isMenuBar() const { return false; }
    virtual bool isMenuButton() const { return false; }
    virtual bool isMenuItem() const { return false; }
    virtual bool isFileUploadButton() const { return false; }
    virtual bool isInputImage() const { return false; }
    virtual bool isProgressIndicator() const { return false; }
    virtual bool isSlider() const { return false; }
    virtual bool isInputSlider() const { return false; }
    virtual bool isControl() const { return false; }
    virtual bool isList() const { return false; }
    virtual bool isAccessibilityTable() const { return false; }
    virtual bool isDataTable() const { return false; }
    virtual bool isTableRow() const { return false; }
    virtual bool isTableColumn() const { return false; }
    virtual bool isTableCell() const { return false; }
    virtual bool isFieldset() const { return false; }
    virtual bool isGroup() const { return false; }
    virtual bool isARIATreeGridRow() const { return false; }
    virtual bool isImageMapLink() const { return false; }
    virtual bool isMenuList() const { return false; }
    virtual bool isMenuListPopup() const { return false; }
    virtual bool isMenuListOption() const { return false; }
    virtual bool isSpinButton() const { return false; }
    virtual bool isSpinButtonPart() const { return false; }
    virtual bool isMockObject() const { return false; }
    bool isTextControl() const { return roleValue() == TextAreaRole || roleValue() == TextFieldRole; }
    bool isARIATextControl() const;
    bool isTabList() const { return roleValue() == TabListRole; }
    bool isTabItem() const { return roleValue() == TabRole; }
    bool isRadioGroup() const { return roleValue() == RadioGroupRole; }
    bool isComboBox() const { return roleValue() == ComboBoxRole; }
    bool isTree() const { return roleValue() == TreeRole; }
    bool isTreeItem() const { return roleValue() == TreeItemRole; }
    bool isScrollbar() const { return roleValue() == ScrollBarRole; }
    bool isButton() const { return roleValue() == ButtonRole; }
    bool isListItem() const { return roleValue() == ListItemRole; }
    bool isCheckboxOrRadio() const { return isCheckbox() || isRadioButton(); }
    bool isScrollView() const { return roleValue() == ScrollAreaRole; }
    bool isBlockquote() const;
    bool isLandmark() const;
    
    virtual bool isChecked() const { return false; }
    virtual bool isEnabled() const { return false; }
    virtual bool isSelected() const { return false; }
    virtual bool isFocused() const { return false; }
    virtual bool isHovered() const { return false; }
    virtual bool isIndeterminate() const { return false; }
    virtual bool isLoaded() const { return false; }
    virtual bool isMultiSelectable() const { return false; }
    virtual bool isOffScreen() const { return false; }
    virtual bool isPressed() const { return false; }
    virtual bool isReadOnly() const { return false; }
    virtual bool isUnvisited() const { return false; }
    virtual bool isVisited() const { return false; }
    virtual bool isRequired() const { return false; }
    virtual bool isLinked() const { return false; }
    virtual bool isExpanded() const;
    virtual bool isVisible() const { return true; }
    virtual bool isCollapsed() const { return false; }
    virtual void setIsExpanded(bool) { }

    // In a multi-select list, many items can be selected but only one is active at a time.
    virtual bool isSelectedOptionActive() const { return false; }

    virtual bool hasBoldFont() const { return false; }
    virtual bool hasItalicFont() const { return false; }
    bool hasMisspelling() const;
    virtual bool hasPlainText() const { return false; }
    virtual bool hasSameFont(RenderObject*) const { return false; }
    virtual bool hasSameFontColor(RenderObject*) const { return false; }
    virtual bool hasSameStyle(RenderObject*) const { return false; }
    bool hasStaticText() const { return roleValue() == StaticTextRole; }
    virtual bool hasUnderline() const { return false; }

    virtual bool canSetFocusAttribute() const { return false; }
    virtual bool canSetTextRangeAttributes() const { return false; }
    virtual bool canSetValueAttribute() const { return false; }
    virtual bool canSetNumericValue() const { return false; }
    virtual bool canSetSelectedAttribute() const { return false; }
    virtual bool canSetSelectedChildrenAttribute() const { return false; }
    virtual bool canSetExpandedAttribute() const { return false; }
    
    // A programmatic way to set a name on an AccessibleObject.
    virtual void setAccessibleName(const AtomicString&) { }
    
    virtual Node* node() const { return 0; }
    virtual RenderObject* renderer() const { return 0; }
    virtual bool accessibilityIsIgnored() const  { return true; }

    int blockquoteLevel() const;
    virtual int headingLevel() const { return 0; }
    virtual int tableLevel() const { return 0; }
    virtual AccessibilityButtonState checkboxOrRadioValue() const;
    virtual String valueDescription() const { return String(); }
    virtual float valueForRange() const { return 0.0f; }
    virtual float maxValueForRange() const { return 0.0f; }
    virtual float minValueForRange() const { return 0.0f; }
    virtual float stepValueForRange() const { return 0.0f; }
    virtual AccessibilityObject* selectedRadioButton() { return 0; }
    virtual AccessibilityObject* selectedTabItem() { return 0; }    
    virtual int layoutCount() const { return 0; }
    virtual double estimatedLoadingProgress() const { return 0; }
    static bool isARIAControl(AccessibilityRole);
    static bool isARIAInput(AccessibilityRole);
    virtual bool supportsARIAOwns() const { return false; }
    virtual void ariaOwnsElements(AccessibilityChildrenVector&) const { }
    virtual bool supportsARIAFlowTo() const { return false; }
    virtual void ariaFlowToElements(AccessibilityChildrenVector&) const { }
    virtual bool ariaHasPopup() const { return false; }
    bool ariaIsMultiline() const;
    virtual const AtomicString& invalidStatus() const;
    bool supportsARIAExpanded() const;
    AccessibilitySortDirection sortDirection() const;
    
    // ARIA drag and drop
    virtual bool supportsARIADropping() const { return false; }
    virtual bool supportsARIADragging() const { return false; }
    virtual bool isARIAGrabbed() { return false; }
    virtual void setARIAGrabbed(bool) { }
    virtual void determineARIADropEffects(Vector<String>&) { }
    
    // Called on the root AX object to return the deepest available element.
    virtual AccessibilityObject* accessibilityHitTest(const LayoutPoint&) const { return 0; }
    // Called on the AX object after the render tree determines which is the right AccessibilityRenderObject.
    virtual AccessibilityObject* elementAccessibilityHitTest(const LayoutPoint&) const;

    virtual AccessibilityObject* focusedUIElement() const;

    virtual AccessibilityObject* firstChild() const { return 0; }
    virtual AccessibilityObject* lastChild() const { return 0; }
    virtual AccessibilityObject* previousSibling() const { return 0; }
    virtual AccessibilityObject* nextSibling() const { return 0; }
    virtual AccessibilityObject* parentObject() const = 0;
    virtual AccessibilityObject* parentObjectUnignored() const;
    virtual AccessibilityObject* parentObjectIfExists() const { return 0; }
    static AccessibilityObject* firstAccessibleObjectFromNode(const Node*);
    void findMatchingObjects(AccessibilitySearchCriteria*, AccessibilityChildrenVector&);

    virtual AccessibilityObject* observableObject() const { return 0; }
    virtual void linkedUIElements(AccessibilityChildrenVector&) const { }
    virtual AccessibilityObject* titleUIElement() const { return 0; }
    virtual bool exposesTitleUIElement() const { return true; }
    virtual AccessibilityObject* correspondingLabelForControlElement() const { return 0; }
    virtual AccessibilityObject* correspondingControlForLabelElement() const { return 0; }
    virtual AccessibilityObject* scrollBar(AccessibilityOrientation) { return 0; }
    
    virtual AccessibilityRole ariaRoleAttribute() const { return UnknownRole; }
    virtual bool isPresentationalChildOfAriaRole() const { return false; }
    virtual bool ariaRoleHasPresentationalChildren() const { return false; }

    void setRoleValue(AccessibilityRole role) { m_role = role; }
    virtual AccessibilityRole roleValue() const { return m_role; }
    virtual String ariaLabeledByAttribute() const { return String(); }
    virtual String ariaDescribedByAttribute() const { return String(); }
    virtual String accessibilityDescription() const { return String(); }

    virtual AXObjectCache* axObjectCache() const;
    AXID axObjectID() const { return m_id; }
    void setAXObjectID(AXID axObjectID) { m_id = axObjectID; }
    
    static AccessibilityObject* anchorElementForNode(Node*);
    virtual Element* anchorElement() const { return 0; }
    virtual Element* actionElement() const { return 0; }
    virtual LayoutRect boundingBoxRect() const { return LayoutRect(); }
    virtual LayoutRect elementRect() const = 0;
    virtual LayoutSize size() const { return elementRect().size(); }
    virtual LayoutPoint clickPoint();
    static LayoutRect boundingBoxForQuads(RenderObject*, const Vector<FloatQuad>&);
    
    virtual PlainTextRange selectedTextRange() const { return PlainTextRange(); }
    unsigned selectionStart() const { return selectedTextRange().start; }
    unsigned selectionEnd() const { return selectedTextRange().length; }
    
    virtual KURL url() const { return KURL(); }
    virtual VisibleSelection selection() const { return VisibleSelection(); }
    virtual String stringValue() const { return String(); }
    virtual String title() const { return String(); }
    virtual String helpText() const { return String(); }
    virtual String textUnderElement() const { return String(); }
    virtual String text() const { return String(); }
    virtual int textLength() const { return 0; }
    virtual String selectedText() const { return String(); }
    virtual const AtomicString& accessKey() const { return nullAtom; }
    const String& actionVerb() const;
    virtual Widget* widget() const { return 0; }
    virtual Widget* widgetForAttachmentView() const { return 0; }
    Page* page() const;
    virtual Document* document() const;
    virtual FrameView* topDocumentFrameView() const { return 0; }
    virtual FrameView* documentFrameView() const;
    String language() const;
    virtual unsigned hierarchicalLevel() const { return 0; }
    const AtomicString& placeholderValue() const;
    
    virtual void setFocused(bool) { }
    virtual void setSelectedText(const String&) { }
    virtual void setSelectedTextRange(const PlainTextRange&) { }
    virtual void setValue(const String&) { }
    virtual void setValue(float) { }
    virtual void setSelected(bool) { }
    virtual void setSelectedRows(AccessibilityChildrenVector&) { }
    
    virtual void makeRangeVisible(const PlainTextRange&) { }
    virtual bool press() const;
    bool performDefaultAction() const { return press(); }
    
    virtual AccessibilityOrientation orientation() const;
    virtual void increment() { }
    virtual void decrement() { }

    virtual void childrenChanged() { }
    virtual void contentChanged() { }
    const AccessibilityChildrenVector& children();
    virtual void addChildren() { }
    virtual bool canHaveChildren() const { return true; }
    virtual bool hasChildren() const { return m_haveChildren; }
    virtual void updateChildrenIfNecessary();
    virtual void setNeedsToUpdateChildren() { }
    virtual void clearChildren();
    virtual void detachFromParent() { }

    virtual void selectedChildren(AccessibilityChildrenVector&) { }
    virtual void visibleChildren(AccessibilityChildrenVector&) { }
    virtual void tabChildren(AccessibilityChildrenVector&) { }
    virtual bool shouldFocusActiveDescendant() const { return false; }
    virtual AccessibilityObject* activeDescendant() const { return 0; }    
    virtual void handleActiveDescendantChanged() { }
    virtual void handleAriaExpandedChanged() { }
    bool isDescendantOfObject(const AccessibilityObject*) const;
    bool isAncestorOfObject(const AccessibilityObject*) const;
    
    static AccessibilityRole ariaRoleToWebCoreRole(const String&);
    const AtomicString& getAttribute(const QualifiedName&) const;

    virtual VisiblePositionRange visiblePositionRange() const { return VisiblePositionRange(); }
    virtual VisiblePositionRange visiblePositionRangeForLine(unsigned) const { return VisiblePositionRange(); }
    
    VisiblePositionRange visiblePositionRangeForUnorderedPositions(const VisiblePosition&, const VisiblePosition&) const;
    VisiblePositionRange positionOfLeftWord(const VisiblePosition&) const;
    VisiblePositionRange positionOfRightWord(const VisiblePosition&) const;
    VisiblePositionRange leftLineVisiblePositionRange(const VisiblePosition&) const;
    VisiblePositionRange rightLineVisiblePositionRange(const VisiblePosition&) const;
    VisiblePositionRange sentenceForPosition(const VisiblePosition&) const;
    VisiblePositionRange paragraphForPosition(const VisiblePosition&) const;
    VisiblePositionRange styleRangeForPosition(const VisiblePosition&) const;
    VisiblePositionRange visiblePositionRangeForRange(const PlainTextRange&) const;

    String stringForVisiblePositionRange(const VisiblePositionRange&) const;
    virtual LayoutRect boundsForVisiblePositionRange(const VisiblePositionRange&) const { return LayoutRect(); }
    int lengthForVisiblePositionRange(const VisiblePositionRange&) const;
    virtual void setSelectedVisiblePositionRange(const VisiblePositionRange&) const { }

    virtual VisiblePosition visiblePositionForPoint(const IntPoint&) const { return VisiblePosition(); }
    VisiblePosition nextVisiblePosition(const VisiblePosition& visiblePos) const { return visiblePos.next(); }
    VisiblePosition previousVisiblePosition(const VisiblePosition& visiblePos) const { return visiblePos.previous(); }
    VisiblePosition nextWordEnd(const VisiblePosition&) const;
    VisiblePosition previousWordStart(const VisiblePosition&) const;
    VisiblePosition nextLineEndPosition(const VisiblePosition&) const;
    VisiblePosition previousLineStartPosition(const VisiblePosition&) const;
    VisiblePosition nextSentenceEndPosition(const VisiblePosition&) const;
    VisiblePosition previousSentenceStartPosition(const VisiblePosition&) const;
    VisiblePosition nextParagraphEndPosition(const VisiblePosition&) const;
    VisiblePosition previousParagraphStartPosition(const VisiblePosition&) const;
    virtual VisiblePosition visiblePositionForIndex(unsigned, bool /*lastIndexOK */) const { return VisiblePosition(); }
    
    virtual VisiblePosition visiblePositionForIndex(int) const { return VisiblePosition(); }
    virtual int indexForVisiblePosition(const VisiblePosition&) const { return 0; }

    AccessibilityObject* accessibilityObjectForPosition(const VisiblePosition&) const;
    int lineForPosition(const VisiblePosition&) const;
    PlainTextRange plainTextRangeForVisiblePositionRange(const VisiblePositionRange&) const;
    virtual int index(const VisiblePosition&) const { return -1; }

    virtual PlainTextRange doAXRangeForLine(unsigned) const { return PlainTextRange(); }
    PlainTextRange doAXRangeForPosition(const IntPoint&) const;
    virtual PlainTextRange doAXRangeForIndex(unsigned) const { return PlainTextRange(); }
    PlainTextRange doAXStyleRangeForIndex(unsigned) const;

    virtual String doAXStringForRange(const PlainTextRange&) const { return String(); }
    virtual LayoutRect doAXBoundsForRange(const PlainTextRange&) const { return LayoutRect(); }
    String listMarkerTextForNodeAndPosition(Node*, const VisiblePosition&) const;

    unsigned doAXLineForIndex(unsigned);

    virtual String stringValueForMSAA() const { return String(); }
    virtual String stringRoleForMSAA() const { return String(); }
    virtual String nameForMSAA() const { return String(); }
    virtual String descriptionForMSAA() const { return String(); }
    virtual AccessibilityRole roleValueForMSAA() const { return roleValue(); }

    // Used by an ARIA tree to get all its rows.
    void ariaTreeRows(AccessibilityChildrenVector&);
    // Used by an ARIA tree item to get all of its direct rows that it can disclose.
    void ariaTreeItemDisclosedRows(AccessibilityChildrenVector&);
    // Used by an ARIA tree item to get only its content, and not its child tree items and groups. 
    void ariaTreeItemContent(AccessibilityChildrenVector&);
    
    // ARIA live-region features.
    bool supportsARIALiveRegion() const;
    bool isInsideARIALiveRegion() const;
    virtual const AtomicString& ariaLiveRegionStatus() const { return nullAtom; }
    virtual const AtomicString& ariaLiveRegionRelevant() const { return nullAtom; }
    virtual bool ariaLiveRegionAtomic() const { return false; }
    virtual bool ariaLiveRegionBusy() const { return false; }
    
    bool supportsARIAAttributes() const;
    
    // CSS3 Speech properties.
    virtual ESpeak speakProperty() const { return SpeakNormal; }

    // Make this object visible by scrolling as many nested scrollable views as needed.
    virtual void scrollToMakeVisible() const;
    // Same, but if the whole object can't be made visible, try for this subrect, in local coordinates.
    virtual void scrollToMakeVisibleWithSubFocus(const IntRect&) const;
    // Scroll this object to a given point in global coordinates of the top-level window.
    virtual void scrollToGlobalPoint(const IntPoint&) const;

#if HAVE(ACCESSIBILITY)
#if PLATFORM(GTK)
    AccessibilityObjectWrapper* wrapper() const;
    void setWrapper(AccessibilityObjectWrapper*);
#else
    AccessibilityObjectWrapper* wrapper() const { return m_wrapper.get(); }
    void setWrapper(AccessibilityObjectWrapper* wrapper) 
    {
        m_wrapper = wrapper;
    }
#endif
#endif

#if HAVE(ACCESSIBILITY)
    // a platform-specific method for determining if an attachment is ignored
    bool accessibilityIgnoreAttachment() const;
    // gives platforms the opportunity to indicate if and how an object should be included
    AccessibilityObjectInclusion accessibilityPlatformIncludesObject() const;
#else
    bool accessibilityIgnoreAttachment() const { return true; }
    AccessibilityObjectInclusion accessibilityPlatformIncludesObject() const { return DefaultBehavior; }
#endif

    // allows for an AccessibilityObject to update its render tree or perform
    // other operations update type operations
    void updateBackingStore();
    
protected:
    AXID m_id;
    AccessibilityChildrenVector m_children;
    mutable bool m_haveChildren;
    AccessibilityRole m_role;
    
    // If this object itself scrolls, return its ScrollableArea.
    virtual ScrollableArea* getScrollableAreaIfScrollable() const { return 0; }
    virtual void scrollTo(const IntPoint&) const { }

    virtual bool isDetached() const { return true; }
    static bool isAccessibilityObjectSearchMatch(AccessibilityObject*, AccessibilitySearchCriteria*);
    static bool isAccessibilityTextSearchMatch(AccessibilityObject*, AccessibilitySearchCriteria*);
    static bool objectMatchesSearchCriteriaWithResultLimit(AccessibilityObject*, AccessibilitySearchCriteria*, AccessibilityChildrenVector&);
    
#if PLATFORM(GTK)
    bool allowsTextRanges() const;
    unsigned getLengthForTextRange() const;
#else
    bool allowsTextRanges() const { return isTextControl(); }
    unsigned getLengthForTextRange() const { return text().length(); }
#endif

#if PLATFORM(MAC)
    RetainPtr<WebAccessibilityObjectWrapper> m_wrapper;
#elif PLATFORM(WIN) && !OS(WINCE)
    COMPtr<AccessibilityObjectWrapper> m_wrapper;
#elif PLATFORM(GTK)
    AtkObject* m_wrapper;
#elif PLATFORM(CHROMIUM)
    RefPtr<AccessibilityObjectWrapper> m_wrapper;
#endif
};

} // namespace WebCore

#endif // AccessibilityObject_h
