<div align="center">
  <img src="[https://raw.githubusercontent.com/gangio-chat/.github/main/assets/gangio-logo.png](https://gangio.pro/assets/web/wordmark.svg?component-solid)" alt="Gangio Logo" width="120" />
  <h1>Gangio for iOS</h1>
  
  <p><b>The ultimate native iOS experience for Gangio, redefining community communication.</b></p>

  [![Swift Version](https://img.shields.io/badge/Swift-5.9-orange.svg?style=flat-square)](https://swift.org)
  [![iOS Version](https://img.shields.io/badge/iOS-16.0+-blue.svg?style=flat-square)](https://apple.com/ios)
  [![License](https://img.shields.io/badge/License-AGPL_v3-green.svg?style=flat-square)](LICENSE)
</div>

<br/>

Welcome to the official iOS repository for **Gangio**. Built with native Swift and modern SwiftUI architectures, this application delivers a fast, fluid, and robust messaging experience for communities of all sizes.

## 🚀 Features

- **Native Performance:** Fully written in Swift using SwiftUI for a buttery-smooth interface.
- **Real-Time Sync:** Instant messaging, server updates, and real-time user presence.
- **Deep Integration:** Seamlessly supports push notifications, dynamic text sizing, and native sharing.
- **Markdown & Code:** Full support for rich text, markdown rendering, and syntax-highlighted code blocks.
- **Themes & Aesthetics:** Premium dark mode and vibrant UI tokens crafted for modern aesthetics.

---

## 🛠 Getting Started

### Prerequisites

- A Mac running macOS Ventura or later.
- **Xcode 15.0** or newer.
- An active Apple Developer Account (optional, but required for on-device push notifications testing).

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/gangio-chat/gangio-ios.git
   cd gangio-ios
   ```

2. **Open in Xcode:**
   Open `Gangio.xcodeproj` (or `.xcworkspace` if using pods) in Xcode.
   ```bash
   open Gangio.xcodeproj
   ```

3. **Build & Run:**
   - Select your preferred iPhone simulator or connected device.
   - Hit `Cmd + R` or press the **Run** button to compile and launch the application.

---

## 🐛 Known Issues & Troubleshooting

- **Push Notifications:** Background notifications require a valid APNs `.p8` key configured on the Gangio backend.
- **Local Cache:** If you encounter unexpected UI overlapping or weird states during development, try performing a clean build (`Cmd + Shift + K`) and resetting the simulator.

## 🤝 Contributing

We welcome contributions from the community! Whether you're fixing a bug, improving performance, or adding a new feature:

1. Fork the repository.
2. Create your feature branch (`git checkout -b feature/AmazingFeature`).
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`).
4. Push to the branch (`git push origin feature/AmazingFeature`).
5. Open a Pull Request.

## 📄 License

This project and all content contained within this repository are licensed under the **GNU Affero General Public License v3.0**. See the [LICENSE](LICENSE) file for more details.
