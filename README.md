# PATCH//WORLD

![PATCH//WORLD key art](assets/images/ui/patch_world_key_art.png)

[![CI](https://github.com/12Ray/PATCH-WORLD/actions/workflows/ci.yml/badge.svg)](https://github.com/12Ray/PATCH-WORLD/actions/workflows/ci.yml)
[![Deploy GitHub Pages](https://github.com/12Ray/PATCH-WORLD/actions/workflows/pages.yml/badge.svg)](https://github.com/12Ray/PATCH-WORLD/actions/workflows/pages.yml)

> 하나를 고치면, 다른 하나가 망가진다.

PATCH//WORLD는 잘못된 게임 규칙으로 붕괴하는 세계를 복구하는 2D 픽셀 액션 로그라이트입니다. 마지막 QA 요원이 된 플레이어는 룸마다 다른 오류 규칙을 공략하고, 문제를 고치는 대신 다음 구간에 새로운 부작용을 누적합니다.

Flutter와 Flame으로 제작했으며 웹, Windows 데스크톱, 키보드와 터치 입력을 지원합니다.

## 지금 플레이

- 웹 게임: [12ray.github.io/PATCH-WORLD](https://12ray.github.io/PATCH-WORLD/)
- 소스 코드: [github.com/12Ray/PATCH-WORLD](https://github.com/12Ray/PATCH-WORLD)
- 배포 상태: [GitHub Pages 워크플로](https://github.com/12Ray/PATCH-WORLD/actions/workflows/pages.yml)

`main` 브랜치의 포맷 검사, 정적 분석, 자동화 테스트와 Flutter Web 릴리스 빌드가 통과하면 GitHub Pages에 자동 배포됩니다.

## 최신 버전 핵심 기능

- 시작 시 한국어, English, 日本語 중 언어 선택
- 캠페인 시작 시 칼, 주먹, 총 중 하나를 선택하고 해당 런 동안 고정
- 룸별 일반 적 4종과 중간보스 1종, 총 15종의 전용 적
- 3개의 2880×1080 캠페인 맵과 1920×1080 최종 보스 맵
- 발판, 낙하 구간, 스파이크, 레이저, 크러셔, 점프 패드, 체크포인트와 잠금 게이트
- Art v3 플레이어·적·환경·최종 보스 스프라이트와 런타임 애니메이션
- 룸 종료 패치 선택, 장점과 부작용 누적, 패리와 무기별 카운터
- 별도 무한 생존 모드 `PATCH//SURVIVE`
- 음량, 언어, 보조 모드, 화면 흔들림과 강한 플래시 감소 설정

## 시작 무기와 빌드 방향

캠페인 시작 무기는 런이 끝날 때까지 바꿀 수 없습니다. 무기의 체력과 고유 능력에 룸 패치가 더해져 매 런의 플레이 방식이 달라집니다.

| 무기 | 체력 | 고유 능력 | 강점 | 약점 |
| --- | ---: | --- | --- | --- |
| 칼 · Sword | 5 | 좌우 더블 탭 또는 `K` 대시, 쿨타임 5초 | 짧은 무적과 높은 기동성 | 대시가 Motion Tax 열을 높임 |
| 주먹 · Gauntlet | 7 | 공중에서 점프를 한 번 더 입력하는 더블 점프 | 높은 생존력과 안정적인 공중 복귀 | 이동 속도 5% 및 공격 속도 감소 |
| 총 · Gun | 3 | 능동형 이동 능력 없음 | 긴 사거리, 0.32초 공격 주기와 콤보 중 차지 레일 | 낮은 체력 |

모든 무기는 6단계 공격 콤보, 패리, 완벽 패리, 카운터와 고유 능력 전환 모션을 사용합니다. 완벽 패리 뒤 1.2초 안에 공격하면 무기별 카운터가 발동합니다.

## 캠페인

```text
Damage Lab
  → 패치 선택
Temporal Hall
  → 패치 선택
Collision Archive
  → 패치 선택
Optimization Core
  → 엔딩
```

각 일반 룸의 적 4종을 처치하면 중간보스가 해제됩니다. 다섯 적을 모두 처리한 뒤 현재 오류를 봉쇄할 패치를 선택하며, 선택한 패치의 이점과 부작용은 다음 룸부터 함께 적용됩니다.

| 구간 | 이상 규칙 | 일반 적 4종 | 중간보스 | 패치 선택지 |
| --- | --- | --- | --- | --- |
| ROOM 1 · Damage Lab | 공격이 적을 회복시키며 한계를 넘겨야 처치 가능 | Patch Mite, Checksum Hopper, Pulse Turret, Repair Leech | Overflow Warden | Motion Tax / Retaliation Echo |
| ROOM 2 · Temporal Hall | 입력이 없으면 시뮬레이션 시간이 멈춤 | Tick Runner, Echo Bat, Delay Sniper, Rewind Skater | Chrono Jailer | Hostile Turbo / Frame Burst |
| ROOM 3 · Collision Archive | 적 충돌이 새로운 위협으로 합쳐짐 | Vector Ram, Polarity Drone, Phase Mimic, Shard Lobber | Kernel Chimera | Phase Leak / Duplicate Fault |
| FINAL · Optimization Core | 선택한 무기와 누적 패치로 패턴 분석 보스를 공략 | — | The Optimizer | Analyze → Predict → Perfect → Overflow |

![Damage Lab enemy roster](docs/visual-concepts/platformer-room-1-enemy-roster-v1.png)

## Art v3 런타임 적용

최신 아트 패스는 콘셉트 이미지에 머무르지 않고 실제 게임 컴포넌트에 연결되어 있습니다.

| 대상 | 적용 내용 |
| --- | --- |
| 플레이어 | 칼·주먹·총 각각 대기, 달리기, 점프 상승, 정점, 낙하, 착지와 10종 전투 모션 |
| 적 15종 | 각 적의 이동 4프레임과 시그니처 공격 4프레임, 기존 고유 AI·히트박스와 연동 |
| 환경 | Damage, Temporal, Collision, Optimizer 테마별 표면·벽·상태 발판·상호작용 구조물 |
| 최종 보스 | Analyze, Predict, Perfect, Overflow 4개 페이즈 전용 애니메이션 |
| 무기 능력 | 칼 대시, 주먹 더블 점프 스핀, 총 차지 레일과 제작된 4단계 공격 모션 연결 |

에셋 누락과 런타임 연결은 별도 회귀 테스트로 검사합니다. 현재 저장소는 총 203개의 자동화 테스트를 포함합니다.

## PATCH//SURVIVE

캠페인과 분리된 8방향 무한 생존 모드입니다. 웨이브가 진행될수록 적 구성과 위협 예산이 상승합니다.

- 레벨업마다 패치 선택 및 최대 3티어 성장
- 패치 조합으로 Ghost Vent, Echo Cascade, Redline 퓨전 해금
- 콤보, Critical Flow, 완벽 회피와 데이터 조각 보상
- 데이터 조각 6개를 모아 Data Surge 활성화
- 미니보스 처치로 패치 제안 재탐색 충전
- 엘리트, Phase Hound, 마일스톤 보스와 무한 난이도 스케일링
- 최고 점수, 생존 시간, 선택 편향과 이벤트 간격을 기록하는 결과 화면

PATCH//SURVIVE는 현재 캠페인의 무기 로드아웃 대신 기존 Pulse 전투를 사용합니다.

## 조작법

### 키보드

| 행동 | 키 |
| --- | --- |
| 좌우 이동 | `A` / `D`, `←` / `→` |
| 점프 | `W`, `↑` |
| 공격 | `J` |
| 특수 능력 | 칼: `K` 또는 좌우 더블 탭 · 주먹: 공중에서 점프 재입력 |
| 패리 | `Shift` |
| 상호작용 | `L` |
| 일시정지 | `Esc`, `P` |

점프 키를 짧게 누르면 낮게, 길게 누르면 높게 뜹니다. 코요테 타임과 점프 버퍼가 적용되어 있으며, 캠페인 도중 숫자 키로 무기를 교체할 수는 없습니다.

PATCH//SURVIVE에서는 `WASD` 또는 방향키로 8방향 이동합니다. 공격, 패리, 상호작용과 일시정지 키는 동일합니다.

### 터치

작은 화면에서는 방향 패드, 공격, 패리, 상호작용과 일시정지 버튼이 표시됩니다. 칼을 선택한 경우 대시 버튼이 추가됩니다.

## 언어와 접근성

- 첫 실행 언어 선택: 한국어, English, 日本語
- 설정 화면에서 언제든 언어 변경 가능
- BGM·효과음 개별 음량 조절
- 보조 모드: 최대 체력 +1, 위험 요소 속도 15% 감소
- 화면 흔들림 강도 및 강한 플래시 감소 설정
- 선택 언어와 설정은 로컬 저장

## 로컬 실행

### 요구 환경

- Flutter stable 3.44.8
- Dart SDK 3.12.2 이상
- Chrome 또는 Windows 데스크톱 빌드 환경

### 의존성 설치

```powershell
cd "C:\Users\USER\Desktop\Flutter Projects\PATCHWORLD"
flutter pub get
```

### 웹 실행

```powershell
flutter run -d chrome
```

### Windows 실행

```powershell
flutter run -d windows
```

연결된 실행 대상을 확인하려면 `flutter devices`를 사용하세요.

## 검증과 빌드

전체 검사:

```powershell
powershell -ExecutionPolicy Bypass -File tool/check.ps1
```

개별 검사:

```powershell
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build windows --release
flutter build web --release
```

GitHub Pages 하위 경로와 동일하게 웹을 빌드하려면 다음 명령을 사용합니다.

```powershell
flutter build web --release --base-href "/PATCH-WORLD/"
```

Windows 실행 파일은 빌드 후 `build/windows/x64/runner/Release/patch_world.exe`에 생성됩니다.

## 배포

GitHub Pages 배포는 [.github/workflows/pages.yml](.github/workflows/pages.yml)이 담당합니다.

1. 변경 사항이 `main`에 병합됩니다.
2. GitHub Actions가 포맷, 분석, 테스트와 웹 릴리스 빌드를 실행합니다.
3. 성공한 `build/web` 아티팩트를 GitHub Pages에 배포합니다.
4. [공개 게임](https://12ray.github.io/PATCH-WORLD/)에서 결과를 확인합니다.

Firebase Hosting 워크플로는 수동 대체 배포 경로로 유지됩니다. 자세한 내용은 [배포 인수인계 문서](docs/DEPLOYMENT.md)를 참고하세요.

## 프로젝트 구조

| 경로 | 역할 |
| --- | --- |
| `lib/app/` | Flutter 셸과 타이틀·언어·무기·HUD·설정 오버레이 |
| `lib/game/patch_world_game.dart` | 게임 모드, 입력, 룸 전환과 UI 상태 조정 |
| `lib/game/patch_world.dart` | Flame 월드, 플레이어와 룸 생명주기 |
| `lib/game/rooms/` | 캠페인 3개 룸, 최종 보스 룸과 생존 아레나 |
| `lib/game/components/` | 플레이어, 적, 투사체, 지형, 구조물과 시각 효과 |
| `lib/game/rules/` | 이상 규칙과 결정적 규칙 엔진 |
| `lib/game/survival/` | 생존 성장, 패치 티어, 퓨전과 텔레메트리 |
| `assets/images/sprites/art_v3/` | 최신 플레이어·적·환경·보스 런타임 스프라이트 |
| `assets/tiles/maps/` | Tiled 룸 데이터 |
| `assets/localization/` | 한국어·영어·일본어 번역 리소스 |
| `test/` | 위젯, 규칙, 진행, 에셋 연결과 골든 회귀 테스트 |
| `tool/` | 에셋 처리, 전체 검사와 릴리스 보조 스크립트 |

## 주요 문서

- [비주얼 방향](docs/VISUAL_DIRECTION.md)
- [플랫포머 적 로스터](docs/PLATFORMER_ENEMY_ROSTER.md)
- [적 스프라이트 통합 계획](docs/ENEMY_SPRITE_INTEGRATION_PLAN.md)
- [전투·애니메이션 구현 계획](docs/ENEMY_COMBAT_ANIMATION_IMPLEMENTATION_PLAN.md)
- [Combat Motion v2](docs/visual-concepts/combat-motion-v2/README.md)
- [배포 안내](docs/DEPLOYMENT.md)
- [제출 자료](docs/submission/SUBMISSION.md)
- [Codex 협업 기록](docs/CODEX_COLLABORATION.md)
- [OpenAI Game 2026 계획표](https://app.notion.com/p/OpenAI-Game-2026-3b2299e21888809aabe7feb9c32fdfa8)

## 에셋과 권리

- 게임 아트와 콘셉트 이미지는 PATCH//WORLD용으로 지시해 OpenAI ImageGen으로 생성했습니다.
- 오디오 플레이스홀더는 프로젝트 스크립트로 절차 생성했으며 외부 샘플을 사용하지 않습니다.
- 생성·가공 이력은 [에셋 권리 원장](assets/licenses/ASSET_LEDGER.md)에 기록합니다.
- Flutter, Flame 등 외부 구성요소 표기는 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)를 참고하세요.

현재 저장소에는 별도의 오픈소스 `LICENSE`가 없습니다. 저장소가 공개되어 있더라도 코드와 에셋의 재사용 권한을 자동으로 허용하는 것은 아닙니다.

## 현재 개발 상태

- 캠페인 ROOM 1~3와 Optimization Core 엔딩: 완료
- 시작 무기 선택과 런 단위 로드아웃 고정: 완료
- 15종 적과 중간보스 해제 흐름: 완료
- 3개 언어 UI와 접근성 설정: 완료
- Art v3 플레이어·적·환경·보스 런타임 연결: 완료
- Flutter Web·Windows 빌드와 GitHub Pages 자동 배포: 완료
- 자동화 테스트 203개: 통과 기준 유지
