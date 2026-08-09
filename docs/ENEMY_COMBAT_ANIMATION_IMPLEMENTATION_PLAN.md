# 적 15종 고유 전투·애니메이션 코드 수정 계획

상태: 구현 전  
작성일: 2026-08-09  
관련 명세: `PLATFORMER_ENEMY_ROSTER.md`, `ENEMY_SPRITE_INTEGRATION_PLAN.md`

## 1. 문제 정의

현재 `PlatformerEnemyComponent` 하나가 15종의 이동, 공격, 체력, 렌더링을
모두 담당한다. 실제 차이는 이동 프로필 5개, 공통 직선탄, Repair Leech의
회복 정도이며, 나머지 고유 공격은 콘셉트 문서에만 존재한다. 애니메이션
상태 머신도 없어서 공격 예고 프레임과 실제 피해 프레임을 맞출 수 없다.

수정 목표는 다음과 같다.

- 15종 모두 최소 한 개의 다른 적과 공유하지 않는 핵심 상호작용을 가진다.
- 모든 피해는 `예고 -> 활성 프레임 -> 회복` 순서를 거친다.
- 애니메이션 이벤트와 hitbox, 투사체, 힘 적용 시점을 같은 타임라인으로
  구동한다.
- ROOM 1~3의 5종 처치 진행과 패치 선택 흐름은 유지한다.
- 최종 스프라이트가 준비되지 않아도 색상 프록시로 전체 행동을 테스트한다.

## 2. 구현 원칙

1. **Gameplay first**: 스프라이트가 없어도 고유 공격 판정과 예고는 완성한다.
2. **One source of timing**: 코드 타이머와 애니메이션 FPS를 따로 두지 않고
   `EnemyActionTimeline`이 wind-up, active, recovery를 모두 결정한다.
3. **Composition over switches**: 15종 분기문 대신 적별 `Brain`을 주입한다.
4. **Deterministic tests**: 랜덤 선택은 주입 가능한 RNG를 사용하고, 테스트는
   고정 시드와 가짜 플레이어 위치를 사용한다.
5. **Collision isolation**: 시각 크기, 몸통 hitbox, 공격 hitbox를 분리한다.
6. **Readable unfairness budget**: 화면 밖 공격 금지, 최소 예고 시간 보장,
   동시에 활성화되는 고위험 공격 수 제한을 둔다.

## 3. 목표 아키텍처

### 3.1 `PlatformerEnemyComponent`의 책임 축소

남길 책임:

- 체력과 overflow 처리
- 몸통 충돌과 월드 위치
- `Brain` 및 상태 머신 생명주기
- 룸의 `onDefeated` 콜백
- visual과 gameplay state 동기화

제거할 책임:

- archetype별 이동/공격 switch
- 공통 `_fireAtPlayer()`
- archetype별 도형 렌더링
- 공격별 개별 타이머

### 3.2 새 공통 타입

`lib/game/components/enemies/platformer/` 아래에 추가한다.

| 파일 | 책임 |
| --- | --- |
| `enemy_state.dart` | spawn, idle, move, telegraph, attack, recovery, hurt, stagger, overflow, defeated 상태 |
| `enemy_action_timeline.dart` | wind-up/active/recovery 시간, 취소 가능 여부, animation key, active event 실행 |
| `platformer_enemy_definition.dart` | 크기, 체력, 속도, 감지 거리, 공격 목록, animation key 등 데이터 |
| `platformer_enemy_brain.dart` | 적별 의사결정 인터페이스와 공통 context |
| `platformer_enemy_context.dart` | 플레이어 snapshot, 지형 query, clock, 대상 검색, spawn API |
| `platformer_enemy_visual.dart` | manifest 로딩, 상태별 애니메이션, 좌우 mirror, proxy fallback |
| `enemy_damage_volume.dart` | 짧은 수명의 근접/충격파 공격 hitbox와 source ID |
| `enemy_projectile.dart` | source ID, 피해량, 수명, 충돌 정책을 가진 투사체 기반 클래스 |
| `enemy_telegraph_component.dart` | 조준선, 착지 원, 돌진 경로, 반사 경로 등의 공통 예고 |

### 3.3 Brain 계약

각 Brain은 다음 명령만 생성한다.

- `setHorizontalIntent(value)`
- `requestJump(velocity)`
- `beginAction(EnemyActionTimeline)`
- `spawnProjectile(spec)`
- `spawnDamageVolume(spec)`
- `applyForce(target, vector)`
- `changeCollisionMode(mode)`
- `requestAnimation(key)`

Brain이 직접 Canvas를 그리거나 플레이어 체력을 변경하지 못하게 한다.
이 제약으로 로직 테스트와 시각 교체를 독립시킨다.

### 3.4 시간 계약

- ROOM 1·3: `game.clock.enemyDt`로 AI, 이동, 공격, 애니메이션 진행.
- ROOM 2: 입력이 멈추면 AI, 투사체, 공격 timeline, 해당 애니메이션을 모두
  같은 프레임에서 정지.
- hurt flash 같은 UI 피드백만 `realDt`를 사용할 수 있다.
- Tick Runner의 beat와 Echo Bat의 기록은 플레이어 입력 이벤트를 받되,
  실제 공격 진행은 `enemyDt`를 사용한다.

## 4. 공통 전투 시스템 수정

### 4.1 피해 식별자 수정

현재 모든 신규 직선탄이 `enemy.sentinel.projectile`을 사용한다. 이를
`enemy.<archetype>.<attack-id>`로 변경한다.

예:

- `enemy.pulseTurret.pulseBolt`
- `enemy.delaySniper.delayedShot`
- `enemy.shardLobber.ricochetShard`

`EnemyProjectileComponent` 생성자에 `sourceId`, `damage`, `collisionPolicy`,
`clockPolicy`를 필수로 받게 한다.

### 4.2 공격 판정 규칙

- contact damage는 모든 적의 기본 능력이 아니다.
- 몸통 자체가 공격인 Ram, Hopper 착지, boss charge 등에만 제한한다.
- 공격별 hitbox는 active 구간에만 존재한다.
- 한 번의 active 구간에서 플레이어 한 명당 한 번만 피해를 준다.
- 피해 후 플레이어 무적 시간과 중복 충돌 콜백을 존중한다.
- 화면 밖 또는 solid 내부에 생성되는 투사체는 즉시 취소한다.

### 4.3 행동 우선순위

`defeated > overflow > stagger > hurt > attack > telegraph > move > idle`
순서로 상태를 잠근다. 보스 phase change는 hurt보다 높고 overflow보다 낮다.

## 5. ROOM 1 — Damage Lab

### 5.1 Patch Mite

- Brain: `PatchMiteBrain`
- 고유성: ledge patrol 후 짧은 물기 돌진; 공격 실패 시 등이 노출된다.
- 상태: idle -> scuttle -> biteWindup -> biteDash -> biteRecovery.
- 판정: 입 앞의 작은 직사각형 hitbox를 biteDash 구간에만 활성화.
- 예고: 몸을 뒤로 6px 당기고 입 코어를 magenta로 0.30초 점멸.
- 취약점: recovery 0.55초 동안 뒤쪽 pulse에 overflow 보너스 1.
- 테스트: 절벽에서 떨어지지 않음, 0.30초 전 피해 없음, dash당 피해 1회.

### 5.2 Checksum Hopper

- Brain: `ChecksumHopperBrain`
- 고유성: 플레이어가 서 있는 발판 중심을 목표로 포물선 도약.
- 상태: idle -> compress -> airborneRise -> airborneFall -> landingAttack -> stall.
- 판정: 도약 중 몸통은 밀어내기만 하고, 착지 원형 충격파가 피해 담당.
- 예고: 목표 지점에 0.45초 착지 원과 예상 호를 표시.
- 반격: 플레이어가 호 아래로 통과하면 착지 stall 0.65초.
- 테스트: 목표 지점 clamp, 천장 충돌, 착지 전 충격파 없음, pit 복귀.

### 5.3 Pulse Turret

- Brain: `PulseTurretBrain`
- 고유성: scan -> line lock -> slow bolt -> vent의 명확한 lane control.
- 상태: scan -> charge -> fire -> vent.
- 판정: 0.60초 조준선 이후 느린 `PulseBoltComponent` 1발.
- 예고: 조준선은 charge 시작 위치에 고정해 마지막 순간 추적을 금지.
- 반격: vent 0.75초 동안 받는 pulse healing +1.
- 테스트: 고정된 조준선, fire 이전 projectile 0개, vent 중 보너스 적용.

### 5.4 Repair Leech

- Brain: `RepairLeechBrain`
- 고유성: 가장 손상된 적을 선택해 물리적인 hose로 연결하고 회복한다.
- 상태: seek -> latchWindup -> channel -> detach -> flee.
- 판정: target이 죽거나 거리 230px 초과, solid 차폐 시 연결 해제.
- channel: 0.65초마다 1 heal; overflow 발생 시 Leech가 stagger되고 주변에
  작은 chain burst를 만든다.
- 예고: target과 Leech 사이에 끊어질 수 있는 hose hitbox 표시.
- 테스트: 대상 우선순위, 자기 자신 제외, 차폐/거리 해제, 과회복 연쇄.

### 5.5 Overflow Warden

- Brain: `OverflowWardenBrain`
- 고유성: frontal guard, floor slam, Leech 소환, tank vent의 조합 보스.
- 패턴: guardWalk -> slam 또는 summon -> vent -> 반복.
- guard: 정면 pulse 효과 0, 후면 pulse 정상 적용; 방향은 wind-up 중 고정.
- slam: 0.75초 팔 예고 후 바닥을 따라 진행하는 conduit wave 두 방향 생성.
- summon: HP 66%, 33%에서 각 1회, 룸에 Leech가 없을 때만 실행.
- vent: tank가 임계치에 도달하면 1.2초 stagger, 이때 healing multiplier 2.
- 테스트: 방패 방향, wave 지형 추종, 소환 상한, phase당 1회, 사망 콜백 1회.

ROOM 1 완료 게이트:

- 다섯 적의 공격 실루엣과 대응법이 이름표 없이 구분된다.
- 같은 투사체 클래스와 같은 contact damage로 대체된 적이 없다.
- 5종 처치 후 기존 patch selection이 정확히 한 번 열린다.

## 6. ROOM 2 — Temporal Hall

### 6.1 Tick Runner

- Brain: `TickRunnerBrain`
- 플레이어의 movement start 이벤트를 beat로 기록한다.
- 3 beat 후 `beatCharge -> threeStepLunge -> recovery` 실행.
- 입력이 멈추면 이동, lunge, animation frame 모두 즉시 정지한다.
- 테스트: 정지 중 beat 증가 없음, 정확히 3 beat, lunge 1회 피해.

### 6.2 Echo Bat

- Brain: `EchoBatBrain`
- `PlayerMotionHistory`에서 최근 완결된 jump arc를 최대 0.9초 저장한다.
- record tell 후 해당 상대 좌표 경로를 `EchoTrailDamageComponent`가 재생한다.
- 기록이 없으면 저고도 sweep fallback을 사용한다.
- 테스트: 같은 입력은 같은 arc, 시간 정지 중 샘플/재생 정지, 기록 길이 상한.

### 6.3 Delay Sniper

- Brain: `DelaySniperBrain`
- 0.9초 aim lock 후 `DelayedShotComponent` 발사.
- 탄환은 플레이어 입력 정지와 함께 멈추며, 재개 시 기존 속도로 이어진다.
- 조준선은 발사 0.25초 전에 색을 바꿔 deadline을 전달한다.
- 테스트: aim lock 이후 방향 불변, 정지 중 위치 불변, 재개 후 연속성.

### 6.4 Rewind Skater

- Brain: `RewindSkaterBrain`
- dash 중 최대 1.2초의 위치를 ring buffer에 저장한다.
- rewindTell 후 기록을 역순으로 따라가며 별도의 trail hitbox를 남긴다.
- rewind 중 solid 보정은 기록 좌표를 우선하되 맵 밖 좌표는 폐기한다.
- 테스트: 정확한 역경로, buffer 상한, tell 중 무피해, rewind 종료 위치.

### 6.5 Chrono Jailer

- Brain: `ChronoJailerBrain`
- 순환 패턴: platformLock -> handSweep -> echoReplay -> coreExpose.
- `TemporalLockField`가 선택한 발판을 시각적으로 잠그고 플레이어 착지 시
  짧은 movement tax를 부여한다.
- 두 clock hand는 서로 다른 각속도의 damage volume으로 회전한다.
- Echo Bat과 같은 motion history를 사용하되 한 번만 재생한다.
- coreExpose 동안만 overflow를 누적할 수 있다.
- 테스트: 패턴 순서, 발판 선택 유효성, 두 손 판정 분리, 노출창 외 보호.

ROOM 2 완료 게이트:

- 입력 정지 한 프레임 내 적, 투사체, 공격 애니메이션이 함께 멈춘다.
- Runner, Bat, Sniper, Skater가 서로 다른 종류의 시간 조작을 보여준다.
- Jailer가 이 네 문법 중 최소 세 개를 조합한다.

## 7. ROOM 3 — Collision Archive

### 7.1 Vector Ram

- Brain: `VectorRamBrain`
- aim arrow -> charge -> impact -> rebound/stun.
- charge 방향은 수평으로 잠그고 solid 충돌 시 충격량을 계산한다.
- cracked surface 또는 다른 적에 힘을 전달할 수 있게 `ForceReceiver` 계약 추가.
- 테스트: 방향 고정, 벽 관통 없음, impact당 한 번, stun 시간.

### 7.2 Polarity Drone

- Brain: `PolarityDroneBrain`
- hover -> rotateTell -> pullField/pushField -> cooldown.
- `PolarityFieldComponent`가 거리 감쇠된 힘을 player, enemy, loose object에 적용.
- cyan pull과 magenta push를 시각·부호·sound ID로 명확히 분리한다.
- 테스트: 힘 방향, 거리 감쇠, 최대 속도 clamp, solid 내부 끌어당김 방지.

### 7.3 Phase Mimic

- Brain: `PhaseMimicBrain`
- disguise 상태에서는 발판처럼 보이지만 별도 seam tell을 유지한다.
- player가 위에 올라오면 wake -> phaseOut -> belowSnap.
- phaseOut 동안 body collision은 끄되 공격 hitbox는 snap active에만 활성화.
- downward pulse로 조기 발각하면 긴 stagger에 들어간다.
- 테스트: disguise 판정, collision mode 전환, snap 전 무피해, 조기 발각.

### 7.4 Shard Lobber

- Brain: `ShardLobberBrain`
- 주변 solid를 대상으로 최대 두 번 반사하는 경로를 사전 계산한다.
- `RicochetShardComponent`는 계산된 segment를 따라 이동하고 각 bounce에서
  속도와 trail 색을 갱신한다.
- 유효한 두-bounce 경로가 없으면 one-bounce 또는 direct fallback.
- 테스트: 반사각, bounce 상한, 예고 점과 실제 경로 오차, corner loop 방지.

### 7.5 Kernel Chimera

- Brain: `KernelChimeraBrain`
- fused -> split -> opposingCharge -> polarityLane -> recombineShockwave.
- 두 half는 독립 위치와 hitbox를 가지지만 공유 health state를 사용한다.
- 올바른 cyan/magenta 충돌이 발생해야 kernelExpose로 전환한다.
- 잘못 재결합하면 shockwave, 올바른 충돌이면 1.4초 stagger.
- 테스트: 공유 체력, half 개별 충돌, 올바른 재결합 조건, 중복 사망 방지.

ROOM 3 완료 게이트:

- 힘, 위장, 반사, 분리/재결합이 실제 collision 결과를 바꾼다.
- 공격 예고에 표시된 방향과 실제 힘/탄도 오차가 허용치 이내다.
- Chimera는 다른 네 적의 물리 문법을 단순 복제하지 않고 조합한다.

## 8. 애니메이션 연결 계획

### 8.1 manifest 모델

기존 JSON 직접 파싱을 `AnimationManifestRepository`로 감싼다.
각 entry는 다음 필드를 필수로 한다.

- `asset`, `frames`, `fps`, `loop`, `frameSize`, `pivot`
- `events`: `hitboxOn`, `spawnProjectile`, `applyForce`, `hitboxOff`
- `validation`: baseline, centroidX, alphaCoverage, transparentCorners

공격 이벤트는 frame index가 아니라 정규화된 timeline phase로 저장해 FPS 조정 시
gameplay timing이 바뀌지 않게 한다. manifest의 event는 시각 검증용이며,
최종 권한은 `EnemyActionTimeline`이 가진다.

### 8.2 fallback 순서

1. 요청된 고유 animation strip
2. 같은 적의 idle strip
3. 기존 procedural proxy

릴리스 빌드에서는 2 또는 3이 발생하면 테스트가 실패해야 한다. 개발 빌드에서는
게임을 계속 실행하고 누락 key를 한 번만 로그로 남긴다.

### 8.3 동기화 기준

- telegraph animation 마지막 프레임 다음 tick부터 active 시작.
- projectile spawn 위치는 sprite가 아니라 component local socket 좌표 사용.
- mirror 시 socket X만 반전하고 world hitbox 크기는 유지.
- hurt animation은 공격을 끊을 수 있는 적에게만 state interrupt를 허용.
- defeat animation 종료 후 `onDefeated`를 호출하되 룸 진행 중복 방지 token 유지.

## 9. 룸과 월드 API 변경

`PlatformerRoomGeometry`에 query 기능을 추가한다.

- `Rect get worldBounds`
- `Iterable<Rect> get solidBounds`
- `Iterable<PlatformSurfaceRef> get surfaces`
- `RaycastHit? raycast(Vector2 from, Vector2 to)`
- `PlatformSurfaceRef? surfaceAt(Vector2 point)`

룸별 controller는 좌표를 직접 적 AI에 알려주지 않고 spawn definition과
arena constraint만 제공한다. boss 소환 적은 controller의 roster count와
별개인 `summoned` 태그를 가져 5종 완료 카운트를 오염시키지 않게 한다.

## 10. 테스트 계획

### 10.1 공통 단위 테스트

- state transition 우선순위와 취소 정책
- wind-up 중 피해 없음, active에서 1회, recovery에서 피해 없음
- source ID가 15종 공격마다 고유하고 `sentinel`을 포함하지 않음
- time freeze 시 timeline, projectile, animation frame 정지
- mirror 후 hitbox와 socket 정렬
- 사망/overflow/onDefeated idempotency

### 10.2 적별 Brain 테스트

각 적마다 최소 다음 네 테스트를 둔다.

1. 공격 선택 조건
2. 예고 시간과 active 시작점
3. 고유 상호작용 결과
4. 취소·pit·wall·target loss 같은 실패 경로

총 최소 60개 behavior test를 예상한다.

### 10.3 룸 통합 테스트

- 룸마다 exactly 5개의 primary archetype
- 소환 적이 완료 카운트에 포함되지 않음
- 각 archetype이 10초 내 최소 한 번 고유 attack state 진입
- 룸 완료 overlay가 정확히 한 번 열림
- 플레이어 사망/재시작 후 이전 공격 컴포넌트가 남지 않음

### 10.4 시각·에셋 테스트

- 15종 필수 animation key 존재
- strip width = frameWidth x frames, height = frameHeight
- pivot와 baseline 편차 허용치 준수
- 공격 key마다 telegraph/action/recovery mapping 존재
- golden 또는 캡처 기반으로 ROOM 1 다섯 실루엣 검토

## 11. 구현 단계와 예상 작업량

| 단계 | 범위 | 예상 |
| --- | --- | --- |
| M0 | characterization test, source ID 수정, 회귀 안전망 | 1~2일 |
| M1 | state machine, timeline, Brain/context, damage volume, projectile 기반 | 2~3일 |
| M2 | ROOM 1 5종 행동과 프록시 telegraph | 4~6일 |
| M3 | ROOM 1 animation strip 연결 및 품질 승인 | 자산 준비 후 2~4일 |
| M4 | ROOM 2 motion history와 5종 | 5~7일 |
| M5 | ROOM 3 force/raycast와 5종 | 5~7일 |
| M6 | 전체 애니메이션 연결, 밸런스, 브라우저 QA | 3~5일 |

총 예상은 코드와 테스트 기준 17~25 작업일이며, 최종 스프라이트 생성·수정
시간은 별도다. 한 번에 15종을 구현하지 않고 ROOM 단위 승인 게이트를 사용한다.

## 12. 커밋 분할

1. `refactor: introduce platformer enemy state machine`
2. `fix: give enemy attacks unique source identities`
3. `feat: implement damage lab enemy behaviors`
4. `feat: integrate damage lab enemy animations`
5. `feat: implement temporal hall enemy behaviors`
6. `feat: implement collision archive enemy behaviors`
7. `feat: integrate remaining platformer enemy animations`
8. `test: cover platformer enemy combat contracts`
9. `chore: validate platformer sprite manifest`

각 커밋은 `flutter analyze`와 관련 테스트가 통과해야 하며, ROOM 단위 기능 커밋은
브라우저 실플레이 확인 후 다음 단계로 넘어간다.

## 13. 위험과 대응

| 위험 | 영향 | 대응 |
| --- | --- | --- |
| 15종 상태가 공통 컴포넌트에 다시 집중 | 수정 충돌과 회귀 | Brain 분리와 switch 금지 테스트/리뷰 기준 |
| 애니메이션 FPS와 피해 타이밍 불일치 | 불공정한 피격 | 단일 timeline, active frame 자동 검증 |
| ROOM 2 정지 중 일부 효과만 움직임 | 콘셉트 붕괴 | clock policy 명시와 freeze integration test |
| ROOM 3 force가 플레이어를 solid 안으로 밀음 | soft lock | sweep collision, 최대 힘 clamp, 탈출 보정 |
| 보스 소환 적이 완료 카운트 증가 | 조기 룸 종료 | primary/summoned roster tag 분리 |
| 최종 자산 지연 | 코드 검증 지연 | proxy telegraph로 행동 먼저 완료 |
| 화면에 공격이 과도하게 겹침 | 가독성·난이도 악화 | RoomThreatBudget으로 동시 고위험 공격 제한 |

## 14. 완료 조건

- 15종 모두 고유 Brain과 최소 한 개의 독점 상호작용을 가진다.
- 15종 모두 idle/move 또는 hover/telegraph/action/hurt/defeat 상태가 실제
  animation key와 연결된다.
- 모든 공격은 플레이어가 반응 가능한 예고를 가지며 예고와 판정 방향이 일치한다.
- 공통 직선탄을 사용하는 적도 속도만 바꾸는 수준이 아니라 궤적, 시간 규칙,
  반사, 힘 등 상호작용이 다르다.
- ROOM 1~3이 각각 정확히 5종의 primary 적을 처리한 뒤 다음 단계로 이동한다.
- 전체 테스트, 정적 분석, 웹 빌드, 타이틀부터 엔딩까지의 실플레이가 통과한다.
- 릴리스 빌드에서 procedural enemy proxy와 missing animation fallback이 0회다.
