pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// Shared sub-page for adding a new Wi-Fi network or editing the security of an
// existing saved profile. Reached from the "Add network" row on NetworkPage, an
// unconfigured row in the Wi-Fi list, or the "Configure" button on the network
// detail page, all via nState.openSubPage.
PageBase {
    id: root

    // True when opened to edit an existing saved profile (from the network
    // detail page); false for a fresh add.
    readonly property bool editing: root.nState?.networkConfigEditing ?? false
    readonly property string targetSsid: root.nState?.networkConfigSsid ?? ""
    // While editing, an already-stored secret may be left untouched.
    readonly property bool passwordOptional: root.editing

    // Protection kind for the connection being configured. Mirrors
    // Nmcli.securityKind*; with no explicit selection the default is
    // WPA/WPA2/WPA3 Personal.
    readonly property string securityKind: securitySelect.active ? securitySelect.active.value : Nmcli.securityKindPsk
    readonly property bool isOpen: securityKind === Nmcli.securityKindOpen
    readonly property bool isWep: securityKind === Nmcli.securityKindWep
    readonly property bool isPersonal: securityKind === Nmcli.securityKindPsk || securityKind === Nmcli.securityKindSae
    readonly property bool isEnterprise: securityKind === Nmcli.securityKindEnterprise
    // Open networks carry no secret; everything else needs one.
    readonly property bool secured: !isOpen
    readonly property string eapMethod: eapSelect.active ? eapSelect.active.value : "peap"
    readonly property string phase2Method: phase2Select.active ? phase2Select.active.value : "mschapv2"

    property bool connecting: false
    property bool failed: false
    property bool success: false
    property bool revealPassword: false

    function selectSecurity(kind: string): void {
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

    function selectEap(value: string): void {
        if (value === "ttls")
            eapSelect.active = eapTtlsItem;
        else if (value === "tls")
            eapSelect.active = eapTlsItem;
        else
            eapSelect.active = eapPeapItem;
    }

    function selectPhase2(value: string): void {
        if (value === "gtc")
            phase2Select.active = phase2GtcItem;
        else if (value === "pap")
            phase2Select.active = phase2PapItem;
        else if (value.length === 0)
            phase2Select.active = phase2NoneItem;
        else
            phase2Select.active = phase2Mschapv2Item;
    }

    // Pre-fills the form for the requested network: detects the advertised
    // protection for a fresh add, or loads the saved profile when editing.
    function loadInitialState(): void {
        const ssid = root.targetSsid;
        if (ssid.length === 0)
            return;

        ssidField.text = ssid;

        if (!root.editing) {
            const ap = Nmcli.findNetwork(ssid);
            if (ap)
                root.selectSecurity(Nmcli.securityKind(ap.security));
            hiddenToggle.checked = false;
            return;
        }

        Nmcli.getSavedSecurityConfig(ssid, cfg => {
            if (!cfg)
                return;
            root.selectSecurity(cfg.security);
            root.selectEap(cfg.eap);
            root.selectPhase2(cfg.phase2);
            passwordField.text = cfg.password;
            identityField.text = cfg.identity;
            anonIdentityField.text = cfg.anonIdentity;
            caCertField.text = cfg.caCert;
            hiddenToggle.checked = cfg.hidden;
        });
    }

    function submit(): void {
        const ssid = ssidField.text.trim();
        if (ssid.length === 0) {
            ssidField.isError = true;
            ssidField.forceActiveFocus();
            return;
        }

        const password = passwordField.text;
        // Personal passwords must be at least 8 characters, but a stored
        // secret may be left blank while editing.
        if (root.isPersonal && password.length > 0 && password.length < 8) {
            passwordField.isError = true;
            passwordField.forceActiveFocus();
            return;
        }
        if (root.secured && password.length === 0 && !root.passwordOptional) {
            passwordField.isError = true;
            passwordField.forceActiveFocus();
            return;
        }
        if (root.isEnterprise && identityField.text.trim().length === 0) {
            identityField.isError = true;
            identityField.forceActiveFocus();
            return;
        }

        root.failed = false;
        root.connecting = true;

        const config = {
            security: root.securityKind,
            password: password,
            identity: identityField.text.trim(),
            eap: root.eapMethod,
            phase2: root.phase2Method,
            anonIdentity: anonIdentityField.text.trim(),
            caCert: caCertField.text.trim(),
            hidden: hiddenToggle.checked
        };

        const onResult = result => {
            root.connecting = false;
            if (result && result.success) {
                root.success = true;
                root.nState.closeSubPage();
                return;
            }
            root.failed = true;
            if (root.secured)
                passwordField.isError = true;
            // Drop the half-created profile so a retry starts fresh. Never in
            // edit mode, where doing so would delete the live profile.
            if (!root.editing)
                Nmcli.forgetNetwork(ssid);
        };

        if (root.editing)
            Nmcli.updateConnection(ssid, config, onResult);
        else
            Nmcli.addConnection(ssid, config, hiddenToggle.checked, onResult);
    }

    title: root.editing ? Tr.tr("Network settings") : Tr.tr("Add network")
    isSubPage: true

    Component.onCompleted: root.loadInitialState()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.large

        Connections {
            function onSubPageClosed(): void {
                if (root.success || root.editing)
                    return;

                const ssid = ssidField.text.trim();
                if (ssid)
                    Nmcli.forgetNetwork(ssid);
            }

            target: root.nState
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.extraSmall
            text: root.editing ? Tr.tr("Update the security settings used to connect to this network.") : Tr.tr("Enter the details below to manually connect to a network.")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
            wrapMode: Text.WordWrap
        }

        StyledTextField {
            id: ssidField

            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.extraSmall
            readOnly: root.editing
            // TRANSLATORS: SSID is a protocol term, leave it untranslated
            placeholderText: Tr.tr("Network name (SSID)")
            // TRANSLATORS: sample network name, translate the e.g. but the name is a placeholder
            supportingText: root.editing ? Tr.tr("The network name cannot be changed here") : Tr.tr("e.g. MyHiddenNetwork")
            leadingIcon: "wifi"
            errorText: Tr.tr("Network name is required")
            inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText

            onAccepted: root.secured ? passwordField.forceActiveFocus() : root.submit()
        }

        ToggleRow {
            id: hiddenToggle

            first: true
            text: Tr.tr("Hidden network")
            subtext: Tr.tr("Actively probe for a network that doesn't broadcast its name")
            checked: true
        }

        SelectRow {
            id: securitySelect

            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            last: !root.secured
            label: Tr.tr("Security")
            // TRANSLATORS: WPA/WPA2/WPA3 are protocol names, leave them untranslated
            fallbackText: Tr.tr("WPA/WPA2/WPA3 Personal")
            fallbackIcon: "lock"

            menuItems: [
                MenuItem {
                    id: pskItem

                    icon: "lock"
                    // TRANSLATORS: WPA/WPA2/WPA3 are protocol names, leave them untranslated
                    text: Tr.tr("WPA/WPA2/WPA3 Personal")
                    value: Nmcli.securityKindPsk
                },
                MenuItem {
                    id: saeItem

                    icon: "lock"
                    // TRANSLATORS: WPA3 and SAE are protocol names, leave them untranslated
                    text: Tr.tr("WPA3 Personal (SAE)")
                    value: Nmcli.securityKindSae
                },
                MenuItem {
                    id: enterpriseItem

                    icon: "apartment"
                    // TRANSLATORS: WPA/WPA2/WPA3 and 802.1X are protocol names, leave them untranslated
                    text: Tr.tr("WPA/WPA2/WPA3 Enterprise")
                    value: Nmcli.securityKindEnterprise
                },
                MenuItem {
                    id: wepItem

                    icon: "lock"
                    // TRANSLATORS: WEP is a protocol name, leave it untranslated
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

            Behavior on bottomLeftRadius {
                Anim {
                    type: Anim.DefaultEffects
                }
            }

            Behavior on bottomRightRadius {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        // Credentials for the selected protection. Ordering: identity
        // (enterprise only) -> secret -> EAP options (enterprise only). Hidden
        // entirely for open networks.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: root.secured ? 0 : -parent.spacing
            visible: root.secured
            spacing: Tokens.spacing.large

            StyledTextField {
                id: identityField

                Layout.fillWidth: true
                visible: root.isEnterprise
                enabled: root.isEnterprise
                placeholderText: Tr.tr("Username")
                leadingIcon: "person"
                inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                errorText: Tr.tr("Username is required")

                onAccepted: passwordField.forceActiveFocus()
            }

            StyledTextField {
                id: passwordField

                Layout.fillWidth: true
                placeholderText: root.isWep ? Tr.tr("WEP key") : Tr.tr("Password")
                leadingIcon: "key"
                echoMode: root.revealPassword ? TextInput.Normal : TextInput.Password
                trailingIconButton: root.revealPassword ? "visibility_off" : "visibility"
                supportingText: {
                    if (root.editing)
                        return Tr.tr("Leave blank to keep the saved password");
                    if (root.isWep)
                        return Tr.tr("WEP keys are 5 or 13 characters");
                    if (root.isEnterprise)
                        return Tr.tr("Password for the account");
                    // TRANSLATORS: WPA and WEP are protocol names, leave them untranslated
                    return Tr.tr("WPA passwords are at least 8 characters");
                }
                errorText: {
                    if (root.failed)
                        return Tr.tr("Connection failed — check the credentials");
                    if (root.isWep)
                        return Tr.tr("A WEP key is required");
                    return Tr.tr("Password must be at least 8 characters");
                }

                onTrailingIconClicked: root.revealPassword = !root.revealPassword
                onAccepted: root.submit()
            }

            // Enterprise (802.1X) authentication options.
            RowLayout {
                Layout.fillWidth: true
                visible: root.isEnterprise
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
                            id: eapPeapItem

                            text: "PEAP"
                            value: "peap"
                        },
                        MenuItem {
                            id: eapTtlsItem

                            text: "TTLS"
                            value: "ttls"
                        },
                        MenuItem {
                            id: eapTlsItem

                            text: "TLS"
                            value: "tls"
                        }
                    ]
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.isEnterprise && root.eapMethod !== "tls"
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
                            id: phase2Mschapv2Item

                            text: "MSCHAPv2"
                            value: "mschapv2"
                        },
                        MenuItem {
                            id: phase2GtcItem

                            text: "GTC"
                            value: "gtc"
                        },
                        MenuItem {
                            id: phase2PapItem

                            text: "PAP"
                            value: "pap"
                        },
                        MenuItem {
                            id: phase2NoneItem

                            text: Tr.trCtx("None", "phase 2 authentication")
                            value: ""
                        }
                    ]
                }
            }

            StyledTextField {
                id: anonIdentityField

                Layout.fillWidth: true
                visible: root.isEnterprise
                enabled: root.isEnterprise
                placeholderText: Tr.tr("Anonymous identity (optional)")
                leadingIcon: "badge"
                inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
            }

            StyledTextField {
                id: caCertField

                Layout.fillWidth: true
                visible: root.isEnterprise
                enabled: root.isEnterprise
                placeholderText: Tr.tr("CA certificate path (optional)")
                leadingIcon: "verified"
                supportingText: Tr.tr("Path to a certificate on this machine")
                inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignRight
            Layout.topMargin: Tokens.spacing.extraSmall - parent.spacing
            spacing: Tokens.spacing.small

            TextButton {
                Layout.fillHeight: true
                isRound: true
                horizontalPadding: Tokens.padding.extraLarge
                type: TextButton.Tonal
                text: Tr.trCtx("Cancel", "button")
                onClicked: root.nState.closeSubPage()
            }

            // Connect button — swaps to a loading spinner while connecting,
            // matching the Wi-Fi list connect animation.
            ButtonBase {
                id: connectBtn

                shapeMorph: true
                isRound: true
                inactiveColour: Colours.palette.m3primary
                inactiveOnColour: Colours.palette.m3onPrimary
                stateLayer.disabled: root.connecting || ssidField.text.trim().length === 0

                implicitWidth: connectMetrics.width + Tokens.padding.extraLarge * 2
                implicitHeight: connectMetrics.height + Tokens.padding.medium * 2

                onClicked: {
                    if (!root.connecting && ssidField.text.trim().length > 0)
                        root.submit();
                }

                TextMetrics {
                    id: connectMetrics

                    text: root.editing ? Tr.tr("Save") : Tr.tr("Connect")
                    font: connectBtn.font
                }

                AnimLoader {
                    id: connectContent

                    anchors.centerIn: parent
                    sourceComp: root.connecting ? connectLoadingComp : connectTextComp
                    outAnimType: Anim.SlowEffects
                    inAnimType: Anim.SlowEffects
                }

                Component {
                    id: connectLoadingComp

                    LoadingIndicator {
                        implicitSize: Math.round(Tokens.font.body.medium.pointSize * 1.4)
                        color: connectBtn.onColour
                    }
                }

                Component {
                    id: connectTextComp

                    StyledText {
                        text: connectMetrics.text
                        font: connectBtn.font
                        color: connectBtn.onColour
                    }
                }
            }
        }
    }
}
