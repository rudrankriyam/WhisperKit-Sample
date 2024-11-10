# Whispering

Whispering is a sample SwiftUI project showing how to use [**WhisperKit**](https://github.com/argmaxinc/WhisperKit) to transcribe audio across Apple platforms. The app has audio recording and transcription, using WhisperKit and AVFoundation. 

## Features

- Record audio and view transcription results almost instantly.
- Simplest UI with controls for starting and stopping recordings.
- Can be used across various Apple platforms with SwiftUI.

## Running the App

```bash
git clone https://github.com/rudrankriyam/whispering.git
cd whispering
```

Open the project in Xcode, build and run the app on a **real** device.

## Usage

- Record Audio: Tap the microphone icon to start recording audio. It will first ask for permission to microphone and then download the model. The recording status will be indicated by a visual waveform and a “Recording…” label.
- Transcribe: Once recording is stopped, the audio file will be transcribed, and results will appear in the text view.

## License

This project is licensed under the MIT License - see the LICENSE file for details. 

---

Enjoy using Whispering! If you have questions or feedback, feel free to reach out to me on [X @rudrankriyam](https://x.com/rudrankriyam)!
