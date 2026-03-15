# macOS minimal recorder

맥미니처럼 항상 켜 두는 환경이라면, 이 프로젝트를 Python 앱으로 전부 운영하지 않아도 됩니다. 이 폴더의 구성은 `launchd + ffmpeg`로 정해진 시간에 녹음하고, 원하면 정적 `feed.xml`까지 만들어 팟캐스트 앱에 연결할 수 있도록 만든 macOS 전용 최소 구성입니다.

## 구성

- `check-and-record.sh`: 매 분 실행되며 현재 시각과 `PROGRAMn` 설정을 비교한 뒤 녹음을 시작합니다.
- `generate-feed.sh`: 각 프로그램 폴더 안에 `feed.xml`을 생성합니다.
- `install-launch-agent.sh`: 사용자 `launchd` 에이전트를 설치합니다.
- `start-static-server.sh`: `OUTPUT_DIR`를 로컬 HTTP로 서빙합니다.
- `install-podcast-server.sh`: 팟캐스트용 로컬 HTTP 서버를 `launchd`로 설치합니다.
- `configure-tailscale-serve.sh`: 로컬 HTTP 서버를 Tailscale `Serve` 뒤에 연결합니다.
- `com.radio.recorder.plist`: `launchd` 템플릿입니다.
- `com.radio.podcast-http.plist`: 팟캐스트 HTTP 서버용 `launchd` 템플릿입니다.
- `radio.conf.example`: 설정 예시입니다.

## 언제 이 구성이 맞는지

- 목적이 "정해진 시간에 라디오를 녹음해서 폴더에 쌓기"에 가깝다
- 맥미니에서 단순하게 돌리고 싶다
- 웹앱이나 인증, 캐시, 동적 피드 서버까지는 지금 필요 없다

## 1. 녹음만 쓰는 경우

1. `ffmpeg` 설치

```bash
brew install ffmpeg
```

2. 설정 파일 복사

```bash
cp scripts/macos/radio.conf.example scripts/macos/radio.conf
```

3. `scripts/macos/radio.conf` 수정

- `OUTPUT_DIR`를 원하는 저장 폴더로 바꿉니다.
- `FFMPEG_BIN` 경로를 확인합니다.
- `PROGRAM1`, `PROGRAM2`를 실제 방송 시간과 스트림 주소로 바꿉니다.
- 녹음만 쓸 때는 `FEED_ENABLED="0"` 그대로 두면 됩니다.

4. 수동 테스트

```bash
scripts/macos/check-and-record.sh PROGRAM1
```

이 명령은 `PROGRAM1`을 지금 즉시 한 번 녹음해 봅니다.

5. `launchd` 설치

```bash
scripts/macos/install-launch-agent.sh
```

설치 후에는 60초마다 한 번씩 체크하고, 방송 시작 시각부터 기본 5분 이내에 들어오면 녹음을 시작합니다.

## 2. 팟캐스트 RSS까지 같이 쓰는 경우

1. `scripts/macos/radio.conf`에서 아래 항목을 추가로 설정합니다.

- `FEED_ENABLED="1"`
- 필요하면 `PODCAST_IMAGE_URL`

2. 팟캐스트용 로컬 HTTP 서버 설치

```bash
scripts/macos/install-podcast-server.sh
```

3. Tailscale을 맥미니와 아이폰에 설치하고, 같은 tailnet에 로그인합니다.

Tailscale 공식 문서 기준으로 `Serve`는 tailnet 내부 기기들에 로컬 서비스를 HTTPS로 노출합니다. 또 macOS에서는 디렉터리를 직접 서빙하는 방식이 설치 종류에 따라 제한될 수 있어, 여기서는 `OUTPUT_DIR`를 로컬 HTTP로 띄우고 `tailscale serve`가 그것을 프록시하는 방식으로 구성했습니다.

4. Tailscale Serve 연결

```bash
scripts/macos/configure-tailscale-serve.sh
```

5. 피드 생성 테스트

```bash
RADIO_CONFIG=scripts/macos/radio.conf scripts/macos/generate-feed.sh
```

6. 팟캐스트 앱에는 프로그램별 피드를 넣으면 됩니다.

예시:

```text
https://your-device.your-tailnet.ts.net/morning-news/feed.xml
```

## 저장 구조

기본적으로 프로그램별로 하위 폴더가 생성됩니다.

```text
OUTPUT_DIR/
  morning-news/
    20260315-0740-1742014102.m4a
    20260316-0740-1742100501.m4a
    feed.xml
  weekend-show/
    20260315-2000-1742053200.m4a
    feed.xml
```

## 운영 팁

- `launchd` 사용자 에이전트는 로그인 이후 실행됩니다. 로그인 전부터 돌려야 하면 같은 스크립트를 LaunchDaemon 쪽으로 옮겨 쓰는 편이 맞습니다.
- 시작 시각이 정확히 맞지 않는 경우를 대비해 기본 허용 범위는 5분입니다.
- 방송 스트림이 AAC가 아니면 `AUDIO_CODEC="aac"`가 안전하고, 이미 AAC라면 `AUDIO_CODEC="copy"`가 더 가볍습니다.
- `PUBLIC_BASE_URL`를 비워두면 `generate-feed.sh`는 Tailscale의 MagicDNS 이름을 이용해 기본 URL을 추론하려고 시도합니다.
- 아이폰에서 밖에서도 들으려면 Tailscale 앱이 연결된 상태여야 합니다.

## 로그와 해제

로그:

- `logs/macos-recorder.out.log`
- `logs/macos-recorder.err.log`
- `logs/macos-podcast-http.out.log`
- `logs/macos-podcast-http.err.log`

해제:

```bash
launchctl bootout "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.radio.recorder.plist"
launchctl bootout "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.radio.podcast-http.plist"
rm -f "$HOME/Library/LaunchAgents/com.radio.recorder.plist"
rm -f "$HOME/Library/LaunchAgents/com.radio.podcast-http.plist"
```
