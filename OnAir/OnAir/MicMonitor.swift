import CoreAudio
import AVFoundation

/// Queries the default audio input device to determine whether any process
/// currently has it open. This mirrors what the Rust POC did via coreaudio-sys.
///
/// macOS 10.15+ requires microphone permission before this query returns
/// meaningful results — request access via AVCaptureDevice before using.
struct MicMonitor {
    func isInUse() -> Bool {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)

        var defaultInputAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let idStatus = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultInputAddr, 0, nil, &size, &deviceID
        )
        guard idStatus == noErr, deviceID != kAudioDeviceUnknown else { return false }

        var isRunning: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        var runningAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let runStatus = AudioObjectGetPropertyData(deviceID, &runningAddr, 0, nil, &size, &isRunning)
        return runStatus == noErr && isRunning != 0
    }
}
