# PATCH//WORLD

![PATCH//WORLD key art](assets/images/ui/patch_world_key_art.png)

AI가 망가뜨린 게임 세계에서 마지막 인간 QA가 잘못된 규칙을 역이용해 세계를 복구하는 2D 액션 로그라이크입니다.

> 하나를 고치면, 다른 하나가 망가진다.

캠페인 ROOM 1~3은 **횡스크롤 플랫포머 로그라이크** 수직 슬라이스로 전환되었습니다. 플레이어와 지상 적이 같은 중력·발판·벽 충돌을 사용하며, 각 룸에 일반 적 4종과 중간보스 1종이 적용되어 있습니다.

## 현재 개발 상태

| 영역 | 상태 | 설명 |
|---|---|---|
| ROOM 1 — Damage Lab | 플랫포머 적용 | Patch Mite 등 4종과 Overflow Warden, 역전 회복·오버플로 전투 |
| ROOM 2 — Temporal Hall | 플랫포머 적용 | Tick Runner 등 4종과 Chrono Jailer, 입력을 멈추면 적과 투사체 정지 |
| ROOM 3 — Collision Archive | 플랫포머 적용 | Vector Ram 등 4종과 Kernel Chimera, 이동형·비행형·고정형 혼합 전투 |
| THE OPTIMIZER | 기존 버전 유지 | 캠페인 보스와 엔딩 흐름 동작 |
| PATCH//SURVIVE | 기존 버전 유지 | 무한 생존, 패치 성장, Fusion 시스템 동작. 캠페인 전환 완료 후 재설계 예정 |

세 룸 모두 적 5종을 처리하면 패치 선택 화면을 거쳐 다음 룸으로 이동합니다. `PATCH//SURVIVE`는 캠페인 전환이 안정화될 때까지 기존 8방향 이동을 유지합니다.

## 게임 방향

- 지형을 따라 달리고 점프하는 정통 2D 플랫포머 조작
- 룸마다 일반 적 4종과 중간보스 1종으로 구성된 전투 구조
- 플레이할 때마다 패치의 이점과 부작용을 조합하는 로그라이크 진행
- `DAMAGE_SIGN_INVERTED`, 시간 정지, 충돌 통합처럼 게임 규칙 자체를 전투 도구로 사용하는 시스템
- 단순한 직사각형 대신 역할과 공격 패턴이 실루엣에서 읽히는 픽셀 캐릭터와 애니메이션

![PATCH//WORLD gameplay concept](docs/visual-concepts/patchworld-gameplay-concept-v1.png)

### 적용된 적 로스터

| 룸 | 일반 적 4종 | 중간보스 |
|---|---|---|
| Damage Lab | Patch Mite, Checksum Hopper, Pulse Turret, Repair Leech | Overflow Warden |
| Temporal Hall | Tick Runner, Echo Bat, Delay Sniper, Rewind Skater | Chrono Jailer |
| Collision Archive | Vector Ram, Polarity Drone, Phase Mimic, Shard Lobber | Kernel Chimera |

![Damage Lab enemy roster](docs/visual-concepts/platformer-room-1-enemy-roster-v1.png)

전체 역할과 애니메이션 프레임 명세는 [플랫포머 적 로스터 문서](docs/PLATFORMER_ENEMY_ROSTER.md)에서 확인할 수 있습니다.

## 조작

### 캠페인 ROOM 1~3

| 행동 | 키보드 | 터치 |
|---|---|---|
| 좌우 이동 | `A` / `D`, `←` / `→` | 좌우 방향 버튼 |
| 점프 | `W`, `↑` | 위 방향 버튼 |
| 패치 펄스 | `Space`, `J` | `PULSE` 버튼 |
| 상호작용 | `E`, `Enter` | `E` 버튼 |
| 일시정지 | `Esc`, `P` | 일시정지 버튼 |

점프는 버튼을 짧게 누르면 낮아지고 길게 누르면 높아집니다. 최고 점프 높이는 필수 90px 단차를 여유 있게 통과하도록 조정했습니다. 발판에서 벗어난 직후에도 약 0.10초 동안 점프할 수 있으며, 착지 직전 입력한 점프도 약 0.12초 동안 보존됩니다.

### 생존 모드

생존 모드에서는 `WASD` 또는 방향키로 기존 8방향 이동을 사용합니다. 공격과 상호작용 키는 동일합니다.

## 로컬 실행

필요 환경:

- Flutter stable
- Dart 3.12 이상
- Flame 1.38.0

```powershell
cd "C:\Users\USER\Desktop\Flutter Projects\PATCHWORLD"
flutter pub get
flutter run -d chrome
```

Windows 데스크톱으로 실행하려면 다음 명령을 사용합니다.

```powershell
flutter run -d windows
```

## 검증과 빌드

전체 분석, 테스트와 웹 빌드 검증:

```powershell
powershell -ExecutionPolicy Bypass -File tool/check.ps1
```

개별 명령:

```powershell
flutter analyze
flutter test
flutter build web
```

GitHub Pages용 하위 경로 빌드:

```powershell
flutter build web --release --base-href "/PATCH-WORLD/"
```

현재 기준으로 정적 분석, 전체 테스트, release 웹 빌드와 실제 브라우저 ROOM 1 점프 검증을 통과했습니다.

## 주요 코드 위치

- 플랫포머 물리: [`lib/game/components/player/platformer_motion.dart`](lib/game/components/player/platformer_motion.dart)
- 플레이어 제어와 충돌: [`lib/game/components/player/player_component.dart`](lib/game/components/player/player_component.dart)
- Damage Lab 구성: [`lib/game/rooms/room_one_controller.dart`](lib/game/rooms/room_one_controller.dart)
- 플랫폼과 피트: [`lib/game/components/environment/platform_surface_component.dart`](lib/game/components/environment/platform_surface_component.dart)
- 입력 처리: [`lib/game/core/input_controller.dart`](lib/game/core/input_controller.dart)
- 플랫포머 물리 테스트: [`test/components/platformer_motion_test.dart`](test/components/platformer_motion_test.dart)
- Damage Lab 통합 테스트: [`test/game/damage_lab_platformer_test.dart`](test/game/damage_lab_platformer_test.dart)

## 다음 구현 순서

1. 현재 프로그램형 픽셀 프록시를 최종 64×64·96×96 스프라이트 스트립으로 교체
2. 적별 anticipation/action/hurt/defeat 애니메이션 연결
3. Polarity, Rewind, Phase 등 룸별 고유 상호작용 심화
4. 카메라 스크롤과 더 긴 절차형 룸 구간 제작
5. PATCH//SURVIVE를 side-view 체계로 재설계

## 배포와 저장소

- GitHub: [12Ray/PATCH-WORLD](https://github.com/12Ray/PATCH-WORLD)
- GitHub Pages 워크플로: [`.github/workflows/pages.yml`](.github/workflows/pages.yml)
- Firebase Hosting 대체 경로: [`.github/workflows/firebase-hosting.yml`](.github/workflows/firebase-hosting.yml), [`firebase.json`](firebase.json)

GitHub CLI를 사용할 경우 먼저 인증합니다.

```powershell
gh auth login
gh run list --repo 12Ray/PATCH-WORLD --limit 10
```

## 문서와 라이선스

- [비주얼 방향](docs/VISUAL_DIRECTION.md)
- [플랫포머 적 로스터 및 애니메이션 명세](docs/PLATFORMER_ENEMY_ROSTER.md)
- [출품 소개와 영상 구성](docs/submission/SUBMISSION.md)
- [Codex 작업 기록](docs/CODEX_COLLABORATION.md)
- [서드파티 고지](THIRD_PARTY_NOTICES.md)
- [에셋 권리 원장](assets/licenses/ASSET_LEDGER.md)
- [PATCH//WORLD Project HQ](https://app.notion.com/p/3b2299e2188881ec8e45d6d7fa5ee356)
- [Damage Lab 플랫포머 구현 계획](https://app.notion.com/p/3b7299e2188881198f41c84cf2b2093c)
