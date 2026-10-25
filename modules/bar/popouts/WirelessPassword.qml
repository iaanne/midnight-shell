pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils

ColumnLayout {
    id: root

    required property PopoutState popouts
    property var network: null
    property bool isClosing: false

    readonly property bool shouldBeVisible: root.popouts.currentName === "wirelesspassword"

    property bool _isSidebarOpen: popouts.sidebarOpen && popouts.isHorizontal && popouts.currentSection === "end"

    // Protection advertised by the network being joined, used to seed the
    // security selector and to decide which credential fields to show.
    readonly property string detectedSecurity: Nmcli.securityKind(root.network ? root.network.security : "")
    // Effective protection: what the user picked, else what the network
    // advertised. Mirrors Nmcli.securityKind*.
    readonly property string securityKind: securitySelect.active ? securitySelect.active.value : root.detectedSecurity
    readonly property bool isOpen: securityKind === Nmcli.securityKindOpen
    readonly property bool isEnterprise: securityKind === Nmcli.securityKindEnterprise
    readonly property bool isWep: securityKind === Nmcli.securityKindWep
    readonly property bool needsConfig: isEnterprise || isWep || isOpen
    readonly property string eapMethod: eapSelect.active ? eapSelect.active.value : "peap"
    readonly property string phase2Method: phase2Select.active ? phase2Select.active.value : "mschapv2"
    // Open networks need no secret; enterprise also needs a username.
    readonly property bool canConnect: root.isOpen ? true : (root.isEnterprise ? identityField.text.trim().length > 0 : true) && passwordContainer.passwordBuffer.length > 0

    function checkConnectionStatus(): void {
        if (!root.shouldBeVisible || !connectButton.connecting) {
            return;
        }

        // Check if we're connected to the target network (case-insensitive SSID comparison)
        const isConnected = root.network && Nmcli.active && Nmcli.active.ssid && Nmcli.active.ssid.toLowerCase().trim() === root.network.ssid.toLowerCase().trim();

        if (isConnected) {
            // Successfully connected - give it a moment for network list to update
            // Use Timer for actual delay
            connectionSuccessTimer.start();
            return;
        }

        // Check for connection failures - if pending connection was cleared but we're not connected
        if (Nmcli.pendingConnection === null && connectButton.connecting) {
            // Wait a bit more before giving up (allow time for connection to establish)
            if (connectionMonitor.repeatCount > 10) {
                connectionMonitor.stop();
                connectButton.connecting = false;
                connectButton.hasError = true;
                connectButton.enabled = true;
                connectButton.text = Tr.tr("Connect");
                passwordContainer.passwordBuffer = "";
                // Delete the failed connection
                if (root.network && root.network.ssid) {
                    Nmcli.forgetNetwork(root.network.ssid);
                }
            }
        }
    }

    function closeDialog(): void {
        if (isClosing) {
            return;
        }

        isClosing = true;
        passwordContainer.passwordBuffer = "";
        identityField.text = "";
        anonIdentityField.text = "";
        caCertField.text = "";
        connectButton.connecting = false;
        connectButton.hasError = false;
        connectButton.text = Tr.tr("Connect");
        connectionMonitor.stop();

        // Return to network popout
        if (root.popouts.currentName === "wirelesspassword") {
            root.popouts.currentName = "network";
        }

        // Clear the closing flag once the exit animation has played, so a quick
        // reopen starts from a fully expanded card.
        closeTimer.restart();
    }

    // Matches the security selector to the network's advertised protection,
    // dropping any manual override from a previously selected network.
    function syncSecuritySelection(): void {
        if (!securitySelect)
            return;

        // Until the network is known, assume Personal so the credential field
        // stays put rather than the card collapsing to the open layout.
        const kind = root.network ? root.detectedSecurity : Nmcli.securityKindPsk;
        if (kind === Nmcli.securityKindSae)
            securitySelect.active = saeItem;
        else if (kind === Nmcli.securityKindEnterprise)
            securitySelect.active = enterpriseItem;
        else if (kind === Nmcli.securityKindWep)
            securitySelect.active = wepItem;
        else if (kind === Nmcli.securityKindOpen)
            securitySelect.active = openItem;
        else
            securitySelect.active = pskItem;
    }

    // Shared handler for a connection attempt result. Success is resolved by the
    // connection monitor; failures reset the dialog and drop the profile.
    function handleResult(result): void {
        if (result && result.success) {
            // Connection successful, monitor will handle the rest
            return;
        }

        connectionMonitor.stop();
        connectButton.connecting = false;
        connectButton.hasError = true;
        connectButton.enabled = true;
        connectButton.text = Tr.tr("Connect");
        passwordContainer.passwordBuffer = "";
        // Delete the failed connection
        if (root.network && root.network.ssid) {
            Nmcli.forgetNetwork(root.network.ssid);
        }
    }

    spacing: Tokens.spacing.medium
    implicitWidth: Math.max(400, _isSidebarOpen ? Tokens.sizes.sidebar.width - Tokens.padding.extraLargeIncreased : 0)
    implicitHeight: content.implicitHeight + Tokens.padding.extraLargeIncreased
    visible: shouldBeVisible || isClosing
    enabled: shouldBeVisible && !isClosing
    focus: enabled

    Component.onCompleted: {
        if (shouldBeVisible) {
            // Use Timer for actual delay to ensure dialog is fully rendered
            focusTimer.start();
        }
        root.syncSecuritySelection();
    }

    onShouldBeVisibleChanged: {
        if (shouldBeVisible) {
            // A previous close may still be holding the card collapsed; clear it
            // so it always opens fully expanded.
            isClosing = false;
            // Use Timer for actual delay to ensure dialog is fully rendered
            focusTimer.start();
        }
    }

    onNetworkChanged: root.syncSecuritySelection()

    Keys.onEscapePressed: closeDialog()

    Connections {
        function onCurrentNameChanged() {
            if (root.popouts.currentName === "wirelesspassword") {
                // Update network when popout becomes active
                Qt.callLater(() => {
                    // Try to get network from parent Content's networkPopout
                    const content = root.parent?.parent?.parent;
                    if (content) {
                        const networkPopout = content.children.find(c => c.name === "network");
                        if (networkPopout && networkPopout.item) {
                            root.network = networkPopout.item.passwordNetwork;
                        }
                    }
                    // Force focus to password container when popout becomes active
                    // Use Timer for actual delay to ensure dialog is fully rendered
                    focusTimer.start();
                });
            }
        }

        target: root.popouts
    }

    Timer {
        id: focusTimer

        interval: 150
        onTriggered: {
            root.forceActiveFocus();
            root.syncSecuritySelection();
            if (root.isOpen)
                connectButton.forceActiveFocus();
            else if (root.isEnterprise)
                identityField.forceActiveFocus();
            else
                passwordContainer.forceActiveFocus();
        }
    }

    StyledRect {
        Layout.fillWidth: true
        Layout.preferredWidth: 400
        implicitHeight: content.implicitHeight + Tokens.padding.extraLargeIncreased
        radius: Tokens.rounding.large
        color: Colours.tPalette.m3surfaceContainer
        visible: root.shouldBeVisible || root.isClosing
        opacity: root.shouldBeVisible ? 1 : 0
        scale: root.shouldBeVisible ? 1 : 0.7
        Keys.onEscapePressed: root.closeDialog()

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Behavior on scale {
            Anim {}
        }

        ColumnLayout {
            id: content

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Tokens.padding.large

            spacing: Tokens.spacing.medium

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: "lock"
                fontStyle: Tokens.font.icon.builders.extraLarge.scale(2).build()
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: {
                    if (root.isOpen)
                        return Tr.tr("Connect to network");
                    if (root.isEnterprise)
                        return Tr.tr("Sign in");
                    if (root.isWep)
                        return Tr.tr("Enter network key");
                    return Tr.tr("Enter password");
                }
                font: Tokens.font.body.builders.large.weight(Font.Medium).build()
            }

            StyledText {
                id: networkNameText

                Layout.alignment: Qt.AlignHCenter
                text: {
                    if (root.network) {
                        const ssid = root.network.ssid;
                        if (ssid && ssid.length > 0) {
                            // TRANSLATORS: %1 = the network SSID
                            return Tr.tr("Network: %1").arg(ssid);
                        }
                    }
                    return Tr.tr("Unknown network");
                }
                color: Colours.palette.m3outline
                font: Tokens.font.body.small
            }

            // Always-available protection type. Seeds from the network's
            // advertised security but lets the user override it.
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.small
                spacing: Tokens.spacing.medium

                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("Security")
                }

                SplitButton {
                    id: securitySelect

                    type: SplitButton.Tonal
                    fallbackText: Tr.tr("WPA/WPA2/WPA3 Personal")
                    fallbackIcon: "lock"
                    stateLayer.onClicked: securitySelect.expanded = !securitySelect.expanded

                    menuItems: [
                        MenuItem {
                            id: pskItem

                            icon: "lock"
                            text: Tr.tr("WPA/WPA2/WPA3 Personal")
                            value: Nmcli.securityKindPsk
                        },
                        MenuItem {
                            id: saeItem

                            icon: "lock"
                            text: Tr.tr("WPA3 Personal (SAE)")
                            value: Nmcli.securityKindSae
                        },
                        MenuItem {
                            id: enterpriseItem

                            icon: "apartment"
                            text: Tr.tr("WPA/WPA2/WPA3 Enterprise")
                            value: Nmcli.securityKindEnterprise
                        },
                        MenuItem {
                            id: wepItem

                            icon: "lock"
                            text: "WEP"
                            value: Nmcli.securityKindWep
                        },
                        MenuItem {
                            id: openItem

                            icon: "lock_open"
                            text: Tr.trCtx("None (open)", "wifi security type")
                            value: Nmcli.securityKindOpen
                        }
                    ]
                }
            }

            Timer {
                property int attempts: 0

                interval: 50
                running: root.shouldBeVisible && (!root.network || !root.network.ssid)
                repeat: true
                onTriggered: {
                    attempts++;
                    // Keep trying to get network from Network component
                    const content = root.parent?.parent?.parent;
                    if (content) {
                        const networkPopout = content.children.find(c => c.name === "network");
                        if (networkPopout && networkPopout.item && networkPopout.item.passwordNetwork) {
                            root.network = networkPopout.item.passwordNetwork;
                        }
                    }
                    // Stop if we got it or after 20 attempts (1 second)
                    if ((root.network && root.network.ssid) || attempts >= 20) {
                        stop();
                        attempts = 0;
                    }
                }
                onRunningChanged: {
                    if (!running) {
                        attempts = 0;
                    }
                }
            }

            StyledText {
                id: statusText

                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Tokens.spacing.small
                visible: connectButton.connecting || connectButton.hasError
                text: {
                    if (connectButton.hasError) {
                        return Tr.tr("Connection failed. Please check your credentials and try again.");
                    }
                    if (connectButton.connecting) {
                        return Tr.tr("Connecting...");
                    }
                    return "";
                }
                color: connectButton.hasError ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.builders.small.weight(Font.Normal).build()
                wrapMode: Text.WordWrap
                Layout.maximumWidth: parent.width - Tokens.padding.extraLargeIncreased
            }

            // Enterprise (802.1X) username. Shown above the secret so the
            // standard key-capture surface below keeps its prominent position.
            StyledTextField {
                id: identityField

                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.largeIncreased
                visible: root.isEnterprise
                placeholderText: Tr.tr("Username")
                leadingIcon: "person"
                inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText

                onAccepted: passwordContainer.forceActiveFocus()
            }

            FocusScope {
                id: passwordContainer

                property string passwordBuffer: ""

                objectName: "passwordContainer"
                Layout.topMargin: Tokens.spacing.largeIncreased
                Layout.fillWidth: true
                visible: !root.isOpen
                implicitHeight: Math.max(48, charList.implicitHeight + Tokens.padding.medium * 2)
                focus: true
                activeFocusOnTab: true

                Component.onCompleted: {
                    if (root.shouldBeVisible) {
                        // Use Timer for actual delay to ensure focus works correctly
                        passwordFocusTimer.start();
                    }
                }

                Keys.onPressed: event => {
                    // Ensure we have focus when receiving keyboard input
                    if (!activeFocus) {
                        forceActiveFocus();
                    }

                    if (event.key === Qt.Key_Escape) {
                        event.accepted = false;
                        closeDialog();
                    }

                    // Clear error when user starts typing
                    if (connectButton.hasError && event.text && event.text.length > 0) {
                        connectButton.hasError = false;
                    }

                    if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                        if (connectButton.enabled) {
                            connectButton.clicked();
                        }
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Backspace) {
                        if (event.modifiers & Qt.ControlModifier) {
                            passwordBuffer = "";
                        } else {
                            passwordBuffer = passwordBuffer.slice(0, -1);
                        }
                        event.accepted = true;
                    } else if (event.text && event.text.length > 0) {
                        if (event.key === Qt.Key_Tab) {
                            event.accepted = false;
                            return;
                        }
                        passwordBuffer += event.text;
                        event.accepted = true;
                    }
                }

                Connections {
                    function onShouldBeVisibleChanged(): void {
                        if (root.shouldBeVisible) {
                            // Use Timer for actual delay to ensure focus works correctly
                            passwordFocusTimer.start();
                            passwordContainer.passwordBuffer = "";
                            identityField.text = "";
                            anonIdentityField.text = "";
                            caCertField.text = "";
                            connectButton.hasError = false;
                        }
                    }

                    target: root
                }

                Timer {
                    id: passwordFocusTimer

                    interval: 50
                    onTriggered: {
                        if (root.isEnterprise)
                            identityField.forceActiveFocus();
                        else
                            passwordContainer.forceActiveFocus();
                    }
                }

                StyledRect {
                    anchors.fill: parent
                    radius: Tokens.rounding.large
                    color: passwordContainer.activeFocus ? Qt.lighter(Colours.tPalette.m3surfaceContainer, 1.05) : Colours.tPalette.m3surfaceContainer
                    border.width: passwordContainer.activeFocus || connectButton.hasError ? 4 : (root.shouldBeVisible ? 1 : 0)
                    border.color: {
                        if (connectButton.hasError) {
                            return Colours.palette.m3error;
                        }
                        if (passwordContainer.activeFocus) {
                            return Colours.palette.m3primary;
                        }
                        return root.shouldBeVisible ? Colours.palette.m3outline : "transparent";
                    }

                    Behavior on border.color {
                        CAnim {}
                    }

                    Behavior on border.width {
                        CAnim {}
                    }

                    Behavior on color {
                        CAnim {}
                    }
                }

                StateLayer {
                    hoverEnabled: false
                    cursorShape: Qt.IBeamCursor
                    radius: Tokens.rounding.large
                    onClicked: passwordContainer.forceActiveFocus()
                }

                StyledText {
                    id: placeholder

                    anchors.centerIn: parent
                    text: root.isWep ? Tr.tr("WEP key") : Tr.tr("Password")
                    color: Colours.palette.m3outline
                    font: Tokens.font.mono.medium
                    opacity: passwordContainer.passwordBuffer ? 0 : 1

                    Behavior on opacity {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }
                }

                ListView {
                    id: charList

                    readonly property int fullWidth: count * (implicitHeight + spacing) - spacing

                    anchors.centerIn: parent
                    implicitWidth: fullWidth
                    implicitHeight: Tokens.font.body.medium.pointSize

                    orientation: Qt.Horizontal
                    spacing: Tokens.spacing.extraSmall
                    interactive: false

                    model: ScriptModel {
                        values: passwordContainer.passwordBuffer.split("")
                    }

                    delegate: StyledRect {
                        id: ch

                        implicitWidth: implicitHeight
                        implicitHeight: charList.implicitHeight

                        color: Colours.palette.m3onSurface
                        radius: Tokens.rounding.medium / 2

                        opacity: 0
                        scale: 0
                        Component.onCompleted: {
                            opacity = 1;
                            scale = 1;
                        }
                        ListView.onRemove: removeAnim.start()

                        SequentialAnimation {
                            id: removeAnim

                            PropertyAction {
                                target: ch
                                property: "ListView.delayRemove"
                                value: true
                            }
                            ParallelAnimation {
                                Anim {
                                    type: Anim.DefaultEffects
                                    target: ch
                                    property: "opacity"
                                    to: 0
                                }
                                Anim {
                                    target: ch
                                    property: "scale"
                                    to: 0.5
                                }
                            }
                            PropertyAction {
                                target: ch
                                property: "ListView.delayRemove"
                                value: false
                            }
                        }

                        Behavior on opacity {
                            Anim {
                                type: Anim.DefaultEffects
                            }
                        }

                        Behavior on scale {
                            Anim {
                                type: Anim.FastSpatial
                            }
                        }
                    }

                    Behavior on implicitWidth {
                        Anim {}
                    }
                }
            }

            // Enterprise (802.1X) authentication options. The network key is
            // still entered above; these supplement it.
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.isEnterprise
                spacing: Tokens.spacing.medium

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.medium

                    StyledText {
                        Layout.fillWidth: true
                        text: Tr.tr("EAP method")
                    }

                    SplitButton {
                        id: eapSelect

                        type: SplitButton.Tonal
                        fallbackText: "PEAP"
                        stateLayer.onClicked: eapSelect.expanded = !eapSelect.expanded

                        menuItems: [
                            MenuItem {
                                text: "PEAP"
                                value: "peap"
                            },
                            MenuItem {
                                text: "TTLS"
                                value: "ttls"
                            },
                            MenuItem {
                                text: "TLS"
                                value: "tls"
                            }
                        ]
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: root.eapMethod !== "tls"
                    spacing: Tokens.spacing.medium

                    StyledText {
                        Layout.fillWidth: true
                        text: Tr.tr("Phase 2 authentication")
                    }

                    SplitButton {
                        id: phase2Select

                        type: SplitButton.Tonal
                        fallbackText: "MSCHAPv2"
                        stateLayer.onClicked: phase2Select.expanded = !phase2Select.expanded

                        menuItems: [
                            MenuItem {
                                text: "MSCHAPv2"
                                value: "mschapv2"
                            },
                            MenuItem {
                                text: "GTC"
                                value: "gtc"
                            },
                            MenuItem {
                                text: "PAP"
                                value: "pap"
                            },
                            MenuItem {
                                text: Tr.trCtx("None", "phase 2 authentication")
                                value: ""
                            }
                        ]
                    }
                }

                StyledTextField {
                    id: anonIdentityField

                    Layout.fillWidth: true
                    placeholderText: Tr.tr("Anonymous identity (optional)")
                    leadingIcon: "badge"
                    inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                }

                StyledTextField {
                    id: caCertField

                    Layout.fillWidth: true
                    placeholderText: Tr.tr("CA certificate path (optional)")
                    leadingIcon: "verified"
                    inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                }
            }

            RowLayout {
                Layout.topMargin: Tokens.spacing.medium
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                TextButton {
                    id: cancelButton

                    Layout.fillWidth: true
                    Layout.minimumHeight: Tokens.font.body.medium.pointSize + Tokens.padding.medium * 2
                    inactiveColour: Colours.palette.m3secondaryContainer
                    inactiveOnColour: Colours.palette.m3onSecondaryContainer
                    text: Tr.trCtx("Cancel", "button")

                    onClicked: root.closeDialog()
                }

                TextButton {
                    id: connectButton

                    property bool connecting: false
                    property bool hasError: false

                    Layout.fillWidth: true
                    Layout.minimumHeight: Tokens.font.body.medium.pointSize + Tokens.padding.medium * 2
                    inactiveColour: Colours.palette.m3primary
                    inactiveOnColour: Colours.palette.m3onPrimary
                    text: Tr.tr("Connect")
                    enabled: root.canConnect && !connecting

                    onClicked: {
                        if (!root.network || connecting) {
                            return;
                        }

                        const password = passwordContainer.passwordBuffer;
                        if (!root.isOpen && (!password || password.length === 0)) {
                            return;
                        }

                        // Clear any previous error
                        hasError = false;

                        // Set connecting state
                        connecting = true;
                        enabled = false;
                        text = Tr.tr("Connecting...");

                        // Connect to network. Open, enterprise and WEP need the
                        // full security configuration; the rest is a plain key.
                        if (root.needsConfig) {
                            NetworkConnection.connectWithConfig(root.network, {
                                security: root.securityKind,
                                password: password,
                                identity: identityField.text.trim(),
                                eap: root.eapMethod,
                                phase2: root.phase2Method,
                                anonIdentity: anonIdentityField.text.trim(),
                                caCert: caCertField.text.trim()
                            }, result => root.handleResult(result));
                        } else {
                            NetworkConnection.connectWithPassword(root.network, password, result => root.handleResult(result));
                        }

                        // Start monitoring connection
                        connectionMonitor.start();
                    }
                }
            }
        }
    }

    Timer {
        id: connectionMonitor

        property int repeatCount: 0

        interval: 1000
        repeat: true
        triggeredOnStart: false

        onTriggered: {
            repeatCount++;
            root.checkConnectionStatus();
        }

        onRunningChanged: {
            if (!running) {
                repeatCount = 0;
            }
        }
    }

    Timer {
        id: closeTimer

        interval: Tokens.anim.durations.expressiveDefaultEffects
        onTriggered: root.isClosing = false
    }

    Timer {
        id: connectionSuccessTimer

        interval: 500
        onTriggered: {
            // Double-check connection is still active
            if (root.shouldBeVisible && Nmcli.active && Nmcli.active.ssid) {
                const stillConnected = Nmcli.active.ssid.toLowerCase().trim() === root.network.ssid.toLowerCase().trim();
                if (stillConnected) {
                    connectionMonitor.stop();
                    connectButton.connecting = false;
                    connectButton.text = Tr.tr("Connect");
                    // Return to network popout on successful connection
                    if (root.popouts.currentName === "wirelesspassword") {
                        root.popouts.currentName = "network";
                    }
                    closeDialog();
                }
            }
        }
    }

    Connections {
        function onActiveChanged() {
            if (root.shouldBeVisible) {
                root.checkConnectionStatus();
            }
        }

        function onConnectionFailed(ssid: string) {
            if (root.shouldBeVisible && root.network && root.network.ssid === ssid && connectButton.connecting) {
                connectionMonitor.stop();
                connectButton.connecting = false;
                connectButton.hasError = true;
                connectButton.enabled = true;
                connectButton.text = Tr.tr("Connect");
                passwordContainer.passwordBuffer = "";
                // Delete the failed connection
                Nmcli.forgetNetwork(ssid);
            }
        }

        target: Nmcli
    }
}
