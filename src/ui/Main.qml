import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtMultimedia
import Rimution 1.0

ApplicationWindow {
    id: root
    visible: true
    width: 1510
    height: 940
    minimumWidth: 1120
    minimumHeight: 760
    title: "Rimution 0.2 — Media Studio"
    color: "#101116"

    property string currentLanguage: "id"
    property string projectName: "Untitled Project"
    property string currentFile: ""
    property string statusText: "Siap · Media diproses lokal"
    property string previewKind: "none"
    property url previewImageSource: ""
    property string activeVisualId: ""
    property string activeAudioId: ""
    property string selectedId: ""
    property string selectedType: "none"
    property string selectedAssetPath: ""
    property string lastExportMessage: ""
    property int currentFrame: 0
    property int fps: 24
    property int compositionWidth: 1920
    property int compositionHeight: 1080
    property int inspectorTab: 0
    property int serial: 1
    property int pendingSeekMs: 0
    property int pendingAudioSeekMs: 0
    property real currentTime: 0
    property real zoom: 72
    property real previewVolume: 1.0
    property real musicVolume: 0.85
    property bool playing: false
    property bool motionOverlayEnabled: false
    property bool syncingPlayer: false
    property bool exportDialogVisible: false

    property var assets: []
    property var videoClips: []
    property var audioClips: []
    property var keyframes: [
        { "frame": 0, "x": 320, "y": 165, "scale": 100, "rotation": 0, "opacity": 100 },
        { "frame": 120, "x": 520, "y": 215, "scale": 120, "rotation": 0, "opacity": 100 }
    ]
    property var undoStack: []
    property var redoStack: []

    readonly property color bg: "#101116"
    readonly property color panel: "#191b23"
    readonly property color raised: "#222530"
    readonly property color borderColor: "#343846"
    readonly property color textColor: "#f1f2f7"
    readonly property color muted: "#969caf"
    readonly property color lime: "#c6f36b"
    readonly property color purple: "#9b8cff"
    readonly property color cyan: "#62e6d5"
    readonly property color orange: "#ffbd69"
    readonly property color red: "#ff7187"

    function tr(id, en) { return currentLanguage === "id" ? id : en }
    function uid() { serial += 1; return "clip-" + serial + "-" + Math.round(Date.now() % 1000000) }
    function timecode(seconds) {
        const ms = Math.max(0, Math.floor(Number(seconds || 0) * 1000))
        const h = Math.floor(ms / 3600000)
        const m = Math.floor((ms % 3600000) / 60000)
        const s = Math.floor((ms % 60000) / 1000)
        const centi = Math.floor((ms % 1000) / 10)
        return (h ? String(h).padStart(2, "0") + ":" : "") +
               String(m).padStart(2, "0") + ":" + String(s).padStart(2, "0") + "." + String(centi).padStart(2, "0")
    }
    function fmtDuration(seconds) { return Number(seconds || 0).toFixed(2) + " s" }
    function mediaLabel(kind) {
        if (kind === "video") return "VIDEO"
        if (kind === "audio") return "AUDIO"
        if (kind === "image") return "IMAGE"
        return "MEDIA"
    }
    function visualDuration() {
        let total = 0
        for (let i = 0; i < videoClips.length; ++i)
            total += Math.max(0, Number(videoClips[i].duration || 0))
        return total
    }
    function audioEndTime() {
        let end = 0
        for (let i = 0; i < audioClips.length; ++i)
            end = Math.max(end, Number(audioClips[i].start || 0) + Number(audioClips[i].duration || 0))
        return end
    }
    function timelineDuration() {
        let motionEnd = 0
        for (let i = 0; i < keyframes.length; ++i)
            motionEnd = Math.max(motionEnd, Number(keyframes[i].frame || 0) / fps)
        return Math.max(1, visualDuration(), audioEndTime(), motionEnd)
    }
    function timelineWidth() { return 86 + timelineDuration() * zoom + 160 }
    function clipStart(index) {
        let total = 0
        for (let i = 0; i < index && i < videoClips.length; ++i)
            total += Number(videoClips[i].duration || 0)
        return total
    }
    function clipIndexAtTime(time) {
        let cursor = 0
        for (let i = 0; i < videoClips.length; ++i) {
            const end = cursor + Number(videoClips[i].duration || 0)
            if (time < end || (i === videoClips.length - 1 && time <= end + 0.001))
                return i
            cursor = end
        }
        return -1
    }
    function getSelectedVisual() {
        for (let i = 0; i < videoClips.length; ++i)
            if (videoClips[i].id === selectedId && selectedType === "visual") return videoClips[i]
        return null
    }
    function getSelectedAudio() {
        for (let i = 0; i < audioClips.length; ++i)
            if (audioClips[i].id === selectedId && selectedType === "audio") return audioClips[i]
        return null
    }
    function selectedAsset() {
        for (let i = 0; i < assets.length; ++i)
            if (assets[i].path === selectedAssetPath) return assets[i]
        return null
    }
    function findVisualIndex(id) {
        for (let i = 0; i < videoClips.length; ++i)
            if (videoClips[i].id === id) return i
        return -1
    }
    function stateSnapshot() {
        return JSON.stringify({
            projectName: projectName, assets: assets, videoClips: videoClips, audioClips: audioClips,
            keyframes: keyframes, currentTime: currentTime, selectedId: selectedId,
            selectedType: selectedType, motionOverlayEnabled: motionOverlayEnabled
        })
    }
    function pushUndo() {
        const next = undoStack.slice()
        next.push(stateSnapshot())
        if (next.length > 80) next.shift()
        undoStack = next
        redoStack = []
    }
    function restoreSnapshot(raw) {
        const s = JSON.parse(raw)
        projectName = s.projectName || "Untitled Project"
        assets = s.assets || assets
        videoClips = s.videoClips || []
        audioClips = s.audioClips || []
        keyframes = s.keyframes || []
        currentTime = Number(s.currentTime || 0)
        selectedId = s.selectedId || ""
        selectedType = s.selectedType || "none"
        motionOverlayEnabled = !!s.motionOverlayEnabled
        currentFrame = Math.round(currentTime * fps)
        syncPreview(true)
        syncAudio(true)
    }
    function undo() {
        if (undoStack.length === 0) return
        const previous = undoStack.slice()
        const raw = previous.pop()
        redoStack = redoStack.concat([stateSnapshot()])
        undoStack = previous
        restoreSnapshot(raw)
        statusText = tr("Perubahan dibatalkan", "Undo")
    }
    function redo() {
        if (redoStack.length === 0) return
        const next = redoStack.slice()
        const raw = next.pop()
        undoStack = undoStack.concat([stateSnapshot()])
        redoStack = next
        restoreSnapshot(raw)
        statusText = tr("Perubahan dipulihkan", "Redo")
    }

    function importMedia(urls) {
        let added = 0
        let errors = []
        for (let i = 0; i < urls.length; ++i) {
            const path = urls[i].toLocalFile()
            if (!path) continue
            let exists = false
            for (let j = 0; j < assets.length; ++j)
                if (assets[j].path === path) exists = true
            if (exists) continue
            const info = mediaController.probeMedia(path)
            if (info.error) {
                errors.push(info.name || path.split("/").pop())
                continue
            }
            assets = assets.concat([info])
            added += 1
            selectedAssetPath = info.path
        }
        if (added > 0) statusText = tr("Media diimpor: ", "Imported media: ") + added
        else statusText = errors.length ? tr("Sebagian berkas tidak dapat dibaca", "Some files could not be read") : tr("Media sudah ada di bin", "Media already in the bin")
        if (errors.length) statusText += " · " + errors.slice(0, 2).join(", ")
    }
    function addSelectedAsset() {
        const asset = selectedAsset()
        if (!asset) {
            statusText = tr("Pilih media dari bin terlebih dahulu", "Select media in the bin first")
            return
        }
        pushUndo()
        if (asset.kind === "audio") {
            const duration = Math.max(0.01, Number(asset.duration || 0))
            const clip = {
                id: uid(), path: asset.path, name: asset.name, kind: "audio",
                sourceIn: 0, sourceOut: duration, duration: duration,
                start: Math.max(0, currentTime), volume: 100, hasAudio: true
            }
            audioClips = audioClips.concat([clip])
            selectedId = clip.id
            selectedType = "audio"
            statusText = tr("Audio ditambahkan ke A1", "Audio added to A1")
        } else {
            const duration = asset.kind === "image" ? 3.0 : Math.max(0.05, Number(asset.duration || 0))
            const clip = {
                id: uid(), path: asset.path, name: asset.name, kind: asset.kind,
                sourceIn: 0, sourceOut: duration, duration: duration,
                hasAudio: !!asset.hasAudio, width: asset.width || 0, height: asset.height || 0
            }
            videoClips = videoClips.concat([clip])
            selectedId = clip.id
            selectedType = "visual"
            currentTime = clipStart(videoClips.length - 1)
            syncPreview(true)
            statusText = tr("Klip ditambahkan ke V1", "Clip added to V1")
        }
        syncAudio(true)
    }
    function selectVisual(id) {
        selectedId = id
        selectedType = "visual"
        inspectorTabs.currentIndex = 0
    }
    function selectAudio(id) {
        selectedId = id
        selectedType = "audio"
        inspectorTabs.currentIndex = 0
    }
    function moveSelectedVisual(direction) {
        const index = findVisualIndex(selectedId)
        const target = index + direction
        if (index < 0 || target < 0 || target >= videoClips.length) return
        pushUndo()
        const next = videoClips.slice()
        const tmp = next[index]
        next[index] = next[target]
        next[target] = tmp
        videoClips = next
        currentTime = clipStart(target)
        syncPreview(true)
        statusText = tr("Urutan klip diperbarui", "Clip order updated")
    }
    function removeSelectedClip() {
        if (selectedType === "visual") {
            const index = findVisualIndex(selectedId)
            if (index < 0) return
            pushUndo()
            const next = videoClips.slice()
            next.splice(index, 1)
            videoClips = next
            selectedId = ""
            selectedType = "none"
            currentTime = Math.min(currentTime, visualDuration())
            syncPreview(true)
        } else if (selectedType === "audio") {
            const nextIndex = audioClips.findIndex(function(c) { return c.id === selectedId })
            if (nextIndex < 0) return
            pushUndo()
            const next = audioClips.slice()
            next.splice(nextIndex, 1)
            audioClips = next
            selectedId = ""
            selectedType = "none"
            syncAudio(true)
        }
        statusText = tr("Klip dihapus", "Clip removed")
    }
    function splitSelectedClip() {
        const index = findVisualIndex(selectedId)
        if (index < 0) return
        const clip = videoClips[index]
        const localTime = currentTime - clipStart(index)
        if (localTime < 0.08 || localTime > Number(clip.duration) - 0.08) {
            statusText = tr("Playhead harus berada di dalam klip", "Move the playhead inside the clip to split")
            return
        }
        pushUndo()
        const left = Object.assign({}, clip)
        const right = Object.assign({}, clip)
        left.sourceOut = Number(clip.sourceIn) + localTime
        left.duration = localTime
        right.id = uid()
        right.sourceIn = Number(clip.sourceIn) + localTime
        right.duration = Number(clip.sourceOut) - right.sourceIn
        const next = videoClips.slice()
        next.splice(index, 1, left, right)
        videoClips = next
        selectedId = right.id
        selectedType = "visual"
        syncPreview(true)
        statusText = tr("Klip dipotong pada ", "Clip split at ") + timecode(currentTime)
    }
    function applyVisualTrim() {
        const clip = getSelectedVisual()
        if (!clip) return
        const sourceIn = Number(visualInField.text)
        const sourceOut = Number(visualOutField.text)
        if (!isFinite(sourceIn) || !isFinite(sourceOut) || sourceIn < 0 || sourceOut <= sourceIn + 0.04) {
            statusText = tr("Rentang In/Out tidak valid", "Invalid In/Out range")
            return
        }
        const info = mediaController.probeMedia(clip.path)
        if (info.duration > 0 && sourceOut > Number(info.duration) + 0.02) {
            statusText = tr("Out melebihi durasi sumber", "Out exceeds source duration")
            return
        }
        pushUndo()
        const next = videoClips.slice()
        const index = findVisualIndex(clip.id)
        const changed = Object.assign({}, clip, {
            sourceIn: sourceIn, sourceOut: sourceOut, duration: sourceOut - sourceIn
        })
        next[index] = changed
        videoClips = next
        currentTime = clipStart(index)
        syncPreview(true)
        statusText = tr("Trim diterapkan", "Trim applied")
    }
    function applyAudioRange() {
        const clip = getSelectedAudio()
        if (!clip) return
        const sourceIn = Number(audioInField.text)
        const sourceOut = Number(audioOutField.text)
        if (!isFinite(sourceIn) || !isFinite(sourceOut) || sourceIn < 0 || sourceOut <= sourceIn + 0.04) {
            statusText = tr("Rentang audio tidak valid", "Invalid audio range")
            return
        }
        const info = mediaController.probeMedia(clip.path)
        if (info.duration > 0 && sourceOut > Number(info.duration) + 0.02) {
            statusText = tr("Out melebihi durasi sumber", "Out exceeds source duration")
            return
        }
        pushUndo()
        const next = audioClips.slice()
        const index = next.findIndex(function(c) { return c.id === clip.id })
        next[index] = Object.assign({}, clip, { sourceIn: sourceIn, sourceOut: sourceOut, duration: sourceOut - sourceIn })
        audioClips = next
        syncAudio(true)
        statusText = tr("Trim audio diterapkan", "Audio trim applied")
    }
    function applyAudioStart() {
        const clip = getSelectedAudio()
        if (!clip) return
        const start = Number(audioStartField.text)
        if (!isFinite(start) || start < 0) {
            statusText = tr("Waktu mulai tidak valid", "Invalid start time")
            return
        }
        pushUndo()
        audioClips = audioClips.map(function(c) {
            return c.id === clip.id ? Object.assign({}, c, { start: start }) : c
        })
        syncAudio(true)
    }
    function applyAudioVolume(value) {
        const clip = getSelectedAudio()
        if (!clip) return
        audioClips = audioClips.map(function(c) {
            return c.id === clip.id ? Object.assign({}, c, { volume: Math.round(value) }) : c
        })
    }
    function seekTime(time, force) {
        const end = Math.max(visualDuration(), audioEndTime(), 0)
        currentTime = Math.max(0, Math.min(Number(time || 0), Math.max(end, 0.01)))
        currentFrame = Math.round(currentTime * fps)
        syncPreview(force !== false)
        syncAudio(true)
    }
    function syncPreview(forceSeek) {
        const index = clipIndexAtTime(currentTime)
        if (index < 0) {
            activeVisualId = ""
            previewKind = "none"
            previewImageSource = ""
            if (videoPlayer.playbackState === MediaPlayer.PlayingState) videoPlayer.pause()
            return
        }
        const clip = videoClips[index]
        const start = clipStart(index)
        const local = Math.max(0, currentTime - start)
        previewKind = clip.kind
        activeVisualId = clip.id
        if (clip.kind === "image") {
            if (videoPlayer.playbackState === MediaPlayer.PlayingState) videoPlayer.pause()
            previewImageSource = mediaController.fileUrl(clip.path)
            return
        }
        previewImageSource = ""
        const url = mediaController.fileUrl(clip.path)
        if (videoPlayer.source.toString() !== url.toString() || pendingClipId !== clip.id) {
            pendingClipId = clip.id
            pendingSeekMs = Math.round((Number(clip.sourceIn) + local) * 1000)
            videoPlayer.stop()
            videoPlayer.source = url
            return
        }
        if (forceSeek && videoPlayer.mediaStatus === MediaPlayer.LoadedMedia)
            videoPlayer.position = Math.round((Number(clip.sourceIn) + local) * 1000)
        if (playing) videoPlayer.play()
        else videoPlayer.pause()
    }
    function syncAudio(forceSeek) {
        let found = null
        for (let i = 0; i < audioClips.length; ++i) {
            const c = audioClips[i]
            const start = Number(c.start || 0)
            if (currentTime >= start && currentTime < start + Number(c.duration || 0)) {
                found = c
                break
            }
        }
        if (!found) {
            if (audioPlayer.playbackState === MediaPlayer.PlayingState) audioPlayer.pause()
            activeAudioId = ""
            return
        }
        const url = mediaController.fileUrl(found.path)
        const target = Number(found.sourceIn) + Math.max(0, currentTime - Number(found.start || 0))
        if (activeAudioId !== found.id || audioPlayer.source.toString() !== url.toString()) {
            activeAudioId = found.id
            pendingAudioSeekMs = Math.round(target * 1000)
            audioPlayer.stop()
            audioPlayer.source = url
            return
        }
        if (forceSeek && audioPlayer.mediaStatus === MediaPlayer.LoadedMedia)
            audioPlayer.position = Math.round(target * 1000)
        if (playing) audioPlayer.play()
        else audioPlayer.pause()
    }
    function handleVideoPosition(position) {
        if (!playing || syncingPlayer) return
        const index = findVisualIndex(activeVisualId)
        if (index < 0) return
        const clip = videoClips[index]
        const localSource = position / 1000
        const sourceIn = Number(clip.sourceIn)
        const sourceOut = Number(clip.sourceOut)
        if (localSource >= sourceOut - 0.035) {
            if (index + 1 < videoClips.length) {
                currentTime = clipStart(index + 1)
                syncPreview(true)
                syncAudio(true)
            } else {
                playing = false
                currentTime = visualDuration()
                videoPlayer.pause()
                audioPlayer.pause()
                statusText = tr("Pemutaran selesai", "Playback finished")
            }
            return
        }
        syncingPlayer = true
        currentTime = clipStart(index) + Math.max(0, localSource - sourceIn)
        currentFrame = Math.round(currentTime * fps)
        syncingPlayer = false
    }
    function togglePlayback() {
        if (playing) {
            playing = false
            videoPlayer.pause()
            audioPlayer.pause()
            statusText = tr("Dijeda", "Paused")
            return
        }
        if (currentTime >= visualDuration() && visualDuration() > 0)
            currentTime = 0
        playing = true
        syncPreview(true)
        syncAudio(true)
        if (previewKind === "video" && videoPlayer.mediaStatus === MediaPlayer.LoadedMedia)
            videoPlayer.play()
        statusText = tr("Memutar timeline", "Playing timeline")
    }
    function newProject() {
        pushUndo()
        playing = false
        videoPlayer.stop()
        audioPlayer.stop()
        projectName = "Untitled Project"
        currentFile = ""
        videoClips = []
        audioClips = []
        assets = []
        selectedId = ""
        selectedType = "none"
        selectedAssetPath = ""
        currentTime = 0
        keyframes = [
            { "frame": 0, "x": 320, "y": 165, "scale": 100, "rotation": 0, "opacity": 100 },
            { "frame": 120, "x": 520, "y": 215, "scale": 120, "rotation": 0, "opacity": 100 }
        ]
        syncPreview(true)
        statusText = tr("Proyek baru dibuat", "New project created")
    }
    function projectData() {
        return {
            projectName: projectName, currentTime: currentTime, fps: fps,
            compositionWidth: compositionWidth, compositionHeight: compositionHeight,
            language: currentLanguage, assets: assets, videoClips: videoClips, audioClips: audioClips,
            keyframes: keyframes, motionOverlayEnabled: motionOverlayEnabled
        }
    }
    function saveProjectTo(url) {
        let path = url.toLocalFile()
        if (!path.toLowerCase().endsWith(".rim")) path += ".rim"
        if (projectController.saveProject(path, projectData())) {
            currentFile = path
            statusText = tr("Proyek tersimpan", "Project saved")
        }
    }
    function saveCurrentProject() {
        if (currentFile) saveProjectTo(mediaController.fileUrl(currentFile))
        else saveDialog.open()
    }
    function openProjectFrom(url) {
        const loaded = projectController.loadProject(url.toLocalFile())
        if (!loaded || !loaded.keyframes) {
            statusText = tr("Gagal membuka proyek", "Could not open project")
            return
        }
        playing = false
        videoPlayer.stop()
        audioPlayer.stop()
        projectName = loaded.projectName || "Untitled Project"
        currentFile = url.toLocalFile()
        currentTime = Math.max(0, Number(loaded.currentTime || 0))
        fps = Math.max(12, Number(loaded.fps || 24))
        compositionWidth = Math.max(160, Number(loaded.compositionWidth || 1920))
        compositionHeight = Math.max(90, Number(loaded.compositionHeight || 1080))
        if (loaded.language === "id" || loaded.language === "en") currentLanguage = loaded.language
        videoClips = loaded.videoClips || []
        audioClips = loaded.audioClips || []
        assets = loaded.assets || []
        // Projects saved by early builds only stored clips; rebuild the media bin from their paths.
        const knownPaths = {}
        for (let i = 0; i < assets.length; ++i) knownPaths[assets[i].path] = true
        const savedMedia = videoClips.concat(audioClips)
        for (let i = 0; i < savedMedia.length; ++i) {
            const clip = savedMedia[i]
            if (!knownPaths[clip.path]) {
                const info = mediaController.probeMedia(clip.path)
                if (!info.error) { assets = assets.concat([info]); knownPaths[clip.path] = true }
            }
        }
        keyframes = (loaded.keyframes || []).map(function(k) { return Object.assign({rotation: 0}, k) })
        motionOverlayEnabled = !!loaded.motionOverlayEnabled
        selectedId = ""
        selectedType = "none"
        undoStack = []
        redoStack = []
        syncPreview(true)
        statusText = tr("Proyek dibuka", "Project opened")
    }
    function addKeyframe() {
        pushUndo()
        const frame = Math.round(currentTime * fps)
        const next = keyframes.slice()
        let found = false
        for (let i = 0; i < next.length; ++i) {
            if (Number(next[i].frame) === frame) {
                next[i] = {
                    frame: frame, x: Math.round(valueAt("x", frame)), y: Math.round(valueAt("y", frame)),
                    scale: Math.round(valueAt("scale", frame)), rotation: Math.round(valueAt("rotation", frame)),
                    opacity: Math.round(valueAt("opacity", frame))
                }
                found = true
                break
            }
        }
        if (!found) next.push({
            frame: frame, x: Math.round(valueAt("x", frame)), y: Math.round(valueAt("y", frame)),
            scale: Math.round(valueAt("scale", frame)), rotation: Math.round(valueAt("rotation", frame)),
            opacity: Math.round(valueAt("opacity", frame))
        })
        keyframes = next.sort(function(a,b) { return a.frame - b.frame })
        statusText = tr("Keyframe ditambahkan", "Keyframe added")
    }
    function valueAt(propertyName, frame) {
        const frames = keyframes.slice().sort(function(a,b) { return a.frame-b.frame })
        if (!frames.length) return propertyName === "scale" || propertyName === "opacity" ? 100 : 0
        if (frame <= frames[0].frame) return Number(frames[0][propertyName] || 0)
        for (let i = 1; i < frames.length; ++i) {
            const prev = frames[i - 1], next = frames[i]
            if (frame <= next.frame) {
                const amount = (frame - prev.frame) / Math.max(1, next.frame - prev.frame)
                return Number(prev[propertyName] || 0) + (Number(next[propertyName] || 0) - Number(prev[propertyName] || 0)) * amount
            }
        }
        return Number(frames[frames.length - 1][propertyName] || 0)
    }
    function setCurrentMotionProperty(name, value) {
        const frame = Math.round(currentTime * fps)
        let next = keyframes.slice()
        const index = next.findIndex(function(k) { return Number(k.frame) === frame })
        const record = {
            frame: frame, x: Math.round(valueAt("x", frame)), y: Math.round(valueAt("y", frame)),
            scale: Math.round(valueAt("scale", frame)), rotation: Math.round(valueAt("rotation", frame)),
            opacity: Math.round(valueAt("opacity", frame))
        }
        record[name] = Math.round(value)
        if (index < 0) next.push(record)
        else next[index] = Object.assign({}, next[index], record)
        keyframes = next.sort(function(a,b) { return a.frame-b.frame })
    }
    function startExport(url) {
        const path = url.toLocalFile()
        if (!path) return
        if (!videoClips.length) {
            statusText = tr("Tambahkan video atau gambar sebelum ekspor", "Add a video or image before exporting")
            return
        }
        lastExportMessage = ""
        exportDialogVisible = true
        const ok = mediaController.exportTimeline(videoClips, audioClips, path, compositionWidth, compositionHeight, fps)
        if (!ok) exportDialogVisible = false
        else statusText = tr("Merender MP4…", "Rendering MP4…")
    }

    MediaController { id: mediaController }
    ProjectController { id: projectController }

    Connections {
        target: projectController
        function onErrorOccurred(message) { root.statusText = message }
    }
    Connections {
        target: mediaController
        function onErrorOccurred(message) {
            root.statusText = message
            root.lastExportMessage = message
            root.exportDialogVisible = false
        }
        function onExportFinished(success, message) {
            root.lastExportMessage = message
            root.statusText = message
            root.exportDialogVisible = false
        }
    }

    MediaPlayer {
        id: videoPlayer
        audioOutput: AudioOutput { volume: root.previewVolume }
        videoOutput: videoOutput
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.LoadedMedia) {
                position = root.pendingSeekMs
                if (root.playing) play()
                else pause()
            }
            if (mediaStatus === MediaPlayer.EndOfMedia && root.playing)
                root.handleVideoPosition(position)
        }
        onPositionChanged: root.handleVideoPosition(position)
    }
    MediaPlayer {
        id: audioPlayer
        audioOutput: AudioOutput { volume: root.musicVolume }
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.LoadedMedia) {
                position = root.pendingAudioSeekMs
                if (root.playing) play()
                else pause()
            }
        }
    }

    Timer {
        interval: 33
        repeat: true
        running: root.playing && root.previewKind !== "video"
        onTriggered: {
            const nextTime = root.currentTime + interval / 1000
            const end = Math.max(root.visualDuration(), root.audioEndTime())
            if (nextTime >= end) {
                root.currentTime = end
                root.playing = false
                root.audioPlayer.pause()
                return
            }
            root.currentTime = nextTime
            const index = root.clipIndexAtTime(root.currentTime)
            if (root.previewKind === "none" || (index >= 0 && root.videoClips[index].id !== root.activeVisualId))
                root.syncPreview(true)
            root.syncAudio(false)
        }
    }
    onCurrentTimeChanged: {
        currentFrame = Math.round(currentTime * fps)
        if (playing) syncAudio(false)
    }

    FileDialog {
        id: importDialog
        title: root.tr("Impor Media", "Import Media")
        fileMode: FileDialog.OpenFiles
        nameFilters: ["Media (*.mp4 *.mov *.mkv *.webm *.avi *.m4v *.mp3 *.wav *.ogg *.flac *.aac *.m4a *.png *.jpg *.jpeg *.webp *.bmp *.gif)", "All files (*)"]
        onAccepted: root.importMedia(selectedFiles)
    }
    FileDialog {
        id: openDialog
        title: root.tr("Buka Proyek", "Open Project")
        fileMode: FileDialog.OpenFile
        nameFilters: ["Rimution Project (*.rim)", "JSON files (*.json)", "All files (*)"]
        onAccepted: root.openProjectFrom(selectedFile)
    }
    FileDialog {
        id: saveDialog
        title: root.tr("Simpan Proyek", "Save Project")
        fileMode: FileDialog.SaveFile
        nameFilters: ["Rimution Project (*.rim)"]
        onAccepted: root.saveProjectTo(selectedFile)
    }
    FileDialog {
        id: exportFileDialog
        title: root.tr("Ekspor Video", "Export Video")
        fileMode: FileDialog.SaveFile
        nameFilters: ["MP4 Video (*.mp4)"]
        onAccepted: root.startExport(selectedFile)
    }

    Shortcut { sequence: "Space"; onActivated: root.togglePlayback() }
    Shortcut { sequence: "Ctrl+S"; onActivated: root.saveCurrentProject() }
    Shortcut { sequence: "Ctrl+I"; onActivated: importDialog.open() }
    Shortcut { sequence: "Ctrl+Z"; onActivated: root.undo() }
    Shortcut { sequence: "Ctrl+Shift+Z"; onActivated: root.redo() }
    Shortcut { sequence: "Delete"; onActivated: root.removeSelectedClip() }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 62
            color: "#171920"
            border.color: root.borderColor
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 14
                spacing: 10
                Rectangle {
                    width: 36; height: 36; radius: 10
                    color: root.lime
                    Text { anchors.centerIn: parent; text: "R"; color: "#151710"; font.pixelSize: 23; font.bold: true }
                }
                ColumnLayout {
                    spacing: 0
                    Label { text: "Rimution"; color: root.textColor; font.pixelSize: 18; font.bold: true }
                    Label { text: "MEDIA LAB  ·  0.2"; color: root.purple; font.pixelSize: 9; font.letterSpacing: 1.4 }
                }
                Rectangle { width: 1; height: 30; color: root.borderColor; Layout.leftMargin: 4; Layout.rightMargin: 4 }
                Button {
                    text: root.tr("Proyek Baru", "New")
                    onClicked: root.newProject()
                    ToolTip.visible: hovered
                    ToolTip.text: "Ctrl+N"
                }
                Button { text: root.tr("Buka", "Open"); onClicked: openDialog.open() }
                Button { text: root.tr("Simpan", "Save"); highlighted: true; onClicked: root.saveCurrentProject() }
                Button { text: root.tr("Impor Media", "Import Media") + "  +"; onClicked: importDialog.open() }
                Item { Layout.fillWidth: true }
                Label { text: root.projectName; color: root.muted; elide: Text.ElideRight; Layout.maximumWidth: 180 }
                Button {
                    text: mediaController.exporting ? root.tr("Merender…", "Rendering…") : root.tr("Ekspor MP4", "Export MP4") + "  ↗"
                    highlighted: true
                    enabled: !mediaController.exporting
                    onClicked: exportFileDialog.open()
                }
                ComboBox {
                    model: ["Bahasa Indonesia", "English"]
                    currentIndex: root.currentLanguage === "id" ? 0 : 1
                    onActivated: root.currentLanguage = currentIndex === 0 ? "id" : "en"
                    Layout.preferredWidth: 142
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Rectangle {
                Layout.preferredWidth: 254
                Layout.fillHeight: true
                color: root.panel
                border.color: root.borderColor
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: root.tr("MEDIA BIN", "MEDIA BIN"); color: root.muted; font.pixelSize: 10; font.letterSpacing: 1.4; font.bold: true }
                        Item { Layout.fillWidth: true }
                        Label { text: root.assets.length; color: root.lime; font.pixelSize: 11; font.bold: true }
                    }
                    Button {
                        Layout.fillWidth: true
                        text: "＋  " + root.tr("Aggiungi file", "Add media")
                        highlighted: true
                        onClicked: importDialog.open()
                    }
                    TextField {
                        id: assetSearch
                        Layout.fillWidth: true
                        placeholderText: root.tr("Cerca nei media…", "Search media…")
                        selectByMouse: true
                    }
                    Label { text: root.tr("MEDIA LOCALI", "LOCAL MEDIA"); color: root.muted; font.pixelSize: 9; font.letterSpacing: 1.2 }
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        ColumnLayout {
                            width: parent.width
                            spacing: 6
                            Repeater {
                                model: root.assets.filter(function(a) {
                                    return !assetSearch.text || a.name.toLowerCase().indexOf(assetSearch.text.toLowerCase()) >= 0
                                })
                                delegate: Rectangle {
                                    required property var modelData
                                    width: parent.width
                                    Layout.fillWidth: true
                                    height: 58
                                    radius: 8
                                    color: root.selectedAssetPath === modelData.path ? "#2c3329" : root.raised
                                    border.color: root.selectedAssetPath === modelData.path ? root.lime : root.borderColor
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 8
                                        Rectangle {
                                            width: 34; height: 34; radius: 7
                                            color: modelData.kind === "audio" ? "#353056" : modelData.kind === "image" ? "#263c3b" : "#293847"
                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.kind === "audio" ? "♫" : modelData.kind === "image" ? "▧" : "▶"
                                                color: modelData.kind === "audio" ? root.purple : modelData.kind === "image" ? root.cyan : root.lime
                                                font.pixelSize: 17; font.bold: true
                                            }
                                        }
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 3
                                            Label { text: modelData.name; color: root.textColor; font.pixelSize: 11; elide: Text.ElideMiddle; Layout.fillWidth: true }
                                            Label { text: root.mediaLabel(modelData.kind) + "  ·  " + root.fmtDuration(modelData.duration); color: root.muted; font.pixelSize: 9 }
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: root.selectedAssetPath = modelData.path
                                        onDoubleClicked: { root.selectedAssetPath = modelData.path; root.addSelectedAsset() }
                                    }
                                }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                height: root.assets.length === 0 ? 150 : 1
                                color: root.assets.length === 0 ? "#20232c" : "transparent"
                                radius: 10
                                visible: root.assets.length === 0
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 7
                                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: "✧"; color: root.purple; font.pixelSize: 26 }
                                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: root.tr("Belum ada media", "No media yet"); color: root.textColor; font.pixelSize: 12 }
                                    Label { anchors.horizontalCenter: parent.horizontalCenter; text: root.tr("Impor video, gambar, atau audio", "Import video, images, or audio"); color: root.muted; font.pixelSize: 10 }
                                }
                            }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 74
                        radius: 9
                        color: "#202319"
                        border.color: "#454c31"
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 10; spacing: 4
                            Label { text: root.tr("ALUR LOKAL", "LOCAL WORKFLOW"); color: root.lime; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.1 }
                            Label { text: root.tr("Media tetap di komputermu. Ekspor memakai FFmpeg.", "Media stays on your computer. Export uses FFmpeg."); color: root.muted; font.pixelSize: 10; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                        }
                    }
                    Button {
                        Layout.fillWidth: true
                        enabled: !!root.selectedAssetPath
                        text: root.tr("Tambahkan ke Timeline", "Add to Timeline") + "  ↓"
                        onClicked: root.addSelectedAsset()
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
                    color: "#111319"
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: root.tr("PRATINJAU", "PREVIEW"); color: root.textColor; font.pixelSize: 12; font.bold: true }
                            Rectangle { width: 6; height: 6; radius: 3; color: root.cyan }
                            Label { text: root.previewKind === "none" ? root.tr("Belum ada klip", "No clip selected") : root.previewKind.toUpperCase(); color: root.muted; font.pixelSize: 9; font.letterSpacing: 1 }
                            Item { Layout.fillWidth: true }
                            Label { text: root.compositionWidth + " × " + root.compositionHeight; color: root.muted; font.pixelSize: 10 }
                            Rectangle { width: 1; height: 16; color: root.borderColor }
                            Label { text: root.fps + " FPS"; color: root.lime; font.pixelSize: 10; font.bold: true }
                        }
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            Rectangle {
                                id: stage
                                width: Math.min(parent.width, parent.height * 16 / 9)
                                height: Math.min(parent.height, parent.width * 9 / 16)
                                anchors.centerIn: parent
                                color: "#07090d"
                                border.color: root.borderColor
                                radius: 4
                                VideoOutput {
                                    id: videoOutput
                                    anchors.fill: parent
                                    fillMode: VideoOutput.PreserveAspectFit
                                    visible: root.previewKind === "video"
                                }
                                Image {
                                    anchors.fill: parent
                                    source: root.previewImageSource
                                    fillMode: Image.PreserveAspectFit
                                    visible: root.previewKind === "image"
                                    asynchronous: true
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: "#252a35"
                                    visible: root.previewKind === "none"
                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 9
                                        Label { anchors.horizontalCenter: parent.horizontalCenter; text: "◈"; color: root.purple; font.pixelSize: 44 }
                                        Label { anchors.horizontalCenter: parent.horizontalCenter; text: root.tr("Impor media untuk memulai", "Import media to get started"); color: root.textColor; font.pixelSize: 14 }
                                        Label { anchors.horizontalCenter: parent.horizontalCenter; text: root.tr("Video · Gambar · Audio", "Video · Images · Audio"); color: root.muted; font.pixelSize: 11 }
                                    }
                                }
                                Rectangle {
                                    id: motionObject
                                    x: root.valueAt("x", root.currentFrame) * stage.width / 800
                                    y: root.valueAt("y", root.currentFrame) * stage.height / 450
                                    width: 84 * root.valueAt("scale", root.currentFrame) / 100 * stage.width / 800
                                    height: 84 * root.valueAt("scale", root.currentFrame) / 100 * stage.height / 450
                                    rotation: root.valueAt("rotation", root.currentFrame)
                                    radius: 17
                                    color: root.lime
                                    opacity: root.valueAt("opacity", root.currentFrame) / 100
                                    border.color: "#eaffbb"
                                    visible: root.motionOverlayEnabled
                                    z: 10
                                    Text { anchors.centerIn: parent; text: "R"; color: "#151710"; font.pixelSize: 30; font.bold: true }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                        drag.target: parent
                                        drag.minimumX: 0; drag.minimumY: 0
                                        drag.maximumX: stage.width - parent.width
                                        drag.maximumY: stage.height - parent.height
                                        onReleased: {
                                            root.setCurrentMotionProperty("x", parent.x * 800 / stage.width)
                                            root.setCurrentMotionProperty("y", parent.y * 450 / stage.height)
                                        }
                                    }
                                }
                                Rectangle {
                                    anchors.left: parent.left; anchors.bottom: parent.bottom
                                    anchors.leftMargin: 10; anchors.bottomMargin: 9
                                    radius: 5; color: "#aa0e1119"; border.color: "#333845"
                                    width: 116; height: 22
                                    Row {
                                        anchors.centerIn: parent; spacing: 6
                                        Rectangle { width: 5; height: 5; radius: 3; color: root.lime; anchors.verticalCenter: parent.verticalCenter }
                                        Text { text: "RIMUTION  /  LOCAL"; color: "#b9c0ce"; font.pixelSize: 8; font.letterSpacing: 0.7 }
                                    }
                                }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Button {
                                text: root.playing ? "Ⅱ" : "▶"
                                highlighted: true
                                onClicked: root.togglePlayback()
                                ToolTip.visible: hovered
                                ToolTip.text: "Space"
                            }
                            Button { text: "↤"; onClicked: root.seekTime(0, true); ToolTip.visible: hovered; ToolTip.text: root.tr("Ke awal", "Go to start") }
                            Button { text: "−1f"; onClicked: root.seekTime(Math.max(0, root.currentTime - 1 / root.fps), true) }
                            Button { text: "+1f"; onClicked: root.seekTime(Math.min(root.visualDuration(), root.currentTime + 1 / root.fps), true) }
                            Label { text: root.timecode(root.currentTime); color: root.lime; font.family: "monospace"; font.pixelSize: 12; font.bold: true }
                            Label { text: "/ " + root.timecode(root.visualDuration()); color: root.muted; font.family: "monospace"; font.pixelSize: 11 }
                            Item { Layout.fillWidth: true }
                            CheckBox {
                                text: root.tr("Layer gerak", "Motion layer")
                                checked: root.motionOverlayEnabled
                                onToggled: root.motionOverlayEnabled = checked
                            }
                            Slider { Layout.preferredWidth: 90; from: 0; to: 1; value: root.previewVolume; onMoved: root.previewVolume = value; ToolTip.visible: hovered; ToolTip.text: root.tr("Volume video", "Video volume") }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 300
                    color: root.panel
                    border.color: root.borderColor
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: root.tr("TIMELINE", "TIMELINE"); color: root.textColor; font.pixelSize: 12; font.bold: true; font.letterSpacing: 0.5 }
                            Rectangle { width: 5; height: 5; radius: 3; color: root.purple }
                            Label { text: root.videoClips.length + " " + root.tr("klip video", "video clips") + " · " + root.audioClips.length + " " + root.tr("audio", "audio"); color: root.muted; font.pixelSize: 10 }
                            Item { Layout.fillWidth: true }
                            Button { text: "✂  " + root.tr("Pisah", "Split"); enabled: root.selectedType === "visual"; onClicked: root.splitSelectedClip() }
                            Button { text: "−  " + root.tr("Hapus", "Delete"); enabled: root.selectedType !== "none"; onClicked: root.removeSelectedClip() }
                            Label { text: root.tr("Zoom", "Zoom"); color: root.muted; font.pixelSize: 9 }
                            Slider { Layout.preferredWidth: 100; from: 32; to: 150; value: root.zoom; onMoved: root.zoom = value }
                        }
                        Flickable {
                            id: timelineFlick
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            contentWidth: root.timelineWidth()
                            contentHeight: 154
                            boundsBehavior: Flickable.StopAtBounds
                            ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }
                            Column {
                                width: root.timelineWidth()
                                spacing: 4
                                Item {
                                    width: parent.width; height: 24
                                    Repeater {
                                        model: Math.ceil(root.timelineDuration()) + 1
                                        delegate: Item {
                                            required property int index
                                            x: 86 + index * root.zoom
                                            width: 1; height: 24
                                            Rectangle { width: 1; height: 8; color: root.borderColor; anchors.left: parent.left }
                                            Text { text: root.timecode(index); color: root.muted; font.pixelSize: 9; anchors.left: parent.left; anchors.top: parent.top; anchors.topMargin: 9 }
                                        }
                                    }
                                }
                                Rectangle {
                                    width: parent.width; height: 42; radius: 6; color: "#151720"; border.color: root.borderColor
                                    Text { x: 10; anchors.verticalCenter: parent.verticalCenter; text: "V1"; color: root.lime; font.pixelSize: 10; font.bold: true }
                                    MouseArea {
                                        anchors.fill: parent
                                        z: 0
                                        onClicked: root.seekTime(Math.max(0, (mouse.x - 86) / root.zoom), true)
                                    }
                                    Repeater {
                                        model: root.videoClips
                                        delegate: Rectangle {
                                            required property var modelData
                                            required property int index
                                            x: 86 + root.clipStart(index) * root.zoom
                                            width: Math.max(6, Number(modelData.duration) * root.zoom - 2)
                                            height: 34; y: 4; radius: 5
                                            color: root.selectedId === modelData.id ? "#3a4829" : "#283544"
                                            border.color: root.selectedId === modelData.id ? root.lime : "#425a71"
                                            clip: true; z: 2
                                            Row {
                                                anchors.fill: parent; anchors.leftMargin: 7; anchors.rightMargin: 6; spacing: 5
                                                Rectangle { width: 3; height: 20; radius: 2; color: modelData.kind === "image" ? root.purple : root.cyan; anchors.verticalCenter: parent.verticalCenter }
                                                Column {
                                                    anchors.verticalCenter: parent.verticalCenter; spacing: 2
                                                    width: Math.max(0, parent.width - 18)
                                                    Text { text: modelData.name; color: root.textColor; font.pixelSize: 9; elide: Text.ElideRight; width: parent.width }
                                                    Text { text: root.fmtDuration(modelData.duration); color: root.muted; font.pixelSize: 8 }
                                                }
                                            }
                                            MouseArea { anchors.fill: parent; z: 4; onClicked: { root.selectVisual(modelData.id); root.seekTime(root.clipStart(index), true) } }
                                        }
                                    }
                                }
                                Rectangle {
                                    width: parent.width; height: 42; radius: 6; color: "#151720"; border.color: root.borderColor
                                    Text { x: 10; anchors.verticalCenter: parent.verticalCenter; text: "A1"; color: root.purple; font.pixelSize: 10; font.bold: true }
                                    MouseArea {
                                        anchors.fill: parent
                                        z: 0
                                        onClicked: root.seekTime(Math.max(0, (mouse.x - 86) / root.zoom), true)
                                    }
                                    Repeater {
                                        model: root.audioClips
                                        delegate: Rectangle {
                                            required property var modelData
                                            x: 86 + Number(modelData.start || 0) * root.zoom
                                            width: Math.max(8, Number(modelData.duration) * root.zoom - 2)
                                            height: 34; y: 4; radius: 5
                                            color: root.selectedId === modelData.id ? "#39304f" : "#2b2640"
                                            border.color: root.selectedId === modelData.id ? root.purple : "#574b77"
                                            clip: true; z: 2
                                            Row {
                                                anchors.fill: parent; anchors.leftMargin: 7; spacing: 5
                                                Text { text: "♫"; color: root.purple; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                                                Text { text: modelData.name; color: root.textColor; font.pixelSize: 9; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter; width: Math.max(0, parent.width - 24) }
                                            }
                                            MouseArea { anchors.fill: parent; z: 4; onClicked: { root.selectAudio(modelData.id); root.seekTime(Number(modelData.start || 0), true) } }
                                        }
                                    }
                                }
                                Rectangle {
                                    width: parent.width; height: 30; radius: 6; color: "#151720"; border.color: root.borderColor
                                    Text { x: 10; anchors.verticalCenter: parent.verticalCenter; text: "FX"; color: root.orange; font.pixelSize: 9; font.bold: true }
                                    Repeater {
                                        model: root.keyframes
                                        delegate: Rectangle {
                                            required property var modelData
                                            width: 8; height: 8; radius: 2; rotation: 45
                                            x: 86 + Number(modelData.frame) / root.fps * root.zoom
                                            y: 11
                                            color: root.orange; border.color: "#fff0d7"
                                            MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: root.seekTime(Number(modelData.frame) / root.fps, true) }
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        z: -1
                                        onClicked: root.seekTime(Math.max(0, (mouse.x - 86) / root.zoom), true)
                                    }
                                }
                                Rectangle {
                                    width: parent.width; height: 20; color: "transparent"
                                    Text { text: root.tr("Seret playhead dengan mengeklik ruler/track · pilih klip untuk trim, split, atau pindah urutan", "Click the ruler/track to seek · select clips to trim, split, or reorder"); color: root.muted; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter }
                                }
                            }
                            Rectangle {
                                x: 86 + root.currentTime * root.zoom
                                y: 0
                                width: 2
                                height: 154
                                color: root.lime
                                z: 20
                                Rectangle { width: 9; height: 8; radius: 2; color: root.lime; anchors.horizontalCenter: parent.horizontalCenter; y: 0 }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 306
                Layout.fillHeight: true
                color: root.panel
                border.color: root.borderColor
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: root.tr("INSPEKTOR", "INSPECTOR"); color: root.textColor; font.pixelSize: 12; font.bold: true; font.letterSpacing: 0.7 }
                        Item { Layout.fillWidth: true }
                        Rectangle { width: 7; height: 7; radius: 4; color: root.lime }
                    }
                    TabBar {
                        id: inspectorTabs
                        Layout.fillWidth: true
                        currentIndex: root.inspectorTab
                        onCurrentIndexChanged: root.inspectorTab = currentIndex
                        TabButton { text: root.tr("Klip", "Clip") }
                        TabButton { text: root.tr("Gerak", "Motion") }
                    }
                    StackLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        currentIndex: root.inspectorTab
                        ScrollView {
                            clip: true
                            ColumnLayout {
                                width: parent.width
                                spacing: 11
                                Rectangle {
                                    Layout.fillWidth: true; height: 66; radius: 8
                                    color: root.raised; border.color: root.borderColor
                                    ColumnLayout {
                                        anchors.fill: parent; anchors.margins: 10; spacing: 4
                                        Label { text: root.selectedType === "visual" ? root.tr("KLIP VIDEO/GAMBAR", "VIDEO/IMAGE CLIP") : root.selectedType === "audio" ? root.tr("KLIP AUDIO", "AUDIO CLIP") : root.tr("TIDAK ADA PILIHAN", "NO SELECTION"); color: root.lime; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1 }
                                        Label { text: root.getSelectedVisual() ? root.getSelectedVisual().name : root.getSelectedAudio() ? root.getSelectedAudio().name : root.tr("Pilih klip di timeline", "Select a clip on the timeline"); color: root.textColor; font.pixelSize: 11; elide: Text.ElideMiddle; Layout.fillWidth: true }
                                    }
                                }
                                Label { text: root.tr("SUMBER / TRIM", "SOURCE / TRIM"); color: root.muted; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.2 }
                                GridLayout {
                                    Layout.fillWidth: true; columns: 2; rowSpacing: 6; columnSpacing: 8
                                    Label { text: root.tr("In (detik)", "In (seconds)"); color: root.muted; font.pixelSize: 10 }
                                    TextField {
                                        id: visualInField
                                        Layout.fillWidth: true
                                        enabled: root.selectedType === "visual"
                                        text: root.getSelectedVisual() ? Number(root.getSelectedVisual().sourceIn).toFixed(2) : "0.00"
                                        validator: DoubleValidator { bottom: 0; decimals: 4; notation: DoubleValidator.StandardNotation }
                                        selectByMouse: true
                                    }
                                    Label { text: root.tr("Out (detik)", "Out (seconds)"); color: root.muted; font.pixelSize: 10 }
                                    TextField {
                                        id: visualOutField
                                        Layout.fillWidth: true
                                        enabled: root.selectedType === "visual"
                                        text: root.getSelectedVisual() ? Number(root.getSelectedVisual().sourceOut).toFixed(2) : "0.00"
                                        validator: DoubleValidator { bottom: 0; decimals: 4; notation: DoubleValidator.StandardNotation }
                                        selectByMouse: true
                                    }
                                }
                                Button { Layout.fillWidth: true; text: "✓  " + root.tr("Terapkan Trim", "Apply Trim"); enabled: root.selectedType === "visual"; highlighted: true; onClicked: root.applyVisualTrim() }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Button { Layout.fillWidth: true; text: "←"; enabled: root.selectedType === "visual"; onClicked: root.moveSelectedVisual(-1); ToolTip.visible: hovered; ToolTip.text: root.tr("Pindah sebelumnya", "Move earlier") }
                                    Button { Layout.fillWidth: true; text: "→"; enabled: root.selectedType === "visual"; onClicked: root.moveSelectedVisual(1); ToolTip.visible: hovered; ToolTip.text: root.tr("Pindah sesudahnya", "Move later") }
                                    Button { Layout.fillWidth: true; text: "✂"; enabled: root.selectedType === "visual"; onClicked: root.splitSelectedClip(); ToolTip.visible: hovered; ToolTip.text: root.tr("Pisah di playhead", "Split at playhead") }
                                }
                                Rectangle { Layout.fillWidth: true; height: 1; color: root.borderColor }
                                Label { text: root.tr("AUDIO LAYER", "AUDIO LAYER"); color: root.muted; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.2 }
                                GridLayout {
                                    Layout.fillWidth: true; columns: 2; rowSpacing: 6; columnSpacing: 8
                                    Label { text: root.tr("Mulai (detik)", "Start (seconds)"); color: root.muted; font.pixelSize: 10 }
                                    TextField {
                                        id: audioStartField
                                        Layout.fillWidth: true
                                        enabled: root.selectedType === "audio"
                                        text: root.getSelectedAudio() ? Number(root.getSelectedAudio().start).toFixed(2) : "0.00"
                                        validator: DoubleValidator { bottom: 0; decimals: 4; notation: DoubleValidator.StandardNotation }
                                        selectByMouse: true
                                    }
                                    Label { text: root.tr("In (detik)", "In (seconds)"); color: root.muted; font.pixelSize: 10 }
                                    TextField {
                                        id: audioInField
                                        Layout.fillWidth: true
                                        enabled: root.selectedType === "audio"
                                        text: root.getSelectedAudio() ? Number(root.getSelectedAudio().sourceIn).toFixed(2) : "0.00"
                                        validator: DoubleValidator { bottom: 0; decimals: 4; notation: DoubleValidator.StandardNotation }
                                        selectByMouse: true
                                    }
                                    Label { text: root.tr("Out (detik)", "Out (seconds)"); color: root.muted; font.pixelSize: 10 }
                                    TextField {
                                        id: audioOutField
                                        Layout.fillWidth: true
                                        enabled: root.selectedType === "audio"
                                        text: root.getSelectedAudio() ? Number(root.getSelectedAudio().sourceOut).toFixed(2) : "0.00"
                                        validator: DoubleValidator { bottom: 0; decimals: 4; notation: DoubleValidator.StandardNotation }
                                        selectByMouse: true
                                    }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Button { Layout.fillWidth: true; text: root.tr("Terapkan Audio Trim", "Apply Audio Trim"); enabled: root.selectedType === "audio"; onClicked: root.applyAudioRange() }
                                    Button { Layout.fillWidth: true; text: root.tr("Atur Mulai", "Set Start"); enabled: root.selectedType === "audio"; onClicked: root.applyAudioStart() }
                                }
                                Label { text: root.tr("Volume klip", "Clip volume"); color: root.muted; font.pixelSize: 10 }
                                Slider {
                                    Layout.fillWidth: true; from: 0; to: 150
                                    enabled: root.selectedType === "audio"
                                    value: root.getSelectedAudio() ? Number(root.getSelectedAudio().volume || 100) : 100
                                    onMoved: root.applyAudioVolume(value)
                                }
                                Rectangle {
                                    Layout.fillWidth: true; height: 74; radius: 8; color: "#252236"; border.color: "#554879"
                                    ColumnLayout {
                                        anchors.fill: parent; anchors.margins: 10; spacing: 4
                                        Label { text: root.tr("EDIT NON-DESTRUKTIF", "NON-DESTRUCTIVE EDIT"); color: root.purple; font.pixelSize: 9; font.bold: true }
                                        Label { text: root.tr("Trim hanya mengubah rentang sumber. Berkas asli tidak diubah.", "Trimming changes the source range; original files stay untouched."); color: root.muted; font.pixelSize: 10; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                                    }
                                }
                            }
                        }
                        ScrollView {
                            clip: true
                            ColumnLayout {
                                width: parent.width
                                spacing: 10
                                CheckBox { text: root.tr("Tampilkan layer gerak", "Show motion layer"); checked: root.motionOverlayEnabled; onToggled: root.motionOverlayEnabled = checked }
                                Label { text: root.tr("TRANSFORMASI · FRAME ", "TRANSFORM · FRAME ") + root.currentFrame; color: root.muted; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1 }
                                function motionControl(label, propertyName, minValue, maxValue, suffix) {}
                                GridLayout {
                                    columns: 2; Layout.fillWidth: true
                                    Label { text: "X"; color: root.muted; font.pixelSize: 10 }
                                    SpinBox { Layout.fillWidth: true; from: 0; to: 800; editable: true; value: Math.round(root.valueAt("x", root.currentFrame)); onValueModified: root.setCurrentMotionProperty("x", value) }
                                    Label { text: "Y"; color: root.muted; font.pixelSize: 10 }
                                    SpinBox { Layout.fillWidth: true; from: 0; to: 450; editable: true; value: Math.round(root.valueAt("y", root.currentFrame)); onValueModified: root.setCurrentMotionProperty("y", value) }
                                    Label { text: root.tr("Skala", "Scale"); color: root.muted; font.pixelSize: 10 }
                                    SpinBox { Layout.fillWidth: true; from: 10; to: 300; editable: true; value: Math.round(root.valueAt("scale", root.currentFrame)); textFromValue: function(v) { return v + "%" }; valueFromText: function(t) { return Number(t.replace("%","")) }; onValueModified: root.setCurrentMotionProperty("scale", value) }
                                    Label { text: root.tr("Rotasi", "Rotation"); color: root.muted; font.pixelSize: 10 }
                                    SpinBox { Layout.fillWidth: true; from: -360; to: 360; editable: true; value: Math.round(root.valueAt("rotation", root.currentFrame)); textFromValue: function(v) { return v + "°" }; valueFromText: function(t) { return Number(t.replace("°","")) }; onValueModified: root.setCurrentMotionProperty("rotation", value) }
                                    Label { text: root.tr("Opasitas", "Opacity"); color: root.muted; font.pixelSize: 10 }
                                    SpinBox { Layout.fillWidth: true; from: 0; to: 100; editable: true; value: Math.round(root.valueAt("opacity", root.currentFrame)); textFromValue: function(v) { return v + "%" }; valueFromText: function(t) { return Number(t.replace("%","")) }; onValueModified: root.setCurrentMotionProperty("opacity", value) }
                                }
                                Button { Layout.fillWidth: true; highlighted: true; text: "◆  " + root.tr("Tambah Keyframe", "Add Keyframe"); onClicked: root.addKeyframe() }
                                Rectangle { Layout.fillWidth: true; height: 1; color: root.borderColor }
                                Label { text: root.keyframes.length + " " + root.tr("keyframe · interpolasi linear", "keyframes · linear interpolation"); color: root.muted; font.pixelSize: 10 }
                                Repeater {
                                    model: root.keyframes
                                    delegate: Rectangle {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        height: 38; radius: 6
                                        color: "#24251f"; border.color: "#4b4e31"
                                        RowLayout {
                                            anchors.fill: parent; anchors.margins: 8
                                            Label { text: "◆"; color: root.lime; font.pixelSize: 12 }
                                            Label { text: root.tr("Frame ", "Frame ") + modelData.frame; color: root.textColor; font.pixelSize: 10; Layout.fillWidth: true }
                                            Button { text: "↳"; onClicked: root.seekTime(Number(modelData.frame) / root.fps, true) }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            color: "#14161d"
            border.color: root.borderColor
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12
                Rectangle { width: 5; height: 5; radius: 3; color: mediaController.exporting ? root.orange : root.lime }
                Label { text: root.statusText; color: root.muted; font.pixelSize: 9; Layout.fillWidth: true; elide: Text.ElideRight }
                Label { text: "Rimution 0.2  ·  FFmpeg  ·  " + root.fps + " FPS"; color: "#73798b"; font.pixelSize: 9 }
            }
        }
    }

    Dialog {
        id: exportStatusDialog
        modal: false
        visible: root.exportDialogVisible
        title: root.tr("Ekspor MP4", "Export MP4")
        standardButtons: mediaController.exporting ? Dialog.NoButton : Dialog.Close
        width: 420
        anchors.centerIn: Overlay.overlay
        ColumnLayout {
            width: parent.width
            spacing: 10
            Label { text: mediaController.exporting ? root.tr("Membuat video dari timeline…", "Rendering the timeline…") : root.lastExportMessage; color: root.textColor; wrapMode: Text.WordWrap; Layout.fillWidth: true }
            ProgressBar { Layout.fillWidth: true; from: 0; to: 100; value: mediaController.exportProgress }
            Label { text: mediaController.exportProgress + "%"; color: root.lime; font.pixelSize: 11 }
            Label { text: root.tr("Tergantung durasi, resolusi, dan kecepatan CPU.", "Depends on duration, resolution, and CPU speed."); color: root.muted; font.pixelSize: 10 }
        }
        onClosed: root.exportDialogVisible = false
    }

    palette.window: root.bg
    palette.windowText: root.textColor
    palette.base: root.raised
    palette.alternateBase: root.panel
    palette.text: root.textColor
    palette.button: root.raised
    palette.buttonText: root.textColor
    palette.highlight: root.lime
    palette.highlightedText: "#151710"
    palette.mid: root.borderColor
    palette.dark: "#0b0c10"
    palette.light: "#3c4050"
}
