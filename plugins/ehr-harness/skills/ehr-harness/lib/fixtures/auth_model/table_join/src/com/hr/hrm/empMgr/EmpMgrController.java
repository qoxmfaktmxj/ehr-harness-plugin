@Controller
@RequestMapping(value="/EmpMgr.do")
public class EmpMgrController {
    void example(HttpSession session) {
        Object e = session.getAttribute("ssnEnterCd");
        Object s = session.getAttribute("ssnSabun");
    }
}
