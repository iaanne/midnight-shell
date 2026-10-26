pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.services
import qs.modules.nexus
import qs.modules.nexus.common

VerticalFadeFlickable {
    id: root

    required property NexusState nState

    // The developer-only page slides into the list when developer mode is
    // unlocked; this item and the one above it are the ones that animate.
    // Resolved by looking the page up so inserting pages cannot move it.
    readonly property int devPageIdx: {
        for (let i = 0; i < PageRegistry.pages.length; i++) {
            if (PageRegistry.pages[i].developerOnly)
                return i;
        }
        return -1;
    }

    readonly property string normalizedQuery: nState.searchQuery.trim().toLowerCase()
    readonly property bool searching: normalizedQuery.length > 0

    function lower(value) {
        return String(value ?? "").toLowerCase();
    }

    function canonical(value) {
        return lower(value).replace(/[^a-z0-9]+/g, "");
    }

    function pageKeywords(page) {
        return page.keywords ?? [];
    }

    function tokenMatches(value, token) {
        return lower(value).includes(token) || canonical(value).includes(canonical(token));
    }

    function pageMatches(page, tokens) {
        const haystack = lower([page.label, page.description, page.category, page.key, ...pageKeywords(page)].join(" "));
        const compact = canonical(haystack);
        return tokens.every(token => haystack.includes(token) || compact.includes(canonical(token)));
    }

    function pageScore(page, query, tokens) {
        const label = lower(page.label);
        const description = lower(page.description);
        const category = lower(page.category);
        const keywords = pageKeywords(page);
        const queryCompact = canonical(query);
        const labelCompact = canonical(label);
        const descriptionCompact = canonical(description);
        let score = 0;

        if (label === query || labelCompact === queryCompact)
            score += 1000;
        else if (label.startsWith(query) || labelCompact.startsWith(queryCompact))
            score += 800;
        else if (label.includes(query) || labelCompact.includes(queryCompact))
            score += 600;

        for (const keyword of keywords) {
            const k = lower(keyword);
            const kCompact = canonical(keyword);
            if (k === query || kCompact === queryCompact)
                score += 500;
            else if (k.startsWith(query) || kCompact.startsWith(queryCompact))
                score += 400;
            else if (k.includes(query) || kCompact.includes(queryCompact))
                score += 300;
        }

        if (description.includes(query) || descriptionCompact.includes(queryCompact))
            score += 200;
        if (category.includes(query))
            score += 100;

        for (const token of tokens) {
            const tokenCompact = canonical(token);
            if (label.includes(token) || labelCompact.includes(tokenCompact))
                score += 80;
            if (description.includes(token) || descriptionCompact.includes(tokenCompact))
                score += 40;
            for (const keyword of keywords) {
                if (tokenMatches(keyword, token)) {
                    score += 20;
                    break;
                }
            }
        }

        return score;
    }

    function pageMatchText(page, query, tokens) {
        const description = String(page.description ?? "");
        const label = String(page.label ?? "");

        // When the page title itself matched, its description gives more
        // context than repeating the title through a keyword.
        if ((lower(label).includes(query) || canonical(label).includes(canonical(query))) && description)
            return description;

        const keywords = pageKeywords(page);
        let matches = keywords.filter(keyword => tokens.every(token => tokenMatches(keyword, token)));
        if (!matches.length)
            matches = keywords.filter(keyword => tokens.some(token => tokenMatches(keyword, token)));

        const queryCompact = canonical(query);
        matches.sort((a, b) => {
            const aLower = lower(a);
            const bLower = lower(b);
            const aStarts = aLower.startsWith(query) || canonical(a).startsWith(queryCompact) ? 0 : 1;
            const bStarts = bLower.startsWith(query) || canonical(b).startsWith(queryCompact) ? 0 : 1;
            return aStarts - bStarts || aLower.length - bLower.length;
        });

        const selected = [];
        for (const match of matches) {
            const matchCanonical = canonical(match);
            if (selected.some(selectedMatch => matchCanonical.startsWith(canonical(selectedMatch))))
                continue;
            selected.push(match);
            if (selected.length === 3)
                break;
        }

        if (selected.length)
            return selected.join(", ");

        if (description)
            return description;

        return String(page.category ?? "");
    }

    readonly property var searchResults: {
        if (!searching)
            return [];

        const query = normalizedQuery;
        const tokens = query.split(/\s+/).filter(token => token.length > 0);
        const results = [];

        for (let i = 0; i < PageRegistry.pages.length; i++) {
            const page = PageRegistry.pages[i];
            if (page.developerOnly && !GlobalConfig.general.developerMode)
                continue;
            if (!pageMatches(page, tokens))
                continue;

            results.push({
                originalIndex: i,
                label: page.label,
                icon: page.icon,
                description: page.description,
                category: page.category,
                noFill: page.noFill ?? false,
                matchText: pageMatchText(page, query, tokens),
                score: pageScore(page, query, tokens)
            });
        }

        results.sort((a, b) => b.score - a.score || a.originalIndex - b.originalIndex);
        return results;
    }

    topMargin: Tokens.padding.large
    bottomMargin: Tokens.padding.large
    contentHeight: content.implicitHeight

    TapHandler {
        onTapped: root.focus = true
    }

    ColumnLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Tokens.spacing.extraSmall

        ColumnLayout {
            id: normalList

            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall
            visible: !root.searching

            Repeater {
                id: list

                model: {
                    const arr = [];
                    for (let i = 0; i < PageRegistry.pages.length; i++) {
                        const page = PageRegistry.pages[i];
                        if (!page.developerOnly || GlobalConfig.general.developerMode) {
                            arr.push({
                                originalIndex: i,
                                label: page.label,
                                icon: page.icon,
                                description: page.description,
                                category: page.category,
                                noFill: page.noFill ?? false
                            });
                        }
                    }
                    return arr;
                }

                StyledRect {
                    id: item

                    required property var modelData
                    required property int index

                    clip: true

                    readonly property bool isCurrentPage: modelData.originalIndex === root.nState.currentPageIdx
                    readonly property bool isCategoryStart: index === 0 || list.model[index - 1].category !== modelData.category
                    readonly property bool isCategoryEnd: index === list.model.length - 1 || list.model[index + 1].category !== modelData.category

                    property real animHeight: 1
                    property real animSlide: 1
                    property bool isUnlocking: false

                    Component.onCompleted: {
                        if (modelData.originalIndex === root.devPageIdx && root.nState.justUnlockedDevMode) {
                            animHeight = 0;
                            animSlide = 0;
                            heightAnim.start();
                            slideAnim.start();
                            isUnlocking = true;
                            unlockTimer.start();
                        } else if (modelData.originalIndex === root.devPageIdx - 1 && root.nState.justUnlockedDevMode) {
                            isUnlocking = true;
                            unlockTimer.start();
                        }
                    }

                    Timer {
                        id: unlockTimer
                        interval: 20
                        onTriggered: item.isUnlocking = false
                    }

                    NumberAnimation {
                        id: heightAnim
                        target: item
                        property: "animHeight"
                        to: 1
                        duration: 320
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.1
                        onFinished: root.nState.justUnlockedDevMode = false
                    }

                    NumberAnimation {
                        id: slideAnim
                        target: item
                        property: "animSlide"
                        to: 1
                        duration: 320
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.2
                    }

                    Layout.fillWidth: true
                    Layout.topMargin: (index !== 0 && isCategoryStart ? Tokens.spacing.medium : 0) * animHeight
                    implicitHeight: {
                        const h = layout.implicitHeight + layout.anchors.margins * 2;
                        const targetH = h % 2 === 0 ? h : h + 1;
                        return targetH * animHeight;
                    }
                    opacity: modelData.originalIndex === root.devPageIdx ? animSlide : 1.0

                    transform: Translate {
                        y: modelData.originalIndex === root.devPageIdx ? (1 - item.animSlide) * -40 : 0
                    }

                    color: isCurrentPage ? Colours.palette.m3secondaryContainer : Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)

                    topLeftRadius: stateLayer.pressed ? Tokens.rounding.medium : isCurrentPage ? Tokens.rounding.extraLargeIncreased : (isUnlocking && modelData.originalIndex === root.devPageIdx) ? Tokens.rounding.extraLarge : isCategoryStart ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
                    topRightRadius: stateLayer.pressed ? Tokens.rounding.medium : isCurrentPage ? Tokens.rounding.extraLargeIncreased : (isUnlocking && modelData.originalIndex === root.devPageIdx) ? Tokens.rounding.extraLarge : isCategoryStart ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
                    bottomLeftRadius: stateLayer.pressed ? Tokens.rounding.medium : isCurrentPage ? Tokens.rounding.extraLargeIncreased : (isUnlocking && modelData.originalIndex === root.devPageIdx - 1) ? Tokens.rounding.extraLarge : isCategoryEnd ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall
                    bottomRightRadius: stateLayer.pressed ? Tokens.rounding.medium : isCurrentPage ? Tokens.rounding.extraLargeIncreased : (isUnlocking && modelData.originalIndex === root.devPageIdx - 1) ? Tokens.rounding.extraLarge : isCategoryEnd ? Tokens.rounding.extraLarge : Tokens.rounding.extraSmall

                    RadiusBehavior on topLeftRadius {}
                    RadiusBehavior on topRightRadius {}
                    RadiusBehavior on bottomLeftRadius {}
                    RadiusBehavior on bottomRightRadius {}

                    StateLayer {
                        id: stateLayer

                        anchors.fill: parent
                        topLeftRadius: parent.topLeftRadius
                        topRightRadius: parent.topRightRadius
                        bottomLeftRadius: parent.bottomLeftRadius
                        bottomRightRadius: parent.bottomRightRadius

                        onClicked: root.nState.currentPageIdx = item.modelData.originalIndex
                    }

                    RowLayout {
                        id: layout

                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: Tokens.padding.large
                        spacing: Tokens.spacing.medium

                        opacity: modelData.originalIndex === root.devPageIdx ? item.animSlide : 1.0

                        StyledRect {
                            Layout.fillHeight: true
                            Layout.topMargin: -1
                            Layout.bottomMargin: -1
                            implicitWidth: height

                            radius: Tokens.rounding.full
                            color: item.isCurrentPage ? Colours.palette.m3primary : Colours.palette.m3secondaryContainer

                            MaterialIcon {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: 1

                                text: item.modelData.icon
                                color: item.isCurrentPage ? Colours.palette.m3onPrimary : Colours.palette.m3onSecondaryContainer
                                fontStyle: Tokens.font.icon.builders.medium.weight(Font.Medium).build()
                                grade: 25
                                fill: item.modelData.noFill ? 0 : 1
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: item.modelData.label
                                font: Tokens.font.body.medium
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: item.modelData.description
                                color: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.label.small
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }

        ColumnLayout {
            id: searchList

            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall
            visible: root.searching

            Repeater {
                model: root.searchResults

                NavRow {
                    required property var modelData
                    required property int index

                    first: index === 0
                    last: index === root.searchResults.length - 1
                    icon: modelData.icon
                    text: modelData.label
                    subtext: modelData.matchText
                    label.font: Tokens.font.body.medium
                    subLabel.animate: false
                    color: modelData.originalIndex === root.nState.currentPageIdx ? Colours.palette.m3secondaryContainer : Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)
                    iconLabel.color: modelData.originalIndex === root.nState.currentPageIdx ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                    iconLabel.fill: modelData.noFill ? 0 : 1

                    onClicked: {
                        root.nState.currentPageIdx = modelData.originalIndex;
                        root.nState.searchQuery = "";
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.padding.extraLarge
                spacing: Tokens.spacing.small
                visible: root.searchResults.length === 0

                MaterialIcon {
                    Layout.alignment: Qt.AlignHCenter
                    text: "search_off"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.large
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Tr.tr("No settings found")
                    font: Tokens.font.body.medium
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Tr.tr("Try a different keyword")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.small
                }
            }
        }
    }

    component RadiusBehavior: Behavior {
        Anim {
            type: Anim.DefaultEffects
        }
    }
}
