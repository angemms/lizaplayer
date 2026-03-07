## About the Player

- Open source
- Fully custom design with dark and light themes
- Accent color selection (aqua, red, grey, orange, purple, etc.)
- User-friendly interface
- "My Wave" (personalized radio)
- Track search
- Smooth animations and attention to detail
- Cross-platform: Works on Linux and Windows

## Screenshots (2560x1440)

![w1](https://github.com/user-attachments/assets/bf8f3b63-be6a-4c1c-8f98-368bcc25e128)
![e2](https://github.com/user-attachments/assets/605de2bb-2308-4533-9275-4faeff2d1859)
![r2](https://github.com/user-attachments/assets/5d078405-3d66-40cc-9e85-6a7f69943661)

### How to Run

- Download the latest release
- Unpack the archive
- Run the executable file

### How to Run (Alternative)

```bash

# Cloning

git clone https://github.com/lizapropanol/lizaplayer.git

cd lizaplayer


# Installing dependencies

flutter pub get


# Let's launch

flutter run -d linux --release

```

### How to get a Yandex Music token

- Open music.yandex.ru in your browser.
- Press F12 → go to the Application tab → Local Storage → https://music.yandex.ru.
- Find the access_token or oauth key and copy its value.
- Paste it into lizaplayer and click "Save and Login".

### Tech Stack

- intl: ^0.20.2
- yandex_music: ^1.2.2
- just_audio: ^0.9.46
- just_audio_media_kit: ^1.0.0
- cached_network_image: ^3.4.1
- window_manager: ^0.4.2
- flutter_riverpod: ^2.5.1
- shared_preferences: ^2.3.2
- path_provider: ^2.1.4
- build_runner: ^2.4.13
- riverpod_generator: ^2.4.3
- riverpod_lint: ^2.3.0

## Star History

<a href="https://www.star-history.com/?repos=lizapropanol%2Flizaplayer&type=date&legend=bottom-right">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/image?repos=lizapropanol/lizaplayer&type=date&theme=dark&legend=top-left" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/image?repos=lizapropanol/lizaplayer&type=date&legend=top-left" />
   <img alt="Star History Chart" src="https://api.star-history.com/image?repos=lizapropanol/lizaplayer&type=date&legend=top-left" />
 </picture>
</a>
