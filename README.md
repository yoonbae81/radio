# 라디오 녹음 및 팟캐스트 피드

자동 라디오 프로그램 녹음 및 팟캐스트 RSS 피드 생성 시스템

## ⚠️ 법적 고지 (중요)

본 프로그램은 **개인 학습 및 사적 이용**만을 목적으로 함
- 개인적 용도 또는 가정 내 사용을 위해 설계
- 저작권법상 사적 복제 범위를 초과하는 사용(예: 제3자 공유, 영리 목적 사용, 공중 제공 등)으로 발생하는 모든 법적 책임은 **사용자 본인**에게 있음
- 방송사의 공식 도구가 아님

## 🎯 주요 기능

- 📻 **자동 녹음**: 예약된 시간에 맞춰 라디오 스트림을 자동으로 녹음
- ⏰ **스마트 스케줄링**: 환경 변수 기반의 프로그램 설정으로 녹음 시간을 자동 계산
- 📡 **RSS 피드**: 프로그램별 전용 팟캐스트 RSS 피드 제공
- 🔒 **선택적 인증**: `SECRET` 환경 변수를 통한 간편한 인증 기능 제공
- 💾 **캐싱**: 최적의 성능을 위해 TTL 기반의 피드 캐싱 지원
- 🐳 **Docker**: Docker Compose를 이용한 간편한 배포 가능
- ⏱️ **Systemd 타이머**: 호스트 시스템 타이머를 이용한 정교한 스케줄링 지원

## 📋 빠른 시작

### 개발 모드 (Windows/macOS/Linux)

로컬 개발 및 테스트용 설정

**macOS/Linux:**
```bash
git clone https://github.com/yoonbae81/radio.git radio-recorder
cd radio-recorder
chmod +x scripts/setup-dev.sh
./scripts/setup-dev.sh
```

**Windows:**
```cmd
git clone https://github.com/yoonbae81/radio.git radio-recorder
cd radio-recorder
scripts\setup-dev.bat
```

수행 작업:
- ✅ Docker 설치 여부 확인
- ✅ `.env.example`에서 `.env` 생성
- ✅ Docker 이미지 빌드
- ✅ 피드 서비스 시작

이후 `.env` 파일을 편집하여 스트림 URL과 프로그램 설정 (접속 주소: `http://localhost:8013/radio/feed.rss`)

### 운영 모드 (Linux 서버)

자동 스케줄링을 포함한 운영 환경 배포

```bash
# 1. 저장소 복제
git clone https://github.com/yoonbae81/radio.git radio-recorder
cd radio-recorder

# 2. 프로그램 설정
cp .env.example .env
nano .env  # STREAM_URL, PROGRAM1, PROGRAM2 등 설정
           # 포맷: PROGRAM1=시작-종료|별칭|이름|스트림URL

# 3. 서비스 배포 및 타이머 설정 (USER 모드)
./scripts/deploy.sh
```

피드 접속: `http://localhost:8013/radio/feed.rss`

## ⚙️ 설정

### 💡 핵심 설정

- **프로그램 스케줄 (PROGRAM 1/2/3)**: 시작-종료 시간, 피드 별칭, 프로그램 이름을 정의하는 시스템 핵심 설정
- **로고 이미지 관리**: `/srv/radio/logo/` 폴더 내에 `별칭.png`, `별칭.jpg`, `별칭.jpeg` 파일 저장 시 팟캐스트 로고로 자동 반영 (우선순위: png > jpg > jpeg)

### 환경 변수

`.env.example` 파일을 복사하여 `.env` 파일 생성

```bash
# 인증 (선택 사항, 비워두면 비활성화)
SECRET=

# 피드 서비스 포트 (기본값: 8013)
PORT=8013

# 경로 접두어 (기본값: /radio)
ROUTE_PREFIX=/radio

# 캐시 TTL (초 단위, 기본값: 3600 = 1시간)
CACHE_TTL=3600

# 데이터 저장 경로 (호스트 OS 경로)
DATA_DIR=/srv/radio

# (자동 설정) 파일 생성 권한을 위한 유저/그룹 ID
USER_ID=1000
GROUP_ID=1000

# 프로그램 설정
# 포맷: PROGRAMn=시작-종료|별칭|이름|스트림URL
# 시작-종료: HH:MM-HH:MM 형식
# 별칭: URL에 사용될 식별자 (예: /radio/program1/feed.rss)
# 이름: RSS 피드에 표시될 실제 프로그램 이름
# 스트림URL: 특정 프로그램을 위한 전용 스트림 URL
PROGRAM1=07:40-08:00|program1|프로그램 이름 #1|https://example.com/stream1.m3u8
PROGRAM2=08:00-08:20|program2|프로그램 이름 #2|https://example.com/stream2.m3u8
PROGRAM3=20:00-20:20|program3|프로그램 이름 #3|https://example.com/stream3.m3u8

# 글로벌 스트림 URL (수동 녹음 및 테스트용)
STREAM_URL=https://example.com/stream.m3u8
```

**참고**: 하루에 여러 번 방송되는 프로그램은 각각 별도의 PROGRAM 항목으로 구성

### 자동 녹음 시간 계산 방식

`recorder` 서비스 실행 시 동작:
1. 환경 변수에서 `PROGRAM1`, `PROGRAM2` 등 로드
2. 현재 시간(예: `07:42`) 확인
3. 시작 시간 기준 2분 이내의 일치 프로그램 검색
4. 시작-종료 시간 기반 녹음 시간 자동 계산
5. 녹음 시작

**예시**:
- 현재 시간: `07:42`
- `PROGRAM1=07:40-08:00|program1|프로그램 이름 #1|...`
- ✅ 일치 (07:40 기준 2분 이내)
- 20분 동안 녹음 진행 (07:40부터 08:00까지)

## 🐳 Docker Compose

### 서비스 관리

```bash
# 피드 서비스 시작
docker compose up -d

# 로그 확인
docker compose logs -f feed

# 서비스 재시작
docker compose restart feed

# 재빌드 및 재시작
docker compose up -d --build
```

### 수동 녹음 (테스트용)

```bash
# 자동 시간 계산으로 녹음 (현재 시간에 맞는 프로그램 검색)
USER_ID=$(id -u) GROUP_ID=$(id -g) docker compose run --rm recorder

# 수동으로 녹음 시간 지정 (예: 30분)
USER_ID=$(id -u) GROUP_ID=$(id -g) docker compose run --rm recorder 30
```

## ⏰ Systemd 타이머 설정

매 분 실행되어 `.env` 설정에 따라 자동 녹음 수행

### 설치 방법

```bash
# 설치 및 배포 스크립트 실행 (사용자 계정)
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

수행 내용:
1. `loginctl enable-linger $USER` 실행 (로그아웃 후에도 서비스 유지)
2. `radio-record.service` 및 `radio-record.timer`를 `~/.config/systemd/user/`로 복사
3. 서비스 파일 내 경로를 실제 설치 경로에 맞게 동적 수정
4. 캐시 무효화용 `.last_recording` 파일 생성
5. systemd 사용자 데몬 리로드 및 타이머 활성화

### 작동 방식

- **타이머**: 매 분 실행 (`OnCalendar=*:0/1`)
- **서비스**: `docker compose run --rm recorder` 실행 (USER 모드)
- **check-recording.sh**: Docker 기동 전 녹음 필요 여부를 미리 확인하는 경량 스크립트
- **record.py**:
  - `.env` 파일 확인 및 현재 시간 체크
  - 프로그램 매칭 시 녹음 시작
  - 시작-종료 시간 기반 녹음 시간 자동 계산

### 모니터링 (USER 모드)

```bash
# 타이머 상태 확인
systemctl --user status radio-record.timer

# 예약된 타이머 목록 확인
systemctl --user list-timers

# 녹음 로그 확인
journalctl --user -u radio-record.service -f

# 오늘의 녹음 기록 확인
journalctl --user -u radio-record.service --since today
```

### 수동 즉시 실행

```bash
# 즉시 녹음 여부 확인 및 실행
systemctl --user start radio-record.service
```

`.env` 파일 편집만으로 프로그램 추가/제거 가능:

```bash
# 프로그램 추가
PROGRAM4=08:20-08:40|program4|프로그램 이름 #4|...

# 프로그램 제거 (삭제 또는 주석 처리)
# PROGRAM2=...
```

변경 사항은 다음 타이머 실행 시 자동 반영

### 타이머 비활성화

```bash
# 중지 및 비활성화
systemctl --user stop radio-record.timer
systemctl --user disable radio-record.timer

# 파일 삭제
rm ~/.config/systemd/user/radio-record.{service,timer}
systemctl --user daemon-reload
```

## 📡 RSS 피드 API

### 엔드포인트

| 엔드포인트 | 설명 | 인증 필요 |
|----------|-------------|---------------|
| `GET /` | 상태 확인(Health check) | ❌ |
| `GET /radio/feed.rss` | 전체 프로그램 피드 | ✅ (SECRET 설정 시) |
| `GET /radio/<alias>/feed.rss` | 특정 프로그램 전용 피드 | ✅ (SECRET 설정 시) |
| `GET /radio/<filename>` | 오디오 파일 스트리밍 | ❌ |

### 사용 예시

```bash
# 상태 확인
curl http://localhost:8013/

# 전체 피드 조회
curl 'http://localhost:8013/radio/feed.rss?secret=your-secret'

# 특정 프로그램 전용 피드
curl 'http://localhost:8013/radio/program1/feed.rss?secret=your-secret'
```

### 팟캐스트 앱 설정

팟캐스트 앱(Apple Podcasts, Pocket Casts 등)에 아래 URL 추가:
```
https://your-domain.com/radio/program1/feed.rss?secret=your-secret
```

### 피드 캐싱

- `CACHE_TTL` 초 동안 캐싱 수행 (기본 1시간)
- 새로운 녹음 완료 시 캐시 자동 무효화

## 📂 프로젝트 구조

```
radio-recorder/
├── docker-compose.yml          # Docker Compose 설정
├── Dockerfile                  # 멀티 스테이지 빌드 설정
├── .env.example                # 환경 변수 템플릿
├── src/
│   ├── record.py              # 녹음 핵심 로직
│   ├── feed.py                # RSS 피드 서비스 (Bottle)
│   └── touch.py               # 유틸리티 스크립트
├── scripts/
│   ├── deploy.sh              # 운영 환경 배포 스크립트
│   ├── setup-dev.sh           # 개발 환경 설정 스크립트
│   ├── check-recording.sh      # 경량 사전 확인 스크립트
│   └── systemd/
│       ├── radio-record.service # systemd 서비스 정의
│       └── radio-record.timer   # systemd 타이머 정의
├── recordings/                 # 녹음 파일 저장소 (볼륨 매핑)
└── logo/                       # 프로그램 로고 저장소
```

## 🧪 테스트 실행

```bash
# 모든 유닛 테스트 실행
python -m unittest discover tests -v
```

## 🔧 문제 해결

### 녹음 시작 실패 시

- 타이머 상태 확인: `systemctl --user status radio-record.timer`
- 서비스 로그 확인: `journalctl --user -u radio-record.service -n 50`
- 설정 파일 확인: `cat .env`
- 시스템 시간 확인: `date`

### 피드 갱신 무효화 확인

- 피드 서비스 로그 확인: `docker compose logs -f feed`
- 피드 서비스 재시작: `docker compose restart feed`
- `.last_recording` 파일 존재 및 수정 시간 확인

## 🛠️ 기술 스택

- **Python 3.14** - 코어 언어
- **FFmpeg** - 스트림 녹음 및 처리
- **Bottle** - 경량 웹 프레임워크
- **Podgen** - RSS 피드 생성 라이브러리
- **cachetools** - 메모리 기반 캐싱
- **Docker** - 컨테이너 가상화
- **Systemd** - 리눅스 서비스 및 스케줄링

## 🔒 보안

- **RSS 피드 보호**: `SECRET` 설정 시 비밀번호 형태의 토큰이 포함된 URL로만 프로그램 목록 및 피드 접근 가능
- **파일 경로 익명화**: 모든 녹음 파일명에 랜덤 해시를 부여하여 피드 정보 없이는 개별 파일 주소를 유추할 수 없도록 방어
- **개인 서비스 최적화**: 비밀번호 노출 없는 간단한 토큰 방식과 경로 익명화로 개인용 서비스에 필요한 보안 수준 확보
- **역방향 프록시 지원**: HAProxy/Nginx 등과 연동 시 HTTPS 프로토콜 자동 감지 및 외부 호스트 이름 유지 지원

## 📄 라이선스

MIT License - 상세 내용은 LICENSE 파일 참조
