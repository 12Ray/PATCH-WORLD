# 스토리 보스전 개편 계약

## 적용 범위

이 개편은 스토리 모드의 Overflow Warden, Chrono Jailer, Kernel Chimera, The Optimizer에만 적용한다. `PATCH//SURVIVE`의 맵, 웨이브, 적, 보스, HUD와 난이도 곡선은 변경하지 않는다.

## 공통 전투 계약

- 지역 보스 방은 최소 `1440×832`, Optimization Core는 `1920×1080`으로 운용한다.
- 새 페이즈로 넘어가려면 현재 페이즈에서 서로 다른 대표 공격을 최소 2개 완료해야 한다. 체력만 빠르게 소모해 패턴과 연출을 건너뛸 수 없다.
- 보스 이름, 페이즈, 체력이 캠페인 전용 HUD에 표시된다. 무한 모드의 압축형 HUD는 그대로 유지한다.
- 인트로, 페이즈 전환, 승리에는 보스별 오디오 큐·카메라·조명·무대 모티프를 사용한다.
- 페이즈 레이저는 등장 후 1.1초 동안 비활성 경고 상태를 유지한다. 경고 중 레이저와 겹친 플레이어도 활성 전환 순간 한 번만 피해를 받는다.
- 칼의 대시, 주먹의 더블 점프, 공통 해금 능력 없이도 필수 바닥 경로와 보상·출구에 도달할 수 있어야 한다.

## 보스별 구조

| 보스 | 무대 | 핵심 기믹 | 패턴 계약 |
| --- | --- | --- | --- |
| Overflow Warden | 1440×832 압력 격납고 | 경고형 압력 벤트, 페이즈 발판, 안전 구역, Repair Leech 소환 게이트, 봉인 안에서 끝나는 실드 돌진 | Shield Slam, Overflow Grenade, Shield Charge를 시작으로 Checksum Fan과 Memory Quake가 추가된다. Leech 회복은 보스를 임계치 1 아래까지만 복구하며 플레이어의 마지막 타격을 대신할 수 없다. |
| Chrono Jailer | 1440×832 시계 감옥 | 승강 발판, 되감기 궤도, 시간 봉합 레이저, 3페이즈 안전 발판 | Rewind Charge, Clock Fan, Clock Sweep에서 Time Cage와 Hourglass Mine으로 확장된다. |
| Kernel Chimera | 1440×832 극성 융합로 | 극성 이동 레일, 분할 승강로, 병합 발판, 컨베이어, 벡터 봉합 레이저 | Merge Slam, Split Kernel, Gravity Shard에서 Polarity Cross와 Vector Cage로 확장된다. 보스는 양쪽 봉인을 벗어날 수 없다. |
| The Optimizer | 1920×1080 Optimization Core | 보이는 방화벽, 일반 점프 대칭 계단, 페이즈 이동·파괴 발판, 분석 레이저, 플레이어·보스 동시 추적 카메라 | Analyze·Predict·Perfect에 각각 3개 패턴을 순환한다. Perfect도 계속 공격하며, Overflow 붕괴→코어 노출→엔딩 전환을 순서대로 실행한다. |

## 일반 점프 검증

필수 경로 검사는 실제 `PlatformerMotion`의 달리기 속도·가속·감속, 점프 속도, 중력, 최대 낙하 속도, 점프 컷과 32×32 충돌체를 120Hz로 모사한다. 목적 발판 아랫면, 출발 발판 재착지, 중간 장애물도 양방향 충돌로 검사한다.

검증 대상은 다음과 같다.

- 완전 해금된 Boot Sector의 모든 스토리 문
- Damage Lab 모든 방의 양방향 스폰과 필수 문·보상·출구
- Temporal Hall과 Collision Archive 모든 방의 양방향 스폰, 목표 노드, QA 기록, 수리·로드아웃·보상·패치·허브·분기 지점
- Overflow Warden, Chrono Jailer, Kernel Chimera의 바닥 필수 경로
- Optimization Core의 Legacy 단말, 우측 전장, 칼 근접 공격 높이

이동·되감기·파괴·병합·페이즈 발판, 점프 패드와 대시·더블 점프·벽차기·공중 대시는 필수 경로 판정에서 제외한다.

## 회귀 검증

- `test/game/ordinary_jump_reachability_test.dart`
- `test/game/story_ordinary_jump_reachability_test.dart`
- `test/game/damage_lab_runtime_map_test.dart`
- `test/game/phase_four_boss_presentation_test.dart`
- `test/game/regional_campaign_node_navigation_test.dart`
- `test/game/connected_campaign_three_weapon_full_run_test.dart`
- `test/components/pulsing_laser_component_test.dart`
- `test/components/optimizer_arena_stage_component_test.dart`
- `test/components/conveyor_platform_component_test.dart`

릴리스 전에는 `tool/check.ps1` 전체 검사, Windows 릴리스 빌드, GitHub Pages 하위 경로 웹 릴리스 빌드와 공개 URL 확인을 모두 수행한다.
