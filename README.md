# PATCH//WORLD

![PATCH//WORLD key art](assets/images/ui/patch_world_key_art.png)

최적화 AI가 망가뜨린 게임 세계에서, 마지막 인간 QA가 규칙의 오류를 이해하고 패치의 부작용까지 전투 도구로 바꾸는 탑다운 2D 액션 게임입니다.

> 하나를 고치면, 다른 하나가 망가진다.

## 플레이

- **PATCH//STORY:** Damage Lab, Temporal Hall, Collision Archive를 지나 `THE OPTIMIZER`와 싸우는 3개 룸 + 보스 캠페인
- **PATCH//SURVIVE:** 적 웨이브와 시간 변칙 속에서 패치를 조합하고 Fusion을 완성하는 무한 생존 모드
- 적을 공격하면 회복시키는 `DAMAGE_SIGN_INVERTED`, 시간 정지, 충돌 융합 등 룸마다 다른 규칙을 역이용합니다.
- 룸을 해결할 때마다 패치 하나를 선택합니다. 규칙 하나는 고쳐지지만 새로운 부작용이 다음 전투를 바꿉니다.
- 생존 모드에서는 6개 패치를 Tier 3까지 성장시키고 `GHOST VENT`, `ECHO CASCADE`, `REDLINE` Fusion을 만들 수 있습니다.

![PATCH//WORLD gameplay concept](docs/visual-concepts/patchworld-gameplay-concept-v1.png)

## 공개 웹 빌드

[GitHub Pages에서 실행](https://12ray.github.io/PATCH-WORLD/)

Pages가 아직 활성화되지 않았다면 저장소의 **Settings → Pages → Build and deployment → Source**를 **GitHub Actions**로 설정해야 합니다. `main`에 push하면 `.github/workflows/pages.yml`이 분석, 테스트, 웹 빌드와 배포를 순서대로 실행합니다.

## 조작

| 행동 | 키보드 | 마우스·터치 |
|---|---|---|
| 이동 | `WASD` / 방향키 | 화면 이동 패드 |
| 패치 펄스 | `Space` / `J` | 공격 버튼 또는 왼쪽 클릭 |
| 상호작용 | `E` / `Enter` | 상호작용 버튼 |
| 일시정지 | `Esc` / `P` | 일시정지 버튼 |

## 로컬 실행

필수 환경은 Flutter 3.44.8 stable, Dart 3.12.2, Flame 1.38.0입니다.

```powershell
flutter pub get
flutter run -d chrome
```

GitHub Pages의 하위 경로 조건까지 확인하려면 다음 release build를 사용합니다.

```powershell
flutter build web --release --base-href "/PATCH-WORLD/"
```

## 검증

```powershell
powershell -ExecutionPolicy Bypass -File tool/check.ps1
```

Linux/macOS에서는 `./tool/check.sh`를 사용합니다. 현재 기준은 `flutter analyze`, 자동 테스트 121개, release web build 통과입니다.

## 배포

- GitHub Pages: `.github/workflows/pages.yml`
- Firebase Hosting 대체 경로: `.github/workflows/firebase-hosting.yml`, `firebase.json`
- 로컬 릴리스 패키징: `./tool/release_web.sh 0.2.0-rc1`

GitHub CLI로 비공개 저장소의 Actions와 Pages 상태를 확인하려면 먼저 로그인합니다.

```powershell
gh auth login
gh run list --repo 12Ray/PATCH-WORLD --limit 10
```

## 문서와 라이선스

- [제출 소개·영상 구성](docs/submission/SUBMISSION.md)
- [Codex 협업 기록](docs/CODEX_COLLABORATION.md)
- [서드파티 고지](THIRD_PARTY_NOTICES.md)
- [에셋 권리 원장](assets/licenses/ASSET_LEDGER.md)
- [게임플레이·비주얼 방향](docs/VISUAL_DIRECTION.md)
- [PATCH//WORLD Project HQ](https://app.notion.com/p/3b2299e2188881ec8e45d6d7fa5ee356)
