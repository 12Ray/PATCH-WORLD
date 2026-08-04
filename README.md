# PATCH//WORLD

![PATCH//WORLD key art](assets/images/ui/patch_world_key_art.png)

《PATCH//WORLD: 인간이 마지막으로 정한 규칙》은 피해·시간·충돌 규칙의 오류를 역이용하고, 패치의 부작용으로 `THE OPTIMIZER`를 무너뜨리는 5~8분 분량의 탑다운 액션 퍼즐입니다.

> 하나를 고치면, 다른 하나가 망가진다.

## 핵심 게임플레이

- 공격이 적을 회복시키는 `DAMAGE_SIGN_INVERTED`를 이용해 최대 체력을 넘기고 오버플로시킵니다.
- 룸을 해결할 때마다 하나의 패치를 선택하지만, 고친 규칙은 새로운 부작용을 다음 전투에 남깁니다.
- 적이 방출한 데이터 조각 6개를 회수하면 펄스 대기시간이 초기화되고 무결성 1을 회복합니다.
- Damage Lab, Temporal Hall, Collision Archive, Optimizer Core가 서로 다른 규칙과 공간 언어를 사용합니다.
- QA 주인공과 Crawler는 픽셀 프레임 애니메이션을 사용하고, Sentinel과 Optimizer는 상태별 텔레그래프와 반동으로 행동을 예고합니다.

![PATCH//WORLD gameplay concept](docs/visual-concepts/patchworld-gameplay-concept-v1.png)

## 현재 구성

- Flutter 3.44.8 stable · Dart 3.12.2 · Flame 1.38.0
- 960×540 고정 논리 해상도, 데스크톱 웹 우선
- 3개 룸 + 보스 룸, 일반 적 2종, 패치 카드 6개, 8개 조합
- 키보드·마우스·터치 입력
- 한국어/영어, 텍스트 배율, 볼륨, 화면 흔들림, 플래시 감소, Assist Mode
- Tiled 객체 레이어 기반 스폰·충돌·상호작용 좌표
- 타이틀, 설정, 크레딧, 패배, 엔딩 선택, 런 요약, 최고 점수

## 조작

| 행동 | 키보드 | 마우스·터치 |
|---|---|---|
| 이동 | `WASD` / 방향키 | 화면 이동 패드 |
| 패치 펄스 | `Space` / `J` | 왼쪽 클릭 / 공격 버튼 |
| 상호작용 | `E` / `Enter` | 상호작용 버튼 |
| 일시정지 | `Esc` / `P` | 일시정지 버튼 |

## 실행

```powershell
flutter pub get
flutter run -d chrome
```

## 전체 검증

```powershell
powershell -ExecutionPolicy Bypass -File tool/check.ps1
```

Linux/macOS에서는 `./tool/check.sh`를 사용합니다.

현재 기준 `flutter analyze`, 자동 테스트 66개, 릴리스 웹 빌드와 Room 1 브라우저 스모크를 통과했습니다.

## 릴리스

```bash
./tool/release_web.sh 0.2.0-rc1
```

Firebase Hosting 설정은 `firebase.json`, GitHub Pages 배포는 `.github/workflows/pages.yml`에 있습니다. GitHub 원격 저장소는 연결되어 있으며, 공개 배포에는 Pages 활성화 또는 Firebase 프로젝트 ID가 필요합니다.

## 제출 자료

- [제출 소개·영상 구성](docs/submission/SUBMISSION.md)
- [Codex 협업 기록](docs/CODEX_COLLABORATION.md)
- [서드파티 고지](THIRD_PARTY_NOTICES.md)
- [에셋 권리 원장](assets/licenses/ASSET_LEDGER.md)
- [게임플레이·비주얼 방향](docs/VISUAL_DIRECTION.md)

프로젝트 기준 문서: [PATCH//WORLD Project HQ](https://app.notion.com/p/3b2299e2188881ec8e45d6d7fa5ee356)
