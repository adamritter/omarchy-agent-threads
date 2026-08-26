import QtQuick
import QtWebEngine

Item {
  id: root

  required property var messages
  property bool busy: false
  property string conversationTitle: "New conversation"
  property string conversationDetail: ""
  property bool pageReady: false
  readonly property url transcriptUrl: Qt.resolvedUrl("web/transcript.html")

  function scheduleSync() {
    syncTimer.restart()
  }

  function syncState() {
    if (!pageReady) return
    var state = {
      messages: Array.isArray(messages) ? messages : [],
      busy: busy,
      header: {
        title: conversationTitle,
        detail: conversationDetail
      }
    }
    webView.runJavaScript(
      "window.AgentChat && window.AgentChat.setState(" + JSON.stringify(state) + ")")
  }

  function scrollPage(direction) {
    if (!pageReady) return
    webView.runJavaScript(
      "window.AgentChat && window.AgentChat.scrollPage("
        + (Number(direction) < 0 ? "-1" : "1") + ")")
  }

  function scrollEdge(edge) {
    if (!pageReady) return
    webView.runJavaScript(
      "window.AgentChat && window.AgentChat.scrollEdge("
        + (Number(edge) < 0 ? "-1" : "1") + ")")
  }

  WebEngineProfile {
    id: transcriptProfile
    offTheRecord: true
  }

  WebEngineView {
    id: webView
    anchors.fill: parent
    profile: transcriptProfile
    url: root.transcriptUrl
    backgroundColor: "#171717"
    activeFocusOnPress: true

    settings.javascriptEnabled: true
    settings.javascriptCanOpenWindows: false
    settings.javascriptCanAccessClipboard: false
    settings.localStorageEnabled: true
    settings.localContentCanAccessRemoteUrls: false
    settings.localContentCanAccessFileUrls: true
    settings.errorPageEnabled: false
    settings.pluginsEnabled: false
    settings.fullScreenSupportEnabled: false
    settings.webGLEnabled: false
    settings.pdfViewerEnabled: false

    onLoadingChanged: function(loadingInfo) {
      if (loadingInfo.status === WebEngineView.LoadSucceededStatus) {
        root.pageReady = true
        root.scheduleSync()
      } else if (loadingInfo.status === WebEngineView.LoadFailedStatus) {
        root.pageReady = false
        console.warn("Agent Chat transcript failed to load:", loadingInfo.errorString)
      }
    }

    onNavigationRequested: function(request) {
      if (request.navigationType !== WebEngineNavigationRequest.LinkClickedNavigation) return
      request.reject()
      var target = String(request.url || "")
      if (/^(https?:|mailto:)/i.test(target)) Qt.openUrlExternally(request.url)
    }

    onRenderProcessTerminated: function(terminationStatus, exitCode) {
      root.pageReady = false
      console.warn("Agent Chat transcript renderer stopped:", terminationStatus, exitCode)
      reloadTimer.restart()
    }
  }

  Timer {
    id: syncTimer
    interval: 45
    repeat: false
    onTriggered: root.syncState()
  }

  Timer {
    id: reloadTimer
    interval: 750
    repeat: false
    onTriggered: webView.reload()
  }

  onMessagesChanged: scheduleSync()
  onBusyChanged: scheduleSync()
  onConversationTitleChanged: scheduleSync()
  onConversationDetailChanged: scheduleSync()
  Component.onCompleted: scheduleSync()
}
