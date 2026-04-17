# EHR4 코드맵 (참조 예시 통합)

> EHR_NG, EHR_SY, OPTI_UNID 3개 예시 프로젝트의 `*Controller.java` 위치를 병합한 스냅샷. EHR4 는 표준 기본 패키지가 없으므로 이 맵은 **fallback 참조** — 실제 하네스 생성 시 `lib/gen-code-map.js` 가 대상 프로젝트의 CODE_MAP 을 런타임 생성하며, 그 단계가 실패할 때만 이 파일이 복사된다.
> 출처 태그: `[N]` EHR_NG · `[S]` EHR_SY · `[O]` OPTI_UNID. 여러 글자 결합 = 복수 프로젝트에 존재.
> 생성일: 2026-04-17

## BEN (복리후생) — `src/com/hr/ben/` (291화면)

- **(루트 직속)** (4화면): empInsEmpMthDataMgr [S], empInsGradeMgr [NS], famResUpd [NS] 외 1개
- **benefitBasis/** (16화면): accRatioMgr [NOS], appBenSabunMgr [NOS], comRatioMgr [O] 외 13개
- **bisCard/** (2화면): bisCardMgr [O], bisCardRegMgr [O]
- **buscard/** (3화면): buscardApp [NS], buscardAppDet [NS], buscardApr [NS]
- **carAllocate/** (1화면): carAllocateApr [NS]
- **carCost/** (3화면): carCostApp [N], carCostAppDet [N], carCostApr [N]
- **childSubsidy/** (3화면): childSubsidyFeeStat [S], childSubsidyMgr [S], childSubsidyStat [S]
- **club/** (17화면): clubAgreeSta [NS], clubApp [NOS], clubAppDet [NOS] 외 14개
- **clubSupport/** (3화면): clubSupportApp [N], clubSupportAppDet [N], clubSupportApr [N]
- **common/** (1화면): benQuery [O]
- **condo/** (3화면): condoAppUpload [O], condoCalendar [O], condoMgr [O]
- **corporate/** (3화면): corporateApp [N], corporateAppApr [N], corporateAppDet [N]
- **dream/** (3화면): dreamSaveMgr [O], dreamSavePaySta [O], dreamSaveSta [O]
- **employee/** (3화면): emploayeeCardApp [N], emploayeeCardApr [N], employeeCardAppDet [N]
- **employeeStock/** (17화면): empStockAllotInfoLst [O], empStockAllotMgr [O], empStockIssueMgr [O] 외 14개
- **etc/** (2화면): psnalPcMgr [NS], sealMgr [NS]
- **famAllow/** (3화면): famAllowApp [S], famAllowAppDet [S], famAllowApr [S]
- **familyAllowance/** (3화면): familyAllowanceApp [N], familyAllowanceAppDet [N], familyAllowanceApr [N]
- **food/** (5화면): foodMgr [O], foodPayMgr [O], foodPerApp [O] 외 2개
- **foodTicket/** (2화면): foodShopMgr [O], foodTicketMgr [O]
- **fosterCare/** (6화면): dayCareCenterStd [N], fosterCareApp [N], fosterCareAppDet [N] 외 3개
- **ftestmon/** (3화면): ftestmonApp [NS], ftestmonAppDet [NS], ftestmonApr [NS]
- **gcard/** (4화면): gCardAllocationMgr [O], gCardBokjiMgr [O], gcardMgr [O] 외 1개
- **gift/** (4화면): giftApp [NS], giftAppDet [NS], giftMgr [NS] 외 1개
- **globalVisit/** (5화면): globalApp [O], globalAppDet [O], globalApr [O] 외 2개
- **golf/** (3화면): golfApp [NS], golfMgr [NS], golfStd [NS]
- **groupPrize/** (3화면): groupPrizeApp [N], groupPrizeAppDet [N], groupPrizeApr [N]
- **health/** (6화면): compHealthApp [N], compHealthApr [N], compHealthAprList [N] 외 3개
- **healthInsurance/** (17화면): healthInsAddBackMgr [NOS], healthInsBasic [O], healthInsDed [O] 외 14개
- **hiringRequest/** (3화면): hiringRequestApp [N], hiringRequestAppDet [N], hiringRequestApr [N]
- **hotel/** (1화면): hotelMgr [O]
- **house/** (4화면): houseCheckMgr [O], houseExEmpMgr [O], housePayMgr [O] 외 1개
- **houseSubsidy/** (3화면): houseSubsidyApp [N], houseSubsidyAppDet [N], houseSubsidyApr [N]
- **induInsurance/** (5화면): empInduInsYyCalcMgr [O], induInsMgr [O], induInsMthCalcMgr [O] 외 2개
- **infantEdu/** (3화면): infantEduApp [N], infantEduAppDet [N], infantEduApr [N]
- **livingSubsidy/** (4화면): livSubApp [O], livSubAppDet [O], livSubApr [O] 외 1개
- **loan/** (13화면): loanApp [NOS], loanAppDet [NOS], loanApr [NOS] 외 10개
- **longWork/** (3화면): longWorkMailLst [O], longWorkPayLst [O], longWorkStd [O]
- **marriage/** (3화면): marriageApp [O], marriageAppDet [O], marriageApr [O]
- **medical/** (6화면): medApp [NOS], medAppDet [NOS], medApr [NOS] 외 3개
- **medicalExam/** (8화면): medExamApp [O], medExamCheckStd [O], medExamCounselMgr [O] 외 5개
- **meetRoom/** (1화면): meetRoomApr [NS]
- **mobile/** (1화면): mobileMgr [O]
- **move/** (3화면): moveApp [O], moveAppDet [O], moveApr [O]
- **mutualJoin/** (3화면): mutualJoinApp [N], mutualJoinAppDet [N], mutualJoinApr [N]
- **nojo/** (3화면): nojoMgr [O], nojoPayLst [O], nojoPayMgr [O]
- **occasion/** (8화면): occApp [NOS], occAppDet [NOS], occApr [NOS] 외 5개
- **optionalWelfare/** (5화면): optionalWelfareAppr [O], optionalWelfareLst [O], optionalWelfareReq [O] 외 2개
- **other/** (1화면): comSaleLst [O]
- **parkingCard/** (3화면): parkingCardApp [N], parkingCardApr [N], parkingCardDet [N]
- **pension/** (12화면): staPenAddBackMgr [NOS], staPenBasic [O], staPenDed [O] 외 9개
- **postal/** (3화면): postalApp [N], postalAppApr [N], postalAppDet [N]
- **psnalPension/** (5화면): psnalPenApp [NS], psnalPenAppDet [NS], psnalPenApr [NS] 외 2개
- **reservation/** (3화면): reservationApp [NS], reservationMgr [NS], reservationStd [NS]
- **resort/** (8화면): resortApp [NS], resortAppDet [NS], resortApr [NS] 외 5개
- **scholarship/** (6화면): schApp [NOS], schAppDet [NOS], schApr [NOS] 외 3개
- **stock/** (3화면): stockMgr [O], stockPerSta [O], stockPerUseSta [O]
- **transferMovein/** (3화면): tranMoveApp [O], tranMoveAppDet [O], tranMoveApr [O]
- **transportation/** (4화면): tranExpApp [O], tranExpAppDet [O], tranExpApr [O] 외 1개
- **unempInsurance/** (3화면): empInsMgr [NOS], empInsMthCalcMgr [O], empInsMthMonMgr [O]
- **uniform/** (5화면): uniformApp [N], uniformAppDet [N], uniformAppSrch [N] 외 2개
- **warrant/** (4화면): warrantGiveSta [O], warrantMailLst [O], warrantMgr [O] 외 1개

## COMMON (공통 유틸) — `src/com/hr/common/` (64화면)

- **(루트 직속)** (20화면): code [NOS], com [NS], commonTabInfo [NOS] 외 17개
- **popup/** (35화면): benComPopup [NOS], childcareFamPopup [NS], commonCodeLayer [NS] 외 32개
- **upload/** (4화면): fileUpload [NOS], imageUpload [NOS], imageUploadTorg903 [NOS] 외 1개
- **util/** (5화면): api [NS], brityApi [S], ftp [NS] 외 2개

## CPN (급여/임금) — `src/com/hr/cpn/` (292화면)

- **basisConfig/** (26화면): annualIncomeStdMgr [O], appCpnSabunMgr [N], contractCre [NOS] 외 23개
- **common/** (1화면): cpnQuery [NOS]
- **daylaborPayMgr/** (1화면): daylaborPayMgr [S]
- **element/** (8화면): allowEleMgr [NOS], allowElePptMgr [NOS], dedEleMgr [NOS] 외 5개
- **ifrs/** (2화면): ifrsUploadCCSta [O], ifrsUploadMgr [O]
- **incentive/** (7화면): incBasicMgr [O], incDegreMgr [O], incEtcMgr [O] 외 4개
- **meritIncrease/** (4화면): miCalMgr [S], miPayZoneMgr [S], miRateMgr [S] 외 1개
- **origintax/** (20화면): comIncomeCCStd [O], comIncomeEmpStd [O], earnComDataConfSta [O] 외 17개
- **payApp/** (12화면): deptPartPayApp [NS], deptPartPayAppDet [NS], deptPartPayAppMgr [NS] 외 9개
- **payCalculate/** (37화면): annualCalcCre [O], bankTransferData [O], bonCalcCre [O] 외 34개
- **payReport/** (39화면): beforeYearFileDown [NS], empAccCalcSta [O], empIndicatorSta [O] 외 36개
- **payRetire/** (40화면): annualIncomeTable [NS], nujinDateMgr [NS], retConnectPay [NS] 외 37개
- **payRetroact/** (6화면): retroCalcCre [NOS], retroCalcWorkSta [NOS], retroEleSetMgr [NOS] 외 3개
- **paySimulation/** (7화면): outPeoplePlan [N], payAnalyzeStaff [O], payBudget [O] 외 4개
- **pension/** (3화면): paymentApp [O], paymentAppDet [O], paymentApr [O]
- **performanceCompensation/** (10화면): payAiCalculateMgr [N], payAiRateStd [N], payMeritGroupMgr [N] 외 7개
- **personalBasis/** (2화면): attachList [N], attachMgr [NOS]
- **personalPay/** (30화면): accMgr [NOS], allowChangeOrgApp [N], allowChangeOrgAppDet [N] 외 27개
- **yearEnd/** (26화면): befComMgr [O], creaditCardBrkDownMgr [O], dedErrChkMgr [O] 외 23개
- **yearPay/** (10화면): yearPayAddPitchMgr [O], yearPayAllMgr [O], yearPayAttMgr [O] 외 7개
- **youthIncome/** (1화면): youthIncomeExemption [NOS]

## EIS (경영정보) — `src/com/hr/eis/` (33화면)

- **(루트 직속)** (2화면): compareEmpNg [N], keywordSearch [S]
- **compareEmp/** (1화면): compareEmp [NS]
- **empSituation/** (18화면): careerCntGrpSta [NS], cmpDivGrpSta [NS], empEmpHisSta [NOS] 외 15개
- **groupEmpSituation/** (2화면): empRetHisSta [NS], empRetHisSta2 [NS]
- **hrm/** (6화면): conditionByEmpSta [S], empEmpSta [NOS], monthlyEmpSta [S] 외 3개
- **perOrgSta/** (3화면): perOrgHolAttSta [O], perOrgHolAttSta2 [O], perOrgYcSta [O]
- **specificEmp/** (1화면): specificEmpSrch [NOS]

## EST (기초설정) — `src/com/hr/est/` (7화면)

- **basicConfig/** (7화면): estBasicMgr [O], estComCodeMgr [O], estComStateMgr [O] 외 4개

## FTM (휴일근무/연장근무) — `src/com/hr/ftm/` (7화면)

- **holidayWork/** (3화면): holidayWorkApp [O], holidayWorkAppDet [O], holidayWorkApr [O]
- **overTime/** (4화면): overTimeApp [O], overTimeAppDet [O], overTimeApr [O] 외 1개

## HRD (CDP/경력관리) — `src/com/hr/hrd/` (30화면)

- **(루트 직속)** (2화면): trmCdMgr [S], trmManage [S]
- **applicant/** (1화면): qualifiedApplicant [S]
- **code/** (8화면): careerPathPreView [S], careerTarget [S], cdpManage [S] 외 5개
- **selfDevelopment/** (7화면): selfDevelopmentAdminStat [S], selfDevelopmentApp [S], selfDevelopmentApr [S] 외 4개
- **selfRating/** (3화면): selfRatingApproval [S], selfRatingRegist [S], selfRatingStatistics [S]
- **selfReport/** (2화면): SelfReportRegist [S], SelfReportRegStatistics [S]
- **statistics/** (7화면): careerPathWorkAssignStat [S], hopeWorkAssignState [S], successorState [S] 외 4개

## HRI (인사정보/조회) — `src/com/hr/hri/` (18화면)

- **(루트 직속)** (1화면): appAdminMgr [S]
- **applicationBasis/** (3화면): appCodeMgr [NOS], appPathReg [NOS], bizAppAuthor [NS]
- **applyApproval/** (9화면): appAfterLst [NOS], appBeforeLst [NOS], appBoxLst [NOS] 외 6개
- **commonApproval/** (5화면): comApp [NS], comAppDet [NS], comAppFormMgr [NS] 외 2개

## HRM (인사관리) — `src/com/hr/hrm/` (277화면)

- **(루트 직속)** (11화면): empAccMgr [NS], empPrivacy [S], psnalEtcMonUpload [NS] 외 8개
- **appmt/** (14화면): appmtHistoryMgr [NOS], appmtTimelineSrch [NS], execAppmt [NOS] 외 11개
- **appmtBasic/** (9화면): appmtApp [N], appmtAppDet [N], appmtApr [N] 외 6개
- **certificate/** (4화면): certiApp [NOS], certiAppDet [NOS], certiApr [NOS] 외 1개
- **change/** (3화면): changeOrgApp [S], changeOrgAppDet [S], changeOrgMgr [S]
- **comRecom/** (3화면): comRecomApp [O], comRecomAppDet [O], comRecomMgr [O]
- **coreTalent/** (1화면): coreTalentMgr [O]
- **cost/** (1화면): costEmpMgr [O]
- **empContract/** (5화면): empContractCre [NS], empContractCreVw [S], empContractEleMgr [NS] 외 2개
- **empPap/** (2화면): empPapHistMgr [NS], empPapResultUpload [NS]
- **empPlan/** (5화면): empMngPlanLst [O], empMngRealLst [O], empPlanMgr [O] 외 2개
- **foreignSenMgr/** (3화면): foreignSenMgr [S], foreignSenStatus [S], foreignSenStdMgr [S]
- **hrmComPopup/** (6화면): appmtConfirmPopup [NOS], hrmAcaMajPopup [NOS], hrmDigitalSignPopup [NOS] 외 3개
- **indit/** (5화면): inditCBonusMgr [O], inditFctMgr [O], inditRstSta [O] 외 2개
- **inst/** (4화면): instClfcMgr [O], instEnrMgr [O], instLst [O] 외 1개
- **job/** (7화면): jobChgApp [O], jobChgAppDet [O], jobChgApr [O] 외 4개
- **justice/** (5화면): punishMgr [NS], rewardApp [N], rewardAppDet [N] 외 2개
- **language/** (1화면): languageMgr [O]
- **ob/** (1화면): obMgr [O]
- **oei/** (1화면): oeiTargetMgr [N]
- **officer/** (2화면): officerStaLst [O], officerStaMgr [O]
- **other/** (53화면): admissionCongratuLst [N], allEmpStat [NS], anniversary [NS] 외 50개
- **ovsCorp/** (5화면): ovsCorpAmtMgr [O], ovsCorpIdacMgr [O], ovsCorpInsuMgr [O] 외 2개
- **process/** (2화면): processApp [O], processAppDet [O]
- **processItem/** (1화면): processItemMgr [O]
- **promotion/** (21화면): careerEmpLst [O], managerRecommendApp [O], managerRecommendApr [O] 외 18개
- **psnalInfo/** (61화면): psnalAdmitCareer [S], psnalApprentice [S], psnalAssurance [NOS] 외 58개
- **rcrReq/** (3화면): rcrReqApp [O], rcrReqAppDet [O], rcrReqAppMgr [O]
- **retire/** (8화면): retireApp [NOS], retireAppDet [NOS], retireApr [NOS] 외 5개
- **retireAgree/** (3화면): retireAgreeApp [S], retireAgreeApr [S], retireAgreeDet [S]
- **reward/** (8화면): punishTargetMgr [O], rewardStdMgr [O], rewardTargetMgr [O] 외 5개
- **supervisor/** (1화면): supervisorMgr [O]
- **timeOff/** (5화면): timeOffApp [NOS], timeOffApr [NOS], timeOffExtApp [O] 외 2개
- **union/** (3화면): unionJikMgr [O], unionLcaMgr [O], unionMemberMgr [O]
- **unionMgr/** (2화면): productionUnionMgr [NS], unionMgr [NS]
- **visa/** (4화면): visaApp [O], visaAppDet [O], visaAppMgr [O] 외 1개
- **workingType/** (4화면): workingTypeApp [S], workingTypeAppDet [S], workingTypeApr [S] 외 1개

## KMS (지식관리) — `src/com/hr/kms/` (1화면)

- **(루트 직속)** (1화면): board [NOS]

## MAIN (메인) — `src/com/hr/main/` (6화면)

- **(루트 직속)** (6화면): filter [NS], link [NOS], login [NOS] 외 3개

## MNT (멘토링) — `src/com/hr/mnt/` (14화면)

- **mentoring/** (14화면): mntActionPlanApp [O], mntActionPlanAppDet [O], mntActivitiesFinalRepApp [O] 외 11개

## ORG (조직관리) — `src/com/hr/org/` (59화면)

- **capacity/** (6화면): orgCapaInfoSta [NOS], orgCapaPlanApp [NOS], orgCapaPlanAppDet [NOS] 외 3개
- **competency/** (4화면): competencyActMgr [O], competencyMgr [NOS], competencySchemeMgr [NOS] 외 1개
- **job/** (17화면): jikmooMgr [O], jobCDPSurvey [NS], jobCDPSurveyMgr [NS] 외 14개
- **org/** (3화면): orgRnrApp [O], orgRnrAppDet [O], orgRnrMgr [O]
- **organization/** (29화면): corpImgReg [NOS], corpInfoMgr [NOS], hrmEmpHQSta [NS] 외 26개

## PAP (성과/평가) — `src/com/hr/pap/` (255화면)

- **(루트 직속)** (14화면): appAppStatusMgr [S], appFanlTargetUpload [N], appGroupMemMgr [NS] 외 11개
- **annualSalary/** (3화면): annualSalaryEmployeeMngr [NOS], annualSalaryIncreBasicMngr [NOS], annualSalaryPeopleMngr [NOS]
- **blue/** (25화면): blueAppAnalysisLst [O], blueAppCompAdjustMgr [O], blueAppCompFinal2Mgr [O] 외 22개
- **chief/** (11화면): chiefAppAdjustMgr [O], chiefAppFeedBackLst [O], chiefAppItemMgr [O] 외 8개
- **config/** (43화면): achiAppMgr [S], appChgOrg [N], appClassAssignMgr [NOS] 외 40개
- **contract/** (3화면): contractApp1st2nd [S], contractAppItemMngr [S], contractAppPeopleMngr [S]
- **evaluation/** (26화면): app1st2nd [NOS], app1st2ndRef [N], app1stDetail [S] 외 23개
- **imwon/** (5화면): appSabunImwonMgr [S], appSabunImwonPeopleMng [S], appSabunImwonRate [S] 외 2개
- **intern/** (10화면): internApp [NOS], internApp1st2nd [NOS], internApp1stApr [NOS] 외 7개
- **memtoring/** (2화면): memtoringIdMgr [NOS], memtoringMgr [NOS]
- **mentoring/** (3화면): mentoringIdMgr [NOS], mentoringMgr [NOS], mentoringSta [NOS]
- **orgEvaluation/** (11화면): mboAppOrgResultMgr [NOS], mboCompanyMgr [NOS], mboLst [NOS] 외 8개
- **probation/** (6화면): probationApp [N], probationAppDet [N], probationAppItemMngr [N] 외 3개
- **production/** (13화면): appProd1st2nd [S], appProdAddingControl [S], appProdGroupMgr [S] 외 10개
- **progress/** (24화면): appAddingControl [NOS], appAdjStausMng [NOS], appCommitteeMgr [NOS] 외 21개
- **promotion/** (7화면): promAppRateStd [NOS], promIdMgr [NOS], promPointMgr [NOS] 외 4개
- **replacement/** (2화면): keyPositionStd [NOS], replacementLstMgr [NOS]
- **sales/** (14화면): appSalesAddingControl [S], appSalesApp1st [S], appSalesAppDetail [S] 외 11개
- **training/** (3화면): trainingApp1st2nd [S], trainingAppItemMngr [S], trainingAppPeopleMngr [S]
- **white/** (30화면): whiteAppAnalysisLst [O], whiteAppCompAdjustMgr [O], whiteAppCompAdviceMgr [O] 외 27개

## SAMPLE (샘플) — `src/com/hr/sample/` (1화면)

- **(루트 직속)** (1화면): sample [NOS]

## STF (채용) — `src/com/hr/stf/` (79화면)

- **basis/** (13화면): recBasisInfoMgr [O], recCapacityMgr [O], recMailMgr [O] 외 10개
- **comRec/** (3화면): comRecApp [O], comRecApr [O], comRecSchMgr [O]
- **common/** (14화면): applicantBasicDet [O], applicantCarDet [O], applicantFamDet [O] 외 11개
- **notice/** (3화면): recFaqMgr [O], recNoticeMgr [O], recQuestionMgr [O]
- **recommend/** (3화면): comRcmApp [O], comRcmAppDet [O], comRcmApr [O]
- **screen/** (43화면): applicantBasis [O], applicantFamily [O], applicantFlyCareer [O] 외 40개

## SYS (시스템관리) — `src/com/hr/sys/` (100화면)

- **(루트 직속)** (1화면): psnalInfoPop [NOS]
- **alteration/** (4화면): mainMnMgr [NOS], mainMuPrg [NOS], prgMgr [NOS] 외 1개
- **code/** (5화면): grpCdMapMgr [S], grpCdMgr [NOS], measureCdMgr [NOS] 외 2개
- **combined/** (2화면): exceptUserMgr [NOS], ptrComMgr [NOS]
- **conv/** (2화면): convColMapMgr [NS], convTabMgr [NS]
- **log/** (7화면): acessLogSht [NOS], ifLogSht [NOS], interLogMgr [NOS] 외 4개
- **loginMenu/** (1화면): loginMenuMgr [NS]
- **mail/** (1화면): mailSmsMgr [NS]
- **other/** (10화면): boardMgr [NOS], contactMgr [NOS], guideMgr [NOS] 외 7개
- **psnalInfoPop/** (15화면): psnalAssurancePop [NOS], psnalBasicPop [NOS], psnalCareerPop [NOS] 외 12개
- **pwrSrch/** (6화면): pwrSrchAdminUser [NOS], pwrSrchCdElemtMgr [NOS], pwrSrchMgr [NOS] 외 3개
- **rem/** (4화면): code [S], empSearch [S], interfaceInfo [S] 외 1개
- **research/** (5화면): researchApp [NOS], researchAppMgr [S], researchMgr [NOS] 외 2개
- **security/** (20화면): athGrpMenuMgr [NOS], authGrpCorpMgr [NS], authGrpUserMgr [NOS] 외 17개
- **system/** (17화면): apiKeyMgr [N], creQueryMgr [NS], dbItemMgr [NOS] 외 14개

## TEMPLATE (템플릿) — `src/com/hr/template/` (1화면)

- **(루트 직속)** (1화면): template [O]

## TIM (근태관리) — `src/com/hr/tim/` (289화면)

- **addedHours/** (6화면): addedHoursAppr [O], addedHoursPlanReq [O], addedHoursPlanReqDet [O] 외 3개
- **annual/** (21화면): annualCalcu [O], annualCompare [S], annualCre [NOS] 외 18개
- **annualRecmnd/** (4화면): annualRecmndLst [O], annualRecmndMgr [O], annualRecmndPnl [O] 외 1개
- **closePay/** (1화면): closePayMgr [O]
- **code/** (26화면): closeDayMgr [NOS], holidayMgr [NOS], holidayOccurStd [NOS] 외 23개
- **daily/** (1화면): dailyWorkCount [N]
- **etc/** (34화면): annualYearRate [S], annualYearRateSub [S], annualYearStats [NS] 외 31개
- **holWork/** (3화면): holWorkApp [O], holWorkAppDet [O], holWorkApr [O]
- **inout/** (2화면): inoutTimeInq [O], inoutTimeMgr [O]
- **interfaceGnt/** (1화면): interfaceGntData [O]
- **month/** (29화면): dailyAbsMgr [NS], dailyWorkMgr [NS], dailyWorkSafeSta [N] 외 26개
- **org/** (1화면): orgGntMgr [O]
- **overTime/** (11화면): changeExpApp [O], changeExpAppDet [O], trafficExpAdd [O] 외 8개
- **psnlWork/** (8화면): gatePassLst [O], psnlAnnualSta [O], psnlAnnualStaUser [O] 외 5개
- **reqWork/** (6화면): reqWorkApp [O], reqWorkAppDet [O], reqWorkApr [O] 외 3개
- **request/** (57화면): bizTripApp [NS], bizTripAppDet [NS], bizTripApr [NS] 외 54개
- **schedule/** (38화면): amShortenWorkPayPreservation [S], dailyExcWorkTimeMgr [NS], dailyWorkExcMgr [NOS] 외 35개
- **status/** (1화면): timeCardMgrTeam [NS]
- **workApp/** (39화면): excWorkApp [NS], excWorkAppDet [NS], excWorkApr [NS] 외 36개

## TRA (교육훈련) — `src/com/hr/tra/` (116화면)

- **appCompetency/** (10화면): CompAppItemResult [O], CompAppPeopleMng [O], CompAppPeopleMngdUpload [O] 외 7개
- **basis/** (22화면): eduAttendMgr [O], eduBudgetLocationMgr [O], eduBudgetMng [O] 외 19개
- **club/** (6화면): eduClubApp [O], eduClubAppDet [O], eduClubApr [O] 외 3개
- **eLearning/** (4화면): eduElApp [NS], eduElAppDet [NS], eduElApr [NS] 외 1개
- **inside/** (3화면): inEduApp [O], inEduApr [O], inEduTargetMgr [O]
- **jobLicense/** (6화면): jobLicenseApp [O], jobLicenseAppDet [O], jobLicenseApr [O] 외 3개
- **lectureFee/** (3화면): lectureFeeApp [NS], lectureFeeAppDet [NS], lectureFeeApr [NS]
- **lectureRst/** (3화면): lectureRstApp [NS], lectureRstAppDet [NS], lectureRstApr [NS]
- **outcome/** (24화면): certiList [O], cSalesCertify [O], cyberEduLoad [NOS] 외 21개
- **plan/** (6화면): eduPlanApp [O], eduPlanAppDet [O], eduPlanApr [O] 외 3개
- **requestApproval/** (16화면): eduApp [NOS], eduAppDet [NOS], eduApr [NOS] 외 13개
- **self/** (3화면): eduSelfApp [O], eduSelfAppDet [O], eduSelfApr [O]
- **task/** (3화면): eduTaskMgr [O], eduTaskPeopleMgr [O], eduTaskSta [O]
- **yearEduPlan/** (7화면): yearEduApp [NS], yearEduOrgApp [NS], yearEduOrgAppDet [NS] 외 4개

---

## 프로젝트별 수치

| 프로젝트 | 모듈 수 | Controller 총개수 |
|----------|---------|--------------------|
| EHR_NG | 14 | 988 |
| EHR_SY | 15 | 1052 |
| OPTI_UNID | 19 | 1217 |
