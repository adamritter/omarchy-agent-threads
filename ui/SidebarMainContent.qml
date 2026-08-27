import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui

Column {
  id: root
  required property var panel
  property alias providerMenu: header.providerMenu
  property alias renameField: renameInput
  property alias searchField: searchInput
  property alias threadList: body.threadList
  property alias modelEffortSelector: body.modelEffortSelector
  spacing: Style.space(8)

  SidebarHeader {
    id: header
    width: parent.width
    height: Style.space(36)
    panel: root.panel
  }

  Text {
    id: statusLabel
    width: parent.width
    height: Style.space(18)
    text: panel.providerActions.statusText()
    color: panel.providerActions.providerErrorText() !== ""
      ? Color.urgent : panel.appearance.dim
    font.family: panel.appearance.fontFamily
    font.pixelSize: Style.font.caption
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
  }
  
  TextField {
    id: renameInput
    visible: panel.session.renameOpen
    width: parent.width
    height: Style.space(34)
    placeholderText: "Thread name…"
    maximumLength: 200
    foreground: panel.appearance.foreground
    accent: Color.accent
    font.family: panel.appearance.fontFamily
    font.pixelSize: Style.font.body
    verticalPadding: Style.space(5)
    selectByMouse: true
    onActiveFocusChanged: if (activeFocus) panel.session.keyboardFocusRequested = true
  
    Keys.priority: Keys.BeforeItem
    Keys.onPressed: function(event) {
      if (event.key === Qt.Key_Escape) {
        panel.overlayActions.cancelRename()
        event.accepted = true
      } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
        panel.overlayActions.submitRename()
        event.accepted = true
      } else if (event.key === Qt.Key_U && (event.modifiers & Qt.ControlModifier)) {
        text = ""
        event.accepted = true
      }
    }
  }
  
  TextField {
    id: searchInput
    visible: panel.session.searchOpen || panel.session.searchText !== ""
    width: parent.width
    height: Style.space(34)
    text: panel.session.searchText
    placeholderText: "Search threads and projects…"
    foreground: panel.appearance.foreground
    accent: Color.accent
    font.family: panel.appearance.fontFamily
    font.pixelSize: Style.font.body
    verticalPadding: Style.space(5)
    rightPadding: Style.space(30)
    selectByMouse: true
    onTextEdited: panel.overlayActions.setSearchText(text)
    onActiveFocusChanged: if (activeFocus) panel.session.keyboardFocusRequested = true
  
    Keys.priority: Keys.BeforeItem
    Keys.onPressed: function(event) {
      if (event.key === Qt.Key_Escape) {
        panel.overlayActions.cancelSearch()
        event.accepted = true
      } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Up) {
        panel.overlayActions.leaveSearch()
        if (panel.viewRows.length > 0) {
          var direction = event.key === Qt.Key_Down ? 1 : -1
          panel.selectedIndex = Math.max(0, Math.min(panel.viewRows.length - 1,
                                                     panel.selectedIndex + direction))
          root.threadList.positionViewAtIndex(panel.selectedIndex, ListView.Contain)
        }
        event.accepted = true
      } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
        panel.overlayActions.leaveSearch()
        event.accepted = true
      } else if (event.key === Qt.Key_U && (event.modifiers & Qt.ControlModifier)) {
        panel.overlayActions.setSearchText("")
        event.accepted = true
      }
    }
  
    TapHandler {
      onTapped: {
        panel.session.keyboardFocusRequested = true
        Qt.callLater(panel.startSearch)
      }
    }
  
    Text {
      anchors.right: parent.right
      anchors.rightMargin: Style.space(9)
      anchors.verticalCenter: parent.verticalCenter
      visible: panel.session.searchText !== ""
      text: "×"
      color: clearSearchMouse.containsMouse ? Color.accent : panel.appearance.dim
      font.family: panel.appearance.fontFamily
      font.pixelSize: Style.font.body
  
      MouseArea {
        id: clearSearchMouse
        anchors.fill: parent
        anchors.margins: -Style.space(7)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          panel.overlayActions.setSearchText("")
          panel.overlayActions.startSearch()
        }
      }
    }
  }
  
  PanelSeparator { width: parent.width }
  

  SidebarBody {
    id: body
    width: parent.width
    height: Math.max(0, parent.height - y)
    panel: root.panel
  }
}
