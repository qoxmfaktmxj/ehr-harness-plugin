# controller_lawB

## 입력
`/impact partMgrAppController.java`

## fixture 구성
partMgrApp.jsp 가 `GetDataList.do?cmd=getPartMgrList` 호출 + 매퍼에 해당 queryId

## 기대 출력 핵심 포인트

### 6. 판정
`⚙ Conditional-Go`
근거: SIGNAL_LAW_B=1 — GetDataList.do/SaveData.do 호출
