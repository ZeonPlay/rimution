import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Rimution 1.0

ApplicationWindow {
    id: root
    visible: true
    width: 1440
    height: 900
    minimumWidth: 1120
    minimumHeight: 720
    title: "Rimution 0.1 — Motion Studio"
    color: palette.window

    property string currentLanguage: "id"
    property string projectName: "Untitled Project"
    property string currentFile: ""
    property int currentFrame: 0
    property int totalFrames: 120
    property int fps: 24
    property bool playing: false
    property string statusText: "Ready"
    property var keyframes: [
        { "frame": 0, "x": 100, "y": 175, "scale": 100, "rotation": 0, "opacity": 100 },
        { "frame": 120, "x": 590, "y": 205, "scale": 135, "rotation": 0, "opacity": 100 }
    ]

    readonly property color panel: "#191B21"
    readonly property color panelRaised: "#22252D"
    readonly property color panelBorder: "#30343E"
    readonly property color mutedText: "#9299A8"
    readonly property color brightText: "#F1F3F7"
    readonly property color accent: "#C6F36B"
    readonly property color accentDark: "#303D1B"

    function t(key) {
        const stringsId = {
            "file": "Berkas", "new": "Proyek Baru", "open": "Buka", "save": "Simpan",
            "project": "PROYEK", "assets": "ASET", "composition": "Komposisi",
            "properties": "Properti", "transform": "Transformasi", "positionX": "Posisi X",
            "positionY": "Posisi Y", "scale": "Skala", "rotation": "Rotasi", "opacity": "Opasitas",
            "timeline": "Timeline", "addKeyframe": "Tambah Keyframe", "play": "Putar",
            "pause": "Jeda", "frame": "Frame", "layer": "Shape 01", "background": "Latar",
            "ready": "Siap", "saved": "Proyek berhasil disimpan", "loaded": "Proyek berhasil dibuka",
            "newCreated": "Proyek baru dibuat", "keyframeAdded": "Keyframe ditambahkan",
            "language": "Bahasa", "canvasHint": "Pratinjau Komposisi", "motion": "Motion Studio",
            "noFile": "Belum ada berkas proyek", "dragObject": "Seret objek untuk memindahkan"
        }
        const en = {
            "file": "File", "new": "New Project", "open": "Open", "save": "Save",
            "project": "PROJECT", "assets": "ASSETS", "composition": "Composition",
            "properties": "Properties", "transform": "Transform", "positionX": "Position X",
            "positionY": "Position Y", "scale": "Scale", "rotation": "Rotation", "opacity": "Opacity",
            "timeline": "Timeline", "addKeyframe": "Add Keyframe", "play": "Play",
            "pause": "Pause", "frame": "Frame", "layer": "Shape 01", "background": "Background",
            "ready": "Ready", "saved": "Project saved successfully", "loaded": "Project loaded successfully",
            "newCreated": "New project created", "keyframeAdded": "Keyframe added",
            "language": "Language", "canvasHint": "Composition Preview", "motion": "Motion Studio",
            "noFile": "No project file yet", "dragObject": "Drag the object to move it"
        }
        return (currentLanguage === "id" ? stringsId : en)[key] || key
    }

    function sortedKeyframes() {
        return keyframes.slice().sort(function(a, b) { return a.frame - b.frame })
    }

    function valueAt(propertyName, frame) {
        const frames = sortedKeyframes()
        if (frames.length === 0)
            return propertyName === "scale" || propertyName === "opacity" ? 100 : 0
        if (frame <= frames[0].frame)
            return Number(frames[0][propertyName])
        for (let i = 1; i < frames.length; ++i) {
            const next = frames[i]
            const previous = frames[i - 1]
            if (frame <= next.frame) {
                const range = Math.max(1, next.frame - previous.frame)
                const amount = (frame - previous.frame) / range
                const startValue = Number(previous[propertyName])
                const endValue = Number(next[propertyName])
                return startValue + (endValue - startValue) * amount
            }
        }
        return Number(frames[frames.length - 1][propertyName])
    }

    function addKeyframe() {
        const nextFrames = sortedKeyframes()
        let found = false
        for (let i = 0; i < nextFrames.length; ++i) {
            if (nextFrames[i].frame === currentFrame) {
                nextFrames[i].x = Math.round(valueAt("x", currentFrame))
                nextFrames[i].y = Math.round(valueAt("y", currentFrame))
                nextFrames[i].scale = Math.round(valueAt("scale", currentFrame))
                nextFrames[i].rotation = Math.round(valueAt("rotation", currentFrame))
                nextFrames[i].opacity = Math.round(valueAt("opacity", currentFrame))
                found = true
                break
            }
        }
        if (!found) {
            nextFrames.push({
                "frame": currentFrame,
                "x": Math.round(valueAt("x", currentFrame)),
                "y": Math.round(valueAt("y", currentFrame)),
                "scale": Math.round(valueAt("scale", currentFrame)),
                "rotation": Math.round(valueAt("rotation", currentFrame)),
                "opacity": Math.round(valueAt("opacity", currentFrame))
            })
        }
        keyframes = nextFrames
        statusText = t("keyframeAdded") + " · " + currentFrame
    }

    function setCurrentProperty(propertyName, value) {
        const nextFrames = sortedKeyframes()
        let found = false
        for (let i = 0; i < nextFrames.length; ++i) {
            if (nextFrames[i].frame === currentFrame) {
                nextFrames[i][propertyName] = Math.round(value)
                found = true
                break
            }
        }
        if (!found) {
            const newFrame = {
                "frame": currentFrame,
                "x": Math.round(valueAt("x", currentFrame)),
                "y": Math.round(valueAt("y", currentFrame)),
                "scale": Math.round(valueAt("scale", currentFrame)),
                "rotation": Math.round(valueAt("rotation", currentFrame)),
                "opacity": Math.round(valueAt("opacity", currentFrame))
            }
            newFrame[propertyName] = Math.round(value)
            nextFrames.push(newFrame)
        }
        keyframes = nextFrames
    }

    function newProject() {
        playing = false
        projectName = "Untitled Project"
        currentFile = ""
        currentFrame = 0
        totalFrames = 120
        fps = 24
        keyframes = [
            { "frame": 0, "x": 100, "y": 175, "scale": 100, "rotation": 0, "opacity": 100 },
            { "frame": 120, "x": 590, "y": 205, "scale": 135, "rotation": 0, "opacity": 100 }
        ]
        statusText = t("newCreated")
    }

    function saveTo(url) {
        let path = url.toLocalFile()
        if (!path.toLowerCase().endsWith(".rim"))
            path += ".rim"
        const project = {
            "projectName": projectName,
            "currentFrame": currentFrame,
            "totalFrames": totalFrames,
            "fps": fps,
            "language": currentLanguage,
            "keyframes": keyframes
        }
        if (projectController.saveProject(path, project)) {
            currentFile = path
            statusText = t("saved")
        }
    }

    function openFrom(url) {
        const loaded = projectController.loadProject(url.toLocalFile())
        if (!loaded || loaded.formatVersion !== 1 || !loaded.keyframes) {
            statusText = currentLanguage === "id" ? "Gagal membuka proyek" : "Could not open project"
            return
        }
        playing = false
        projectName = loaded.projectName || "Untitled Project"
        currentFrame = Math.max(0, Math.min(Number(loaded.currentFrame || 0), Number(loaded.totalFrames || 120)))
        totalFrames = Math.max(1, Number(loaded.totalFrames || 120))
        fps = Math.max(1, Number(loaded.fps || 24))
        if (loaded.language === "id" || loaded.language === "en")
            currentLanguage = loaded.language
        keyframes = loaded.keyframes.map(function(frameData) {
            return Object.assign({ "rotation": 0 }, frameData)
        })
        currentFile = url.toLocalFile()
        statusText = t("loaded")
    }

    ProjectController {
        id: projectController
    }

    Connections {
        target: projectController
        function onErrorOccurred(message) {
            root.statusText = message
        }
    }

    Timer {
        id: playbackTimer
        interval: Math.max(1, Math.round(1000 / root.fps))
        repeat: true
        running: root.playing
        onTriggered: {
            if (root.currentFrame >= root.totalFrames) {
                root.playing = false
                root.currentFrame = 0
            } else {
                root.currentFrame += 1
            }
        }
    }

    FileDialog {
        id: openDialog
        title: root.t("open")
        fileMode: FileDialog.OpenFile
        nameFilters: ["Rimution Project (*.rim)", "JSON files (*.json)", "All files (*)"]
        onAccepted: root.openFrom(selectedFile)
    }

    FileDialog {
        id: saveDialog
        title: root.t("save")
        fileMode: FileDialog.SaveFile
        nameFilters: ["Rimution Project (*.rim)", "JSON files (*.json)"]
        onAccepted: root.saveTo(selectedFile)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            color: root.panel
            border.color: root.panelBorder
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 14

                Rectangle {
                    width: 32
                    height: 32
                    radius: 9
                    color: root.accent
                    Text {
                        anchors.centerIn: parent
                        text: "R"
                        color: "#151710"
                        font.pixelSize: 20
                        font.bold: true
                    }
                }

                ColumnLayout {
                    spacing: 0
                    Label {
                        text: "Rimution"
                        color: root.brightText
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                    }
                    Label {
                        text: root.t("motion")
                        color: root.mutedText
                        font.pixelSize: 10
                    }
                }

                Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 32; color: root.panelBorder }

                Button {
                    text: root.t("new")
                    onClicked: root.newProject()
                }
                Button {
                    text: root.t("open")
                    onClicked: openDialog.open()
                }
                Button {
                    text: root.t("save")
                    highlighted: true
                    onClicked: saveDialog.open()
                }

                Item { Layout.fillWidth: true }

                TextField {
                    Layout.preferredWidth: 210
                    text: root.projectName
                    selectByMouse: true
                    color: root.brightText
                    placeholderText: "Project name"
                    onTextEdited: root.projectName = text
                    background: Rectangle {
                        radius: 7
                        color: root.panelRaised
                        border.color: root.panelBorder
                    }
                }

                ComboBox {
                    Layout.preferredWidth: 112
                    model: ["Bahasa Indonesia", "English"]
                    currentIndex: root.currentLanguage === "id" ? 0 : 1
                    onActivated: root.currentLanguage = currentIndex === 0 ? "id" : "en"
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Rectangle {
                Layout.preferredWidth: 220
                Layout.fillHeight: true
                color: root.panel
                border.color: root.panelBorder
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 14

                    Label {
                        text: root.t("project")
                        color: root.mutedText
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 58
                        radius: 8
                        color: root.panelRaised
                        border.color: root.panelBorder

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10
                            Rectangle {
                                width: 34
                                height: 34
                                radius: 6
                                color: root.accentDark
                                Text { anchors.centerIn: parent; text: "◈"; color: root.accent; font.pixelSize: 20 }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3
                                Label { text: root.projectName; color: root.brightText; elide: Text.ElideRight; Layout.fillWidth: true }
                                Label { text: root.currentFile === "" ? root.t("noFile") : "*.rim"; color: root.mutedText; font.pixelSize: 10; elide: Text.ElideMiddle; Layout.fillWidth: true }
                            }
                        }
                    }

                    Label {
                        text: root.t("assets")
                        color: root.mutedText
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        topPadding: 8
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Rectangle { width: 30; height: 30; radius: 6; color: "#C6F36B" }
                        ColumnLayout {
                            spacing: 2
                            Label { text: "Shape 01"; color: root.brightText; font.pixelSize: 12 }
                            Label { text: "Vector shape"; color: root.mutedText; font.pixelSize: 10 }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Rectangle { width: 30; height: 30; radius: 6; color: "#2B303C"; border.color: "#454B59" }
                        ColumnLayout {
                            spacing: 2
                            Label { text: root.t("background"); color: root.brightText; font.pixelSize: 12 }
                            Label { text: "Composition"; color: root.mutedText; font.pixelSize: 10 }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 74
                        radius: 8
                        color: "#20251A"
                        border.color: "#39452A"
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 4
                            Label { text: "MVP 0.1"; color: root.accent; font.pixelSize: 11; font.bold: true }
                            Label {
                                Layout.fillWidth: true
                                text: "2D motion · Keyframes · Project files"
                                color: root.mutedText
                                font.pixelSize: 10
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#111318"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: root.t("composition"); color: root.brightText; font.pixelSize: 13; font.weight: Font.DemiBold }
                            Item { Layout.fillWidth: true }
                            Label { text: "1920 × 1080"; color: root.mutedText; font.pixelSize: 11 }
                            Rectangle { width: 1; height: 18; color: root.panelBorder }
                            Label { text: root.fps + " FPS"; color: root.mutedText; font.pixelSize: 11 }
                        }

                        Item {
                            id: stageViewport
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true

                            Rectangle {
                                id: stage
                                width: 800
                                height: 450
                                radius: 2
                                anchors.centerIn: parent
                                color: "#0C0E12"
                                border.color: "#343844"
                                border.width: 1

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 24
                                    color: "transparent"
                                    border.color: "#272B34"
                                    border.width: 1
                                }

                                Rectangle {
                                    width: 160 * root.valueAt("scale", root.currentFrame) / 100
                                    height: 160 * root.valueAt("scale", root.currentFrame) / 100
                                    x: root.valueAt("x", root.currentFrame)
                                    y: root.valueAt("y", root.currentFrame)
                                    rotation: root.valueAt("rotation", root.currentFrame)
                                    radius: 24
                                    color: root.accent
                                    opacity: Math.max(0, Math.min(1, root.valueAt("opacity", root.currentFrame) / 100))
                                    border.color: "#E4FFAC"
                                    border.width: 1

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: parent.width * 0.38
                                        height: parent.height * 0.38
                                        radius: width / 2
                                        color: "#22271A"
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 16
                                        text: "R"
                                        color: "#171B11"
                                        font.pixelSize: 26
                                        font.bold: true
                                    }
                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.bottom: parent.bottom
                                    anchors.leftMargin: 14
                                    anchors.bottomMargin: 10
                                    text: "RIMUTION / PREVIEW"
                                    color: "#687080"
                                    font.pixelSize: 9
                                    font.letterSpacing: 1.2
                                }

                                MouseArea {
                                    id: canvasMouseArea
                                    anchors.fill: parent
                                    z: 100
                                    acceptedButtons: Qt.LeftButton
                                    preventStealing: true
                                    property bool draggingObject: false
                                    property real dragOffsetX: 0
                                    property real dragOffsetY: 0
                                    cursorShape: draggingObject ? Qt.ClosedHandCursor : Qt.ArrowCursor

                                    onPressed: function(mouse) {
                                        const objectX = root.valueAt("x", root.currentFrame)
                                        const objectY = root.valueAt("y", root.currentFrame)
                                        const objectSize = 160 * root.valueAt("scale", root.currentFrame) / 100
                                        if (mouse.x >= objectX && mouse.x <= objectX + objectSize &&
                                            mouse.y >= objectY && mouse.y <= objectY + objectSize) {
                                            draggingObject = true
                                            dragOffsetX = mouse.x - objectX
                                            dragOffsetY = mouse.y - objectY
                                            mouse.accepted = true
                                        } else {
                                            draggingObject = false
                                            mouse.accepted = false
                                        }
                                    }

                                    onPositionChanged: function(mouse) {
                                        if (!draggingObject)
                                            return
                                        const objectSize = 160 * root.valueAt("scale", root.currentFrame) / 100
                                        const nextX = Math.max(0, Math.min(stage.width - objectSize, mouse.x - dragOffsetX))
                                        const nextY = Math.max(0, Math.min(stage.height - objectSize, mouse.y - dragOffsetY))
                                        root.setCurrentProperty("x", nextX)
                                        root.setCurrentProperty("y", nextY)
                                    }

                                    onReleased: draggingObject = false
                                    onCanceled: draggingObject = false
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: root.t("canvasHint") + " · " + root.t("dragObject"); color: root.mutedText; font.pixelSize: 10 }
                            Item { Layout.fillWidth: true }
                            Label { text: root.t("frame") + " " + root.currentFrame + " / " + root.totalFrames; color: root.mutedText; font.pixelSize: 10; font.family: "monospace" }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 238
                    color: root.panel
                    border.color: root.panelBorder
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: root.t("timeline"); color: root.brightText; font.pixelSize: 13; font.weight: Font.DemiBold }
                            Item { Layout.fillWidth: true }
                            Button {
                                text: root.t("addKeyframe")
                                highlighted: true
                                onClicked: root.addKeyframe()
                            }
                            Button {
                                text: root.playing ? "Ⅱ  " + root.t("pause") : "▶  " + root.t("play")
                                onClicked: root.playing = !root.playing
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            Label { text: "00:" + (Math.floor(root.currentFrame / root.fps)).toString().padStart(2, "0") + ":" + (Math.floor((root.currentFrame % root.fps) * 100 / root.fps)).toString().padStart(2, "0"); color: root.accent; font.family: "monospace"; font.pixelSize: 12 }
                            Slider {
                                id: timelineSlider
                                Layout.fillWidth: true
                                from: 0
                                to: root.totalFrames
                                stepSize: 1
                                value: root.currentFrame
                                onMoved: root.currentFrame = Math.round(value)
                            }
                            Label { text: root.totalFrames + " fr"; color: root.mutedText; font.pixelSize: 10 }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: root.panelBorder }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Rectangle {
                                Layout.preferredWidth: 176
                                Layout.preferredHeight: 58
                                color: root.panelRaised
                                radius: 6
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    Rectangle { width: 7; height: 30; radius: 3; color: root.accent }
                                    ColumnLayout {
                                        spacing: 3
                                        Label { text: root.t("layer"); color: root.brightText; font.pixelSize: 11 }
                                        Label { text: "Transform · 4 keys"; color: root.mutedText; font.pixelSize: 9 }
                                    }
                                }
                            }
                            Item {
                                id: keyframeArea
                                Layout.fillWidth: true
                                Layout.preferredHeight: 58
                                Layout.leftMargin: 12

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: 28
                                    radius: 4
                                    color: "#262A33"
                                }

                                Repeater {
                                    model: root.keyframes
                                    delegate: Rectangle {
                                        required property var modelData
                                        width: 9
                                        height: 9
                                        radius: 2
                                        rotation: 45
                                        color: root.accent
                                        x: Math.max(0, Math.min(keyframeArea.width - width, (Number(modelData.frame) / root.totalFrames) * (keyframeArea.width - width)))
                                        anchors.verticalCenter: parent.verticalCenter
                                        border.color: "#E9FFC2"
                                        border.width: 1
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.currentFrame = Number(modelData.frame)
                                                root.statusText = root.t("frame") + " " + root.currentFrame
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    width: 2
                                    height: 54
                                    x: Math.max(0, Math.min(keyframeArea.width - width, (root.currentFrame / root.totalFrames) * keyframeArea.width))
                                    y: 2
                                    color: "#F4F5F8"
                                    Rectangle { anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; width: 8; height: 8; radius: 2; color: "#F4F5F8" }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 284
                Layout.fillHeight: true
                color: root.panel
                border.color: root.panelBorder
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 16

                    Label {
                        text: root.t("properties")
                        color: root.brightText
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: root.panelBorder }

                    Label {
                        text: root.t("transform")
                        color: root.mutedText
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: root.t("positionX"); color: root.brightText; font.pixelSize: 11 }
                            Item { Layout.fillWidth: true }
                            SpinBox {
                                Layout.preferredWidth: 96
                                from: 0
                                to: 800
                                editable: true
                                value: Math.round(root.valueAt("x", root.currentFrame))
                                onValueModified: root.setCurrentProperty("x", value)
                            }
                        }
                        Slider { Layout.fillWidth: true; from: 0; to: 800; value: root.valueAt("x", root.currentFrame); onMoved: root.setCurrentProperty("x", value) }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: root.t("positionY"); color: root.brightText; font.pixelSize: 11 }
                            Item { Layout.fillWidth: true }
                            SpinBox {
                                Layout.preferredWidth: 96
                                from: 0
                                to: 450
                                editable: true
                                value: Math.round(root.valueAt("y", root.currentFrame))
                                onValueModified: root.setCurrentProperty("y", value)
                            }
                        }
                        Slider { Layout.fillWidth: true; from: 0; to: 450; value: root.valueAt("y", root.currentFrame); onMoved: root.setCurrentProperty("y", value) }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: root.t("scale"); color: root.brightText; font.pixelSize: 11 }
                            Item { Layout.fillWidth: true }
                            SpinBox {
                                Layout.preferredWidth: 96
                                from: 10
                                to: 300
                                editable: true
                                value: Math.round(root.valueAt("scale", root.currentFrame))
                                textFromValue: function(value) { return value + "%" }
                                valueFromText: function(text) { return Number(text.replace("%", "")) }
                                onValueModified: root.setCurrentProperty("scale", value)
                            }
                        }
                        Slider { Layout.fillWidth: true; from: 10; to: 300; value: root.valueAt("scale", root.currentFrame); onMoved: root.setCurrentProperty("scale", value) }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: root.t("rotation"); color: root.brightText; font.pixelSize: 11 }
                            Item { Layout.fillWidth: true }
                            SpinBox {
                                Layout.preferredWidth: 96
                                from: -360
                                to: 360
                                editable: true
                                value: Math.round(root.valueAt("rotation", root.currentFrame))
                                textFromValue: function(value) { return value + "°" }
                                valueFromText: function(text) { return Number(text.replace("°", "")) }
                                onValueModified: root.setCurrentProperty("rotation", value)
                            }
                        }
                        Slider { Layout.fillWidth: true; from: -360; to: 360; value: root.valueAt("rotation", root.currentFrame); onMoved: root.setCurrentProperty("rotation", value) }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: root.t("opacity"); color: root.brightText; font.pixelSize: 11 }
                            Item { Layout.fillWidth: true }
                            SpinBox {
                                Layout.preferredWidth: 96
                                from: 0
                                to: 100
                                editable: true
                                value: Math.round(root.valueAt("opacity", root.currentFrame))
                                textFromValue: function(value) { return value + "%" }
                                valueFromText: function(text) { return Number(text.replace("%", "")) }
                                onValueModified: root.setCurrentProperty("opacity", value)
                            }
                        }
                        Slider { Layout.fillWidth: true; from: 0; to: 100; value: root.valueAt("opacity", root.currentFrame); onMoved: root.setCurrentProperty("opacity", value) }
                    }

                    Item { Layout.fillHeight: true }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 94
                        radius: 8
                        color: root.panelRaised
                        border.color: root.panelBorder
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 5
                            Label { text: "KEYFRAME INFO"; color: root.mutedText; font.pixelSize: 9; font.letterSpacing: 1 }
                            Label { text: root.keyframes.length + " keyframes"; color: root.brightText; font.pixelSize: 15; font.weight: Font.DemiBold }
                            Label { text: "Linear interpolation"; color: root.mutedText; font.pixelSize: 10 }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            color: "#14161B"
            border.color: root.panelBorder
            border.width: 1
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                Label { text: root.statusText; color: root.mutedText; font.pixelSize: 10; Layout.fillWidth: true; elide: Text.ElideRight }
                Label { text: "Rimution 0.1.0  ·  Qt 6  ·  " + root.fps + " FPS"; color: "#656C7B"; font.pixelSize: 10 }
            }
        }
    }

    palette.window: "#111318"
    palette.windowText: brightText
    palette.base: panelRaised
    palette.alternateBase: panel
    palette.text: brightText
    palette.button: panelRaised
    palette.buttonText: brightText
    palette.highlight: accent
    palette.highlightedText: "#151710"
    palette.mid: panelBorder
    palette.dark: "#0D0E12"
    palette.light: "#3A3E49"
}
