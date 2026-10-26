pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.components.containers
import qs.components.controls
import qs.components.effects
import qs.services

StyledWindow {
    id: root

    // The session lock owns WlrKeyboardFocus while it is up; queue prompts in
    // the service and only draw them once the lock releases.
    required property bool sessionLocked

    readonly property var prompt: KeyringPrompter.prompt
    readonly property bool active: KeyringPrompter.hasPrompt && KeyringPrompter.ready && !root.sessionLocked
    readonly property bool passwordPrompt: root.prompt.type === "password"
    readonly property bool passwordNew: root.prompt.passwordNew ?? false
    readonly property string choiceLabel: root.prompt.choiceLabel ?? ""

    property bool showPassword: false
    property bool choiceChosen: false

    function resetFields(): void {
        root.showPassword = false;
        root.choiceChosen = root.prompt.choiceChosen ?? false;
        choiceSwitch.checked = root.choiceChosen;
        passwordField.text = "";
        confirmField.text = "";
        confirmField.isError = false;
        confirmField.errorText = "";
    }

    function focusPrompt(): void {
        Qt.callLater(() => {
            if (!root.active)
                return;
            if (root.passwordPrompt)
                passwordField.forceActiveFocus();
            else
                continueButton.forceActiveFocus();
        });
    }

    function submit(): void {
        if (!root.active)
            return;

        if (root.passwordPrompt && root.passwordNew && passwordField.text !== confirmField.text) {
            confirmField.isError = true;
            confirmField.errorText = Tr.tr("Passwords do not match");
            confirmField.forceActiveFocus();
            return;
        }

        KeyringPrompter.respond(root.prompt.id, root.passwordPrompt ? passwordField.text : "", root.choiceChosen);
        root.resetFields();
    }

    function cancel(): void {
        if (root.active)
            KeyringPrompter.cancel(root.prompt.id);
    }

    name: "keyring"
    screen: Quickshell.screens.find(s => s.name === Compositor.focusedMonitorName) ?? Quickshell.screens[0]
    visible: root.active
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    Component.onCompleted: {
        root.resetFields();
        KeyringPrompter.ready = true;
    }
    Component.onDestruction: KeyringPrompter.ready = false

    onActiveChanged: {
        if (root.active) {
            root.resetFields();
            root.focusPrompt();
        }
    }

    Connections {
        function onPromptChanged(): void {
            root.resetFields();
            root.focusPrompt();
        }

        target: KeyringPrompter
    }

    MouseArea {
        anchors.fill: parent
    }

    StyledRect {
        anchors.fill: parent
        color: Colours.palette.m3scrim
        opacity: 0.5
    }

    StyledRect {
        anchors.centerIn: parent
        implicitWidth: Math.min(parent.width - Tokens.padding.extraLarge * 2, 460)
        implicitHeight: content.implicitHeight + Tokens.padding.extraLarge * 2
        width: implicitWidth
        height: implicitHeight
        radius: Tokens.rounding.extraLarge
        color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 1)
        opacity: root.active ? 1 : 0
        scale: root.active ? 1 : 0.95

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
        Behavior on scale {
            Anim {
                type: Anim.Emphasized
            }
        }

        Elevation {
            anchors.fill: parent
            radius: parent.radius
            z: -1
            level: 3
        }

        MouseArea {
            anchors.fill: parent
        }

        FocusScope {
            anchors.fill: parent
            focus: root.active

            Keys.onEscapePressed: root.cancel()

            ColumnLayout {
                id: content

                anchors.fill: parent
                anchors.margins: Tokens.padding.extraLarge
                spacing: Tokens.spacing.medium

                RowLayout {
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        Layout.alignment: Qt.AlignVCenter
                        text: root.passwordNew ? "key" : "lock"
                        color: Colours.palette.m3primary
                        fontStyle: Tokens.font.icon.large
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.extraSmall

                        StyledText {
                            Layout.fillWidth: true
                            text: root.prompt.title || (root.passwordNew ? Tr.tr("Set keyring password") : Tr.tr("Authentication Required"))
                            font: Tokens.font.body.large
                            wrapMode: Text.Wrap
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: (root.prompt.message ?? "").length > 0
                            text: root.prompt.message ?? ""
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.body.small
                            wrapMode: Text.Wrap
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: (root.prompt.description ?? "").length > 0
                            text: root.prompt.description ?? ""
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.body.small
                            wrapMode: Text.Wrap
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: (root.prompt.warning ?? "").length > 0
                    text: root.prompt.warning ?? ""
                    color: Colours.palette.m3error
                    font: Tokens.font.body.small
                    wrapMode: Text.Wrap
                }

                StyledTextField {
                    id: passwordField

                    Layout.fillWidth: true
                    visible: root.passwordPrompt
                    type: StyledTextField.Filled
                    placeholderText: root.passwordNew ? Tr.tr("New password") : Tr.tr("Password")
                    echoMode: root.showPassword ? TextInput.Normal : TextInput.Password
                    leadingIcon: "key"
                    trailingIconButton: root.showPassword ? "visibility_off" : "visibility"
                    onTrailingIconClicked: root.showPassword = !root.showPassword
                    onAccepted: {
                        if (root.passwordNew)
                            confirmField.forceActiveFocus();
                        else
                            root.submit();
                    }
                    Keys.onEscapePressed: root.cancel()
                }

                StyledTextField {
                    id: confirmField

                    Layout.fillWidth: true
                    visible: root.passwordPrompt && root.passwordNew
                    type: StyledTextField.Filled
                    placeholderText: Tr.tr("Confirm new password")
                    echoMode: root.showPassword ? TextInput.Normal : TextInput.Password
                    leadingIcon: "key"
                    onAccepted: root.submit()
                    Keys.onEscapePressed: root.cancel()
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: root.choiceLabel.length > 0
                    spacing: Tokens.spacing.small

                    StyledSwitch {
                        id: choiceSwitch

                        onToggled: root.choiceChosen = checked
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.choiceLabel
                        font: Tokens.font.body.small
                        wrapMode: Text.Wrap
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    Layout.topMargin: Tokens.spacing.small
                    spacing: Tokens.spacing.medium

                    TextButton {
                        text: root.prompt.cancelLabel || Tr.trCtx("Cancel", "button")
                        type: TextButton.Text
                        onClicked: root.cancel()
                        Keys.onEscapePressed: root.cancel()
                    }

                    TextButton {
                        id: continueButton

                        text: root.prompt.continueLabel || (root.prompt.type === "confirm" ? Tr.trCtx("Continue", "button") : (root.passwordNew ? Tr.tr("Save") : Tr.tr("Unlock")))
                        type: TextButton.Filled
                        onClicked: root.submit()
                        Keys.onReturnPressed: root.submit()
                        Keys.onSpacePressed: root.submit()
                        Keys.onEscapePressed: root.cancel()
                    }
                }
            }
        }
    }
}