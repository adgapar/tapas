import CoreAudio
import Foundation

struct MicrophoneProcess: Sendable {
    let pid: Int32
    let bundleID: String?
}

/// Reads process activity flags only. Does not open a device, install a tap,
/// request microphone access, or receive audio samples.
enum MicrophoneActivity {
    static func read() throws -> [MicrophoneProcess] {
        var address = property(kAudioHardwarePropertyProcessObjectList)
        var size: UInt32 = 0
        try check(AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size))
        let stride = MemoryLayout<AudioObjectID>.stride
        guard Int(size) % stride == 0 else { throw ReadError(status: kAudioHardwareBadPropertySizeError) }
        var processes = [AudioObjectID](repeating: 0, count: Int(size) / stride)
        if processes.isEmpty { return [] }
        let status = processes.withUnsafeMutableBytes { bytes in
            AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, bytes.baseAddress!)
        }
        try check(status)
        return try processes.prefix(Int(size) / stride).compactMap { process in
            do {
                guard try uint32(process, kAudioProcessPropertyIsRunningInput) != 0 else { return nil }
                let pid = Int32(bitPattern: try uint32(process, kAudioProcessPropertyPID))
                return MicrophoneProcess(pid: pid, bundleID: bundleID(process))
            } catch let error as ReadError where error.status == kAudioHardwareBadObjectError {
                // A process can exit between enumeration and its property read.
                return nil
            }
        }
    }

    private static func uint32(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) throws -> UInt32 {
        var address = property(selector)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        try check(AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value))
        return value
    }

    private static func bundleID(_ object: AudioObjectID) -> String? {
        var address = property(kAudioProcessPropertyBundleID)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr else { return nil }
        // The Core Audio property contract returns an owned CFString.
        return value?.takeRetainedValue() as String?
    }

    private static func property(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    }

    private static func check(_ status: OSStatus) throws {
        if status != noErr { throw ReadError(status: status) }
    }

    struct ReadError: Error { let status: OSStatus }
}
