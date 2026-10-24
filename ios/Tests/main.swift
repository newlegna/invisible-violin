import Foundation

func hand(x: Double, y: Double, bent: [Int] = [], rotation: Double = 0) -> TrackedHand {
    var world = Array(repeating: HandPoint(x: 0, y: 0, z: 0), count: 21)
    for i in 0..<4 {
        let base = 5 + 4 * i
        let px = Double(i) * 0.025
        world[base] = HandPoint(x: px, y: 0.03)
        world[base + 1] = HandPoint(x: px, y: 0.06)
        world[base + 2] = bent.contains(i) ? HandPoint(x: px + 0.025, y: 0.06) : HandPoint(x: px, y: 0.085)
        world[base + 3] = bent.contains(i) ? HandPoint(x: px + 0.04, y: 0.06) : HandPoint(x: px, y: 0.10)
    }
    world = world.map { p in
        HandPoint(x: p.x * cos(rotation) + p.z * sin(rotation), y: p.y,
                  z: -p.x * sin(rotation) + p.z * cos(rotation))
    }
    var image = world.map { HandPoint(x: x + $0.x, y: y - $0.y) }
    image[0] = HandPoint(x: x, y: y)
    return TrackedHand(points: image, worldPoints: world)
}

var instrument = GestureInstrument()
var time = 0.0
func frame(y: Double = 0.5, fingers: [Int] = [], rotation: Double = 0) -> InstrumentNote {
    time += 0.02
    return instrument.update(hands: [hand(x: 0.22 + 0.04 * sin(time * 8), y: y),
                                     hand(x: 0.8, y: 0.5, bent: fingers, rotation: rotation)], time: time)!
}
func settle(y: Double, fingers: [Int], rotation: Double = 0) -> InstrumentNote {
    var result = frame(y: y, fingers: fingers, rotation: rotation)
    for _ in 0..<4 { result = frame(y: y, fingers: fingers, rotation: rotation) }
    return result
}
let expected = [[76,77,79,81,83], [69,71,72,74,76], [62,64,65,67,69], [55,57,59,60,62]]
let heights = [0.2, 0.45, 0.6, 0.85]
assert(frame().amplitude == 0, "First frame must be silent")
var played = settle(y: 0.45, fingers: [])
assert(played.amplitude > 0 && played.midi == 69)
for string in 0..<4 {
    for finger in Array(0...4) + Array((0...3).reversed()) {
        played = settle(y: heights[string], fingers: Array(0..<finger))
        assert(played.stringIndex == string && played.midi == expected[string][finger], "Incorrect sequential fingering")
        assert(played.finger == finger)
    }
}
// Every finger can also be used independently; lower held fingers do not form chords.
for finger in 1...4 {
    let result = settle(y: 0.6, fingers: [finger - 1])
    assert(result.midi == expected[2][finger])
}
assert(settle(y: 0.6, fingers: [0, 1]).label == "F4", "Second finger on D must be F natural")
assert(settle(y: 0.2, fingers: [0]).label == "F5", "First finger on E must be F natural")
// A brief spurious little-finger detection must not jump from E to A.
_ = settle(y: 0.6, fingers: [0])
assert(frame(y: 0.6, fingers: [0,3]).midi == 64)
assert(frame(y: 0.6, fingers: [0]).midi == 64)
// World-space flexion is unchanged by tilting the hand toward the camera.
assert(settle(y: 0.6, fingers: [0,1], rotation: .pi / 2).midi == 65)
// String threshold jitter does not interrupt an established D-string note.
assert(frame(y: 0.53, fingers: [0,1]).stringIndex == 2)
assert(frame(y: 0.51, fingers: [0,1]).stringIndex == 2)
assert(instrument.update(hands: [], time: time + 0.02) == nil)
time += 0.04
assert(frame(y: 0.6, fingers: [0]).amplitude == 0, "Reacquisition must wait for a stable pose")
_ = settle(y: 0.6, fingers: [0])
time += 0.3
assert(frame(y: 0.6, fingers: [3]).amplitude == 0, "Long stalls must not keep the previous pose")
assert(instrument.update(hands: [hand(x: 0.48,y: 0.5),hand(x: 0.52,y: 0.5)],time: time + 0.02) == nil)
instrument.bowOnScreenLeft = false
instrument.reset()
for _ in 0..<5 {
    time += 0.02
    played = instrument.update(hands: [hand(x: 0.2,y: 0.5,bent: [0,1]),hand(x: 0.8,y: 0.6)],time: time)!
}
assert(played.midi == 65)
assert(instrument.update(hands: [TrackedHand(points: []),hand(x: 0.8,y: 0.5)],time: time + 0.02) == nil)
assert(instrument.update(hands: [TrackedHand(points: hand(x: 0.2,y: 0.5).points),hand(x: 0.8,y: 0.5)],time: time + 0.04) == nil)
let reference: [(Int, Double)] = [(55,195.997718),(62,293.664768),(64,329.627557),(65,349.228231),(67,391.995436),(69,440),(76,659.255114),(77,698.456463),(83,987.766603)]
for (midi,hertz) in reference {
    assert(abs(InstrumentNote(midi: midi,stringIndex: 2,amplitude: 0).frequency - hertz) < 0.00001)
}
print("Gesture checks passed: every string ascending/descending, natural F, independent fingers, jitter rejection, hand rotation, dropout, swap, and reference tuning.")

// Index presses can bend at the palm knuckle while the middle knuckle stays straight.
func indexPose(baseFlex: Double = 0, middleFlex: Double = 0) -> TrackedHand {
    let original = hand(x: 0.8, y: 0.5)
    var world = original.worldPoints
    let b = baseFlex * .pi / 180
    let m = (baseFlex + middleFlex) * .pi / 180
    world[6] = HandPoint(x: 0, y: 0.03 + 0.03 * cos(b), z: 0.03 * sin(b))
    world[7] = HandPoint(x: 0, y: world[6].y + 0.025 * cos(m), z: world[6].z + 0.025 * sin(m))
    world[8] = HandPoint(x: 0, y: world[7].y + 0.02 * cos(m), z: world[7].z + 0.02 * sin(m))
    return TrackedHand(points: original.points, worldPoints: world)
}
var indexInstrument = GestureInstrument()
var indexTime = 0.0
func holdIndex(base: Double = 0, middle: Double = 0) -> InstrumentNote {
    var result: InstrumentNote!
    for _ in 0..<6 {
        indexTime += 0.02
        result = indexInstrument.update(hands: [hand(x: 0.2,y: 0.6),indexPose(baseFlex: base,middleFlex: middle)], time: indexTime)
    }
    return result
}
assert(!indexInstrument.calibrateIndexUp(), "No calibration without visible landmarks")
assert(holdIndex().midi == 62)
assert(holdIndex(base: 35).midi == 64, "Base-knuckle press must play first finger")
assert(indexInstrument.fingersDown[0] && indexInstrument.indexPressAmount == 1)
assert(holdIndex().midi == 62)
assert(holdIndex(middle: 35).midi == 64, "A shallow middle-knuckle curl must register")
_ = holdIndex()
indexInstrument.indexSensitivity = 1
assert(holdIndex(base: 20).midi == 64, "Higher sensitivity should accept a smaller press")
_ = holdIndex()
indexInstrument.indexSensitivity = 0
assert(holdIndex(base: 35).midi == 62, "Lower sensitivity should reject smaller movements")
indexInstrument.indexSensitivity = 0.6
_ = holdIndex(base: 35)
assert(indexInstrument.calibrateIndexUp())
assert(holdIndex(base: 35).midi == 62, "Calibrated resting curve is finger up")
assert(holdIndex(base: 45).midi == 62)
assert(holdIndex(base: 65).midi == 64)
assert(holdIndex(base: 40).midi == 62, "Release returns to the calibrated open string")
assert(indexInstrument.update(hands: [],time: indexTime+0.02) == nil)
assert(indexInstrument.indexPressAmount == nil && !indexInstrument.canCalibrateIndex)
assert(holdIndex(base: 35).midi == 62, "Calibration survives temporary hand loss")
indexInstrument.clearIndexCalibration()
assert(holdIndex(base: 35).midi == 64, "Changing bow hands can discard the old calibration")
print("Index checks passed: base and middle knuckle presses, sensitivity, live feedback, rest calibration, release, and reacquisition.")
