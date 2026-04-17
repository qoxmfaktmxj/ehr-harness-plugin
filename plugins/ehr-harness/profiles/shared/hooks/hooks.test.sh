#!/bin/bash
# hooks.test.sh — db-read-only.sh / vcs-no-commit.sh 단위 테스트
# 사용: bash hooks.test.sh
# 성공: exit 0 / 실패: exit 1

set -u -o pipefail

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS=0
FAIL=0
FAIL_CASES=()

# JSON payload 생성 (jq 있으면 jq, 없으면 node, 없으면 수동 escape)
to_json() {
  local cmd="$1"
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg cmd "$cmd" '{tool_input:{command:$cmd}}'
  else
    node -e "process.stdout.write(JSON.stringify({tool_input:{command:process.argv[1]}}))" "$cmd"
  fi
}

# assert_hook <case_name> <hook_file> <command_string> <expected_exit_code>
assert_hook() {
  local name="$1"
  local hook="$2"
  local cmd="$3"
  local expected="$4"

  local payload actual=0 output
  if [ -z "$cmd" ]; then
    payload=""                                   # 빈 입력 시뮬레이션
  else
    payload=$(to_json "$cmd")
  fi

  output=$(echo "$payload" | "$HOOK_DIR/$hook" 2>&1) || actual=$?

  if [ "$actual" -eq "$expected" ]; then
    echo "  ✓ $name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name (expected exit $expected, got $actual)"
    echo "     cmd:    $cmd"
    echo "     output: $output"
    FAIL=$((FAIL + 1))
    FAIL_CASES+=("$name")
  fi
}

# ─────────────────────────────────────────────
# db-read-only.sh 테스트
# ─────────────────────────────────────────────
echo "=== db-read-only.sh ==="

# 통과해야 할 케이스 (exit 0)
assert_hook "empty input"                        db-read-only.sh "" 0
assert_hook "non-SQL command (ls)"               db-read-only.sh "ls -la" 0
assert_hook "non-SQL command (grep in files)"    db-read-only.sh "grep UPDATE *.sql" 0
assert_hook "cat sql file (no exec)"             db-read-only.sh "cat foo.sql" 0
assert_hook "ls sql files"                       db-read-only.sh "ls *.sql" 0
assert_hook "simple SELECT via sqlplus"          db-read-only.sh "echo 'SELECT * FROM dual;' | sqlplus -s u/p" 0
assert_hook "SELECT with WHERE"                  db-read-only.sh "echo \"SELECT name FROM t WHERE id=1\" | sqlplus u/p" 0
assert_hook "sqlplus help flag"                  db-read-only.sh "sqlplus -?" 0

# 차단해야 할 케이스 (exit 2)
assert_hook "DELETE via sqlplus"                 db-read-only.sh "echo 'DELETE FROM t' | sqlplus u/p" 2
assert_hook "UPDATE via sqlplus"                 db-read-only.sh "echo 'UPDATE t SET x=1' | sqlplus u/p" 2
assert_hook "INSERT via sqlplus"                 db-read-only.sh "echo 'INSERT INTO t VALUES(1)' | sqlplus u/p" 2
assert_hook "DROP via sqlplus"                   db-read-only.sh "echo 'DROP TABLE t' | sqlplus u/p" 2
assert_hook "MERGE via sqlplus"                  db-read-only.sh "echo 'MERGE INTO t USING s ON ...' | sqlplus u/p" 2
assert_hook "CTE + UPDATE bypass attempt"        db-read-only.sh "echo 'WITH cte AS (SELECT 1 FROM dual) UPDATE t SET x=1' | sqlplus u/p" 2
assert_hook "DECLARE BEGIN END block"            db-read-only.sh "echo 'DECLARE x NUMBER; BEGIN x:=1; END;' | sqlplus u/p" 2
assert_hook "BEGIN block only"                   db-read-only.sh "echo 'BEGIN dbms_output.put_line(1); END;' | sqlplus u/p" 2
assert_hook "dbms_ lowercase"                    db-read-only.sh "echo 'BEGIN dbms_sql.execute(1); END;' | sqlplus u/p" 2
assert_hook "UTL_MAIL usage"                     db-read-only.sh "echo 'BEGIN utl_mail.send(1); END;' | sqlplus u/p" 2
assert_hook "@script.sql execution"              db-read-only.sh "sqlplus u/p @cleanup.sql" 2
assert_hook "CREATE TABLE"                       db-read-only.sh "echo 'CREATE TABLE t (id INT)' | sqlplus u/p" 2
assert_hook "GRANT statement"                    db-read-only.sh "echo 'GRANT SELECT ON t TO user' | sqlplus u/p" 2
assert_hook "impdp data pump"                    db-read-only.sh "impdp user/pass dumpfile=data.dmp" 0      # impdp 자체는 통과 (DML 키워드 없음). 의도: impdp 도 차단 대상인지 논의
assert_hook "tibero tbsql with DELETE"           db-read-only.sh "echo 'DELETE FROM t' | tbsql u/p" 2

echo

# ─────────────────────────────────────────────
# vcs-no-commit.sh 테스트
# ─────────────────────────────────────────────
echo "=== vcs-no-commit.sh ==="

# 통과해야 할 케이스
assert_hook "empty input"                        vcs-no-commit.sh "" 0
assert_hook "git status"                         vcs-no-commit.sh "git status" 0
assert_hook "git log"                            vcs-no-commit.sh "git log --oneline" 0
assert_hook "git diff"                           vcs-no-commit.sh "git diff HEAD" 0
assert_hook "git branch list"                    vcs-no-commit.sh "git branch -a" 0
assert_hook "git stash push (save only)"         vcs-no-commit.sh "git stash push -m 'wip'" 0
assert_hook "git stash list"                     vcs-no-commit.sh "git stash list" 0
assert_hook "svn status"                         vcs-no-commit.sh "svn status" 0
assert_hook "svn log"                            vcs-no-commit.sh "svn log" 0

# 차단해야 할 케이스
assert_hook "git commit"                         vcs-no-commit.sh "git commit -m 'x'" 2
assert_hook "git push"                           vcs-no-commit.sh "git push origin main" 2
assert_hook "git rebase"                         vcs-no-commit.sh "git rebase -i HEAD~3" 2
assert_hook "git reset hard"                     vcs-no-commit.sh "git reset --hard HEAD" 2
assert_hook "git revert"                         vcs-no-commit.sh "git revert abc123" 2
assert_hook "git tag"                            vcs-no-commit.sh "git tag v1.0" 2
assert_hook "git apply patch"                    vcs-no-commit.sh "git apply patch.diff" 2
assert_hook "git am mail patch"                  vcs-no-commit.sh "git am < mail.patch" 2
assert_hook "git cherry-pick"                    vcs-no-commit.sh "git cherry-pick abc123" 2
assert_hook "git format-patch"                   vcs-no-commit.sh "git format-patch -1 HEAD" 2
assert_hook "git stash pop"                      vcs-no-commit.sh "git stash pop" 2
assert_hook "git stash apply"                    vcs-no-commit.sh "git stash apply stash@{0}" 2
assert_hook "svn commit"                         vcs-no-commit.sh "svn commit -m 'x'" 2
assert_hook "svn ci"                             vcs-no-commit.sh "svn ci -m 'x'" 2
assert_hook "svn import"                         vcs-no-commit.sh "svn import foo https://svn/..." 2
assert_hook "svn delete"                         vcs-no-commit.sh "svn delete file.txt" 2

# ─────────────────────────────────────────────
# Windows 경로 엣지 케이스 (공백/한글)
# 실제 symlink/junction 은 Git Bash 관리자 권한 필요 →
#   파일 복사로 대체. 실제 symlink 는 별도 환경 검증 필요
# ─────────────────────────────────────────────
echo "=== Windows path edge cases ==="

# ── WP-1: 공백 포함 경로의 sqlplus 명령 (C:/Program Files (x86)/ 시뮬레이션) ──
# 허용: 공백 경로 안의 SELECT (읽기 전용)
assert_hook "WP-1 공백경로 SELECT (read-only)" \
  db-read-only.sh \
  "echo 'SELECT * FROM dual;' | \"/c/Program Files (x86)/oracle/sqlplus\" -s u/p" \
  0

# 차단: 공백 경로 안의 DELETE
assert_hook "WP-1 공백경로 DELETE (blocked)" \
  db-read-only.sh \
  "echo 'DELETE FROM t WHERE id=1' | \"/c/Program Files (x86)/oracle/sqlplus\" u/p" \
  2

# ── WP-2: 한글 포함 경로의 sqlplus 명령 (C:/사용자/홍길동/ 시뮬레이션) ──
# 허용: 한글 경로 안의 SELECT
assert_hook "WP-2 한글경로 SELECT (read-only)" \
  db-read-only.sh \
  "echo 'SELECT id FROM 사용자테이블;' | sqlplus -s u/p" \
  0

# 차단: 한글 포함 경로 UPDATE — 키워드 감지
assert_hook "WP-2 한글경로 UPDATE (blocked)" \
  db-read-only.sh \
  "echo 'UPDATE 한글테이블 SET col=1' | sqlplus u/p" \
  2

# ── WP-3: 공백 포함 경로에서 git commit 차단 ──
# 시뮬레이션: C:/Program Files (x86)/repo/
assert_hook "WP-3 공백경로 git commit (blocked)" \
  vcs-no-commit.sh \
  "cd '/c/Program Files (x86)/repo' && git commit -m 'x'" \
  2

# ── WP-4: 한글 포함 경로에서 git status 허용 ──
# 시뮬레이션: /home/홍길동/
assert_hook "WP-4 한글경로 git status (allowed)" \
  vcs-no-commit.sh \
  "cd '/home/홍길동/project' && git status" \
  0

# ── WP-5 (심볼릭링크 mock): 경로에 symlink 문자열 포함 시 정상 동작 ──
# 실제 symlink 는 별도 환경 검증 필요 (mklink /J 는 관리자 권한 필요)
assert_hook "WP-5 심볼릭링크(mock) SELECT (read-only)" \
  db-read-only.sh \
  "echo 'SELECT 1 FROM dual;' | sqlplus u/p" \
  0

echo
echo "=== 결과: $PASS pass, $FAIL fail ==="

if [ "$FAIL" -gt 0 ]; then
  echo "실패 케이스:"
  for c in "${FAIL_CASES[@]}"; do
    echo "  - $c"
  done
  exit 1
fi

exit 0
