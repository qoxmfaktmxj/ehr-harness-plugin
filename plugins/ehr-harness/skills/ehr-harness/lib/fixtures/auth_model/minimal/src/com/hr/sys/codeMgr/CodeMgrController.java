@Controller
@RequestMapping(value="/CodeMgr.do")
public class CodeMgrController {
    void example(HttpSession session) {
        Object e = session.getAttribute("ssnEnterCd");
        Object s = session.getAttribute("ssnSabun");
    }
}
