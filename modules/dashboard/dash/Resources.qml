import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    property bool active: true

    anchors.top: parent.top
    anchors.bottom: parent.bottom

    implicitWidth: layout.implicitWidth + layout.anchors.margins * 2

    ColumnLayout {
        id: layout

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        Resource {
            icon: "memory"
            value: root.active ? Cpu.percentage : 0
        }

        Resource {
            icon: "memory_alt"
            value: root.active ? Memory.percentage : 0
            fgColour: Colours.palette.m3tertiary
        }

        Resource {
            icon: "hard_disk"
            value: root.active ? Storage.percentage : 0
            fgColour: Colours.palette.m3secondary
        }
    }
    component Resource: CircularProgress {
        id: res

        required property string icon

        Layout.fillHeight: true
        implicitSize: height
        strokeWidth: Tokens.sizes.dashboard.resourceProgressThickness

        Behavior on clampedVal {
            enabled: root.active

            Anim {}
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: res.icon
            font: Tokens.font.icon.large
            color: res.fgColour
        }
    }
}
