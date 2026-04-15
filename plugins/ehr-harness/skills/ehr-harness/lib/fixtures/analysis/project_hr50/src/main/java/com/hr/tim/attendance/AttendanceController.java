@Controller
@RequestMapping(value="/Attendance.do")
public class AttendanceController {
    void handle(HttpSession session) {
        Object e = session.getAttribute("ssnEnterCd");
        Object s = session.getAttribute("ssnSabun");
    }
}
