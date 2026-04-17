@Controller
public class VacationAppController {
    @Autowired
    private AuthTableService authTableService;

    void example(HttpSession session) {
        Object e = session.getAttribute("ssnEnterCd");
        Object s = session.getAttribute("ssnSabun");
        Object t = session.getAttribute("ssnSearchType");
    }
}
