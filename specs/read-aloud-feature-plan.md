# Technical Implementation Plan: Storia "Read Aloud" Recognition Feature

### 1. Architectural Overview and System Requirements
The Storia "Read Aloud" feature utilizes a hybrid architecture leveraging the `speech_to_text` plugin for real-time recognition and `flutter_tts` for supplemental progress tracking. The implementation is optimized for short-phrase recognition, prioritizing low latency and battery efficiency.

#### Permissions Matrix
The following configurations must be implemented to ensure microphone access and service availability across all supported platforms.

| Platform | Permission / Key | Description |
| :--- | :--- | :--- |
| **iOS/macOS** | `NSSpeechRecognitionUsageDescription` | Explains speech recognition usage (Required by Apple). |
| **iOS/macOS** | `NSMicrophoneUsageDescription` | Explains microphone access usage (Required by Apple). |
| **Android** | `RECORD_AUDIO` | Grants microphone access for recognition. |
| **Android** | `INTERNET` | Required for network-based recognition services. |
| **Android** | `BLUETOOTH` | Support for Bluetooth headsets (SDK < 31). |
| **Android** | `BLUETOOTH_ADMIN` | Management of Bluetooth connectivity (SDK < 31). |
| **Android** | `BLUETOOTH_CONNECT` | Required for Bluetooth headset usage on SDK 31+. |

#### Platform-Specific Manifest Requirements
*   **Android SDK 30+:** You must declare the TTS service intent in the `<queries>` block of the `AndroidManifest.xml` to ensure visibility of the speech engine:
    ```xml
    <queries>
      <intent>
        <action android:name="android.intent.action.TTS_SERVICE" />
      </intent>
    </queries>
    ```
*   **Minimum SDKs:** Android SDK 21+ and iOS 10.0+ are non-negotiable requirements for the underlying speech APIs.

#### Initialization Lifecycle: The "Initialize Once" Pattern
The `speech_to_text` plugin requires an "Initialize Once" approach. Calling `initialize` multiple times is ignored and, critically, subsequent calls will not reset the `onStatus` or `onError` callbacks. If the initial registration of these callbacks is lost or overwritten, the UI highlighting logic will effectively "go dark" even if recognition continues. We will manage a single persistent instance via a Riverpod provider to ensure these listeners remain attached for the entire app session.

---

### 2. Speech-to-Text Package Integration
To maintain UX parity and minimize latency, we will configure the `speech_to_text` package with specific attention to audio feedback and session options.

#### Integration Parameters (v6.6.0+)
We will utilize the `SpeechListenOptions` object for fine-grained control over recognition sessions, including haptics and punctuation on iOS.
1.  **`initialize`**: Setup engine; establish persistent status listeners.
2.  **`listen`**: Pass `SpeechListenOptions` and a target `localeId`.
3.  **`stop`**: Finalize processing; the engine finishes converting the current buffer.
4.  **`cancel`**: Immediate termination; discards pending buffers.

#### iOS Sound Assets and Latency Warning
While Android handles system beeps natively, iOS requires assets to be defined in `pubspec.yaml`. 
*   **Mandatory Assets:** `speech_to_text_listening.m4r`, `speech_to_text_cancel.m4r`, and `speech_to_text_stop.m4r`.
*   **Architectural Note:** These files must be **extremely short** (e.g., <500ms). The recognizer delays startup until the asset playback finishes; long sound files will introduce perceived lag for the user.

---

### 3. Real-Time Word Matching & Phoneme-Level Tracking
Our matching engine must handle the discrepancies between spoken audio and text representation.

#### Rigorous Data Models
```dart
enum WordState { pending, current, correct, error }

class WordNode {
  final String target;
  final WordState state;
  final double confidence;
  final Duration? timestamp;

  WordNode({required this.target, this.state = WordState.pending, this.confidence = 0.0, this.timestamp});
}
```

#### The "Last Word Lost" Mitigation Algorithm
Android recognition often drops the final word of a phrase in the "final" result, even if it appeared in "partial" results. Our logic will implement the following:
1.  **Buffer partials:** Store the `RecognitionPart` array from the most recent partial result.
2.  **Compare on Final:** When `finalResult` is received, compare its word count against the last partial.
3.  **Synthesis:** If the final result is missing the last word but the partial result had it with high confidence, our `ReadingSessionProvider` will manually merge the partial's final word into the session state to prevent false errors for the child.

---

### 4. Children’s Speech Challenges and Technical Mitigations
Children's speech is characterized by pauses and hesitations that exceed standard engine timeouts.

*   **Android Timeout Mitigation:** Android timeouts are hard-coded (<5 seconds). We will implement a "relisten loop." If the `SpeechToText.status` stream emits `notListening` or `done` before the reader has reached the end of the `WordNode` list, the app will automatically restart the `listen` session unless the user has manually stopped it.
*   **iOS Duration Limit:** iOS sessions are capped at 60 seconds. Our provider will track session duration and trigger a graceful `stop` and immediate `listen` restart at the 55-second mark to ensure continuity.
*   **Quick Failure Handling:** If a session fails within 1-2 seconds (per Apple documentation), we will immediately check `isAvailable`. If it's a throttling issue, the UX will shift to an "offline mode" prompt rather than a technical error.

---

### 5. Platform-Specific Implementation Considerations
*   **iOS Live Streams:** For real-time reading, we utilize `SFSpeechAudioBufferRecognitionRequest` to process incoming audio streams rather than file-based processing.
*   **Android Recording Restriction:** It is technically impossible to record audio to a file on Android while simultaneously running speech recognition. We will prioritize recognition for the "Read Aloud" feature and disable the "Record Session" toggle on Android devices.
*   **Background Audio Coexistence:** To prevent background music or story narration from stopping when recognition starts, we will set the iOS `AudioCategory` using `flutter_tts` utilities:
    *   **Category:** `AVAudioSessionCategoryPlayAndRecord`
    *   **Options:** `duckOthers` (ensures background audio lowers in volume rather than stopping).

---

### 6. Flutter Code Architecture with Riverpod
The system follows a unidirectional data flow to ensure state consistency.

#### ASCII Architecture Diagram
```text
[ STT Plugin ] --> [ SpeechToTextRepository ] --> [ ReadingSessionProvider ]
      ^                      |                              |
      |             (Cleans & Buffers Text)         (StateNotifier / Enum)
      |                                                     |
[ UI Listeners ] <------------------------------------------+
(Mic Icon / Text Highlighting)
```

#### State Definitions
```dart
enum SpeechState { idle, listening, processing, error, throttled }
```
The `ReadingSessionProvider` (StateNotifier) will manage the `SpeechToText` instance, `currentIndex`, and `WordNode` list, ensuring that UI updates are reactive to the `speech_to_text` status stream.

---

### 7. UI/UX Flow for "Read Aloud" Mode
*   **Mandatory Visual Indicators:** Per Apple’s Human Interface Guidelines (HIG), a clear visual indicator (e.g., a pulsing microphone icon) must be visible whenever the microphone is active. This is a functional requirement for App Store approval.
*   **Live Feedback:** We will display recognized text fragments with low-opacity styling to show the child the app is "listening," transitioning to full-color highlighting once the matching algorithm confirms a `WordNode` as `correct`.
*   **Android Troubleshooting:** If initialization fails on Android, the UI will provide a specific "Kid-Friendly" action: "Oops! Make sure the 'Google App' is awake and allowed to use your microphone in Settings."

---

### 8. Fluency Metrics and Progress Tracking
#### Metric Calculation
*   **WCPM (Words Correct Per Minute):** Foundation metric based on the count of `WordNode` objects marked `correct` divided by the total session duration (derived from `SpeechRecognitionResult` timestamps).
*   **Detailed Analytics:** The session summary will include a `word_level_results` array, mapping target words to binary success/failure for parent review.

#### Progress Recovery and SDK Constraints
We will use `onRangeStart()` to track the pause index for progress saving.
*   **SDK 26+:** Native `onRangeStart` support will be used for exact index tracking.
*   **SDK 21-25 Fallback:** For older Android versions, we will implement an estimated index recovery based on the last high-confidence matched `WordNode` from the `SpeechToText` stream before the session was interrupted.

---

### 9. Implementation Roadmap
*   **Phase 1 (Foundations):** Manifest/Info.plist configuration including the `<queries>` intent; setup of the "Initialize Once" Riverpod provider.
*   **Phase 2 (Logic):** Implementation of the `WordNode` matching engine and the "Last Word Lost" merge algorithm.
*   **Phase 3 (UX/UI):** Development of the pulsing HIG-compliant microphone indicator, live text highlighting, and the relisten loop for Android.
*   **Phase 4 (Refinement & Troubleshooting):** Implementation of WCPM metrics with SDK 26+ fallbacks; testing of iOS voice asset latency; verification of Bluetooth headset behavior in the iOS simulator.