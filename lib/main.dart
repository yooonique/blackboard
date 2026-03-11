import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '지필평가 시험 시간표',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
        ),
      ),
      home: const ExamBoardScreen(),
    );
  }
}

// ─────────────────────────────────────────────
// 데이터 모델
// ─────────────────────────────────────────────

class ExamPeriod {
  String period;
  String time;
  String subject;
  ExamPeriod({required this.period, required this.time, required this.subject});

  Map<String, dynamic> toJson() => {
    'period': period,
    'time': time,
    'subject': subject,
  };

  factory ExamPeriod.fromJson(Map<String, dynamic> j) => ExamPeriod(
    period: j['period'] as String,
    time: j['time'] as String,
    subject: j['subject'] as String,
  );
}

// ─────────────────────────────────────────────
// 기본값 상수
// ─────────────────────────────────────────────
class AppDefaults {
  static const String adminPassword = '0000';

  static List<ExamPeriod> get examPeriods => [
    ExamPeriod(period: '1교시', time: '09:00 ~ 09:50', subject: '지구과학1'),
    ExamPeriod(period: '2교시', time: '10:10 ~ 11:00', subject: '자  습'),
    ExamPeriod(period: '3교시', time: '11:20 ~ 12:10', subject: '국  어'),
  ];

  static List<Map<String, dynamic>> get noticeSections => [
    {
      'title': '시험 전',
      'items': [
        {'text': '시험 전, 담임 선생님께 핸드폰 및 스마트 기기 제출', 'color': 'white', 'bold': false},
        {'text': '전자기기를 포함한 가방 속 모든 물건은 가방에 넣어 복도로 내놓기', 'color': 'white', 'bold': false},
        {'text': '옷걸이(행거 포함) 및 분리수거함은 복도로 이동', 'color': 'white', 'bold': false},
        {'text': '학급 게시판 게시물을 모두 정리할 것(칠판에 부착된 모든 유인물 수거)', 'color': 'white', 'bold': false},
        {'text': '화장실은 쉬는 시간에 이용하고 시험 시작 5분 전 입실', 'color': 'white', 'bold': false},
        {'text': '시험 전 책상 위에는 필기도구(컴퓨터용 사인펜, 수정테이프, 검은 볼펜, 연필, 지우개)만 놓을 것', 'color': 'white', 'bold': false},
        {'text': '담임나 방서 등 감독 교사에게 반드시 확인 절차를 거칠 것', 'color': 'red', 'bold': true},
        {'text': '여분의 필기구 준비', 'color': 'white', 'bold': false},
        {'text': '시험이 시작되면 주변 학생들과 대화 금지', 'color': 'white', 'bold': false},
      ],
    },
    {
      'title': '시험 중',
      'items': [
        {'text': '시험지 인쇄 상태, 매수 확인 후 성명, 과목, 수험번호 표기', 'color': 'white', 'bold': false},
        {'text': '선택형 답란은 반드시 검은색 컴퓨터용 수성사인펜 사용할 것', 'color': 'white', 'bold': false},
        {'text': '예비마킹 금지, 수정테이프 사용 가능', 'color': 'cyan', 'bold': false},
        {'text': '서답형 답란은 반드시 검은색 볼펜 사용', 'color': 'white', 'bold': false},
        {'text': '연필(샤프) 금지, 수정테이프 사용 불가', 'color': 'cyan', 'bold': false},
        {'text': '서답형 답 기입 시 글씨를 또박또박 써서 채점 시 불이익이 없도록 할 것', 'color': 'white', 'bold': false},
        {'text': '답안 반드시 해당 문항 칸에 작성', 'color': 'cyan', 'bold': false},
        {'text': '시험 종료 10분 전입니다! 종이 들으면 늦어도 OMR 답안지 표기', 'color': 'white', 'bold': false},
        {'text': '시험 종료 종이 올리면 절대 마킹 불가(손을 책상 아래로)', 'color': 'white', 'bold': false},
        {'text': '부정행위 적발 시 0점 처리', 'color': 'white', 'bold': false},
      ],
    },
    {
      'title': '시험 후',
      'items': [
        {'text': '종이를 올리면 답안지 제출(이후 수정 불가!)', 'color': 'white', 'bold': false},
        {'text': '감독 교사의 퇴실 지시 후 퇴실 가능', 'color': 'white', 'bold': false},
      ],
    },
  ];
}

// ─────────────────────────────────────────────
// SharedPreferences 저장소
// ─────────────────────────────────────────────
class AppStorage {
  static const _keyExamNameFontSz= 'exam_name_font_size';
  static const _keyExamName      = 'exam_name';
  static const _keyExamPeriods   = 'exam_periods';
  static const _keyNotices       = 'notice_sections';
  static const _keyExamTitle     = 'exam_title';
  static const _keyIsDateAuto    = 'is_date_auto';
  static const _keyManualDate    = 'manual_date';
  static const _keyNoticeFontSz  = 'notice_font_size';
  static const _keyTableFontSz   = 'table_font_size';
  static const _keyTableHdrFontSz= 'table_hdr_font_size';
  static const _keyClockNumSz    = 'clock_num_size';
  static const _keyColW1         = 'col_w1';
  static const _keyColW2         = 'col_w2';
  static const _keyColW3         = 'col_w3';
  static const _keyNoticeRowH    = 'notice_row_h';
  static const _keyTableRowH     = 'table_row_h';
  static const _keyDateFontSz    = 'date_font_size';

  static Future<void> saveAll({
    required String examName,
    required double examNameFontSize,
    required List<ExamPeriod> examPeriods,
    required List<Map<String, dynamic>> noticeSections,
    required String examTitle,
    required bool isDateAutomatic,
    required String manualDateText,
    required double noticeFontSize,
    required double tableCellFontSize,
    required double tableHeaderFontSize,
    required double clockNumberSize,
    required double tableColWidth1,
    required double tableColWidth2,
    required double tableColWidth3,
    required double noticeRowHeight,
    required double tableRowHeight,
    required double dateFontSize,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyExamName, examName);
    await prefs.setDouble(_keyExamNameFontSz, examNameFontSize);
    await prefs.setString(_keyExamPeriods,
        jsonEncode(examPeriods.map((e) => e.toJson()).toList()));
    await prefs.setString(_keyNotices, jsonEncode(noticeSections));
    await prefs.setString(_keyExamTitle, examTitle);
    await prefs.setBool(_keyIsDateAuto, isDateAutomatic);
    await prefs.setString(_keyManualDate, manualDateText);
    await prefs.setDouble(_keyNoticeFontSz, noticeFontSize);
    await prefs.setDouble(_keyTableFontSz, tableCellFontSize);
    await prefs.setDouble(_keyTableHdrFontSz, tableHeaderFontSize);
    await prefs.setDouble(_keyClockNumSz, clockNumberSize);
    await prefs.setDouble(_keyColW1, tableColWidth1);
    await prefs.setDouble(_keyColW2, tableColWidth2);
    await prefs.setDouble(_keyColW3, tableColWidth3);
    await prefs.setDouble(_keyNoticeRowH, noticeRowHeight);
    await prefs.setDouble(_keyTableRowH, tableRowHeight);
    await prefs.setDouble(_keyDateFontSz, dateFontSize);
  }

  static Future<Map<String, dynamic>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();

    // 시험 교시
    List<ExamPeriod> examPeriods = AppDefaults.examPeriods;
    final periodsJson = prefs.getString(_keyExamPeriods);
    if (periodsJson != null) {
      final list = jsonDecode(periodsJson) as List;
      examPeriods = list.map((e) => ExamPeriod.fromJson(e as Map<String, dynamic>)).toList();
    }

    // 유의사항
    List<Map<String, dynamic>> noticeSections = AppDefaults.noticeSections;
    final noticesJson = prefs.getString(_keyNotices);
    if (noticesJson != null) {
      final list = jsonDecode(noticesJson) as List;
      noticeSections = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    return {
      'examName': prefs.getString(_keyExamName) ?? '2025학년도 1학기 1차 지필평가',
      'examNameFontSize': prefs.getDouble(_keyExamNameFontSz) ?? 26.0,
      'examPeriods': examPeriods,
      'noticeSections': noticeSections,
      'examTitle': prefs.getString(_keyExamTitle) ?? '시험 시간표',
      'isDateAutomatic': prefs.getBool(_keyIsDateAuto) ?? true,
      'manualDateText': prefs.getString(_keyManualDate) ?? '',
      'noticeFontSize': prefs.getDouble(_keyNoticeFontSz) ?? 13.0,
      'tableCellFontSize': prefs.getDouble(_keyTableFontSz) ?? 20.0,
      'tableHeaderFontSize': prefs.getDouble(_keyTableHdrFontSz) ?? 20.0,
      'clockNumberSize': prefs.getDouble(_keyClockNumSz) ?? 22.0,
      'tableColWidth1': prefs.getDouble(_keyColW1) ?? 80.0,
      'tableColWidth2': prefs.getDouble(_keyColW2) ?? 200.0,
      'tableColWidth3': prefs.getDouble(_keyColW3) ?? 160.0,
      'noticeRowHeight': prefs.getDouble(_keyNoticeRowH) ?? 28.0,
      'tableRowHeight': prefs.getDouble(_keyTableRowH) ?? 55.0,
      'dateFontSize': prefs.getDouble(_keyDateFontSz) ?? 22.0,
    };
  }
}

// ─────────────────────────────────────────────
// 메인 화면
// ─────────────────────────────────────────────

class ExamBoardScreen extends StatefulWidget {
  const ExamBoardScreen({super.key});

  @override
  State<ExamBoardScreen> createState() => _ExamBoardScreenState();
}

class _ExamBoardScreenState extends State<ExamBoardScreen> with WidgetsBindingObserver {

  // ── 관리자 모드 ────────────────────────────────
  bool _isAdminMode = false;  // false = 잠금(표시 전용), true = 편집 허용

  // ── 고사명 ────────────────────────────────────
  String examName = '2025학년도 1학기 1차 지필평가';
  double _examNameFontSize = 26.0;

  // ── 날짜 설정 ──────────────────────────────────
  bool _isDateAutomatic = true;
  String _manualDateText = '';
  late Timer _dateTimer;
  static const List<String> _weekdays = ['월','화','수','목','금','토','일'];

  String get examDateText {
    if (!_isDateAutomatic) return _manualDateText;
    final now = DateTime.now();
    final weekday = _weekdays[now.weekday - 1];
    return '${now.month}월 ${now.day}일 ($weekday)';
  }

  String examTitle = '시험 시간표';

  // ── 시험 교시 데이터 ───────────────────────────
  List<ExamPeriod> examPeriods = AppDefaults.examPeriods;

  // ── 유의사항 섹션 ──────────────────────────────
  List<Map<String, dynamic>> noticeSections = AppDefaults.noticeSections;

  // ── 레이아웃 조절 변수 ──────────────────────────
  double _noticeFontSize      = 13.0;
  double _tableHeaderFontSize = 20.0;
  double _tableCellFontSize   = 20.0;
  double _clockNumberSize     = 22.0;
  double _tableColWidth1      = 80.0;
  double _tableColWidth2      = 200.0;
  double _tableColWidth3      = 160.0;
  double _noticeRowHeight     = 28.0;
  double _tableRowHeight      = 55.0;
  double _dateFontSize        = 22.0;

  // ── 로딩 상태 ──────────────────────────────────
  bool _isLoading = true;

  // ─────────────────────────────────────────────
  // 초기화
  // ─────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _dateTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && _isDateAutomatic) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dateTimer.cancel();
    super.dispose();
  }

  // 앱이 백그라운드로 전환되면 관리자 모드 자동 해제 (보안)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (_isAdminMode) {
        setState(() => _isAdminMode = false);
      }
    }
  }

  // ─────────────────────────────────────────────
  // 데이터 저장 / 로드
  // ─────────────────────────────────────────────
  Future<void> _loadData() async {
    final data = await AppStorage.loadAll();
    setState(() {
      examName            = data['examName'] as String;
      _examNameFontSize   = data['examNameFontSize'] as double;
      examPeriods         = data['examPeriods'] as List<ExamPeriod>;
      noticeSections      = data['noticeSections'] as List<Map<String, dynamic>>;
      examTitle           = data['examTitle'] as String;
      _isDateAutomatic    = data['isDateAutomatic'] as bool;
      _manualDateText     = data['manualDateText'] as String;
      _noticeFontSize     = data['noticeFontSize'] as double;
      _tableCellFontSize  = data['tableCellFontSize'] as double;
      _tableHeaderFontSize= data['tableHeaderFontSize'] as double;
      _clockNumberSize    = data['clockNumberSize'] as double;
      _tableColWidth1     = data['tableColWidth1'] as double;
      _tableColWidth2     = data['tableColWidth2'] as double;
      _tableColWidth3     = data['tableColWidth3'] as double;
      _noticeRowHeight    = data['noticeRowHeight'] as double;
      _tableRowHeight     = data['tableRowHeight'] as double;
      _dateFontSize       = data['dateFontSize'] as double;
      _isLoading = false;
    });
  }

  Future<void> _saveData() async {
    await AppStorage.saveAll(
      examName: examName,
      examNameFontSize: _examNameFontSize,
      examPeriods: examPeriods,
      noticeSections: noticeSections,
      examTitle: examTitle,
      isDateAutomatic: _isDateAutomatic,
      manualDateText: _manualDateText,
      noticeFontSize: _noticeFontSize,
      tableCellFontSize: _tableCellFontSize,
      tableHeaderFontSize: _tableHeaderFontSize,
      clockNumberSize: _clockNumberSize,
      tableColWidth1: _tableColWidth1,
      tableColWidth2: _tableColWidth2,
      tableColWidth3: _tableColWidth3,
      noticeRowHeight: _noticeRowHeight,
      tableRowHeight: _tableRowHeight,
      dateFontSize: _dateFontSize,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('저장되었습니다.'),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  // ─────────────────────────────────────────────
  // 관리자 비밀번호 다이얼로그
  // ─────────────────────────────────────────────
  Future<void> _showAdminPasswordDialog() async {
    if (_isAdminMode) {
      // 이미 관리자 모드 → 잠금 해제 확인
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.lock_open, color: Colors.greenAccent),
              SizedBox(width: 8),
              Text('관리자 모드 해제', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: const Text(
            '편집 모드를 종료하고 터치 잠금을 활성화합니다.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => _isAdminMode = false);
                Navigator.pop(ctx);
              },
              child: const Text('잠금 활성화', style: TextStyle(color: Colors.redAccent)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('계속 편집', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      );
      return;
    }

    // 비밀번호 입력
    final pwController = TextEditingController();
    String errorMsg = '';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.admin_panel_settings, color: Colors.lightBlueAccent),
              SizedBox(width: 8),
              Text('관리자 인증', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '편집 모드를 활성화하려면\n관리자 비밀번호를 입력하세요.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // 비밀번호 입력 - 핀 스타일
              TextField(
                controller: pwController,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  letterSpacing: 12,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '● ● ● ●',
                  hintStyle: TextStyle(color: Colors.white24, fontSize: 20),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: errorMsg.isEmpty ? Colors.white30 : Colors.redAccent,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: errorMsg.isEmpty ? Colors.lightBlueAccent : Colors.redAccent,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white10,
                ),
                onSubmitted: (val) {
                  if (val == AppDefaults.adminPassword) {
                    setState(() => _isAdminMode = true);
                    Navigator.pop(ctx);
                  } else {
                    setStateDialog(() => errorMsg = '비밀번호가 올바르지 않습니다.');
                    pwController.clear();
                  }
                },
              ),
              if (errorMsg.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                      const SizedBox(width: 4),
                      Text(errorMsg, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                    ],
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                final val = pwController.text;
                if (val == AppDefaults.adminPassword) {
                  setState(() => _isAdminMode = true);
                  Navigator.pop(ctx);
                } else {
                  setStateDialog(() => errorMsg = '비밀번호가 올바르지 않습니다.');
                  pwController.clear();
                }
              },
              child: const Text('확인', style: TextStyle(color: Colors.lightBlueAccent)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 편집 다이얼로그 (관리자 모드일 때만 동작)
  // ─────────────────────────────────────────────
  Future<String?> _showEditDialog(BuildContext context, String currentText,
      {String title = '내용 수정'}) {
    if (!_isAdminMode) return Future.value(null);
    final controller = TextEditingController(text: currentText);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          decoration: const InputDecoration(
            labelText: '내용 입력',
            labelStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.blueAccent)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.lightBlueAccent)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('확인', style: TextStyle(color: Colors.lightBlueAccent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  // ── 유의사항 편집 ──────────────────────────────
  Future<void> _editNoticeItem(int sIdx, int iIdx) async {
    if (!_isAdminMode) return;
    final current = noticeSections[sIdx]['items'][iIdx]['text'] as String;
    final result = await _showEditDialog(context, current, title: '유의사항 수정');
    if (result != null) setState(() => noticeSections[sIdx]['items'][iIdx]['text'] = result);
  }

  Future<void> _editSectionTitle(int sIdx) async {
    if (!_isAdminMode) return;
    final current = noticeSections[sIdx]['title'] as String;
    final result = await _showEditDialog(context, current, title: '섹션 제목 수정');
    if (result != null) setState(() => noticeSections[sIdx]['title'] = result);
  }

  void _cycleItemColor(int sIdx, int iIdx) {
    if (!_isAdminMode) return;
    const colors = ['white', 'red', 'cyan', 'yellow', 'green', 'orange'];
    final current = noticeSections[sIdx]['items'][iIdx]['color'] as String;
    final nextIdx = (colors.indexOf(current) + 1) % colors.length;
    setState(() => noticeSections[sIdx]['items'][iIdx]['color'] = colors[nextIdx]);
  }

  // ── 날짜 편집 ──────────────────────────────────
  Future<void> _editExamDate() async {
    if (!_isAdminMode) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('날짜 설정', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _isDateAutomatic ? Icons.sync : Icons.edit,
                    color: _isDateAutomatic ? Colors.greenAccent : Colors.orangeAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isDateAutomatic ? '현재: 실시간 자동 날짜' : '현재: 수동 입력 날짜',
                    style: TextStyle(
                      color: _isDateAutomatic ? Colors.greenAccent : Colors.orangeAccent,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade800,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.sync, color: Colors.white),
                label: const Text('실시간 자동 날짜 사용',
                    style: TextStyle(color: Colors.white)),
                onPressed: () {
                  setState(() {
                    _isDateAutomatic = true;
                    _manualDateText = '';
                  });
                  Navigator.pop(ctx);
                },
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.edit, color: Colors.white),
                label: const Text('직접 입력하기',
                    style: TextStyle(color: Colors.white)),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final result = await _showEditDialog(
                    context, examDateText,
                    title: '날짜 직접 입력 (예: 9월 26일 (목))',
                  );
                  if (result != null && result.isNotEmpty) {
                    setState(() {
                      _isDateAutomatic = false;
                      _manualDateText = result;
                    });
                  }
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  // ── 시간표 편집 ────────────────────────────────
  Future<void> _editExamPeriod(int idx, String field) async {
    if (!_isAdminMode) return;
    String current;
    String title;
    if (field == 'period') {
      current = examPeriods[idx].period;
      title = '교시 수정';
    } else if (field == 'time') {
      current = examPeriods[idx].time;
      title = '시간 수정 (예: 09:00 ~ 09:50)';
    } else {
      current = examPeriods[idx].subject;
      title = '과목 수정';
    }
    final result = await _showEditDialog(context, current, title: title);
    if (result != null) {
      setState(() {
        if (field == 'period') {
          examPeriods[idx].period = result;
        } else if (field == 'time') {
          examPeriods[idx].time = result;
        } else {
          examPeriods[idx].subject = result;
        }
      });
    }
  }

  void _addPeriod() {
    if (!_isAdminMode) return;
    setState(() => examPeriods.add(
      ExamPeriod(period: '${examPeriods.length + 1}교시', time: '00:00 ~ 00:00', subject: '과목'),
    ));
  }

  void _removePeriod() {
    if (!_isAdminMode) return;
    if (examPeriods.length > 1) setState(() => examPeriods.removeLast());
  }

  void _addNoticeItem(int sIdx) {
    if (!_isAdminMode) return;
    setState(() => noticeSections[sIdx]['items']
        .add({'text': '여기를 탭하여 내용을 수정하세요', 'color': 'white', 'bold': false}));
  }

  void _removeNoticeItem(int sIdx) {
    if (!_isAdminMode) return;
    final items = noticeSections[sIdx]['items'] as List;
    if (items.length > 1) setState(() => items.removeLast());
  }

  // ── 색상 변환 ──────────────────────────────────
  Color _parseColor(String c) {
    switch (c) {
      case 'red':    return Colors.red;
      case 'cyan':   return Colors.cyanAccent;
      case 'yellow': return Colors.yellow;
      case 'green':  return Colors.lightGreenAccent;
      case 'orange': return Colors.orangeAccent;
      default:       return Colors.white;
    }
  }

  // ─────────────────────────────────────────────
  // 빌드
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white54),
              SizedBox(height: 16),
              Text('데이터 불러오는 중...', style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      );
    }

    // 잠금 상태일 때 뒤로가기/종료 차단 (PopScope)
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (_isAdminMode) {
          // 관리자 모드에서는 종료 확인
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1A1A2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('앱 종료', style: TextStyle(color: Colors.white)),
              content: const Text('앱을 종료하시겠습니까?\n저장되지 않은 변경사항은 사라집니다.',
                  style: TextStyle(color: Colors.white70)),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    SystemNavigator.pop();
                  },
                  child: const Text('종료', style: TextStyle(color: Colors.redAccent)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('취소', style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          );
        }
        // 잠금 상태에서는 아무 동작 없음 (종료 차단)
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          children: [
            // ── 고사명 최상단 바 ──────────────────────
            _buildExamNameBar(),
            // ── 관리자 상태 바 ────────────────────────
            _buildStatusBar(),
            // ── 메인 콘텐츠 ──────────────────────────
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 왼쪽: 유의사항
                  Expanded(flex: 5, child: _buildNoticePanel()),
                  Container(width: 2, color: Colors.white24),
                  // 오른쪽: 시간표 + 시계
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        _buildDateHeader(),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: _buildExamTable(),
                        ),
                        Expanded(
                          child: Center(
                            child: AnalogClock(clockNumberSize: _clockNumberSize),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // ── 하단 바 ──────────────────────────────
            if (_isAdminMode) _buildControlBar(),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 고사명 최상단 바
  // ─────────────────────────────────────────────
  Widget _buildExamNameBar() {
    return GestureDetector(
      onTap: () async {
        if (!_isAdminMode) return;
        final result = await _showEditDialog(
          context, examName,
          title: '고사명 수정',
        );
        if (result != null && result.isNotEmpty) {
          setState(() => examName = result);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D1A),
          border: const Border(
            bottom: BorderSide(color: Colors.white24, width: 1),
          ),
          // 관리자 모드일 때 살짝 강조
          boxShadow: _isAdminMode
              ? [BoxShadow(color: Colors.greenAccent.withValues(alpha: 0.15), blurRadius: 6)]
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 고사명 텍스트 (중앙)
            Text(
              examName.isEmpty ? '고사명을 입력하세요' : examName,
              style: TextStyle(
                color: examName.isEmpty ? Colors.white38 : Colors.white,
                fontSize: _examNameFontSize,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
            // 편집 모드일 때 우측에 편집 아이콘 표시
            if (_isAdminMode)
              Positioned(
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.shade900,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit, color: Colors.greenAccent, size: 13),
                      SizedBox(width: 4),
                      Text('탭하여 수정', style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 상단 상태 바 (관리자 모드 알림)
  // ─────────────────────────────────────────────
  Widget _buildStatusBar() {
    if (!_isAdminMode) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: const Color(0xFF1A2A1A),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.edit, color: Colors.greenAccent, size: 14),
          const SizedBox(width: 6),
          const Text(
            '관리자 편집 모드 활성화 중',
            style: TextStyle(color: Colors.greenAccent, fontSize: 12),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _saveData,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.shade700,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.save, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text('저장', style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _showAdminPasswordDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade700,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text('잠금', style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 유의사항 패널
  // ─────────────────────────────────────────────
  Widget _buildNoticePanel() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white38, width: 1)),
            ),
            child: Text(
              '지필평가 관련 유의사항',
              style: TextStyle(
                color: Colors.white,
                fontSize: _noticeFontSize + 4,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: SingleChildScrollView(
              child: Table(
                border: TableBorder.all(color: Colors.white54, width: 0.8),
                columnWidths: const {
                  0: FixedColumnWidth(52),
                  1: FlexColumnWidth(1),
                },
                children: _buildNoticeTableRows(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<TableRow> _buildNoticeTableRows() {
    final rows = <TableRow>[];
    for (int sIdx = 0; sIdx < noticeSections.length; sIdx++) {
      final section = noticeSections[sIdx];
      final items = section['items'] as List<dynamic>;
      for (int iIdx = 0; iIdx < items.length; iIdx++) {
        final item = items[iIdx];
        final textColor = _parseColor(item['color'] as String);
        final bold = item['bold'] as bool;
        rows.add(TableRow(children: [
          // 섹션명
          GestureDetector(
            onTap: () => _editSectionTitle(sIdx),
            child: Container(
              height: _noticeRowHeight,
              alignment: Alignment.center,
              color: const Color(0xFF0D0D0D),
              child: iIdx == 0
                  ? Text(
                      section['title'] as String,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: _noticeFontSize - 1,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          // 내용
          GestureDetector(
            onTap: () => _editNoticeItem(sIdx, iIdx),
            onLongPress: () => _cycleItemColor(sIdx, iIdx),
            child: Container(
              height: _noticeRowHeight,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Text(
                item['text'] as String,
                style: TextStyle(
                  color: textColor,
                  fontSize: _noticeFontSize,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ),
        ]));
      }
    }
    return rows;
  }

  // ─────────────────────────────────────────────
  // 날짜 헤더
  // ─────────────────────────────────────────────
  Widget _buildDateHeader() {
    return GestureDetector(
      onTap: _editExamDate,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white38, width: 1)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '$examDateText $examTitle',
              style: TextStyle(
                color: Colors.white,
                fontSize: _dateFontSize,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            Positioned(
              right: 0,
              child: Icon(
                _isDateAutomatic ? Icons.sync : Icons.edit,
                color: _isDateAutomatic ? Colors.greenAccent : Colors.orangeAccent,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 시험 시간표 테이블
  // ─────────────────────────────────────────────
  Widget _buildExamTable() {
    return Table(
      border: TableBorder.all(color: Colors.white, width: 1.5),
      columnWidths: {
        0: FixedColumnWidth(_tableColWidth1),
        1: FixedColumnWidth(_tableColWidth2),
        2: FixedColumnWidth(_tableColWidth3),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFF1A1A2E)),
          children: [
            _headerCell('교  시'),
            _headerCell('시  간'),
            _headerCell('과  목'),
          ],
        ),
        ...List.generate(examPeriods.length, (idx) {
          final p = examPeriods[idx];
          return TableRow(children: [
            _editableCell(p.period, () => _editExamPeriod(idx, 'period')),
            _editableCell(p.time,   () => _editExamPeriod(idx, 'time')),
            _editableCell(p.subject,() => _editExamPeriod(idx, 'subject')),
          ]);
        }),
      ],
    );
  }

  Widget _headerCell(String text) => Container(
        height: _tableRowHeight,
        alignment: Alignment.center,
        child: Text(text,
            style: TextStyle(
                color: Colors.white,
                fontSize: _tableHeaderFontSize,
                fontWeight: FontWeight.bold)),
      );

  Widget _editableCell(String text, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: _tableRowHeight,
          alignment: Alignment.center,
          child: Text(text,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: _tableCellFontSize,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center),
        ),
      );

  // ─────────────────────────────────────────────
  // 하단 조절 버튼 바 (관리자 모드에서만 표시)
  // ─────────────────────────────────────────────
  Widget _buildControlBar() {
    return Container(
      color: const Color(0xFF111111),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _ctrlGroup('고사명 글자', [
            _ctrlBtn(Icons.text_increase, () => setState(() => _examNameFontSize += 1)),
            _ctrlBtn(Icons.text_decrease, () => setState(() { if (_examNameFontSize > 12) _examNameFontSize -= 1; })),
          ]),
          _div(),
          _ctrlGroup('유의사항 글자', [
            _ctrlBtn(Icons.text_increase, () => setState(() => _noticeFontSize += 1)),
            _ctrlBtn(Icons.text_decrease, () => setState(() { if (_noticeFontSize > 8) _noticeFontSize -= 1; })),
          ]),
          _div(),
          _ctrlGroup('행 높이', [
            _ctrlBtn(Icons.arrow_upward, () => setState(() => _noticeRowHeight += 4)),
            _ctrlBtn(Icons.arrow_downward, () => setState(() { if (_noticeRowHeight > 18) _noticeRowHeight -= 4; })),
          ]),
          _div(),
          _ctrlGroup('시간표 글자', [
            _ctrlBtn(Icons.text_increase, () => setState(() { _tableCellFontSize += 1; _tableHeaderFontSize += 1; })),
            _ctrlBtn(Icons.text_decrease, () => setState(() {
              if (_tableCellFontSize > 10) { _tableCellFontSize -= 1; _tableHeaderFontSize -= 1; }
            })),
          ]),
          _div(),
          _ctrlGroup('시간표 높이', [
            _ctrlBtn(Icons.arrow_upward, () => setState(() => _tableRowHeight += 5)),
            _ctrlBtn(Icons.arrow_downward, () => setState(() { if (_tableRowHeight > 30) _tableRowHeight -= 5; })),
          ]),
          _div(),
          _ctrlGroup('교시 폭', [
            _ctrlBtn(Icons.arrow_right, () => setState(() => _tableColWidth1 += 10)),
            _ctrlBtn(Icons.arrow_left,  () => setState(() { if (_tableColWidth1 > 40) _tableColWidth1 -= 10; })),
          ]),
          _div(),
          _ctrlGroup('시간 폭', [
            _ctrlBtn(Icons.arrow_right, () => setState(() => _tableColWidth2 += 10)),
            _ctrlBtn(Icons.arrow_left,  () => setState(() { if (_tableColWidth2 > 80) _tableColWidth2 -= 10; })),
          ]),
          _div(),
          _ctrlGroup('과목 폭', [
            _ctrlBtn(Icons.arrow_right, () => setState(() => _tableColWidth3 += 10)),
            _ctrlBtn(Icons.arrow_left,  () => setState(() { if (_tableColWidth3 > 60) _tableColWidth3 -= 10; })),
          ]),
          _div(),
          _ctrlGroup('날짜 글자', [
            _ctrlBtn(Icons.text_increase, () => setState(() => _dateFontSize += 1)),
            _ctrlBtn(Icons.text_decrease, () => setState(() { if (_dateFontSize > 12) _dateFontSize -= 1; })),
          ]),
          _div(),
          _ctrlGroup('시계 숫자', [
            _ctrlBtn(Icons.text_increase, () => setState(() => _clockNumberSize += 1)),
            _ctrlBtn(Icons.text_decrease, () => setState(() { if (_clockNumberSize > 10) _clockNumberSize -= 1; })),
          ]),
          _div(),
          _ctrlGroup('교시', [
            _ctrlBtn(Icons.add,    _addPeriod),
            _ctrlBtn(Icons.remove, _removePeriod),
          ]),
          _div(),
          ...List.generate(noticeSections.length, (idx) => Row(children: [
            _ctrlGroup('${noticeSections[idx]['title']} 항목', [
              _ctrlBtn(Icons.add,    () => _addNoticeItem(idx)),
              _ctrlBtn(Icons.remove, () => _removeNoticeItem(idx)),
            ]),
            _div(),
          ])),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 최하단 바 (잠금 버튼 + 저장 버튼 항상 표시)
  // ─────────────────────────────────────────────
  Widget _buildBottomBar() {
    return Container(
      color: const Color(0xFF0A0A0A),
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 관리자 모드 진입/해제 버튼
          GestureDetector(
            onTap: _showAdminPasswordDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: _isAdminMode
                    ? Colors.green.shade900
                    : const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isAdminMode ? Colors.greenAccent : Colors.white24,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isAdminMode ? Icons.lock_open : Icons.lock,
                    color: _isAdminMode ? Colors.greenAccent : Colors.white54,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isAdminMode ? '편집 모드 (탭하여 잠금)' : '잠금 상태 (탭하여 편집)',
                    style: TextStyle(
                      color: _isAdminMode ? Colors.greenAccent : Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isAdminMode) ...[
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _saveData,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade800,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.save, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text('변경사항 저장', style: TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _ctrlGroup(String label, List<Widget> buttons) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: buttons),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
          ],
        ),
      );

  Widget _ctrlBtn(IconData icon, VoidCallback onPressed) => SizedBox(
        width: 32,
        height: 32,
        child: IconButton(
          padding: EdgeInsets.zero,
          iconSize: 18,
          icon: Icon(icon, color: Colors.white70),
          onPressed: onPressed,
        ),
      );

  Widget _div() => Container(
        width: 1, height: 40,
        color: Colors.white24,
        margin: const EdgeInsets.symmetric(horizontal: 4),
      );
}

// ─────────────────────────────────────────────
// 아날로그 시계
// ─────────────────────────────────────────────

class AnalogClock extends StatefulWidget {
  final double clockNumberSize;
  const AnalogClock({super.key, required this.clockNumberSize});

  @override
  State<AnalogClock> createState() => _AnalogClockState();
}

class _AnalogClockState extends State<AnalogClock> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() { _now = DateTime.now(); });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: CustomPaint(
        painter: ClockPainter(clockNumberSize: widget.clockNumberSize, now: _now),
      ),
    );
  }
}

class ClockPainter extends CustomPainter {
  final double clockNumberSize;
  final DateTime now;

  ClockPainter({required this.clockNumberSize, required this.now});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2) * 0.92;

    // 외부 원
    canvas.drawCircle(center, radius,
        Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 6.0);
    // 배경
    canvas.drawCircle(center, radius - 3,
        Paint()..color = const Color(0xFF0A0A0A));

    // 눈금
    for (int i = 0; i < 60; i++) {
      final angle = pi / 30 * i;
      final isHour = i % 5 == 0;
      final tickLen = isHour ? radius * 0.12 : radius * 0.05;
      final s = Offset(
        center.dx + (radius - tickLen) * cos(angle - pi / 2),
        center.dy + (radius - tickLen) * sin(angle - pi / 2),
      );
      final e = Offset(
        center.dx + (radius - 3) * cos(angle - pi / 2),
        center.dy + (radius - 3) * sin(angle - pi / 2),
      );
      canvas.drawLine(s, e,
          Paint()..color = isHour ? Colors.white : Colors.white54..strokeWidth = isHour ? 3.5 : 1.5);
    }

    // 숫자
    final tp = TextPainter(textAlign: TextAlign.center, textDirection: TextDirection.ltr);
    for (int i = 1; i <= 12; i++) {
      final angle = i * 30 * pi / 180;
      final x = center.dx + radius * 0.75 * cos(angle - pi / 2);
      final y = center.dy + radius * 0.75 * sin(angle - pi / 2);
      tp.text = TextSpan(
          text: '$i',
          style: TextStyle(color: Colors.white, fontSize: clockNumberSize, fontWeight: FontWeight.bold));
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
    }

    // 시침
    final hAngle = (now.hour % 12 + now.minute / 60 + now.second / 3600) * 30 * pi / 180 - pi / 2;
    canvas.drawLine(
      Offset(center.dx - radius * 0.15 * cos(hAngle), center.dy - radius * 0.15 * sin(hAngle)),
      Offset(center.dx + radius * 0.50 * cos(hAngle), center.dy + radius * 0.50 * sin(hAngle)),
      Paint()..color = Colors.white..strokeWidth = 7.0..strokeCap = StrokeCap.round,
    );
    // 분침
    final mAngle = (now.minute + now.second / 60) * 6 * pi / 180 - pi / 2;
    canvas.drawLine(
      Offset(center.dx - radius * 0.12 * cos(mAngle), center.dy - radius * 0.12 * sin(mAngle)),
      Offset(center.dx + radius * 0.72 * cos(mAngle), center.dy + radius * 0.72 * sin(mAngle)),
      Paint()..color = Colors.white..strokeWidth = 4.5..strokeCap = StrokeCap.round,
    );
    // 초침
    final sAngle = now.second * 6 * pi / 180 - pi / 2;
    canvas.drawLine(
      Offset(center.dx - radius * 0.20 * cos(sAngle), center.dy - radius * 0.20 * sin(sAngle)),
      Offset(center.dx + radius * 0.88 * cos(sAngle), center.dy + radius * 0.88 * sin(sAngle)),
      Paint()..color = Colors.red..strokeWidth = 2.0..strokeCap = StrokeCap.round,
    );
    // 중심
    canvas.drawCircle(center, 7, Paint()..color = Colors.white);
    canvas.drawCircle(center, 4, Paint()..color = Colors.red);
  }

  @override
  bool shouldRepaint(covariant ClockPainter old) =>
      old.now != now || old.clockNumberSize != clockNumberSize;
}
