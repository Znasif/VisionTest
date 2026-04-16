# VisionTest — Adaptive Color Discrimination on Meta Quest 3

This repository contains a Unity project for running an adaptive **3AFC color discrimination experiment** on the Meta Quest 3 in mixed reality, as part of the system described in:

> **Hong et al. (2025)** — *Comprehensive characterization of human color discrimination thresholds*
> bioRxiv. [https://doi.org/10.1101/2025.07.16.665219](https://www.biorxiv.org/content/10.1101/2025.07.16.665219v2)

The companion Python server (AEPsych + WPPM fitting) lives here: [github.com/Znasif/aepsych](https://github.com/Znasif/aepsych)

---

## Motivation

Color discrimination thresholds — the smallest detectable color differences — underlie models of color vision, clinical diagnostics, and display calibration. A comprehensive characterization across the full stimulus space has long been intractable due to the **psychophysical curse of dimensionality**.

This project implements an immersive, headset-based stimulus presentation front-end for the adaptive experiment. The Meta Quest 3 runs the task in mixed reality while an AEPsych server (running on a connected PC over a TCP bridge) selects maximally informative stimuli on every trial. After data collection, a Wishart Process Psychophysical Model (WPPM) is fit post-hoc to recover the full discrimination surface with only ~6,000 trials per participant.

---

## What the Experiment Looks Like

![WPPM Stimuli Presentation in Meta Quest 3](Quest.gif)

The participant sees three colored circles in mixed reality. Two are the **reference** color and one is the **comparison** (odd one out). The task is to identify which circle is different. Responses are sent back to the AEPsych server to update the GP model and select the next trial.

---

## System Overview

```
Meta Quest 3 (this repo)                Python server (aepsych repo)
────────────────────────                ────────────────────────────
Unity 3AFC experiment                   AEPsych server on port 5555
│                                       │
│  ←── next trial (x0, delta) ─────────┤  (WSL + conda activate braille)
│  ──── response (correct/incorrect) ──→│
│                                       ├── realtime_visualizer.py
│  (ngrok TCP tunnel over internet)     └── post-hoc WPPM fitting
```

---

## Prerequisites

- Meta Quest 3 or 3s running HorizonOS v74+
- Unity 6 (or 2022.3 LTS)
- A PC running the [AEPsych server](https://github.com/Znasif/aepsych) accessible over TCP (e.g. via [ngrok](https://ngrok.com/))

---

## Setup & Running the Experiment

### 1. Start the AEPsych server (on your PC / WSL)

```bash
conda activate braille
python aepsych/server/server.py --port 5555 --ip 0.0.0.0
```

### 2. Expose it via ngrok

```bash
ngrok tcp 5555
```

Note the forwarding address, e.g. `0.tcp.ngrok.io:12345`.

### 3. Build and deploy the Unity scene

- Open `Unity-QuestVisionKit` in Unity 6.
- Navigate to `Assets/Samples/7 Experiment/Experiment Scene.unity`.
- In the scene, locate the `AEPsychClient` component and enter the ngrok address as the server URL (host + port).
- Build for Android and deploy to your Quest 3.

### 4. Run the experiment

Put on the Quest. The app will connect to the server and begin presenting trials automatically. Three colored circles appear floating in your mixed-reality space. Press:
- **Right trigger** — select left circle
- **B button** — select middle circle
- **A button** — select right circle

### 5. Monitor progress in real time (optional)

On the PC:
```bash
python realtime_visualizer.py
```

This polls the AEPsych database and shows a live scatter plot of sampled stimuli in model space, colour-coded by response correctness.

---

## AEPsych Configuration

The experiment uses a 4-D parameter space (defined in `ColorConfigGenerator.cs`):

| Parameter | Meaning | Range |
|-----------|---------|-------|
| `x0_dim1` | Reference colour, dim 1 (model space) | [-0.7, 0.7] |
| `x0_dim2` | Reference colour, dim 2 (model space) | [-0.7, 0.7] |
| `delta_dim1` | Comparison offset, dim 1 | [-0.3, 0.3] |
| `delta_dim2` | Comparison offset, dim 2 | [-0.3, 0.3] |

Outcome: **1 = correct** (identified the odd one out), **0 = incorrect**.
Target threshold: **66.7% correct** (`MCLevelSetEstimation`).

Phase 1 (900 trials): Sobol quasi-random initialization.
Phase 2 (5100 trials): GP-based adaptive sampling.

---

## Key Files

```
Unity-QuestVisionKit/Assets/
  Samples/7 Experiment/
    Experiment Scene.unity          # Main experiment scene
  Scripts/Experiments/
    ColorDiscrimination.cs          # 3AFC trial logic, model-space → RGB
    ColorConfigGenerator.cs         # AEPsych 4-D config
    StimulusSelectable.cs           # Stimulus interaction handler
    ColorDelete.cs                  # Cleanup helper
```

---

## Color Space

Model-space coordinates `(w1, w2)` are transformed to linear RGB via:

```
RGB = M * [w1, w2, 1]ᵀ

M = [[0.292, -0.292, 0.5],
     [0.158, -0.158, 0.5],
     [-0.45,  0.45,  0.5]]
```

This matrix encodes the isoluminant plane of the display's color gamut.

---

## Related Repository

The Python back-end — AEPsych server, WPPM fitting, simulation scripts, and real-time visualizer — is at:

**[github.com/Znasif/aepsych](https://github.com/Znasif/aepsych)**

---

---

# QuestCameraKit — Original Samples

The rest of this repository is a collection of template and reference projects demonstrating how to use Meta Quest's **Passthrough Camera API (PCA)** for advanced AR/VR vision, tracking, and shader effects. The VisionTest experiment (above) was built on top of this foundation.

[![Follow on X](https://img.shields.io/twitter/follow/xrdevrob?style=social)](https://x.com/xrdevrob)
[![Join our Discord](https://img.shields.io/badge/Join-Discord-blue?style=social&logo=discord)](https://discord.com/invite/KkstGGwueN)

# Table of Contents
- [Overview](#overview)
- [Getting Started with PCA](#getting-started-with-pca)
- [Running the Samples](#running-the-samples)
- [General Troubleshooting & Known Issues](#general-troubleshooting--known-issues)
- [Acknowledgements & Credits](#acknowledgements--credits)
- [Community Contributions](#community-contributions)
- [News](#news)
- [License](#license)
- [Contact](#contact)

# Overview

## 1. 🎨 Color Picker

- **Purpose:** Convert a 3D point in space to its corresponding 2D image pixel.
- **Description:** This sample shows the mapping between 3D space and 2D image coordinates using the Passthrough Camera API. We use MRUK's EnvironmentRaycastManager to determine a 3D point in our environment and map it to the location on our WebcamTexture. We then extract the pixel on that point, to determine the color of a real world object.

## 2. 🍎 Object Detection with Unity Sentis

- **Purpose:** Convert 2D screen coordinates into their corresponding 3D points in space.
- **Description:** Use the Unity Sentis framework to infer different ML models to detect and track objects. Learn how to convert detected image coordinates (e.g. bounding boxes) back into 3D points for dynamic interaction within your scenes. In this sample you will also see how to filter labels. This means e.g. you can only detect humans and pets, to create a more safe play-area for your VR game. The sample video below is filtered to monitor, person and laptop. The sample is running at around `60 fps`.

| 1. 🎨 Color Picker                          | 2. 🍎 Object Detection                      |
|---------------------------------------------|---------------------------------------------|
| ![CPE](Media/ColorPicker_Environment.gif)   | ![OBJD](Media/ObjectDetection.gif)          |

## 3. 📱 QR Code Tracking with ZXing

- **Purpose:** Detect and track QR codes in real time. Open webviews or log-in to 3rd party services with ease.
- **Description:** Similarly to the object detection sample, get QR code coordinated and projects them into 3D space. Detect QR codes and call their URLs. You can select between a multiple or single QR code mode. The sample is running at around `70 fps` for multiple QR codes and a stable `72 fps` for a single code. Users are able to choose between CenterOnly and PerCorner raycasting modes via an enum in the inspector. This enables more accurate rotation tracking for use cases that require it (PerCorner), while preserving a faster fallback (CenterOnly).


## 4. 🪟 Shader Samples

- **Purpose:** Apply a custom shader effect to virtual surfaces.
- **Description:** A shader which takes our camera feed as input to manipulate the content behind it. Right now the project contains a Pixelate, Refract, Water, Zoom, Blur, GameBoy Green and VirtualBoy Red effect. Additionally examples for colorblindness red, green, blue and total have been added (Protanopia, Deuteranopia, Tritanopia, Achromatopsia). Frosted Glass shader is work in progress!

| 3. 📱 QR Code Tracking                | 4. 🪟 Shader Samples                  |
|---------------------------------------|---------------------------------------|
| ![QR Code](Media/QRCodeTracking.gif)  | ![Frosted](Media/ShaderSamples.gif)   |

## 5. 🧠 OpenAI vision model

- **Purpose:** Ask OpenAI's vision model (or any other multi-modal LLM) for context of your current scene.
- **Description:** We use a the OpenAI Speech to text API to create a command. We then send this command together with a screenshot to the Vision model. Lastly, we get the response back and use the Text to speech API to turn the response text into an audio file in Unity to speak the response. The user can select different speakers, models, and speed. For the command we can add additional instructions for the model, as well as select an image, image & text, or just a text mode. The whole loop takes anywhere from `2-6 seconds`, depending on the internet connection.

https://github.com/user-attachments/assets/a4cfbfc2-0306-40dc-a9a3-cdccffa7afea

## 6. 🎥 WebRTC video streaming

- **Purpose:** Stream the Passthrough Camera stream over WebRTC to another client using WebSockets.
- **Description:** This sample uses [SimpleWebRTC](https://assetstore.unity.com/packages/tools/network/simplewebrtc-309727), which is a Unity-based WebRTC wrapper that facilitates peer-to-peer audio, video, and data communication over WebRTC using [Unitys WebRTC package](https://docs.unity3d.com/Packages/com.unity.webrtc@3.0/manual/index.html). It leverages [NativeWebSocket](https://github.com/endel/NativeWebSocket) for signaling and supports both video and audio streaming. You will need to setup your own websocket signaling server beforehand, either online or in LAN. You can find more information about the necessary steps [here](https://www.youtube.com/watch?v=-CwJTgt_Z3M)

| 6. 🎥 WebRTC video streaming                   |
|------------------------------------------------|
| ![WebRTC](Media/PCA_WebRTC.gif)                |

# Getting Started with PCA

| **Information**        | **Details**                                                                                                                                                                                             |
|------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Device Requirements**| - Only for Meta `Quest 3` and `3s`<br>- `HorizonOS v74` or later                                                                                                                                        |
| **Unity WebcamTexture**| - Access through Unity's WebcamTexture<br>- Only one camera at a time (left or right), a Unity limitation                                                                                               |
| **Android Camera2 API**| - Unobstructed forward-facing RGB cameras<br>- Provides camera intrinsics (`camera ID`, `height`, `width`, `lens translation & rotation`)<br>- Android Manifest: `horizonos.permission.HEADSET_CAMERA`  |
| **Public Experimental**| - Apps using PCA are allowed to be submitted to the Meta Horizon Store since May 2025.                                                                                                                           |
| **Specifications**     | - Frame Rate: `30fps`<br>- Image latency: `40-60ms`<br>- Available resolutions per eye: `320x240`, `640x480`, `800x600`, `1280x960`                                                                     |

## Prerequisites

- **Meta Quest Device:** Ensure you are runnning on a `Quest 3` or `Quest 3s` and your device is updated to `HorizonOS v74` or later.
- **Unity:** Recommended is `Unity 6`. Also runs on Unity `2022.3. LTS`.
- **Camera Passthrough API does not work in the Editor or XR Simulator.**
- Get more information from the [Meta Quest Developer Documentation](https://developers.meta.com/horizon/documentation/unity/unity-pca-documentation)

> [!CAUTION]
> Every feature involving accessing the camera has significant impact on your application's performance. Be aware of this and ask yourself if the feature you are trying to implement can be done any other way besides using cameras.

## Installation
1. **Clone the Repository:**
   ```
   git clone https://github.com/Znasif/VisionTest.git
   cd VisionTest
   git checkout fullview
   ```

2. **Open the Project in Unity:**
Launch Unity and open the `Unity-QuestVisionKit` folder.

3. **Configure Dependencies:**
Follow the instructions in the section below to run one of the samples.

# Running the Samples

## 7. **[Color Discrimination Experiment (VisionTest)](https://github.com/Znasif/VisionTest/tree/fullview)**
- Ensure the [AEPsych server](https://github.com/Znasif/aepsych) is running and reachable (see server setup above).
- Open `Assets/Samples/7 Experiment/Experiment Scene.unity`.
- Set the server address on the `AEPsychClient` component.
- Build and deploy to Quest 3.

## 1. **[Color Picker](https://github.com/xrdevrob/QuestCameraKit?tab=readme-ov-file#-color-picker)**
- Open the `ColorPicker` scene.
- Build the scene and run the APK on your headset.
- Aim the ray onto a surface in your real space and press the A button or pinch your fingers to observe the cube changing it's color to the color in your real environment.

## 2. **[Object Detection with Unity Sentis](https://github.com/xrdevrob/QuestCameraKit?tab=readme-ov-file#-object-detection-with-unity-sentis)**
- Open the `ObjectDetection` scene.
- You will need [Unity Sentis](https://docs.unity3d.com/Packages/com.unity.sentis@2.1/manual/get-started.html) for this project to run (com.unity.sentis@2.1.2).
- Select the labels you would like to track. No label means all objects will be tracked.
- Build the scene and run the APK on your headset. Look around your room and see how tracked objects receive a bounding box in accurate 3D space.

## 3. **[QR Code Tracking](https://github.com/xrdevrob/QuestCameraKit?tab=readme-ov-file#-qr-code-tracking-with-zxing)**
- Open the `QRCodeTracking` scene to test real-time QR code detection and tracking.
- Install [NuGet for Unity](https://github.com/GlitchEnzo/NuGetForUnity)
- Click on the `NuGet` menu and then on `Manage NuGet Packages`. Search for the [ZXing.Net package](https://github.com/micjahn/ZXing.Net/) from Michael Jahn and install it.
- Make sure in your `Player Settings` under `Scripting Define Symbols` you see `ZXING_ENABLED`. The ZXingDefineSymbolChecker class should automatically detect if `ZXing.Net` is installed and add the symbol.
- In order to see the label of your QR code, you will also need to install TextMeshPro!
- Build the scene and run the APK on your headset. Look at a QR code to see the marker in 3D space and URL of the QR code.

## 4. **[Shader Samples](https://github.com/xrdevrob/QuestCameraKit?tab=readme-ov-file#shader-samples)**
- Open the `Shader Samples` scene.
- Build the scene and run the APK on your headset.
- Look at the spheres from different angles and observe how objects behind it are changing.
- You can grab the examples too and move them around.

> [!WARNING]
> The Meta Project Setup Tool (PST) will show a warning (opaque textures) and tell you to uncheck it, so do not fix this warning.

## 5. **[OpenAI vision model & voice commands](https://github.com/xrdevrob/QuestCameraKit?tab=readme-ov-file#-openai-vision-model)**
- Open the `ImageLLM` scene.
- Make sure to create an [API key](https://platform.openai.com/api-keys) and enter it in the `OpenAI Manager prefab`.
- Select your desired model and optionally give the LLM some instructions.
- Make sure your headset is connected to the internet (the faster the better).
- Build the scene and run the APK on your headset.

## 6. **[WebRTC video streaming](https://github.com/xrdevrob/QuestCameraKit?tab=readme-ov-file#-webrtc-video-streaming)**

- Open the `Package Manager`, click on the + sign in the upper left/right corner.
	- Select "Add package from git URL".
	- Enter URL: ```https://github.com/endel/NativeWebSocket.git#upm``` and click in Install.
	- After the installation finished, click on the + sign in the upper left/right corner again.
	- Enter URL ```https://github.com/FireDragonGameStudio/SimpleWebRTC.git?path=/Assets/SimpleWebRTC``` and click on Install
- Open the `WebRTC-Quest` scene.
- Link up your signaling server on the `Client-STUNConnection` component in the `Web Socket Server Address` field.
- Build and deploy the `WebRTC-Quest` scene to your Quest3 device.

# General Troubleshooting & Known Issues

- Some users have reported that the app crashes the second and every following time the app is opened. A solution described was to go to the Quest settings under `Privacy & Security` and toggle the camera permission and then start the app and accept the permission again.
- If switching between Unity 6 and other versions such as 2023 or 2022 it can happen that your Android Manifest is getting modified and the app won't run anymore. Should this happen to you make sure to go to `Meta > Tools > Update AndroidManifest.xml` or `Meta > Tools > Create store-compatible AndroidManifest.xml`. After that make sure you add back the `horizonos.permission.HEADSET_CAMERA` manually into your manifest file.

# Acknowledgements & Credits

- Thanks to **Meta** for the Passthrough Camera API and [**Passthrough Camera API Samples**](https://github.com/oculus-samples/Unity-PassthroughCameraApiSamples/).
- Thanks to shader wizard [Daniel Ilett](https://www.youtube.com/@danielilett) for helping in the shader samples.
- Thanks to **[Michael Jahn](https://github.com/micjahn/ZXing.Net/)** for the XZing.Net library used for the QR code tracking samples.
- Thanks to **[Julian Triveri](https://github.com/trev3d/QuestDisplayAccessDemo)** for constantly pushing the boundaries with what is possible with Meta Quest hardware and software.
- Original QuestCameraKit samples by [XR Dev Rob](https://x.com/xrdevrob).

# License

This project is licensed under the MIT License. See the LICENSE file for details.

# Contact

For questions about the VisionTest experiment, open an issue at [github.com/Znasif/VisionTest](https://github.com/Znasif/VisionTest) or [github.com/Znasif/aepsych](https://github.com/Znasif/aepsych).
