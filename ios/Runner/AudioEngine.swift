import Foundation
import AVFoundation
import Flutter

final class AudioEngine {
    static let shared = AudioEngine()

    private let engine = AVAudioEngine()
    private var inputNode: AVAudioInputNode?
    private var mainMixer: AVAudioMixerNode?
    private var outputNode: AVAudioOutputNode?

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

    // Per‑pedal EQ (Bass/Mid/Treble in dB-like scale -10..+10)
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

    // MARK: - DSP helpers

    private struct LFO {
        var phase: Float = 0
        mutating func next(rate: Float, sampleRate: Float) -> Float {
            phase += (2 * .pi * rate) / sampleRate
            if phase > 2 * .pi { phase -= 2 * .pi }
            return sin(phase)
        }
    }

    private struct DelayLine {
        var buffer: [Float]
        var index: Int = 0
        let sampleRate: Float

        init(maxTime: Float, sampleRate: Float) {
            self.sampleRate = sampleRate
            let size = Int(maxTime * sampleRate) + 1
            buffer = Array(repeating: 0, count: size)
        }

        mutating func process(input: Float, time: Float, feedback: Float, mix: Float) -> Float {
            let delaySamples = max(1, min(buffer.count - 1, Int(time * sampleRate)))
            let readIndex = (index - delaySamples + buffer.count) % buffer.count
            let delayed = buffer[readIndex]
            let out = input * (1 - mix) + delayed * mix
            buffer[index] = input + delayed * feedback
            index = (index + 1) % buffer.count
            return out
        }
    }

    private struct Biquad {
        var b0: Float = 1, b1: Float = 0, b2: Float = 0
        var a1: Float = 0, a2: Float = 0
        var z1: Float = 0, z2: Float = 0

        mutating func process(_ x: Float) -> Float {
            let y = b0 * x + z1
            z1 = b1 * x - a1 * y + z2
            z2 = b2 * x - a2 * y
            return y
        }
    }

    private func makePeakingEQ(freq: Float, q: Float, gainDB: Float, sampleRate: Float) -> Biquad {
        let A = pow(10, gainDB / 40)
        let w0 = 2 * Float.pi * freq / sampleRate
        let alpha = sin(w0) / (2 * q)

        let b0 = 1 + alpha * A
        let b1 = -2 * cos(w0)
        let b2 = 1 - alpha * A
        let a0 = 1 + alpha / A
        let a1 = -2 * cos(w0)
        let a2 = 1 - alpha / A

        var biq = Biquad()
        biq.b0 = b0 / a0
        biq.b1 = b1 / a0
        biq.b2 = b2 / a0
        biq.a1 = a1 / a0
        biq.a2 = a2 / a0
        return biq
    }

    private func makeShelf(freq: Float, gainDB: Float, sampleRate: Float, high: Bool) -> Biquad {
        let A = pow(10, gainDB / 40)
        let w0 = 2 * Float.pi * freq / sampleRate
        let alpha = sin(w0) / 2 * sqrt((A + 1 / A) * (1 / 0.707 - 1) + 2)
        let cosw0 = cos(w0)

        var b0: Float, b1: Float, b2: Float, a0: Float, a1: Float, a2: Float

        if high {
            b0 = A * ((A + 1) + (A - 1) * cosw0 + 2 * sqrt(A) * alpha)
            b1 = -2 * A * ((A - 1) + (A + 1) * cosw0)
            b2 = A * ((A + 1) + (A - 1) * cosw0 - 2 * sqrt(A) * alpha)
            a0 = (A + 1) - (A - 1) * cosw0 + 2 * sqrt(A) * alpha
            a1 = 2 * ((A - 1) - (A + 1) * cosw0)
            a2 = (A + 1) - (A - 1) * cosw0 - 2 * sqrt(A) * alpha
        } else {
            b0 = A * ((A + 1) - (A - 1) * cosw0 + 2 * sqrt(A) * alpha)
            b1 = 2 * A * ((A - 1) - (A + 1) * cosw0)
            b2 = A * ((A + 1) - (A - 1) * cosw0 - 2 * sqrt(A) * alpha)
            a0 = (A + 1) + (A - 1) * cosw0 + 2 * sqrt(A) * alpha
            a1 = -2 * ((A - 1) + (A + 1) * cosw0)
            a2 = (A + 1) + (A - 1) * cosw0 - 2 * sqrt(A) * alpha
        }

        var biq = Biquad()
        biq.b0 = b0 / a0
        biq.b1 = b1 / a0
        biq.b2 = b2 / a0
        biq.a1 = a1 / a0
        biq.a2 = a2 / a0
        return biq
    }

    // Per‑pedal DSP state
    private var chorusDelayL = DelayLine(maxTime: 0.03, sampleRate: 44100)
    private var chorusDelayR = DelayLine(maxTime: 0.03, sampleRate: 44100)
    private var flangerDelayL = DelayLine(maxTime: 0.01, sampleRate: 44100)
    private var flangerDelayR = DelayLine(maxTime: 0.01, sampleRate: 44100)
    private var mainDelayL = DelayLine(maxTime: 1.0, sampleRate: 44100)
    private var mainDelayR = DelayLine(maxTime: 1.0, sampleRate: 44100)
    private var reverbDelayL = DelayLine(maxTime: 1.2, sampleRate: 44100)
    private var reverbDelayR = DelayLine(maxTime: 1.2, sampleRate: 44100)

    private var lfoChorus = LFO()
    private var lfoFlanger = LFO()
    private var lfoTremolo = LFO()
    private var lfoRotaryAmp = LFO()
    private var lfoRotaryPan = LFO()

    private var compEnv: Float = 0
    private var gateEnv: Float = 0

    private var pedalEQFiltersL: [String: (low: Biquad, mid: Biquad, high: Biquad)] = [:]
    private var pedalEQFiltersR: [String: (low: Biquad, mid: Biquad, high: Biquad)] = [:]

    private init() {}

    func setFlutterChannel(_ channel: FlutterMethodChannel) {
        self.flutterChannel = channel
    }

    func start() {
        guard !isStarted else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord,
                                    options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
            try session.setActive(true)

            let inNode = engine.inputNode
            let mixer = engine.mainMixerNode
            let outNode = engine.outputNode

            let format = inNode.outputFormat(forBus: 0)
            let sampleRate = Float(format.sampleRate)

            // Re-init delay lines with real sample rate
            chorusDelayL = DelayLine(maxTime: 0.03, sampleRate: sampleRate)
            chorusDelayR = DelayLine(maxTime: 0.03, sampleRate: sampleRate)
            flangerDelayL = DelayLine(maxTime: 0.01, sampleRate: sampleRate)
            flangerDelayR = DelayLine(maxTime: 0.01, sampleRate: sampleRate)
            mainDelayL = DelayLine(maxTime: 1.0, sampleRate: sampleRate)
            mainDelayR = DelayLine(maxTime: 1.0, sampleRate: sampleRate)
            reverbDelayL = DelayLine(maxTime: 1.2, sampleRate: sampleRate)
            reverbDelayR = DelayLine(maxTime: 1.2, sampleRate: sampleRate)

            engine.disconnectNodeInput(mixer)
            engine.disconnectNodeInput(outNode)

            engine.connect(inNode, to: mixer, format: format)
            engine.connect(mixer, to: outNode, format: format)

            mixer.removeTap(onBus: 0)
            mixer.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
                self?.process(buffer: buffer)
            }

            try engine.start()

            self.inputNode = inNode
            self.mainMixer = mixer
            self.outputNode = outNode
            self.isStarted = true

        } catch {
            print("AudioEngine start error: \(error)")
        }
    }

    func setExternalGain(_ value: Float) {
        externalGain = max(0, min(1, value))
    }

    func setMixerParam(name: String, value: Float) {
        switch name {
        case "In": mixerIn = value
        case "Out": mixerOut = value
        case "Gate": mixerGate = value
        case "Limit": mixerLimit = value
        case "Volume": mixerVolume = value
        case "Treble": mixerTreble = value
        case "Master": mixerMaster = value
        default: break
        }
    }

    func setPedalValue(name: String, value: Float) {
        pedalValues[name] = value
        rebuildPedalEQFilters()
    }

    func setPedalEQ(pedal: String, band: String, value: Float) {
        guard var eq = pedalEQ[pedal] else { return }
        eq[band] = value
        pedalEQ[pedal] = eq
        rebuildPedalEQFilters()
    }

    private func rebuildPedalEQFilters() {
        guard let sr = mainMixer?.outputFormat(forBus: 0).sampleRate else { return }
        let sampleRate = Float(sr)

        var newL: [String: (low: Biquad, mid: Biquad, high: Biquad)] = [:]
        var newR: [String: (low: Biquad, mid: Biquad, high: Biquad)] = [:]

        for (pedal, bands) in pedalEQ {
            let bassGain = (bands["Bass"] ?? 0) * 1.5
            let midGain  = (bands["Mid"] ?? 0) * 1.5
            let treGain  = (bands["Treble"] ?? 0) * 1.5

            let low  = makeShelf(freq: 120, gainDB: bassGain, sampleRate: sampleRate, high: false)
            let mid  = makePeakingEQ(freq: 800, q: 0.8, gainDB: midGain, sampleRate: sampleRate)
            let high = makeShelf(freq: 3500, gainDB: treGain, sampleRate: sampleRate, high: true)

            newL[pedal] = (low, mid, high)
            newR[pedal] = (low, mid, high)
        }

        pedalEQFiltersL = newL
        pedalEQFiltersR = newR
    }

    // MARK: - Tuner

    private func sendTunerData(frequency: Float) {
        guard let channel = flutterChannel else { return }
        guard frequency > 40, frequency < 1200 else { return }

        let notes = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
        let midi = 69 + 12 * log2(frequency / 440.0)
        let idx = Int(round(midi)) % 12
        let note = notes[(idx + 12) % 12]

        channel.invokeMethod("tunerData", arguments: [
            "frequency": frequency,
            "note": note
        ])
    }

    private func sendMeterData(rms: Float, peak: Float) {
        guard let channel = flutterChannel else { return }
        channel.invokeMethod("meterData", arguments: [
            "rms": rms,
            "peak": peak
        ])
    }

    // MARK: - Main processing

    private func process(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)
        let channels = Int(buffer.format.channelCount)
        let sampleRate = Float(buffer.format.sampleRate)

        let inGain = ((mixerIn + 50) / 100)
        let outGain = ((mixerOut + 50) / 100)
        let master = (mixerMaster / 10)

        let globalBass = mixerLimit
        let globalMid = mixerVolume
        let globalTreble = mixerTreble

        var sumSquares: Float = 0
        var peakAbs: Float = 0

        for c in 0..<channels {
            let ptr = channelData[c]
            for i in 0..<frameCount {
                var s = ptr[i]

                // Tuner (semplice pitch proxy)
                if c == 0 && i % 256 == 0 {
                    let freq = abs(s) * 800
                    sendTunerData(frequency: freq)
                }

                // Input gain
                s *= inGain

                // Noise gate (con envelope)
                let noiseVal = pedalValues["Noise"] ?? 0
                let gateThreshold = (noiseVal / 18) + (mixerGate / 40)
                let target = fabsf(s)
                let attack: Float = 0.01
                let release: Float = 0.2
                let coeff = target > gateEnv ? attack : release
                gateEnv = gateEnv + (target - gateEnv) * coeff
                if gateEnv < gateThreshold * 0.02 { s = 0 }

                // Compressor
                let compVal = pedalValues["Compressor"] ?? 0
                if compVal > 0 {
                    let threshold: Float = 0.35
                    let ratio: Float = 1 + compVal / 3
                    let envAttack: Float = 0.01
                    let envRelease: Float = 0.15
                    let level = fabsf(s)
                    let envCoeff = level > compEnv ? envAttack : envRelease
                    compEnv = compEnv + (level - compEnv) * envCoeff
                    if compEnv > threshold {
                        let gain = threshold + (compEnv - threshold) / ratio
                        let g = gain / max(compEnv, 0.0001)
                        s *= g
                    }
                }

                // Clean boost
                let cleanVal = pedalValues["Clean"] ?? 0
                if cleanVal > 0 { s *= (1 + cleanVal / 6) }

                // Drive (Overdrive / Crunch / Distortion)
                let od = (pedalValues["Overdrive"] ?? 0) / 10
                let crunch = (pedalValues["Crunch"] ?? 0) / 10
                let dist = (pedalValues["Distortion"] ?? 0) / 10

                if od > 0 || crunch > 0 || dist > 0 {
                    let driveAmount = od * 0.8 + crunch * 1.2 + dist * 1.8
                    let preGain = 1 + driveAmount * 4
                    var x = s * preGain

                    if dist > 0 {
                        // Distortion più aggressiva
                        x = tanh(x * (1 + dist * 3))
                    } else if crunch > 0 {
                        // Crunch più duro
                        let k: Float = 2 + crunch * 6
                        x = (1 + k) * x / (1 + k * fabsf(x))
                    } else {
                        // Overdrive morbido
                        x = softClip(x)
                    }

                    s = x
                }

                // Per‑pedal EQ (applicato come "voicing" globale dei pedali attivi)
                var eqSample = s
                for (name, val) in pedalValues {
                    guard val > 0 else { continue }
                    guard let filtersL = (c == 0 ? pedalEQFiltersL[name] : pedalEQFiltersR[name]) else { continue }
                    let factor = val / 10
                    var tmp = eqSample
                    tmp = filtersL.low.process(tmp)
                    tmp = filtersL.mid.process(tmp)
                    tmp = filtersL.high.process(tmp)
                    eqSample = eqSample * (1 - factor) + tmp * factor
                }
                s = eqSample

                // Modulation LFOs
                let tChorus = lfoChorus.next(rate: 0.8 + (pedalValues["Chorus"] ?? 0) * 0.15,
                                             sampleRate: sampleRate)
                let tFlanger = lfoFlanger.next(rate: 0.3 + (pedalValues["Flanger"] ?? 0) * 0.25,
                                               sampleRate: sampleRate)
                let tTrem = lfoTremolo.next(rate: 2 + (pedalValues["Tremolo"] ?? 0) * 0.6,
                                            sampleRate: sampleRate)
                let tRotAmp = lfoRotaryAmp.next(rate: 1.2 + (pedalValues["Rotary"] ?? 0) * 0.3,
                                                sampleRate: sampleRate)
                let tRotPan = lfoRotaryPan.next(rate: 1.2 + (pedalValues["Rotary"] ?? 0) * 0.3,
                                                sampleRate: sampleRate)

                // Chorus (modulated delay)
                if let v = pedalValues["Chorus"], v > 0 {
                    let depth = 0.002 + 0.002 * (v / 10)
                    let base = 0.008
                    let time = base + depth * tChorus
                    let mix: Float = 0.25 + 0.4 * (v / 10)
                    if c == 0 {
                        s = chorusDelayL.process(input: s, time: time, feedback: 0.1, mix: mix)
                    } else {
                        s = chorusDelayR.process(input: s, time: time, feedback: 0.1, mix: mix)
                    }
                }

                // Flanger (short comb delay)
                if let v = pedalValues["Flanger"], v > 0 {
                    let depth = 0.0008 + 0.0008 * (v / 10)
                    let base = 0.001
                    let time = base + depth * tFlanger
                    let mix: Float = 0.3 + 0.4 * (v / 10)
                    let fb: Float = 0.2 + 0.4 * (v / 10)
                    if c == 0 {
                        s = flangerDelayL.process(input: s, time: time, feedback: fb, mix: mix)
                    } else {
                        s = flangerDelayR.process(input: s, time: time, feedback: fb, mix: mix)
                    }
                }

                // Tremolo (amp modulation)
                if let v = pedalValues["Tremolo"], v > 0 {
                    let depth = min(0.95, v / 10)
                    let lfo = (tTrem + 1) / 2
                    let gain = 1 - depth * lfo
                    s *= gain
                }

                // Rotary (amp + pan)
                if let v = pedalValues["Rotary"], v > 0 {
                    let depthAmp = 0.2 + 0.4 * (v / 10)
                    let depthPan = 0.4 + 0.4 * (v / 10)
                    let ampMod = 1 - depthAmp * ((tRotAmp + 1) / 2)
                    let pan = depthPan * tRotPan
                    let panL = cos((pan + 1) * .pi / 4)
                    let panR = sin((pan + 1) * .pi / 4)
                    s *= ampMod
                    if c == 0 {
                        s *= panL
                    } else {
                        s *= panR
                    }
                }

                // Delay (main echo)
                if let v = pedalValues["Delay"], v > 0 {
                    let time: Float = 0.15 + 0.6 * (v / 10)
                    let fb: Float = 0.15 + 0.6 * (v / 10)
                    let mix: Float = 0.15 + 0.4 * (v / 10)
                    if c == 0 {
                        s = mainDelayL.process(input: s, time: time, feedback: fb, mix: mix)
                    } else {
                        s = mainDelayR.process(input: s, time: time, feedback: fb, mix: mix)
                    }
                }

                // Reverb (simple feedback delay wash)
                if let v = pedalValues["Reverb"], v > 0 {
                    let time: Float = 0.25 + 0.7 * (v / 10)
                    let fb: Float = 0.3 + 0.55 * (v / 10)
                    let mix: Float = 0.12 + 0.35 * (v / 10)
                    if c == 0 {
                        s = reverbDelayL.process(input: s, time: time, feedback: fb, mix: mix)
                    } else {
                        s = reverbDelayR.process(input: s, time: time, feedback: fb, mix: mix)
                    }
                }

                // Acoustic IR (placeholder: gentle cab-like EQ)
                if let v = pedalValues["Acoustic IR"], v > 0 {
                    let factor = v / 10
                    // semplice "cab sim" grossolana
                    var cab = s
                    // taglia un po' di bassi estremi e alti estremi
                    cab *= 0.9
                    s = s * (1 - factor) + cab * factor
                }

                // Global EQ
                s = applyGlobalEQ(sample: s, bass: globalBass, mid: globalMid, treble: globalTreble)

                // Output gain
                s *= outGain * master * externalGain

                // Limiter
                let limit = max(0.1, 1 - mixerLimit / 40)
                if s > limit { s = limit }
                if s < -limit { s = -limit }

                // Meter
                let a = fabsf(s)
                sumSquares += a * a
                if a > peakAbs { peakAbs = a }

                ptr[i] = s
            }
        }

        let totalSamples = Float(frameCount * max(1, channels))
        if totalSamples > 0 {
            let rms = sqrt(sumSquares / totalSamples)
            sendMeterData(rms: rms, peak: peakAbs)
        }
    }

    private func softClip(_ x: Float) -> Float {
        let t = max(-20, min(20, x))
        let e = exp(2 * t)
        return (e - 1) / (e + 1)
    }

    private func applyGlobalEQ(sample: Float, bass: Float, mid: Float, treble: Float) -> Float {
        var s = sample
        s *= (1 + bass / 40)
        s *= (1 + mid / 55)
        s *= (1 + treble / 35)
        return s
    }
}
