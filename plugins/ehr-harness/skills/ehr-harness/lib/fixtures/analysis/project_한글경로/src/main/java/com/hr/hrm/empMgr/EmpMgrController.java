@Controller
@RequestMapping(value="/EmpMgr.do")
public class EmpMgrController {
    void handle(HttpSession session) {
        Object e = session.getAttribute("ssnEnterCd");
        Object s = session.getAttribute("ssnSabun");
        Object t = session.getAttribute("ssnSearchType");
    }
}
