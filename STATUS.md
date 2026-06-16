# 크보웹 (KBO 스탯 웹) — 프로젝트 현황

> 새 세션 시작 시 이 파일만 읽으면 됨 (코드 재탐색 불필요 = 토큰 절약).
> 사이트명 **크보웹**(임시). 배포: https://kbo-stat-card.vercel.app · GitHub: palebluedot12/kbo-stat-card · 폴더: H:\KBOWEB

## 페이지 (정적 HTML, Vercel 자동배포)
- **index.html** — 선수 카드(배포 정식 페이지). ⚠️ 중복본 player-radar-card.html은 삭제됨, **반드시 index.html 수정**
- **myteam.html** — 마이팀(주간 판타지, **예산 120**, 드래그). **가격=지난주 판타지점수 백분위 기준**(weekly_prev.js), 점수=이번주 라이브(weekly.js)
- **heroes.html** — 오늘의 BEST·WORST(경기별 승리기여)
- 공통: 상단 op.gg식 sticky 탭바, OG 공유태그, og.png(공유 썸네일), 모바일 반응형(@media max-width:640)

## 데이터 파일 (GitHub Actions가 매일 자동 갱신 — 직접 수정/통독 금지, 4MB)
- data.js / data_pitchers.js — 시즌 누적(KBO_PLAYERS/KBO_PITCHERS), base64 사진
- heroes.js(BEST/WORST) · weekly.js(이번주 주간) · weekly_prev.js(지난주=가격산정용, KBO_WEEKLY_PREV)
- positions.js(KBO_POS, 타자 주포지션=올시즌 최다출장 G 기준) — **수동** `patch_positions.ps1`(KBO 수비기록). 자동갱신 아님
- trajectory.js(투구 최근10일·KBO_TRAJ) · traj_hr.js(시즌 홈런·KBO_HR, 누적)

## 스크래퍼 / 자동화
- scrape.ps1, scrape_pitchers.ps1, scrape_heroes.ps1, scrape_week.ps1, scrape_trajectory.ps1
- .github/workflows/daily.yml — 크론 **5회**(23:30/01:00/02:30/04:30/07:00 KST). GitHub 예약은 best-effort라 누락 대비. 스크래퍼는 "최신 종료일만·변경시에만 커밋"이라 중복 안전
- 수동 실행: `gh workflow run daily.yml` (gh 경로: "C:\Program Files\GitHub CLI\gh.exe")

## 지금까지 한 것 ✅
- 선수 레이더 카드(S~F 등급, wRC+/WAR 백분위) · PNG 저장
- 마이팀(드래그·예산·대결) · 오늘의 BEST·WORST(WPa·REa 하이브리드)
- 홈런 스프레이(마이팀식 야구장+담장밖 점) / 투수 구종별 투구위치(구종 토글)
- 자동화(매일 6종 데이터 갱신) — 경로 $PSScriptRoot 수정, 날짜 폴백, 크론 5회로 안정화
- op.gg식 탭바 통일 · 사이트명 크보웹 · 모바일 최적화 · OG 공유태그
- **표본부족 처리**(타자<30타석·투수<10이닝 → 등급 대신 '표본부족', 목록 맨 아래)
- **선수 비교**(육각형 2개 오버레이 + 축별 비교표 승자강조 + 비교 PNG 저장)
- **마이팀 강화**: 팀 공유링크(URL-safe base64, `?t=`)·팀 이미지 저장(html2canvas, 워터마크)·친구 팀과 대결/팀 보기

## 다음 후보 (백로그)
- 콘텐츠/수익화: 매일 자동 "세로 9:16 카드"(트위터·인스타·쇼츠용), 워터마크 유입 깔때기
- 저작권 안전화: 선수 사진 → 일러스트/실루엣 대체 검토 (수익화 시 사진이 천장)
- 투수 구종 궤적: 스트라이크존 강조 등 직관성 개선
- 마이팀 추가: 진짜 랭킹(백엔드 필요)·주간 자동 베스트팀 제시
- 사이트명/도메인 확정

## 규칙·주의 (gotchas)
- **index.html이 정식** (선수카드 UI 수정은 여기). myteam=myteam.html, heroes=heroes.html
- PowerShell 5.1 .ps1은 한글 위해 **UTF-8 BOM** 필요 / 출력경로 `$PSScriptRoot` 폴백 / 예약변수 $pid·$home 회피
- 데이터 .js는 4MB → 통독 금지(필요시 grep/substring). ConvertFrom-Json 큰 파일서 불안정
- pcode == KBO playerId == data.js의 pid (동일)
- 커밋 충돌 시: `git pull --no-edit` 후 푸시 (Action도 커밋함)
