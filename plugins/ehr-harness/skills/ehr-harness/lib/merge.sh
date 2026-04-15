#!/usr/bin/env bash
# merge.sh — HARNESS-MANAGED 섹션 병합 유틸
#
# 기존 사용자 편집 문서를 보존하면서 플러그인이 관리하는 섹션만 교체/추가한다.
# 관리 섹션은 `<!-- HARNESS-MANAGED:ID -->` / `<!-- /HARNESS-MANAGED:ID -->` 쌍으로 감싸고,
# 이 마커 내부만 갱신 대상으로 삼아 사용자 커스텀 섹션은 절대 건드리지 않는다.
#
# 사용 예:
#   source merge.sh
#   merge_managed_section "AGENTS.md" "analysis_snapshot" "## 분석 스냅샷 (자동 감별)" "$NEW_BODY"
#
# 동작 (3분기):
#   (1) 마커 쌍 존재      → 내부만 교체, 헤딩·주변 텍스트 불변
#   (2) 헤딩만 존재       → 헤딩은 유지, 본문 영역을 마커로 래핑하면서 교체
#   (3) 헤딩도 없음       → 파일 끝에 `HEADING\n\n[start]\nBODY\n[end]\n` 로 append

set -u -o pipefail

# ── 헬퍼: 파일에서 마커 쌍 사이 본문 추출 ──
# args: FILE SECTION_ID
# stdout: 마커 사이 본문 (앞/뒤 개행 1개씩 trim). 미발견 시 exit 2.
extract_section_body() {
  local file="$1"
  local section_id="$2"
  FILE="$file" ID="$section_id" node -e '
    const fs=require("fs");
    const src=fs.readFileSync(process.env.FILE,"utf8").replace(/\r\n/g,"\n");
    const id=process.env.ID;
    const start=`<!-- HARNESS-MANAGED:${id} -->`;
    const end=`<!-- /HARNESS-MANAGED:${id} -->`;
    const s=src.indexOf(start);
    const e=src.indexOf(end);
    if(s===-1||e===-1||e<=s){process.exit(2);}
    let body=src.slice(s+start.length, e);
    if(body.startsWith("\n"))body=body.slice(1);
    if(body.endsWith("\n"))body=body.slice(0,-1);
    process.stdout.write(body);
  '
}

# ── 헬퍼: 파일에서 start 마커 바로 앞의 `## ...` 헤딩 라인 추출 ──
# args: FILE SECTION_ID
# stdout: `## 섹션 제목` 문자열. 미발견 시 exit 2/3.
extract_section_heading() {
  local file="$1"
  local section_id="$2"
  FILE="$file" ID="$section_id" node -e '
    const fs=require("fs");
    const lines=fs.readFileSync(process.env.FILE,"utf8").replace(/\r\n/g,"\n").split("\n");
    const id=process.env.ID;
    const marker=`<!-- HARNESS-MANAGED:${id} -->`;
    let mi=-1;
    for(let i=0;i<lines.length;i++){ if(lines[i].trim()===marker){ mi=i; break; } }
    if(mi===-1){process.exit(2);}
    // 마커 위쪽으로 탐색하되 다른 HARNESS-MANAGED 마커나 최상위 H1 은 경계로 본다.
    let found=null;
    for(let j=mi-1;j>=0;j--){
      const L=lines[j];
      if(/<!--\s*\/?HARNESS-MANAGED:/.test(L)) break;
      if(/^#\s/.test(L)) break;
      if(/^##\s/.test(L)){ found=L; break; }
    }
    if(found===null){process.exit(3);}
    process.stdout.write(found);
  '
}

merge_managed_section() {
  local file="$1"
  local section_id="$2"
  local heading="$3"
  local body="$4"

  if [ ! -f "$file" ]; then
    echo "merge_managed_section: 파일 없음 — $file" >&2
    return 1
  fi

  FILE="$file" ID="$section_id" HEADING="$heading" BODY="$body" node -e '
    const fs = require("fs");
    const file = process.env.FILE;
    const id = process.env.ID;
    const heading = process.env.HEADING;
    const body = process.env.BODY;
    const start = `<!-- HARNESS-MANAGED:${id} -->`;
    const end = `<!-- /HARNESS-MANAGED:${id} -->`;
    const block = `${start}\n${body}\n${end}`;

    let src = fs.readFileSync(file, "utf8");
    const eol = src.includes("\r\n") ? "\r\n" : "\n";
    // 작업 중에는 \n 으로 통일했다가 쓰기 직전에 원래 EOL 로 복원
    src = src.replace(/\r\n/g, "\n");

    // ── 중복 마커 감지: 사용자 실수로 같은 섹션 ID 의 쌍이 두 번 이상 들어온 경우
    //    첫 쌍만 유지하고 나머지 블록은 제거(orphan 방지) + stderr 경고.
    const allStarts = [];
    {
      let p = 0;
      while ((p = src.indexOf(start, p)) !== -1) { allStarts.push(p); p += start.length; }
    }
    const allEnds = [];
    {
      let p = 0;
      while ((p = src.indexOf(end, p)) !== -1) { allEnds.push(p); p += end.length; }
    }
    if (allStarts.length > 1 || allEnds.length > 1) {
      process.stderr.write(
        `merge_managed_section: 중복 마커 감지 (${id}) — start ${allStarts.length}, end ${allEnds.length}. 첫 쌍만 유지하고 나머지 제거.\n`
      );
      // 역순으로 여분 블록 제거 (뒤에서부터 지워야 앞 인덱스가 유효)
      const extras = [];
      const pairCount = Math.min(allStarts.length, allEnds.length);
      for (let i = 1; i < pairCount; i++) {
        if (allEnds[i] > allStarts[i]) {
          extras.push({ s: allStarts[i], e: allEnds[i] + end.length });
        }
      }
      // 짝 없는 여분 마커도 제거
      for (let i = pairCount; i < allStarts.length; i++) {
        extras.push({ s: allStarts[i], e: allStarts[i] + start.length });
      }
      for (let i = pairCount; i < allEnds.length; i++) {
        extras.push({ s: allEnds[i], e: allEnds[i] + end.length });
      }
      extras.sort((a, b) => b.s - a.s);
      for (const ex of extras) {
        src = src.slice(0, ex.s) + src.slice(ex.e);
      }
    }

    const startIdx = src.indexOf(start);
    const endIdx = src.indexOf(end);

    let out;
    if (startIdx !== -1 && endIdx !== -1 && endIdx > startIdx) {
      // (1) 마커 쌍 존재 → 내부 교체
      const before = src.slice(0, startIdx);
      const after = src.slice(endIdx + end.length);
      out = before + block + after;
    } else {
      // heading 라인 단독 매칭 (공백 trim 후 일치)
      const lines = src.split("\n");
      let headingLine = -1;
      for (let i = 0; i < lines.length; i++) {
        if (lines[i].trim() === heading.trim()) {
          headingLine = i;
          break;
        }
      }
      if (headingLine !== -1) {
        // (2) heading 존재, 마커 없음 → 이 heading 의 섹션 범위를 다음 `## ` 또는 EOF 까지로 보고 교체.
        //     heading 자체는 유지하고 그 아래 본문을 [start]...[end] 로 래핑.
        let nextHeadingLine = lines.length;
        for (let j = headingLine + 1; j < lines.length; j++) {
          if (/^##\s/.test(lines[j])) { nextHeadingLine = j; break; }
        }
        const before = lines.slice(0, headingLine + 1).join("\n");
        const after = lines.slice(nextHeadingLine).join("\n");
        const middle = `\n\n${block}\n\n`;
        out = before + middle + after;
      } else {
        // (3) heading 도 없음 → 파일 끝에 append. 기존 문서가 개행으로 안 끝나면 하나 붙여준다.
        const tail = src.endsWith("\n") ? "" : "\n";
        out = `${src}${tail}\n${heading}\n\n${block}\n`;
      }
    }

    // 연속 공백 라인 정규화 (3개 이상 빈 줄 → 2개)
    out = out.replace(/\n{3,}/g, "\n\n");
    // 파일은 반드시 개행으로 끝나도록
    if (!out.endsWith("\n")) out += "\n";

    // 원래 EOL 복원
    if (eol === "\r\n") out = out.replace(/\n/g, "\r\n");

    fs.writeFileSync(file, out);
  '
}
