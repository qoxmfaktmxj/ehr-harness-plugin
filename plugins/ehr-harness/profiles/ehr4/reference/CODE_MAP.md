# EHR5 코드맵

> graphify에서 자동생성. 코드 탐색 시 이 파일을 먼저 참조.

## CPN (급여/임금) — `EHR_HR50/src/main/java/com/hr/cpn/`

- **basisConfig/** (22화면): contractCre, contractMgr, famInfoMgr 외 13개
- **common/** (1화면): cpnQuery
- **element/** (7화면): allowEleMgr, allowElePptMgr, dedEleMgr 외 4개
- **payApp/** (12화면): deptPartPayApp, deptPartPayAppDet, deptPartPayAppMgr 외 9개
- **payBonus/** (6화면): bonusConfirm1, bonusConfirm2, bonusDiv 외 3개
- **payCalculate/** (14화면): gLInterfaceCalMgr, gLInterfaceStd, monPayMailCre 외 10개
- **payData/** (1화면): payCalculator
- **payReport/** (12화면): beforeYearFileDown, payActionSta, payDayChkStd 외 7개
- **payRetire/** (29화면): annualIncomeTable, nujinDateMgr, retConnectPay 외 26개
- **payRetroact/** (7화면): retroCalcCre, retroCalcWorkSta, retroEleSetMgr 외 3개
- **payUpload/** (2화면): payUploadCal, payUploadEleMgr
- **perExpense/** (6화면): bonusAdjustMonSta, deptAdjustmentSta, inOutOrgMgr 외 3개
- **personalBasis/** (1화면): attachMgr
- **personalPay/** (29화면): accMgr, exceAllowMgr, exceAllowNewMgr 외 24개
- **yjungsan/** (9화면): befComLst, befComMgr, befComUpld 외 6개
- **youthIncome/** (1화면): youthIncomeExemption

## HRM (인사관리) — `EHR_HR50/src/main/java/com/hr/hrm/`

- **apply/** (1화면): hrmApplyUser
- **appmt/** (15화면): appmtHistoryMgr, appmtTimelineSrch, escapeApprentice 외 10개
- **appmtBasic/** (7화면): appmtCodeMgr, appmtColumMgr, appmtDetailCodeHeadMgr 외 4개
- **certificate/** (4화면): certiApp, certiAppDet, certiApr, certiStdMgr
- **dispatch/** (1화면): dispatchApr
- **empAccMgr/** (1화면): 
- **empContract/** (5화면): empContractCre, empContractEleMgr, empContractMgr 외 2개
- **empPap/** (2화면): empPapHistMgr, empPapResultUpload
- **empRcmd/** (3화면): aiEmpRcmd, aiEmpRcmdMgr, aiEmpRcmdSrchMgr
- **hrmComPopup/** (5화면): appmtConfirmPopup, hrmAcaMajPopup, hrmDigitalSignPopup 외 2개
- **job/** (4화면): JobPsnalAssuranceUserMgr, jobKnowledgePopup, jobPsnalAssuranceMgr, jobQualificationPopup
- **justice/** (2화면): punishMgr, rewardMgr
- **other/** (43화면): allEmpStat, allExepEmpLst, anniversary 외 40개
- **promSimulation/** (6화면): groupingJudg, promJudg, promRecord 외 3개
- **promotion/** (10화면): promEvalMgr, promStdMgr, promTagetAppmt 외 3개
- **psnalEtcMonUpload/** (1화면): 
- **psnalEtcMthUpload/** (1화면): 
- **psnalEtcRateUpload/** (1화면): 
- **psnalEtcUpload/** (1화면): 
- **psnalInfo/** (27화면): psnalAssurance, psnalBasic, psnalBasicInf 외 24개
- **psnalInfoCopy/** (1화면): 
- **psnalInfoUpload/** (1화면): 
- **psnalRecordUpload/** (1화면): 
- **regWarkerStat/** (1화면): 
- **retire/** (9화면): retireApp, retireAppDet, retireApr 외 6개
- **successor/** (5화면): succEmpMgr, succEmpProfile, succKeyOrgMgr 외 2개
- **survey/** (1화면): surveyUserList
- **timeOff/** (3화면): timeOffApp, timeOffApr, timeOffStdMgr
- **unionMgr/** (2화면): productionUnionMgr, unionMgr

## WTM (근태/근무(신규)) — `EHR_HR50/src/main/java/com/hr/wtm/`

- **annualPlan/** (5화면): wtmAnnualPlanAgrApp, wtmAnnualPlanAgrAppDet, wtmAnnualPlanAgrApr 외 2개
- **config/** (11화면): wtmEtcConfigMgr, wtmFormulaMgr, wtmGntCdMgr 외 8개
- **count/** (8화면): wtmDailyWorkMgr, wtmMonthlyCount, wtmMonthlyCountMgr 외 3개
- **request/** (17화면): wtmAlterLeaveAppDet, wtmAttendAppDet, wtmAttendAppUpload 외 8개
- **stats/** (10화면): wtmCustomReport, wtmOrgDailyTimeStats, wtmOrgMonthWorkSta 외 7개
- **workMgr/** (7화면): wtmFlexibleWorkScheduleUpload, wtmShiftSchMgr, wtmShiftSchUpload, wtmWorkCalendar
- **workType/** (3화면): wtmPsnlWorkTypeMgr, wtmPsnlWorkTypeMgrAdmin, wtmWorkTypeMgr
- 🔗 허브: findByCode()(3), getCode()(3), getApplyTotalMinutesByDayType()(2)

## PAP (인사행정/평가) — `EHR_HR50/src/main/java/com/hr/pap/`

- **appCompetency/** (9화면): compAppPeopleMng, compAppPeopleMngdUpload, compAppResult 외 6개
- **appGroupMemMgr/** (1화면): 
- **appMtlPappMemMgr/** (1화면): 
- **appPappMemMgr/** (1화면): 
- **appResultGradeMgr/** (1화면): 
- **config/** (42화면): appClassAssignMgr, appClassMgr, appCompItemCreateMgr 외 37개
- **degreeFeedback/** (2화면): degreeFeedback, degreeFeedbackResult
- **evaMain/** (1화면): main
- **evaluation/** (24화면): app1st2nd, appCoachingApr, appCoachingMgr 외 21개
- **execCompAppMngResultSrh/** (1화면): 
- **execCompAppMngUpload/** (1화면): 
- **intern/** (15화면): internApp, internApp1st2nd, internApp1stApr 외 12개
- **progress/** (18화면): appAddingControl, appAdjStausMng, appCommitteeMgr 외 15개

## SYS (시스템/공통) — `EHR_HR50/src/main/java/com/hr/sys/`

- **alteration/** (5화면): mainMnMgr, mainMuPrg, prgMgr 외 2개
- **code/** (3화면): grpCdMgr, measureCdMgr, zipCdMgr
- **combined/** (2화면): exceptUserMgr, ptrComMgr
- **conv/** (2화면): convColMapMgr, convTabMgr
- **layout/** (2화면): layoutLayer, layoutMgr
- **log/** (6화면): acessLogSht, ifLogSht, interLogMgr 외 3개
- **loginMenu/** (1화면): loginMenuMgr
- **mail/** (1화면): mailSmsMgr
- **other/** (12화면): boardMgr, contactMgr, guideMgr 외 9개
- **project/** (3화면): atnatMgr, hmnrsMgr, meetingLogMgr
- **psnalInfoPop/** (16화면): PsnalJobHist, psnalAssurancePop, psnalBasicPop 외 12개
- **pwrSrch/** (6화면): pwrSrchAdminUser, pwrSrchCdElemtMgr, pwrSrchMgr 외 3개
- **research/** (5화면): researchApp, researchAppMgr, researchMgr 외 2개
- **security/** (20화면): PrivacyActSta, athGrpMenuMgr, authGrpCorpMgr 외 16개
- **system/** (17화면): creQueryMgr, dbItemMgr, dictMgr 외 11개
- **timeline/** (3화면): timeline, timelineMgr, timelinePeopleMgr

## TIM (근태/근무(레거시→WTM 마이그중)) — `EHR_HR50/src/main/java/com/hr/tim/`

- **annual/** (15화면): annualCre, annualHolInq, annualHoliday 외 12개
- **code/** (22화면): closeDayMgr, holidayMgr, holidayOccurStd 외 10개
- **etc/** (10화면): annualYearStats, orgDayTimeStats, orgMonthWorkSta 외 7개
- **month/** (9화면): dailyAbsMgr, dailyWorkMgr, dailyWorkStatus 외 6개
- **psnlWork/** (4화면): psnlCalendar, psnlTimeWorkSta
- **request/** (16화면): bizTripApp, bizTripAppDet, bizTripApr 외 13개
- **schedule/** (23화면): dailyExcWorkTimeMgr, dailyWorkExcMgr, dayWorkTimeMgr 외 20개
- **status/** (1화면): timeCardMgrTeam
- **workApp/** (21화면): excWorkApp, excWorkAppDet, excWorkApr 외 18개
- **workingType/** (3화면): workingTypeApp, workingTypeAppDet, workingTypeApr

## BEN (복리후생) — `EHR_HR50/src/main/java/com/hr/ben/`

- **apply/** (1화면): benApplyUser
- **benefitBasis/** (11화면): accRatioMgr, appBenSabunMgr, empRatioMgr 외 8개
- **buscard/** (3화면): buscardApp, buscardAppDet, buscardApr
- **carAllocate/** (3화면): carAllocateApp, carAllocateApr, carAllocateMgr
- **club/** (11화면): clubAgreeSta, clubApp, clubAppDet 외 8개
- **empInsGradeMgr/** (1화면): 
- **etc/** (2화면): psnalPcMgr, sealMgr
- **famResUpd/** (1화면): 
- **ftestmon/** (3화면): ftestmonApp, ftestmonAppDet, ftestmonApr
- **gift/** (4화면): giftApp, giftAppDet, giftMgr, giftStd
- **golf/** (3화면): golfApp, golfMgr, golfStd
- **health/** (2화면): healthMgr, healthStd
- **healthInsurance/** (5화면): healthInsAddBackMgr, healthInsEmpDivMgr, healthInsEmpMthDataMgr 외 2개
- **loan/** (9화면): loanApp, loanAppDet, loanApr 외 6개
- **longWork/** (2화면): longWorkPersonMgr, longWorkStd
- **medical/** (5화면): medApp, medAppDet, medApr 외 2개
- **meetRoom/** (3화면): meetRoomApp, meetRoomApr, meetRoomMgr
- **occasion/** (4화면): occApp, occAppDet, occApr, occStd
- **ourBenefits/** (2화면): outBenefitsMgr, outBenefitsSta
- **pension/** (4화면): staPenAddBackMgr, staPenEmpMthDataMgr, staPenMgr, staPenUploadMgr
- **psnalPension/** (5화면): psnalPenApp, psnalPenAppDet, psnalPenApr 외 2개
- **reservation/** (3화면): reservationApp, reservationMgr, reservationStd
- **resort/** (8화면): resortApp, resortAppDet, resortApr 외 5개
- **scholarship/** (5화면): schApp, schAppDet, schApr, schStd
- **unempInsurance/** (1화면): empInsMgr

## ORG (조직관리) — `EHR_HR50/src/main/java/com/hr/org/`

- **capacity/** (7화면): orgCapaInfoSta, orgCapaInfoSta2, orgCapaPlanApp 외 4개
- **competency/** (2화면): competencyMgr, competencySchemeMgr
- **job/** (15화면): jobCDPSurvey, jobCDPSurveyMgr, jobDivReportApp 외 12개
- **organization/** (22화면): corpImgReg, corpInfoMgr, hrmEmpHQSta 외 19개

## TRA (교육훈련) — `EHR_HR50/src/main/java/com/hr/tra/`

- **basis/** (10화면): eduContentsMgr, eduCourseMgr, eduEmpStat 외 7개
- **eLearning/** (4화면): eduElApp, eduElAppDet, eduElApr, eduElStd
- **eduRcmd/** (1화면): aiEmpRcmd
- **lectureFee/** (3화면): lectureFeeApp, lectureFeeAppDet, lectureFeeApr
- **lectureRst/** (3화면): lectureRstApp, lectureRstAppDet, lectureRstApr
- **outcome/** (8화면): cyberEduLoad, eduHistoryLst, eduInTypePeopleMgr 외 2개
- **requestApproval/** (9화면): eduApp, eduAppDet, eduApr 외 6개
- **yearEduPlan/** (6화면): yearEduApp, yearEduOrgApp, yearEduOrgAppDet 외 3개

## HRD (인사개발) — `EHR_HR50/src/main/java/com/hr/hrd/`

- **applicant/** (1화면): qualifiedApplicant
- **code/** (8화면): careerPathPreView, careerTarget, cdpManage 외 5개
- **core/** (2화면): coreMgr, coreStats
- **core2/** (4화면): coreOrgMgr, coreRcmd, coreSelect, coreState
- **incoming/** (3화면): incomingMgr, incomingReg, incomingStats
- **pubc/** (5화면): pubcApp, pubcAppDet, pubcApr 외 2개
- **selfDevelopment/** (7화면): selfDevelopmentAdminStat, selfDevelopmentApp, selfDevelopmentApr 외 4개
- **selfRating/** (4화면): selfRatingApproval, selfRatingRegist, selfRatingStatistics
- **selfReport/** (5화면): SelfReportRegStatistics, SelfReportRegist
- **statistics/** (8화면): careerPathWorkAssignStat, hopeWorkAssignState, successorState 외 4개
- **trmCdMgr/** (1화면): 
- **trmManage/** (1화면): 

## HRI (인사정보/결재) — `EHR_HR50/src/main/java/com/hr/hri/`

- **applicationBasis/** (3화면): appCodeMgr, appPathReg, bizAppAuthor
- **applyApproval/** (12화면): AppProgressLst, appAfterLst, appAllLst 외 9개
- **commonApproval/** (5화면): comApp, comAppDet, comAppFormMgr 외 2개
- **partMgr/** (3화면): partMgrApp, partMgrAppDet, partMgrApr

## DB 스키마 참조

위치: `db-schema/{MODULE}/`

| DB접두사 | 모듈 | 참조파일 |
|---------|------|---------|
| TCP* | CPN(급여) | `db-schema/CPN/tables_doc.sql` |
| THR* | HRM(인사) | `db-schema/HRM/tables_doc.sql` |
| TSY* | SYS(시스템) | `db-schema/SYS/tables_doc.sql` |
| TTI* | TIM(근태) | `db-schema/TIM/tables_doc.sql` |
| TWT* | WTM(근무) | `db-schema/WTM/tables_doc.sql` |
| TBE* | BEN(복리) | `db-schema/BEN/tables_doc.sql` |
| TOR* | ORG(조직) | `db-schema/ORG/tables_doc.sql` |
| TPA* | PAP(평가) | `db-schema/PAP/tables_doc.sql` |
| TTR* | TRA(교육) | `db-schema/TRN/tables_doc.sql` |
| TYE* | YEA(연말정산) | `db-schema/YEA/tables_doc.sql` |

프로시저/함수: `db-schema/{MODULE}/procedures.sql`, `functions.sql`
패키지: `db-schema/PKG/package_spec.sql`, `package_body.sql`