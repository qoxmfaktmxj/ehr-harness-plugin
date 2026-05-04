---
description: 하네스 첫 사용자를 위한 5분 가이드. 활성화 확인 → 하네스 생성 → 첫 명령 → 스킬 카탈로그 → 작업 사이클 순으로 안내한다.
---

# /ehr:onboarding — EHR 하네스 5분 가이드

> 대상: EHR 코드는 만져봤고, **이 하네스를 처음 쓰는 사용자**.
> EHR 도메인(권한 모델, 법칙, 패턴) 자체를 처음 배우는 경우는 본 가이드의 범위가 아니다 — 하단 "도메인 깊이 학습" 링크 참조.

---

## Step 1 · 활성화 확인 (30초)

이 명령(`/ehr:onboarding`)이 동작했다면 플러그인은 이미 활성화되어 있다.

추가로 필요한 것:

- [ ] **Claude Code** 설치됨 (CLI / Desktop / Web)
- [ ] **superpowers 플러그인** 설치됨 — `/ehr:plan`, `/ehr:work`, `/ehr:review` 가 내부 호출
- [ ] **EHR 프로젝트 폴더**에서 Claude Code 세션을 열어둔 상태

superpowers 미설치 시:

```
/plugin install superpowers@claude-plugins-official
```

---

## Step 2 · 하네스 생성 (1.5분)

EHR 프로젝트 폴더에서 다음 한 마디를 입력한다:

```
하네스 만들어줘
```

플러그인이 프로젝트를 분석하고 다음을 자동 생성한다:

- `AGENTS.md`, `CLAUDE.md` — AI가 따라야 할 프로젝트 규칙
- `.claude/skills/` — 화면 생성 / 코드 탐색 / DB 조회 등 전문 스킬
- `.claude/agents/` — 릴리스 리뷰 / 프로시저 추적 등 전문 에이전트
- `.claude/hooks/` — DB 변경 차단, VCS 커밋 차단 안전 장치
- `HARNESS.json` — 매니페스트

> 프로파일은 자동 판정된다 (EHR4 vs EHR5). 수동 지정이 필요하면 "ehr5 프로파일로 하네스 만들어줘" 형태로 명시한다.

---

## Step 3 · 첫 명령 실행 (1분)

생성된 하네스가 동작하는지 확인하기 위해 **인자 없이** 다음을 입력한다:

```
/ehr:ideate
```

하네스가 이미 알고 있는 프로젝트 정보를 역으로 활용해 **개선 아이디어 후보**를 제안한다. 이 명령은 입력값 없이도 동작하며 결과가 표 형태로 나온다.

→ 결과가 나오면 **하네스 활성화 성공**.

---

## Step 4 · 상황별 스킬 가이드 (2분 보기)

작업 종류에 따라 호출되는 스킬이 다르다. 자연어로 요청하면 자동 라우팅되지만, 어떤 스킬이 어떤 상황에 동작하는지 알면 결과가 빨리 나온다.

| 스킬 | 용도 | 유지보수 | 추가개발 | 키워드 예시 |
|---|---|:-:|:-:|---|
| **impact-analyzer** | 변경 전 영향도 예측 (Go/HOLD/STOP) | ★★★ | ★ | "이거 수정하면 뭐 깨짐", "영향도 분석" |
| **procedure-tracer** | 프로시저 체인 / 동적 SQL 추적 | ★★★ | ★ | "프로시저 분석", "체인 추적", "동적 SQL" |
| **codebase-navigator** | 코드 위치 탐색, 에러 진단 | ★★★ | ★★ | "어디에 있어", "찾아줘", "에러 원인" |
| **db-query** | Oracle/Tibero SELECT 조회 | ★★ | ★★ | "DB 조회", "프로시저 소스 봐줘", "테이블 구조" |
| **screen-builder** | 화면 생성 / 수정 | ★ | ★★★ | "화면 만들어", "신규 개발", "CRUD" |
| **design-guide** | IDS Storybook 컴포넌트 가이드 | – | ★★★ | "IDS", "디자인 시스템", "컴포넌트 사용법" |
| **domain-knowledge** | 4축 권한, 법칙 A~D, 패턴 카탈로그 | ★★ | ★★★ | "권한", "법칙", "패턴", "신청서 상태" |
| **ehr-lessons** | 누적 지식 (검증 명명, 회신 템플릿) | ★★ | ★★ | "검증 함수", "회신 템플릿" |

**유지보수 핵심**: impact-analyzer + procedure-tracer + codebase-navigator
**추가개발 핵심**: screen-builder + design-guide + domain-knowledge

---

## Step 5 · 작업 사이클 (30초 보기)

표준 작업 흐름은 **plan → work → review → compound** 4단계다.

| 명령 | 단계 | 설명 |
|---|---|---|
| `/ehr:plan` | 사전 | 영향도 + DB 영향 섹션 포함 기술 계획 작성 (writing-plans 래퍼) |
| `/ehr:work` | 실행 | 플랜대로 실행하며 위 스킬 자동 라우팅 (executing-plans 래퍼) |
| `/ehr:review` | 사후 | release-reviewer + db-impact-reviewer 병렬 호출 (다중 관점) |
| `/ehr:compound` | 사후 | 새로 알게 된 것을 L2/L3 지식으로 회수 (폐곡선 닫힘점) |

자유 사용 명령:

| 명령 | 용도 |
|---|---|
| `/ehr:ideate` | 개선 아이디어 발굴 (Step 3 에서 사용) |
| `/ehr:harvest-learnings` | 학습 데이터 수확 (주 1회 권장) |

---

## 다음 단계

- **고객사 인계 받음** → `/ehr:handover` (특정 고객사 인수인계 산출물)
- **도메인 깊이 학습** → [domain-knowledge 스킬](../../../profiles/ehr5/skills/domain-knowledge/SKILL.md) (4축 권한, 법칙 A~D, 패턴 카탈로그)
- **전체 명령 목록** → `/help`

## 막힐 때

- 설치/활성화 문제 → 플러그인 [README.md](../../../../README.md) §2 ~ §3
- 동작 원리 / 디렉토리 구조 → 플러그인 [README.md](../../../../README.md) §5, §11
- 안전 정책 (DB / 시크릿 / 권한) → 하네스 SECURITY.md (작성 예정)
