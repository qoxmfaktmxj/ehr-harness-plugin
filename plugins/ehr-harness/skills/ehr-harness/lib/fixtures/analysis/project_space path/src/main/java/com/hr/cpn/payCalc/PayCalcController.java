@Controller
@RequestMapping(value="/PayCalc.do")
public class PayCalcController {
    void handle(HttpSession session) {
        Object e = session.getAttribute("ssnEnterCd");
        Object s = session.getAttribute("ssnSabun");
        Object g = session.getAttribute("ssnGrpCd");
    }
}
