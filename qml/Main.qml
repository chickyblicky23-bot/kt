import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtCore

ApplicationWindow {
    id: root
    width: 560
    height: 820
    minimumWidth: 480
    minimumHeight: 640
    visible: true
    title: "Key Trainer"
    color: "#0e1116"

    // ── constants (change laneKeys to remap) ──
    readonly property var laneKeys: [Qt.Key_D, Qt.Key_F, Qt.Key_J, Qt.Key_K]
    readonly property var laneNames: ["D", "F", "J", "K"]
    readonly property var laneColors: ["#6ea8ff", "#ff7ab6", "#ff7ab6", "#6ea8ff"]
    readonly property var windowsMs: [40, 80, 120, 150]            // Perfect, Great, Good, Bad
    readonly property var judgeNames: ["Perfect", "Great", "Good", "Bad", "Miss"]
    readonly property var judgeColors: ["#7dffb0", "#6ee0ff", "#ffe36e", "#ff9d5c", "#ff5c6e"]
    readonly property var judgeWeight: [1, 0.8, 0.5, 0.2, 0]
    readonly property var stepOptions: [1, 2, 4]

    // ── settings (saved between runs) ──
    property int mode: 0
    property int bpm: 160
    property int stepIndex: 1
    property int seconds: 45
    property int speed: 6
    property string customText: "d f j k dj fk"
    Settings {
        category: "trainer"
        property alias mode: root.mode
        property alias bpm: root.bpm
        property alias stepIndex: root.stepIndex
        property alias seconds: root.seconds
        property alias speed: root.speed
        property alias customText: root.customText
    }

    // ── run state ──
    property string screen: "menu"          // menu | play | results
    property var notes: []
    property int firstOpen: 0
    property real now: 0
    property real startedAt: 0
    property var counts: [0, 0, 0, 0, 0]
    property int combo: 0
    property int maxCombo: 0
    property real offsetSum: 0
    property int offsetN: 0
    property var pressed: [false, false, false, false]
    property int lastJudgeIdx: 0
    property real lastJudgeAt: -1e9
    property real lastOffset: 0

    // ── pattern generation ──
    function makePattern() {
        const stepMs = 60000 / bpm / stepOptions[stepIndex]
        const count = Math.floor(seconds * 1000 / stepMs)
        const out = []
        const add = (i, lane) => out.push({ t: i * stepMs, lane: lane, judged: false })
        const coin = () => Math.random() < 0.5 ? 0 : 1
        let hand = coin(), prev = -1

        if (mode === 0) {                                   // streams: alternate hands
            for (let i = 0; i < count; i++) {
                hand = 1 - hand
                add(i, hand * 2 + coin())
            }
        } else if (mode === 1) {                            // jumpstream: single, single, jump
            for (let i = 0; i < count; i++) {
                if (i % 3 === 2) { add(i, coin()); add(i, 2 + coin()) }
                else { hand = 1 - hand; add(i, hand * 2 + coin()) }
            }
        } else if (mode === 2) {                            // trills: two adjacent lanes, back and forth
            let a = 0, b = 1
            for (let i = 0; i < count; i++) {
                if (i % 8 === 0) {
                    const p = Math.floor(Math.random() * 3)
                    a = p; b = p + 1
                    if (prev === a) { const tmp = a; a = b; b = tmp }
                }
                prev = (i % 2 === 0) ? a : b
                add(i, prev)
            }
        } else if (mode === 3) {                            // random singles, no repeats
            for (let i = 0; i < count; i++) {
                let l = Math.floor(Math.random() * 4)
                while (l === prev) l = Math.floor(Math.random() * 4)
                prev = l
                add(i, l)
            }
        } else {                                            // custom: tokens of d/f/j/k, e.g. "d f j k dj fk"
            let tokens = customText.toLowerCase().split(/\s+/).filter(t => /[dfjk]/.test(t))
            if (tokens.length === 0) tokens = ["d", "f", "j", "k"]
            for (let i = 0; i < count; i++) {
                const tok = tokens[i % tokens.length]
                const seen = {}
                for (const ch of tok) {
                    const l = "dfjk".indexOf(ch)
                    if (l >= 0 && !seen[l]) { seen[l] = true; add(i, l) }
                }
            }
        }
        return out
    }

    // ── game flow ──
    function start() {
        notes = makePattern()
        firstOpen = 0
        counts = [0, 0, 0, 0, 0]
        combo = 0; maxCombo = 0; offsetSum = 0; offsetN = 0
        lastJudgeAt = -1e9
        startedAt = Date.now() + 2000
        now = -2000
        screen = "play"
        game.forceActiveFocus()
    }

    function register(idx, offset) {
        counts[idx]++
        if (idx === 4) combo = 0
        else { combo++; maxCombo = Math.max(maxCombo, combo); offsetSum += offset; offsetN++ }
        lastJudgeIdx = idx
        lastOffset = offset
        lastJudgeAt = now
    }

    function press(lane) {
        if (screen !== "play") return
        const t = Date.now() - startedAt
        let best = -1, bestDist = 1e9
        for (let i = firstOpen; i < notes.length; i++) {
            const n = notes[i]
            if (n.t > t + windowsMs[3]) break
            if (n.judged || n.lane !== lane) continue
            const d = Math.abs(n.t - t)
            if (d < bestDist) { bestDist = d; best = i }
        }
        if (best < 0 || bestDist > windowsMs[3]) return
        notes[best].judged = true
        let idx = 3
        for (let k = 0; k < 4; k++) if (bestDist <= windowsMs[k]) { idx = k; break }
        register(idx, t - notes[best].t)
    }

    function frame() {
        now = Date.now() - startedAt
        while (firstOpen < notes.length && notes[firstOpen].judged) firstOpen++
        for (let i = firstOpen; i < notes.length && notes[i].t < now - windowsMs[3]; i++) {
            if (!notes[i].judged) { notes[i].judged = true; register(4, 0) }
        }
        while (firstOpen < notes.length && notes[firstOpen].judged) firstOpen++
        if (notes.length > 0 && firstOpen >= notes.length && now > notes[notes.length - 1].t + 700)
            finish()
        field.requestPaint()
    }

    function finish() {
        counts = counts.slice()          // notify bindings on the results screen
        screen = "results"
    }

    function accuracy() {
        let total = 0, score = 0
        for (let i = 0; i < 5; i++) { total += counts[i]; score += counts[i] * judgeWeight[i] }
        return total > 0 ? 100 * score / total : 0
    }

    Timer { interval: 8; repeat: true; running: root.screen === "play"; onTriggered: root.frame() }

    // ── input ──
    Item {
        id: game
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.isAutoRepeat) return
            const i = root.laneKeys.indexOf(event.key)
            if (i >= 0) { root.pressed[i] = true; root.press(i); event.accepted = true }
            else if (event.key === Qt.Key_Escape && root.screen === "play") { root.screen = "menu"; event.accepted = true }
        }
        Keys.onReleased: event => {
            if (event.isAutoRepeat) return
            const i = root.laneKeys.indexOf(event.key)
            if (i >= 0) { root.pressed[i] = false; event.accepted = true }
        }
    }

    // ── playfield ──
    Canvas {
        id: field
        anchors.fill: parent
        visible: root.screen !== "menu"
        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            const laneW = Math.min(96, (width - 40) / 4)
            const x0 = (width - laneW * 4) / 2
            const hitY = height - 130
            const noteH = 24
            const pxPerMs = 0.25 + root.speed * 0.08

            for (let l = 0; l < 4; l++) {
                const x = x0 + l * laneW
                ctx.fillStyle = root.pressed[l] ? "rgba(255,255,255,0.14)" : "rgba(255,255,255,0.04)"
                ctx.fillRect(x, 0, laneW, height)
                ctx.fillStyle = "rgba(255,255,255,0.08)"
                ctx.fillRect(x, 0, 1, height)
            }
            ctx.fillStyle = "rgba(255,255,255,0.08)"
            ctx.fillRect(x0 + 4 * laneW, 0, 1, height)

            if (root.screen === "play") {
                for (let i = root.firstOpen; i < root.notes.length; i++) {
                    const n = root.notes[i]
                    const y = hitY - (n.t - root.now) * pxPerMs
                    if (y < -noteH) break
                    if (n.judged) continue
                    ctx.fillStyle = root.laneColors[n.lane]
                    ctx.beginPath()
                    ctx.roundedRect(x0 + n.lane * laneW + 6, y - noteH / 2, laneW - 12, noteH, 6, 6)
                    ctx.fill()
                }
            }

            // receptors + key labels
            ctx.textAlign = "center"
            for (let l = 0; l < 4; l++) {
                const rx = x0 + l * laneW + 6
                ctx.beginPath()
                ctx.roundedRect(rx, hitY - noteH / 2, laneW - 12, noteH, 6, 6)
                if (root.pressed[l]) { ctx.fillStyle = root.laneColors[l]; ctx.fill() }
                ctx.strokeStyle = root.laneColors[l]
                ctx.lineWidth = 3
                ctx.stroke()
                ctx.fillStyle = "rgba(255,255,255,0.6)"
                ctx.font = "bold 18px sans-serif"
                ctx.fillText(root.laneNames[l], x0 + l * laneW + laneW / 2, hitY + 44)
            }

            if (root.screen === "play") {
                const cx = width / 2
                if (root.now < 0) {
                    ctx.fillStyle = "#ffffff"
                    ctx.font = "bold 64px sans-serif"
                    ctx.fillText(String(Math.ceil(-root.now / 1000)), cx, height * 0.4)
                }
                const age = root.now - root.lastJudgeAt
                if (age >= 0 && age < 600) {
                    ctx.globalAlpha = 1 - age / 600
                    ctx.fillStyle = root.judgeColors[root.lastJudgeIdx]
                    ctx.font = "bold 30px sans-serif"
                    ctx.fillText(root.judgeNames[root.lastJudgeIdx], cx, height * 0.45)
                    if (root.lastJudgeIdx < 4) {
                        ctx.font = "14px sans-serif"
                        ctx.fillStyle = "#c8d0d8"
                        const o = Math.round(root.lastOffset)
                        ctx.fillText(o === 0 ? "on time" : (Math.abs(o) + " ms " + (o > 0 ? "late" : "early")), cx, height * 0.45 + 24)
                    }
                    ctx.globalAlpha = 1
                }
                if (root.combo > 1) {
                    ctx.fillStyle = "rgba(255,255,255,0.85)"
                    ctx.font = "bold 22px sans-serif"
                    ctx.fillText(root.combo + " combo", cx, height * 0.3)
                }
                ctx.fillStyle = "rgba(255,255,255,0.35)"
                ctx.font = "12px sans-serif"
                ctx.fillText("Esc to stop", cx, 20)
            }
        }
    }

    // ── menu ──
    ColumnLayout {
        visible: root.screen === "menu"
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 420)
        spacing: 14

        Text { text: "Key Trainer"; color: "#f2f4f5"; font.pixelSize: 28; font.bold: true }
        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: "#9aa4ab"
            font.pixelSize: 13
            text: "Practice 4-key patterns on D F J K. Notes fall to the line; press the key as they land."
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 16
            rowSpacing: 10

            Label { text: "Pattern"; color: "#c8d0d8" }
            ComboBox {
                Layout.fillWidth: true
                model: ["Streams", "Jumpstream", "Trills", "Random", "Custom"]
                currentIndex: root.mode
                onActivated: root.mode = currentIndex
            }

            Label { text: "BPM"; color: "#c8d0d8" }
            SpinBox {
                Layout.fillWidth: true
                from: 60; to: 300; stepSize: 5; editable: true
                value: root.bpm
                onValueModified: root.bpm = value
            }

            Label { text: "Note spacing"; color: "#c8d0d8" }
            ComboBox {
                Layout.fillWidth: true
                model: ["Quarter notes", "8th notes", "16th notes"]
                currentIndex: root.stepIndex
                onActivated: root.stepIndex = currentIndex
            }

            Label { text: "Length (seconds)"; color: "#c8d0d8" }
            SpinBox {
                Layout.fillWidth: true
                from: 15; to: 180; stepSize: 15; editable: true
                value: root.seconds
                onValueModified: root.seconds = value
            }

            Label { text: "Scroll speed"; color: "#c8d0d8" }
            Slider {
                Layout.fillWidth: true
                from: 1; to: 10; stepSize: 1
                value: root.speed
                onMoved: root.speed = value
            }

            Label { text: "Custom steps"; color: "#c8d0d8"; visible: root.mode === 4 }
            TextField {
                Layout.fillWidth: true
                visible: root.mode === 4
                text: root.customText
                placeholderText: "d f j k dj fk"
                selectByMouse: true
                onTextEdited: root.customText = text
            }
        }

        Text {
            Layout.fillWidth: true
            visible: root.mode === 4
            wrapMode: Text.WordWrap
            color: "#9aa4ab"
            font.pixelSize: 12
            text: "Each word is one step; letters in a word are pressed together (dj = D and J). The list repeats."
        }

        Button {
            id: startButton
            Layout.fillWidth: true
            text: "Start"
            onClicked: root.start()
            contentItem: Text { text: startButton.text; color: "#06210f"; font.bold: true; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { implicitHeight: 42; radius: 21; color: startButton.hovered ? "#3be477" : "#1ed760" }
        }
    }

    // ── results ──
    ColumnLayout {
        visible: root.screen === "results"
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 360)
        spacing: 8

        Text { text: root.accuracy().toFixed(1) + "%"; color: "#f2f4f5"; font.pixelSize: 54; font.bold: true; Layout.alignment: Qt.AlignHCenter }
        Text { text: "accuracy"; color: "#9aa4ab"; Layout.alignment: Qt.AlignHCenter }
        Item { Layout.preferredHeight: 10 }

        Repeater {
            model: 5
            RowLayout {
                required property int index
                Layout.fillWidth: true
                Text { text: root.judgeNames[index]; color: root.judgeColors[index]; font.pixelSize: 16; Layout.fillWidth: true }
                Text { text: root.counts[index]; color: "#f2f4f5"; font.pixelSize: 16 }
            }
        }

        Item { Layout.preferredHeight: 6 }
        RowLayout {
            Layout.fillWidth: true
            Text { text: "Max combo"; color: "#c8d0d8"; Layout.fillWidth: true }
            Text { text: root.maxCombo; color: "#f2f4f5" }
        }
        RowLayout {
            Layout.fillWidth: true
            readonly property real avg: root.offsetN > 0 ? root.offsetSum / root.offsetN : 0
            Text { text: "Average timing"; color: "#c8d0d8"; Layout.fillWidth: true }
            Text { text: Math.abs(parent.avg).toFixed(1) + " ms " + (parent.avg > 0 ? "late" : "early"); color: "#f2f4f5" }
        }
        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: "#9aa4ab"
            font.pixelSize: 12
            readonly property real avg: root.offsetN > 0 ? root.offsetSum / root.offsetN : 0
            text: avg > 15 ? "You tend to hit late. Try pressing a touch sooner."
                  : avg < -15 ? "You tend to hit early. Try waiting a touch longer."
                  : "Your timing is well centered."
        }

        Item { Layout.preferredHeight: 10 }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Button { Layout.fillWidth: true; text: "Retry"; onClicked: root.start() }
            Button { Layout.fillWidth: true; text: "Menu"; onClicked: root.screen = "menu" }
        }
    }
}
