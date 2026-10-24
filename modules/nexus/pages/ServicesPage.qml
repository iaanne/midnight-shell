import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    // GPU types, ordered to match config::GpuType (Auto, Nvidia, Generic, None)
    readonly property list<MenuItem> gpuItems: [
        MenuItem {
            text: Tr.trCtx("Auto", "gpu type")
        },
        MenuItem {
            text: "NVIDIA"
        },
        MenuItem {
            text: Tr.trCtx("Generic", "gpu type")
        },
        MenuItem {
            text: Tr.trCtx("None", "gpu type")
        }
    ]

    title: Tr.tr("Services")

    Component.onCompleted: Lyrics.syncProviders()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Detected running players, used as default-player options
        Variants {
            id: playerVariants

            model: [...new Set(Players.list.map(p => Players.getIdentity(p)).filter(id => id))]

            MenuItem {
                required property string modelData

                text: modelData
                icon: modelData === GlobalConfig.services.defaultPlayer ? "check" : ""
                activeIcon: "music_note"
            }
        }

        // Notifications
        SectionHeader {
            first: true
            text: Tr.tr("Notifications")
        }

        NavRow {
            first: true
            last: true
            icon: "notifications"
            text: Tr.tr("Notifications")
            subtext: Tr.tr("Notifications, toasts, timeouts")
            onClicked: root.nState.openSubPage(1)
        }

        // Connections
        SectionHeader {
            text: Tr.tr("Polling")
        }

        StepperRow {
            first: true
            label: Tr.tr("Media refresh")
            // TRANSLATORS: ms is the millisecond unit, leave it untranslated
            subtext: Tr.tr("How often the media position updates (ms)")
            value: GlobalConfig.dashboard.mediaUpdateInterval
            from: 100
            to: 2000
            stepSize: 50
            onMoved: v => GlobalConfig.dashboard.mediaUpdateInterval = v
        }

        StepperRow {
            label: Tr.tr("System stats refresh")
            // TRANSLATORS: CPU and GPU are hardware abbreviations, leave it untranslated
            subtext: Tr.tr("CPU, memory and GPU update interval (seconds)")
            value: GlobalConfig.dashboard.resourceUpdateInterval / 1000
            from: 0.5
            to: 10
            stepSize: 0.5
            onMoved: v => GlobalConfig.dashboard.resourceUpdateInterval = Math.round(v * 1000)
        }

        ToggleRow {
            text: Tr.tr("Keep stats polling when closed")
            subtext: Tr.tr("Continue updating stats after the dashboard closes so it reopens with fresh values")
            checked: GlobalConfig.dashboard.keepResourcePollingWhenClosed
            onToggled: GlobalConfig.dashboard.keepResourcePollingWhenClosed = checked
        }

        StepperRow {
            last: true
            label: Tr.tr("Wi-Fi rescan")
            subtext: Tr.tr("How often available networks are rescanned (seconds)")
            value: GlobalConfig.nexus.networkRescanInterval / 1000
            from: 5
            to: 120
            stepSize: 5
            onMoved: v => GlobalConfig.nexus.networkRescanInterval = Math.round(v * 1000)
        }

        // Media & lyrics
        SectionHeader {
            text: Tr.tr("Media & lyrics")
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.largeIncreased
            Layout.rightMargin: Tokens.padding.largeIncreased
            text: Tr.tr("Drag to reorder. Word-synced results win over line-synced ones. Turn every provider off to use local lyrics only.")
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
        }

        ListEditor {
            id: providerEditor

            removable: false
            first: true
            values: GlobalConfig.services.lyricsProviders.values

            function labelFor(item: var): string {
                const provider = Lyrics.providers.find(p => p.id === item.id);
                return provider?.name ?? item.id;
            }

            function toggledFor(item: var): bool {
                return item.enabled;
            }

            onItemMoved: (from, to) => {
                GlobalConfig.services.lyricsProviders.move(from, to);
            }
            onItemToggled: (index, checked) => {
                const entry = GlobalConfig.services.lyricsProviders.at(index);
                if (entry)
                    Lyrics.setProviderEnabled(entry.id, checked);
            }
        }

        ToggleRow {
            text: Tr.tr("Romanized lyrics")
            subtext: Tr.tr("Prefer latin/romanized variants when the source provides them")
            checked: Lyrics.romanized
            onToggled: Lyrics.romanized = checked
        }

        SelectRow {
            last: true
            label: Tr.tr("Default player")
            subtext: Tr.tr("Preferred media player when several are open")
            menuItems: playerVariants.instances
            active: menuItems.find(i => i.text === GlobalConfig.services.defaultPlayer) ?? null
            fallbackIcon: "music_note"
            fallbackText: GlobalConfig.services.defaultPlayer || Tr.trCtx("Auto", "default media player")
            onSelected: item => GlobalConfig.services.defaultPlayer = item.text
        }

        // Input increments
        SectionHeader {
            text: Tr.tr("Input increments")
        }

        StepperRow {
            first: true
            label: Tr.tr("Volume step")
            subtext: Tr.tr("Amount the volume changes per scroll (%)")
            value: Math.round(GlobalConfig.services.audioIncrement * 100)
            from: 1
            to: 50
            stepSize: 1
            onMoved: v => GlobalConfig.services.audioIncrement = v / 100
        }

        StepperRow {
            label: Tr.tr("Brightness step")
            subtext: Tr.tr("Amount the brightness changes per scroll (%)")
            value: Math.round(GlobalConfig.services.brightnessIncrement * 100)
            from: 1
            to: 50
            stepSize: 1
            onMoved: v => GlobalConfig.services.brightnessIncrement = v / 100
        }

        StepperRow {
            last: true
            label: Tr.tr("Max volume")
            subtext: Tr.tr("Upper limit for output volume (%)")
            value: Math.round(GlobalConfig.services.maxVolume * 100)
            from: 50
            to: 200
            stepSize: 5
            onMoved: v => GlobalConfig.services.maxVolume = v / 100
        }

        // Service tuning
        SectionHeader {
            text: Tr.tr("Service tuning")
        }

        NavRow {
            first: true
            icon: "sports_esports"
            text: Tr.tr("Game mode")
            subtext: Tr.tr("Manage how MiDnight behaves while gaming")
            onClicked: root.nState.openSubPage(2)
        }

        NavRow {
            icon: "chat" // Using chat since discord icon might not be available in Material icons
            text: Tr.tr("Discord Rich Presence")
            subtext: Tr.tr("Broadcast your status to Vesktop")
            onClicked: root.nState.openSubPage(4)
        }

        NavRow {
            icon: "picture_in_picture"
            text: Tr.tr("Picture in Picture")
            subtext: Tr.tr("Configure PiP positioning and focus behavior")
            onClicked: root.nState.openSubPage(5)
        }

        NavRow {
            icon: "near_me"
            text: Tr.tr("Quick Share")
            subtext: Tr.tr("Auto-start and discoverability settings")
            onClicked: root.nState.openSubPage(6)
        }

        NavRow {
            icon: "music_note"
            text: Tr.tr("Last.fm")
            subtext: Tr.tr("Profile, recent scrobbles and music info")
            onClicked: root.nState.openSubPage(7)
        }

        SelectRow {
            Layout.fillWidth: true
            last: true
            label: Tr.tr("GPU")
            subtext: Gpu.name ? Tr.tr("Monitoring: %1").arg(Gpu.name) : Tr.tr("Override for GPU type")
            menuOnTop: true
            menuItems: root.gpuItems
            active: root.gpuItems[GlobalConfig.services.gpuType]
            onSelected: item => GlobalConfig.services.gpuType = root.gpuItems.indexOf(item)
        }
    }
}
