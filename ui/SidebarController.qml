import QtQuick

Item {
  id: root

  required property var panel
  required property var listView
  readonly property var service: panel.service
  property string followedActiveThreadId: ""
  property string activationIntentThreadId: ""
  readonly property alias actions: actionApi
  readonly property alias navigation: navigationApi

  SidebarActionController {
    id: actionApi
    controller: root
  }

  SidebarNavigationController {
    id: navigationApi
    controller: root
  }
}
