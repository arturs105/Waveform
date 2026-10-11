import AVFoundation
import os

/// Process-wide cache of decoded (and channel-isolated) audio buffers, so a
/// lane that re-appears skips the disk read in `ClipRenderer.loadAsync` and
/// draws immediately. Off by default; the app flips `isEnabled` (debug menu
/// "Cache Waveforms"). Disabling drops every entry.
public final class WaveformBufferCache: @unchecked Sendable {
    public static let shared = WaveformBufferCache()

    public struct Entry: @unchecked Sendable {
        public let buffer: AVAudioPCMBuffer
        public let frameCount: Int
        public let sampleRate: Int
    }

    private struct Key: Hashable {
        let url: URL
        let channel: Int?
    }

    private struct Storage {
        var isEnabled = false
        var entries: [Key: Entry] = [:]
    }

    private let storage = OSAllocatedUnfairLock(initialState: Storage())

    public var isEnabled: Bool {
        get { storage.withLock { $0.isEnabled } }
        set {
            storage.withLock {
                $0.isEnabled = newValue
                if !newValue { $0.entries.removeAll() }
            }
        }
    }

    private init() {}

    public func entry(url: URL, channel: Int?) -> Entry? {
        storage.withLock { $0.isEnabled ? $0.entries[Key(url: url, channel: channel)] : nil }
    }

    public func store(_ entry: Entry, url: URL, channel: Int?) {
        storage.withLock {
            guard $0.isEnabled else { return }
            $0.entries[Key(url: url, channel: channel)] = entry
        }
    }

    public func removeAll() {
        storage.withLock { $0.entries.removeAll() }
    }
}
