import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.components.images
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    property bool testing: false
    property bool testOk: false
    property string testMessage: ""
    readonly property bool showProfile: Lastfm.profile !== null

    function runTest(): void {
        testing = true;
        testMessage = "";
        Lastfm.testConnection((ok, message) => {
            testing = false;
            testOk = ok;
            testMessage = message;
            if (ok)
                Lastfm.refreshProfile(true);
        });
    }

    title: Tr.tr("Last.fm")
    isSubPage: true

    Component.onCompleted: {
        if (Lastfm.hasCredentials)
            Lastfm.refreshProfile(false);
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.medium

        SectionHeader {
            first: true
            text: Tr.tr("Account")
        }

        ToggleRow {
            Layout.fillWidth: true
            first: true
            text: Tr.tr("Enable Last.fm")
            subtext: Tr.tr("Show your profile, recent scrobbles, artist and album info")
            checked: GlobalConfig.services.lastfmEnabled
            onToggled: {
                GlobalConfig.services.lastfmEnabled = checked;
                GlobalConfig.save();
                if (Lastfm.configured)
                    Lastfm.refreshProfile(true);
            }
        }

        TextFieldRow {
            label: Tr.tr("Username")
            subtext: Tr.tr("Your Last.fm username")
            value: GlobalConfig.services.lastfmUsername
            placeholderText: "lastfm-user"
            onEditingFinished: value => {
                GlobalConfig.services.lastfmUsername = value.trim();
                GlobalConfig.save();
                if (Lastfm.hasCredentials)
                    Lastfm.refreshProfile(true);
            }
        }

        TextFieldRow {
            last: true
            label: Tr.tr("API key")
            subtext: Lastfm.apiKey !== "" && !Lastfm.keyLooksValid ? Tr.tr("Last.fm API keys are 32 hexadecimal characters") : Tr.tr("Read-only key from your Last.fm API account")
            value: GlobalConfig.services.lastfmApiKey
            placeholderText: Tr.tr("32-character API key")
            field.echoMode: TextInput.Password
            onEditingFinished: value => {
                GlobalConfig.services.lastfmApiKey = value.trim();
                GlobalConfig.save();
                if (Lastfm.hasCredentials)
                    Lastfm.refreshProfile(true);
            }
        }

        SectionHeader {
            text: Tr.tr("Connection")
        }

        ConnectedRect {
            Layout.fillWidth: true
            first: true
            last: !root.showProfile
            implicitHeight: connectionRow.implicitHeight + Tokens.padding.medium * 2

            RowLayout {
                id: connectionRow

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                TextButton {
                    type: TextButton.Tonal
                    text: root.testing ? Tr.tr("Testing…") : Tr.tr("Test connection")
                    disabled: root.testing
                    onClicked: root.runTest()
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.testMessage !== ""
                    text: root.testMessage
                    color: root.testOk ? Colours.palette.m3primary : Colours.palette.m3error
                    font: Tokens.font.label.small
                    elide: Text.ElideRight
                }

                TextButton {
                    text: Tr.tr("Create API key")
                    onClicked: Qt.openUrlExternally("https://www.last.fm/api/account/create")
                }
            }
        }

        ConnectedRect {
            Layout.fillWidth: true
            visible: root.showProfile
            last: true
            implicitHeight: profileRow.implicitHeight + Tokens.padding.medium * 2

            RowLayout {
                id: profileRow

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                StyledClippingRect {
                    implicitWidth: 44
                    implicitHeight: 44
                    radius: width / 2
                    color: Colours.palette.m3surfaceContainerHigh

                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: !Lastfm.profile?.image
                        text: "person"
                        color: Colours.palette.m3outline
                        fontStyle: Tokens.font.icon.medium
                    }

                    FadeImage {
                        anchors.fill: parent
                        source: Lastfm.profile?.image ?? ""
                        fillMode: Image.PreserveAspectCrop
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        text: Lastfm.profile?.name ?? ""
                        font: Tokens.font.title.small
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Lastfm.profile ? Tr.trCtxN("%1 scrobble", "%1 scrobbles", Lastfm.profile.playcount, "profile").arg(Lastfm.formatCount(Lastfm.profile.playcount)) : ""
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.small
                        elide: Text.ElideRight
                    }
                }

                TextButton {
                    text: Tr.tr("Open profile")
                    onClicked: Qt.openUrlExternally(Lastfm.profile?.url ?? "")
                }
            }
        }

        SectionHeader {
            text: Tr.tr("Display")
        }

        StepperRow {
            first: true
            label: Tr.tr("Refresh interval")
            subtext: Tr.tr("How often the dashboard and feed data are checked (seconds). Desktop widgets have their own interval.")
            value: Math.round((GlobalConfig.services.lastfmRefreshInterval ?? 30000) / 1000)
            from: 10
            to: 300
            stepSize: 5
            onMoved: value => {
                GlobalConfig.services.lastfmRefreshInterval = Math.round(value) * 1000;
                GlobalConfig.save();
            }
        }

        StepperRow {
            last: true
            label: Tr.tr("Recent tracks")
            subtext: Tr.tr("How many scrobbles to show")
            value: GlobalConfig.services.lastfmRecentLimit ?? 10
            from: 1
            to: 50
            stepSize: 1
            onMoved: value => {
                GlobalConfig.services.lastfmRecentLimit = Math.round(value);
                GlobalConfig.save();
            }
        }

        SectionHeader {
            text: Tr.tr("About")
        }

        RowButton {
            first: true
            last: true
            icon: "open_in_new"
            text: Tr.tr("Last.fm API")
            subtext: Tr.tr("Profile, scrobble, artist and album data provided by Last.fm")
            onClicked: Qt.openUrlExternally("https://www.last.fm/api")
        }
    }
}
