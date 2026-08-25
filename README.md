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
- 지역별 일반 적 4종과 보스 1종, 총 15종의 전용 적
- 1440×832 지역 보스 전용 무대, 페이즈별 기믹·대표 패턴 보장·전용 HUD/오디오/카메라
- 원경·중경·충돌을 분리하고 실제 충돌면만 32px 모듈 스킨으로 그리는 23개 스토리 노드
- 상·중·하 탐험 밴드, 되감기·압축·파괴·병합 발판, 낙하 구간, 스파이크, 레이저, 크러셔, 점프 패드, 체크포인트와 잠금 게이트
- 지역 보스 보상으로 벽차기 → 공중 대시 → 지형 펄스를 순서대로 해금하고 이전 지역의 선택 경로를 재탐험
- 지역별 1회용 수리 스테이션과 현재 무기에 맞는 조합 아이템을 주는 선택형 이벤트 단말
- 진행 방향 리드, 수직 데드존과 0.92 줌을 사용하는 대형 방 추적 카메라
- Art v3 플레이어·적·환경·최종 보스 스프라이트와 런타임 애니메이션
- ROOM 1 방 클리어마다 무기 전용 3갈래 빌드 성장, 지역 종료 패치 선택, 패리와 무기별 카운터
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
Damage Lab 1-1 → 1-2 → 1-3 → Overflow Warden
  → 패치 선택
Temporal Hall 2-1 → 2-2 → 2-3 → Chrono Jailer
  → 패치 선택
Collision Archive 3-1 → 3-2 → 3-3 → Kernel Chimera
  → 패치 선택
Optimization Core
  → 엔딩
```

각 지역은 일반 전투·플랫폼 도전·함정·기록 수집·수리·선택 이벤트가 결합된 세 개의 연결 방과 지역 보스로 구성됩니다. 일반 방을 완료하면 다음 방과 무기별 비밀 경로가 열리고, 지역 보스를 쓰러뜨리면 공통 탐험 능력과 현재 오류를 봉쇄할 패치를 획득합니다. Damage Lab의 벽차기, Temporal Hall의 공중 대시, Collision Archive의 지형 펄스는 이전 지역에 돌아가 투영 다리와 선택 경로를 여는 데 사용됩니다. 필수 경로는 칼의 대시까지 사용하지 않는 기본 달리기·일반 점프만으로 통과하도록 실제 가속·점프 컷·32×32 충돌체 기반 자동 검사를 적용하며, 무기 능력과 공통 능력은 지름길과 선택 보상에만 사용됩니다.

지역 보스는 공용 직사각형 방을 재사용하지 않습니다. Warden의 압력 격납고, Jailer의 시계 감옥, Chimera의 극성 융합로는 각각 1440×832 이상이며 전용 페이즈 지형과 위험 장치를 사용합니다. 각 페이즈에서 서로 다른 대표 공격을 최소 2개 경험해야 다음 단계로 넘어가고, The Optimizer는 Analyze·Predict·Perfect별 3개 패턴과 붕괴·코어 노출·엔딩 전환을 실행합니다. 자세한 계약은 [스토리 보스전 개편 문서](docs/STORY_BOSS_ENCOUNTER_OVERHAUL.md)에 정리되어 있습니다.

| 탐험 방 | 월드 구조 | 지역 고유 장치 |
| --- | --- | --- |
| ROOM 1-1~1-3 · Damage Lab | 1920×1080, 상·중·하 경로와 정비 지름길 | 점프 패드, 실험 레이저, 위험 실험실 |
| ROOM 2-1~2-3 · Temporal Hall | 1920×1080, 상승로·시간 균열·진자탑 | 이동·파괴·되감기 발판, 진자 크러셔 |
| ROOM 3-1~3-3 · Collision Archive | 1920×1080, 압축고·균열실·병합로 | 압축 피스톤, 위상 균열, 주기적 병합 다리 |

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

에셋 누락과 런타임 연결은 별도 회귀 테스트로 검사합니다. 캠페인 배경, 적 15종의 전투·Art v3·투사체 아틀라스와 최종 보스 프레임은 타이틀 화면에서 비동기 사전 로딩합니다. 전체 자동화 스위트는 맵 계약, 일반 점프 도달성, 보스 패턴·페이즈·위험 장치와 3무기 캠페인 완주를 함께 검증합니다.

## PATCH//SURVIVE

캠페인과 분리된 8방향 무한 생존 모드입니다. 2,880×1,620 규모의 장애물 없는 Survival Nexus 오픈 필드를 카메라가 추적하며, 웨이브가 진행될수록 적 구성과 위협 예산이 상승합니다.

- 시작할 때 칼·주먹·총 중 하나를 선택하고 해당 무기로 런을 끝까지 진행
- 시작 적 7기와 플레이어 주변 540–720px 교전권 증원으로 넓은 맵에서도 전투 밀도 유지
- 칼 Rift Dash, 주먹 Quake Core, 총 Protocol Volley 전용 `K` 특수기
- 무기마다 3개, 총 9개의 전용 성장 분기와 3티어 강화
- 칼·주먹·총 전용 각 6개와 공통 6개로 구성된 중복 없는 24개 패치 아이템
- 공격·대시·패리·투사체·폭발 등 태그를 2개·4개 모아 활성화하는 2단계 시너지
- 구역 이벤트와 보스 처치 후 아이템 3택1 보상, 현재 태그 진행도와 시너지 발동 예고 표시
- 서바이벌 패치·무기 강화·아이템 3지선다는 `J`·`K`·`L`로 왼쪽·가운데·오른쪽 즉시 선택
- 캠페인의 벽차기·공중 대시·지형 펄스 획득 기록으로 공통 아이템 선택지를 확장하는 메타 해금
- 최근 실제 런 최대 90개를 영구 저장하고 무기별 완주율, 사망·피해 원인, 빌드·아이템 성과, 구역 참여를 결과 화면에서 집계하는 Phase 10.5 밸런스 감사
- Windows 저장 데이터를 읽어 무기별 20분 생존율과 출시 게이트를 판정하는 `tool/run_survival_playtest.ps1` 및 [15런 실플레이 절차](docs/SURVIVAL_PLAYTEST_PROTOCOL.md)
- 레벨업마다 패치 선택 및 최대 3티어 성장
- 패치 조합으로 Ghost Vent, Echo Cascade, Redline 퓨전 해금
- 콤보, Critical Flow, 완벽 회피와 데이터 조각 보상
- 데이터 조각 6개를 모아 Data Surge 활성화
- 미니보스 처치로 패치 제안 재탐색 충전
- 엘리트, Phase Hound, Rift Stalker, Arc Warden, Mine Layer, 마일스톤 보스와 무한 난이도 스케일링
- 신규 서바이벌 적 3종과 구역·최종 보스 4종의 8프레임 이동·예고·공격·피격/전환·사망 애니메이션
- 기본 Crawler의 즉시 접촉 피해를 제거하고 0.46초 수축 경고 링 뒤 회피 가능한 물기 공격으로 전환
- 정적 내부 장애물과 상시 위험 지대 없이 이동 가능한 4개 개방 구역과 외곽 회복 릴레이 4개
- Data Foundry 릴레이 수리, Temporal Breach 이동 호위, Collision Graveyard 균열 봉쇄, Reactor Yard 고위험 캐시 회수 이벤트
- 5분 간격의 Foundry Overseer·Temporal Regent·Collision Behemoth와 20분 Nexus Core 최종 보스
- 보스 컷인, 전장 봉쇄, 체력·페이즈 HUD와 페이즈별 3개의 고유 공격 패턴
- 0–5분 Boot, 5–12분 Escalation, 12–20분 Crisis, 20분 이후 Endless의 명시적 난이도 곡선
- 확정 타격 시 무기별 히트스톱·화면 충격·충돌 VFX·SFX 피드백
- 사망 원인, 누적 피해, 완성 빌드와 최근 5개 런의 무기 선택률을 기록하는 결과 텔레메트리
- 최고 점수, 생존 시간, 선택 편향과 이벤트 간격을 기록하는 결과 화면

기존 고정 Pulse 전투는 제거했습니다. 일반 공격 `J`와 특수 능력 `K`는 시작할 때 선택한 무기와 해당 런의 성장 빌드를 사용합니다.

## 조작법

### 키보드

| 행동 | 키 |
| --- | --- |
| 좌우 이동 | `A` / `D`, `←` / `→` |
| 점프 | `W`, `↑` |
| 공격 | `J` |
| 특수 능력 | `K` · 칼 대시 · 주먹 더블 점프 · 공통 공중 대시 해금 후 무기 행동을 소모한 상태에서 발동 |
| 패리 | `Shift` |
| 상호작용 | `L` |
| 일시정지 | `Esc`, `P` |

서바이벌 3지선다 화면에서는 `J`가 왼쪽, `K`가 가운데, `L`이 오른쪽 카드를 선택합니다. 선택 화면을 닫으면 세 키는 다시 공격·특수 능력·상호작용으로 동작합니다.

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
| `lib/game/rooms/` | 연결형 캠페인 9개 탐험 방, 비밀방, 지역·최종 보스 룸과 생존 아레나 |
| `lib/game/components/` | 플레이어, 적, 투사체, 지형, 구조물과 시각 효과 |
| `lib/game/rules/` | 이상 규칙과 결정적 규칙 엔진 |
| `lib/game/survival/` | 생존 성장, 패치 티어, 퓨전과 텔레메트리 |
| `assets/images/sprites/art_v3/` | 최신 플레이어·적·환경·보스 런타임 스프라이트 |
| `assets/tiles/maps/` | Tiled 룸 데이터 |
| `assets/localization/` | 한국어·영어·일본어 번역 리소스 |
| `test/` | 위젯, 규칙, 진행, 에셋 연결과 골든 회귀 테스트 |
| `tool/` | 에셋 처리, 전체 검사와 릴리스 보조 스크립트 |

## 주요 문서

- [스토리 맵 공통 제작 규칙](docs/STORY_MAP_COMMON_RULES.md)
- [스토리 보스전 개편 계약](docs/STORY_BOSS_ENCOUNTER_OVERHAUL.md)
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

- 캠페인 ROOM 1~3의 1920×1080 연결형 탐험 방과 Optimization Core 엔딩: 완료
- 스토리 23개 노드의 원경·중경·충돌 분리, 보이는 지형과 실제 충돌의 1:1 연결: 완료
- 벽차기·공중 대시·지형 펄스 진행 해금, 월드맵 능력·잠금 상태와 역주행 선택 경로: 완료
- 일반 전투·플랫폼·함정·수리·선택 이벤트·비밀방·지역 보스 방 구성: 완료
- Warden·Jailer·Chimera 고유 1440×832 보스 무대, 페이즈 지형·위험 장치·대표 패턴 보장: 완료
- 칼 기본 달리기·일반 점프 기준 스토리 필수 경로 물리 도달성 검사: 완료
- ROOM 1 무기별 3갈래·3티어 빌드와 지역별 선택 아이템 경로: 완료
- 시작 무기 선택과 런 단위 로드아웃 고정: 완료
- 15종 적과 중간보스 해제 흐름: 완료
- 3개 언어 UI와 접근성 설정: 완료
- Art v3 플레이어·적·환경·보스 런타임 연결: 완료
- Flutter Web·Windows 빌드와 GitHub Pages 자동 배포: 완료
- 전체 자동화 테스트, 3개 언어 핵심 UI 오버플로와 지역별 체크포인트 재시작 회귀: 통과
- Windows 릴리스와 GitHub Pages 하위 경로 웹 릴리스 빌드: 통과 기준 유지
- Windows ROOM 1 전투 30초 프레임 QA: 164.8 FPS, 중앙값/P95 6.07ms, 33.4ms 초과 프레임 0%로 통과
- 스토리 공통 원경을 포함한 웹 전체 84.97/90 MiB, 게임 에셋 41.76/42 MiB 예산 통과
