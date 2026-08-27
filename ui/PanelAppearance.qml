import QtQuick
import qs.Commons
import qs.Ui

QtObject {
  required property var bar
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Util.alpha(foreground, 0.58)
  readonly property color faint: Util.alpha(foreground, 0.10)
  readonly property color focusedSelectionFill: Style.selectedFillFor(
    foreground, Color.accent)
  readonly property color unfocusedSelectionFill: Util.alpha(
    focusedSelectionFill, focusedSelectionFill.a * 0.5)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property int sidebarContentWidth: Style.space(380)
  readonly property int sidebarBarGap: Style.gapsOut
  readonly property color readyThreadColor: "#98c379"
}
