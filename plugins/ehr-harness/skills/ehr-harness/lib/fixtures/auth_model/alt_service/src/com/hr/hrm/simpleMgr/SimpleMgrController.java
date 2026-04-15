@Controller
public class SimpleMgrController {
    void example(HttpSession session) {
        Object e = session.getAttribute("ssnEnterCd");
    }
}
