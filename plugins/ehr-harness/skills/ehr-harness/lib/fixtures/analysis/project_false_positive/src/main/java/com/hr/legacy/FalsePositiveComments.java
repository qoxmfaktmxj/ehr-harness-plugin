package com.hr.legacy;

// 리팩 메모: authSqlID 값을 "XXXX999" 로 바꾸는 이슈 (authSqlID 뒤에 한글/공백)
// 주석 안에 authSqlID 라는 단어와 함께 "YYYY888" 도 등장함
/*
 * authSqlID 처리가 불안정한 경우가 있다.
 * authSqlID 검토 필요: 값 "AAAA111" 은 예전 티켓에서 다뤘다.
 */
public class FalsePositiveComments {
    // 한 줄 주석에 authSqlID 라는 키워드가 있지만 실제 할당/put 형태 아님 "BBBB222"
    public String note = "authSqlID 이슈: \"CCCC333\"";
}
