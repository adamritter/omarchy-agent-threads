// Purpose: Verifies chatcomposer behavior with Qt Quick Test.
import QtQuick
import QtQuick.Layouts
import "../ui" as App

ChatComponentTestBase {
  name: "ChatComposer"

  App.ChatComposer {
    id: composer
    width: parent.width
    height: 260
    window: windowApi
    client: clientApi
  }

  function init() {
    resetFakes()
    composer.text = ""
    wait(0)
  }

  function test_boundsPromptInputThroughTheProductionEditor() {
    var editor = findChild(composer, "chatEditor")
    verify(editor !== null)
    composer.text = new Array(200002).join("x")
    compare(composer.text.length, 200000)
  }

  function test_availabilityTracksClientLifecycle() {
    var editor = findChild(composer, "chatEditor")
    verify(editor.enabled)
    clientApi.loading = true
    tryCompare(editor, "enabled", false)
    clientApi.loading = false
    clientApi.ready = false
    tryCompare(editor, "enabled", false)
  }

  function test_returnSendsWhileShiftReturnKeepsEditing() {
    var editor = findChild(composer, "chatEditor")
    editor.forceActiveFocus()
    verify(editor.activeFocus)
    composer.text = "hello"
    keyClick(Qt.Key_Return)
    compare(sendComposerCount, 1)
    keyClick(Qt.Key_Return, Qt.ShiftModifier)
    compare(sendComposerCount, 1)
  }

  function test_composerOwnsToolbarAndAdaptsItsHeight() {
    var frame = findChild(composer, "chatComposerFrame")
    var toolbar = findChild(composer, "chatComposerToolbar")
    verify(frame !== null)
    verify(toolbar !== null)
    verify(frame.height >= 88)
    verify(frame.height <= 204)
    compare(composer.Layout.preferredHeight, frame.height + 28)
  }
}
