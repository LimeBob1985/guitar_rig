import Foundation
import AVFoundation
import Flutter

final class AudioEngine {
    static let shared = AudioEngine()

    private let engine = AVAudioEngine()
    private let inputNode: AVAudioInputNode
    private let mainMixer: AVAudioMixerNode
    private let outputNode: AVAudioOutputNode

    private var flutterChannel: FlutterMethodChannel?

    // Mixer params
    private var mixerIn: Float = 0.0
    private var mixerOut: Float = 0.0
    private var mixerGate: Float = 0.0
    private var mixerLimit: Float = 0.0
    private var mixerVolume: Float = 0.0
    private var mixerTreble: Float = 0.0
    private var mixerMaster: Float = 10.0

    // Pedal intensities (0–10)
    private var pedalValues: [String: Float] = [
        "Acoustic IR": 0.0,
        "Clean": 0.0,
        "Compressor": 0.0,
        "Delay": 0.0,
        "Reverb": 0.0,
        "Chorus": 0.0,
        "Tremolo": 0.0,
        "Rotary": 0.0,
        "Flanger": 0.0,
        "Overdrive": 0.0,
        "Crunch": 0.0,
        "Distortion": 0.0,
        "Noise": 0.0,
    ]

    // Per‑pedal EQ
    private var pedalEQ: [String: [String: Float]] = [
        "Acoustic IR": ["Bass": 0.0, "Mid": 0.0, "Treble": 0.0],
        "Clean": ["Bass": 0.0, "Mid": 0.0, "Treble": 0.0],
        "Compressor": ["Bass": 0.0, "Mid": 0.0, "Treble": 0.0],
        "Delay": ["Bass": 0.0, "Mid": 0.0, "Treble": 0.0],
        "Reverb": ["Bass": 0.0, "Mid": 0.0, "Treble": 0.0],
        "Chorus": ["Bass": 0.0, "Mid": 0.0, "Treble": 0.0],
        "Tremolo": ["Bass": 0.0, "Mid": 0.0, "Treble": 0.0],
        "Rotary": ["Bass": 0.0, "Mid": 0.0, "Treble": 0.0],
        "Flanger": ["Bass": 0.0, "Mid": 0.0, "Treble": 0.0],
        "Overdrive": ["Bass": 0.0, "Mid": 0.0, "Treble": 0.0],
        "Crunch": ["Bass": 0.0, "Mid": 0.0, "Treble": 0.0],
        "Distortion": ["Bass": 0.0, "Mid": 0.0, "Treble": 0.0],
        "Noise": ["Bass": 0.0, "Mid": 0.0, "Treble": 0.0],
    ]

    private var externalGain: Float = 1.0
    private var isStarted = false

    private init() {
        inputNode = engine.inputNode
        mainMixer = engine.mainMixerNode
        outputNode = engine.outputNode

        let format = inputNode.outputFormat(forBus: 0)
        engine.connect(inputNode, to: mainMixer, format: format)
        engine.connect(mainMixer, to: outputNode, format: format)

        mainMixer.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
            self?.process(buffer: buffer)
        }
    }

    func setFlutterChannel(_ channel: FlutterMethodChannel) {
        self.flutterChannel = channel
    }

    func start() {
        guard !isStarted else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            isStarted = true
        } catch {
            print("AudioEngine start error: \(error)")
        }
    }

    func setExternalGain(_ value: Float) { externalGain = max(0, min(1, value)) }
    func setMixerParam(name: String, value: Float) { switch name {
        case "In": mixerIn = value
        case "Out": mixerOut = value
        case "Gate": mixerGate = value
        case "Limit": mixerLimit = value
        case "Volume": mixerVolume = value
        case "Treble": mixerTreble = value
        case "Master": mixerMaster = value
        default: break
    }}

    func setPedalValue(name: String, value: Float) { pedalValues[name] = value }
    func setPedalEQ(pedal: String, band: String, value: Float) {
        guard var eq = pedalEQ[pedal] else { return }
        eq[band] = value
        pedalEQ[pedal] = eq
    }

    // MARK: - TUNER
    private func sendTunerData(frequency: Float) {
        guard let channel = flutterChannel else { return }

        let notes = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
        let midi = 69 + 12 * log2(frequency / 440.0)
        let idx = Int(round(midi)) % 12
        let note = notes[(idx + 12) % 12]

        channel.invokeMethod("tunerData", arguments: [
            "frequency": frequency,
            "note": note
        ])
    }

    private func process(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)
        let channels = Int(buffer.format.channelCount)

        let inGain = ((mixerIn + 50) / 100)
        let outGain = ((mixerOut + 50) / 100)
        let master = (mixerMaster / 10)

        let globalBass = mixerLimit
        let globalMid = mixerVolume
        let globalTreble = mixerTreble

        for c in 0..<channels {
            let ptr = channelData[c]
            for i in 0..<frameCount {
                var s = ptr[i]

                // TUNER (ogni 256 campioni)
                if c == 0 && i % 256 == 0 {
                    let freq = abs(s) * 800
                    if freq > 40 && freq < 1200 {
                        sendTunerData(frequency: freq)
                    }
                }

                // Input gain
                s *= inGain

                // Noise gate
                let noiseVal = pedalValues["Noise"] ?? 0
                let gateThreshold = (noiseVal / 18) + (mixerGate / 40)
                if fabsf(s) < gateThreshold * 0.02 { s = 0 }

                // Compressor
                let compVal = pedalValues["Compressor"] ?? 0
                if compVal > 0 {
                    let ratio = 1 + compVal / 5
                    let threshold: Float = 0.4
                    if s > threshold { s = threshold + (s - threshold) / ratio }
                    else if s < -threshold { s = -threshold + (s + threshold) / ratio }
                }

                // Clean boost
                let cleanVal = pedalValues["Clean"] ?? 0
                if cleanVal > 0 { s *= (1 + cleanVal / 7) }

                // Drive
                let od = (pedalValues["Overdrive"] ?? 0) / 6
                let crunch = (pedalValues["Crunch"] ?? 0) / 5
                let dist = (pedalValues["Distortion"] ?? 0) / 3.5
                let driveBase = mixerGate / 4
                let totalDrive = driveBase + od + crunch + dist
                if totalDrive > 0 {
                    let gain = 1 + totalDrive * 1.4
                    s = softClip(s * gain)
                }

                // Per‑pedal EQ
                var pb: Float = 0, pm: Float = 0, pt: Float = 0
                for (name, val) in pedalValues {
                    guard val > 0, let eq = pedalEQ[name] else { continue }
                    let f = val / 10
                    pb += (eq["Bass"] ?? 0) * f
                    pm += (eq["Mid"] ?? 0) * f
                    pt += (eq["Treble"] ?? 0) * f
                }
                s = applyEQ(sample: s, bass: pb, mid: pm, treble: pt)

                // Modulation
                let t = Float(CACurrentMediaTime())
                if let v = pedalValues["Chorus"], v > 0 { s *= (1 + sin(t * 2.5) * (v / 12)) }
                if let v = pedalValues["Flanger"], v > 0 { s *= (1 + cos(t * 4) * (v / 10) * 0.8) }
                if let v = pedalValues["Rotary"], v > 0 { s *= (1 + sin(t * 7) * (v / 14)) }
                if let v = pedalValues["Tremolo"], v > 0 {
                    let depth = min(0.9, v / 12)
                    let lfo = (sin(t * 8) + 1) / 2
                    s *= (1 - depth * lfo)
                }

                // Space (delay/reverb)
                let delayVal = pedalValues["Delay"] ?? 0
                let reverbVal = pedalValues["Reverb"] ?? 0
                let space = (delayVal * 1.4 + reverbVal * 1.8) / 20
                s *= (1 + space)

                // EQ globale
                s = applyEQ(sample: s, bass: globalBass, mid: globalMid, treble: globalTreble)

                // Output
                s *= outGain * master * externalGain

                // Limiter
                let limit = max(0.1, 1 - mixerLimit / 40)
                if s > limit { s = limit }
                if s < -limit { s = -limit }

                ptr[i] = s
            }
        }
    }

    private func softClip(_ x: Float) -> Float {
        let t = max(-20, min(20, x))
        let e = exp(2 * t)
        return (e - 1) / (e + 1)
    }

    private func applyEQ(sample: Float, bass: Float, mid: Float, treble: Float) -> Float {
        var s = sample
        s *= (1 + bass / 40)
        s *= (1 + mid / 55)
        s *= (1 + treble / 35)
        return s
    }
}
