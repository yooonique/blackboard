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
      title: '정기고사 시험 시간표',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        textTheme: const TextTheme(bodyMedium: TextStyle(color: Colors.white)),
      ),
      home: const ExamBoardScreen(),
    );
  }
}

// ─────────────────────────────────────────────
// 데이터 모델
// ─────────────────────────────────────────────

// 시험표 유형
enum TableType { regular, mock } // regular=정기고사용, mock=모의고사용

// 정기고사용 행: 교시 / 준비령 / 시간 / 과목
class RegularPeriod {
  String period;   // 교시 (예: 1교시)
  String ready;    // 준비령 (예: 08:35)
  String time;     // 시간 (예: 08:40 ~ 09:50)
  String subject;  // 과목 (예: 국어)
  RegularPeriod({required this.period, required this.ready, required this.time, required this.subject});
  Map<String, dynamic> toJson() => {'period': period, 'ready': ready, 'time': time, 'subject': subject};
  factory RegularPeriod.fromJson(Map<String, dynamic> j) => RegularPeriod(
      period: (j['period'] ?? '') as String,
      ready:  (j['ready']  ?? '') as String,
      time:   (j['time']   ?? '') as String,
      subject:(j['subject'] ?? '') as String);
}

// 모의고사용 행: 교시 / 과목 / 준비령 / 본령 / 종료령
class MockPeriod {
  String period;   // 교시 (예: 1교시) — 여러 행이 같은 교시를 공유할 수 있음
  String subject;  // 과목
  String ready;    // 준비령
  String start;    // 본령
  String end;      // 종료령
  MockPeriod({required this.period, required this.subject, required this.ready, required this.start, required this.end});
  Map<String, dynamic> toJson() => {'period': period, 'subject': subject, 'ready': ready, 'start': start, 'end': end};
  factory MockPeriod.fromJson(Map<String, dynamic> j) => MockPeriod(
      period:  (j['period']  ?? '') as String,
      subject: (j['subject'] ?? '') as String,
      ready:   (j['ready']   ?? '') as String,
      start:   (j['start']   ?? '') as String,
      end:     (j['end']     ?? '') as String);
}

// 고사 유형 (고사명용)
enum ExamType { regular, national }

// ─────────────────────────────────────────────
// 기본값
// ─────────────────────────────────────────────
class AppDefaults {
  static const String adminPassword = '0000';

  // ── 정기고사용 기본 시간표 ──
  static List<RegularPeriod> get regularPeriods => [
    RegularPeriod(period: '1교시', ready: '08:50', time: '09:00 ~ 09:50', subject: '국  어'),
    RegularPeriod(period: '2교시', ready: '10:00', time: '10:10 ~ 11:00', subject: '수  학'),
    RegularPeriod(period: '3교시', ready: '11:10', time: '11:20 ~ 12:10', subject: '영  어'),
  ];

  // ── 모의고사용 기본 시간표 (HWPX 파일 기반) ──
  static List<MockPeriod> get mockPeriods => [
    MockPeriod(period: '1교시', subject: '국  어',    ready: '08:35', start: '08:40', end: '10:00'),
    MockPeriod(period: '2교시', subject: '수  학',    ready: '10:25', start: '10:30', end: '12:10'),
    MockPeriod(period: '3교시', subject: '영  어',    ready: '13:05', start: '13:10', end: '14:20'),
    MockPeriod(period: '4교시', subject: '한국사',    ready: '14:45', start: '14:50', end: '15:20'),
    MockPeriod(period: '',      subject: '사회탐구',  ready: '',      start: '15:35', end: '16:15'),
    MockPeriod(period: '',      subject: '과학탐구',  ready: '',      start: '16:30', end: '17:10'),
  ];

  // ── HWPX 기반 유의사항 ──
  static List<Map<String, dynamic>> get noticeSections => [
    {
      'title': '시험 전',
      'items': [
        {'text': '시험 중 반입금지품 제출 (전자기기, 스마트워치 등)', 'color': 'white', 'bold': false},
        {'text': '교실 앞으로 가방 제출, 매 시간 서랍 속 비었는지 확인', 'color': 'white', 'bold': false},
      ],
    },
    {
      'title': '시험 중',
      'items': [
        {'text': '시험 시간 준수, 지정된 시간 전에는 퇴실 금지', 'color': 'white', 'bold': false},
        {'text': '시험지·답안지는 반드시 학생 본인의 가슴 앞(정중앙)에 놓고 풀이', 'color': 'white', 'bold': false},
        {'text': '답안지 교체, 문제에 대한 질의: 조용히 손을 들어 표시 (불필요한 말·행위 금지)', 'color': 'white', 'bold': false},
        {'text': '개인 책상 및 벽면 등에 시험 관련 내용 작성 금지', 'color': 'white', 'bold': false},
        {'text': '선택형 문항 답안 표기 잘못한 경우: 수정테이프로 수정, 감독 교사 날인', 'color': 'cyan', 'bold': false},
        {'text': '서·논술형은 반드시 지워지지 않는 흑색 볼펜 (샤프X, 연필X)으로 작성', 'color': 'cyan', 'bold': false},
        {'text': '서·논술형 문항의 내용 수정: 두 줄 긋고 작성', 'color': 'white', 'bold': false},
        {'text': '종료 잔여 시간에 관계없이 답안지 교체 가능하나, OMR 마킹 시간 부족 등은 학생 본인의 책임임을 인지하고 신속하게 처리', 'color': 'red', 'bold': true},
      ],
    },
    {
      'title': '종료 시',
      'items': [
        {'text': '답안 작성은 시험 종료령과 함께 중지, 두 손을 아래로 내리고 감독교사 지시에 따름', 'color': 'white', 'bold': false},
        {'text': '종료령 이후 객관식 답안 마킹 또는 서술형 답안 작성은 부정행위 적용', 'color': 'red', 'bold': true},
      ],
    },
  ];
}

// ─────────────────────────────────────────────
// SharedPreferences 저장소
// ─────────────────────────────────────────────
class AppStorage {
  static const _kExamName       = 'exam_name';
  static const _kExamNameFontSz = 'exam_name_font_size';
  static const _kExamType       = 'exam_type';
  static const _kExamYear       = 'exam_year';
  static const _kExamMonth      = 'exam_month';
  static const _kExamSemester   = 'exam_semester';
  static const _kExamRound      = 'exam_round';
  static const _kExamCustomName = 'exam_custom_name';
  static const _kTableType      = 'table_type'; // 'regular' | 'mock'
  static const _kRegularPeriods = 'regular_periods';
  static const _kMockPeriods    = 'mock_periods';
  static const _kNotices        = 'notice_sections';
  static const _kExamTitle      = 'exam_title';
  static const _kIsDateAuto     = 'is_date_auto';
  static const _kManualDate     = 'manual_date';
  static const _kNoticeFontSz   = 'notice_font_size';
  static const _kTableFontSz    = 'table_font_size';
  static const _kTableHdrFontSz = 'table_hdr_font_size';
  static const _kClockNumSz     = 'clock_num_size';
  // 정기고사 열 너비
  static const _kRColW1 = 'r_col_w1';
  static const _kRColW2 = 'r_col_w2';
  static const _kRColW3 = 'r_col_w3';
  static const _kRColW4 = 'r_col_w4';
  // 모의고사 열 너비
  static const _kMColW1 = 'm_col_w1';
  static const _kMColW2 = 'm_col_w2';
  static const _kMColW3 = 'm_col_w3';
  static const _kMColW4 = 'm_col_w4';
  static const _kMColW5 = 'm_col_w5';

  static const _kNoticeRowH    = 'notice_row_h';
  static const _kTableRowH     = 'table_row_h';
  static const _kDateFontSz    = 'date_font_size';
  static const _kClockType     = 'clock_type';
  static const _kBurnInInterval= 'burn_in_interval';

  static Future<void> saveAll(Map<String, dynamic> d) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kExamName,      d['examName']);
    await p.setDouble(_kExamNameFontSz,d['examNameFontSize']);
    await p.setString(_kExamType,      d['examType']);
    await p.setInt   (_kExamYear,      d['examYear']);
    await p.setInt   (_kExamMonth,     d['examMonth']);
    await p.setInt   (_kExamSemester,  d['examSemester']);
    await p.setInt   (_kExamRound,     d['examRound']);
    await p.setString(_kExamCustomName,d['examCustomName']);
    await p.setString(_kTableType,     d['tableType']);
    await p.setString(_kRegularPeriods,jsonEncode((d['regularPeriods'] as List<RegularPeriod>).map((e)=>e.toJson()).toList()));
    await p.setString(_kMockPeriods,   jsonEncode((d['mockPeriods']    as List<MockPeriod>   ).map((e)=>e.toJson()).toList()));
    await p.setString(_kNotices,       jsonEncode(d['noticeSections']));
    await p.setString(_kExamTitle,     d['examTitle']);
    await p.setBool  (_kIsDateAuto,    d['isDateAutomatic']);
    await p.setString(_kManualDate,    d['manualDateText']);
    await p.setDouble(_kNoticeFontSz,  d['noticeFontSize']);
    await p.setDouble(_kTableFontSz,   d['tableCellFontSize']);
    await p.setDouble(_kTableHdrFontSz,d['tableHeaderFontSize']);
    await p.setDouble(_kClockNumSz,    d['clockNumberSize']);
    await p.setDouble(_kRColW1,        d['rColW1']);
    await p.setDouble(_kRColW2,        d['rColW2']);
    await p.setDouble(_kRColW3,        d['rColW3']);
    await p.setDouble(_kRColW4,        d['rColW4']);
    await p.setDouble(_kMColW1,        d['mColW1']);
    await p.setDouble(_kMColW2,        d['mColW2']);
    await p.setDouble(_kMColW3,        d['mColW3']);
    await p.setDouble(_kMColW4,        d['mColW4']);
    await p.setDouble(_kMColW5,        d['mColW5']);
    await p.setDouble(_kNoticeRowH,    d['noticeRowHeight']);
    await p.setDouble(_kTableRowH,     d['tableRowHeight']);
    await p.setDouble(_kDateFontSz,    d['dateFontSize']);
    await p.setString(_kClockType,     d['clockType']);
    await p.setInt   (_kBurnInInterval,d['burnInInterval']);
  }

  static Future<Map<String, dynamic>> loadAll() async {
    final p = await SharedPreferences.getInstance();
    List<RegularPeriod> rPeriods = AppDefaults.regularPeriods;
    final rj = p.getString(_kRegularPeriods);
    if (rj != null) {
      rPeriods = (jsonDecode(rj) as List).map((e)=>RegularPeriod.fromJson(e as Map<String,dynamic>)).toList();
    }
    List<MockPeriod> mPeriods = AppDefaults.mockPeriods;
    final mj = p.getString(_kMockPeriods);
    if (mj != null) {
      mPeriods = (jsonDecode(mj) as List).map((e)=>MockPeriod.fromJson(e as Map<String,dynamic>)).toList();
    }
    List<Map<String,dynamic>> notices = AppDefaults.noticeSections;
    final nj = p.getString(_kNotices);
    if (nj != null) {
      notices = (jsonDecode(nj) as List).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
    }
    final currentYear = DateTime.now().year;
    return {
      'examName':            p.getString(_kExamName)       ?? '$currentYear학년도 1학기 1차 정기고사',
      'examNameFontSize':    p.getDouble(_kExamNameFontSz) ?? 26.0,
      'examType':            p.getString(_kExamType)       ?? 'regular',
      'examYear':            p.getInt   (_kExamYear)       ?? currentYear,
      'examMonth':           p.getInt   (_kExamMonth)      ?? 3,
      'examSemester':        p.getInt   (_kExamSemester)   ?? 1,
      'examRound':           p.getInt   (_kExamRound)      ?? 1,
      'examCustomName':      p.getString(_kExamCustomName) ?? '',
      'tableType':           p.getString(_kTableType)      ?? 'regular',
      'regularPeriods':      rPeriods,
      'mockPeriods':         mPeriods,
      'noticeSections':      notices,
      'examTitle':           p.getString(_kExamTitle)      ?? '시험 시간표',
      'isDateAutomatic':     p.getBool  (_kIsDateAuto)     ?? true,
      'manualDateText':      p.getString(_kManualDate)     ?? '',
      'noticeFontSize':      p.getDouble(_kNoticeFontSz)   ?? 13.0,
      'tableCellFontSize':   p.getDouble(_kTableFontSz)    ?? 18.0,
      'tableHeaderFontSize': p.getDouble(_kTableHdrFontSz) ?? 18.0,
      'clockNumberSize':     p.getDouble(_kClockNumSz)     ?? 22.0,
      'rColW1':              p.getDouble(_kRColW1)         ?? 70.0,
      'rColW2':              p.getDouble(_kRColW2)         ?? 80.0,
      'rColW3':              p.getDouble(_kRColW3)         ?? 180.0,
      'rColW4':              p.getDouble(_kRColW4)         ?? 120.0,
      'mColW1':              p.getDouble(_kMColW1)         ?? 65.0,
      'mColW2':              p.getDouble(_kMColW2)         ?? 100.0,
      'mColW3':              p.getDouble(_kMColW3)         ?? 75.0,
      'mColW4':              p.getDouble(_kMColW4)         ?? 75.0,
      'mColW5':              p.getDouble(_kMColW5)         ?? 75.0,
      'noticeRowHeight':     p.getDouble(_kNoticeRowH)     ?? 28.0,
      'tableRowHeight':      p.getDouble(_kTableRowH)      ?? 52.0,
      'dateFontSize':        p.getDouble(_kDateFontSz)     ?? 22.0,
      'clockType':           p.getString(_kClockType)      ?? 'analog',
      'burnInInterval':      p.getInt   (_kBurnInInterval) ?? 30,
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

  // ── 관리자 모드 ──
  bool _isAdminMode = false;

  // ── 번인 방지 ──
  int _burnInIntervalMinutes = 30;
  Timer? _burnInTimer;
  bool _burnInActive = false;
  double _burnInX = 0.1, _burnInY = 0.35;
  double _burnInDx = 0.006, _burnInDy = 0.004;
  Timer? _burnInMoveTimer;
  bool _burnInInverted = false;
  Timer? _burnInInvertTimer;
  int _burnInPhase = 0;

  void _resetBurnInTimer() {
    _burnInTimer?.cancel();
    if (_burnInActive) _deactivateBurnIn();
    _burnInTimer = Timer(Duration(minutes: _burnInIntervalMinutes), _activateBurnIn);
  }

  void _activateBurnIn() {
    _burnInPhase = 0;
    setState(() => _burnInActive = true);
    _burnInMoveTimer = Timer.periodic(const Duration(milliseconds: 60), (_) {
      if (!mounted) return;
      setState(() {
        _burnInX += _burnInDx; _burnInY += _burnInDy;
        if (_burnInX <= 0.0 || _burnInX >= 0.65) _burnInDx = -_burnInDx;
        if (_burnInY <= 0.0 || _burnInY >= 0.80) _burnInDy = -_burnInDy;
      });
    });
    _burnInInvertTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (!mounted) return;
      setState(() {
        _burnInPhase = (_burnInPhase + 1) % 3;
        _burnInInverted = _burnInPhase == 2;
      });
    });
  }

  void _deactivateBurnIn() {
    _burnInMoveTimer?.cancel();
    _burnInInvertTimer?.cancel();
    setState(() { _burnInActive = false; _burnInInverted = false; _burnInPhase = 0; });
    _resetBurnInTimer();
  }

  // ── 고사명 & 유형 ──
  String examName = '2025학년도 1학기 1차 정기고사';
  double _examNameFontSize = 26.0;
  ExamType _examType = ExamType.regular;
  int _examYear     = DateTime.now().year;
  int _examMonth    = 3;
  int _examSemester = 1;
  int _examRound    = 1;
  String _examCustomName = '';

  String get _builtExamName {
    if (_examType == ExamType.regular) {
      return '$_examYear학년도 ${_examSemester == 1 ? '1학기' : '2학기'} $_examRound차 정기고사';
    } else {
      final extra = _examCustomName.isNotEmpty ? ' $_examCustomName' : '';
      return '$_examYear학년도 $_examMonth월 전국연합 학력평가$extra';
    }
  }

  // ── 유의사항 패널 제목 (고사 유형에 따라 자동 변경) ──
  String get _noticeTitle {
    if (_examType == ExamType.national) return '전국연합 학력평가 관련 유의사항';
    return '정기고사 관련 유의사항';
  }

  // ── 날짜 ──
  bool _isDateAutomatic = true;
  String _manualDateText = '';
  late Timer _dateTimer;
  static const _weekdays = ['월','화','수','목','금','토','일'];
  String get examDateText {
    if (!_isDateAutomatic) return _manualDateText;
    final n = DateTime.now();
    return '${n.month}월 ${n.day}일 (${_weekdays[n.weekday-1]})';
  }
  String examTitle = '시험 시간표';

  // ── 시계 유형 ──
  String _clockType = 'analog';

  // ── 시험표 유형 ──
  TableType _tableType = TableType.regular;

  // ── 시험 데이터 ──
  List<RegularPeriod> regularPeriods = AppDefaults.regularPeriods;
  List<MockPeriod>    mockPeriods    = AppDefaults.mockPeriods;
  List<Map<String,dynamic>> noticeSections = AppDefaults.noticeSections;

  // ── 레이아웃 변수 ──
  double _noticeFontSize      = 13.0;
  double _tableHeaderFontSize = 18.0;
  double _tableCellFontSize   = 18.0;
  double _clockNumberSize     = 22.0;
  // 정기고사 열 너비: 교시 / 준비령 / 시간 / 과목
  double _rColW1 = 70.0, _rColW2 = 80.0, _rColW3 = 180.0, _rColW4 = 120.0;
  // 모의고사 열 너비: 교시 / 과목 / 준비령 / 본령 / 종료령
  double _mColW1 = 65.0, _mColW2 = 100.0, _mColW3 = 75.0, _mColW4 = 75.0, _mColW5 = 75.0;
  double _noticeRowHeight = 28.0;
  double _tableRowHeight  = 52.0;
  double _dateFontSize    = 22.0;
  bool _isLoading = true;

  // ─────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _dateTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && _isDateAutomatic) setState(() {});
    });
    _resetBurnInTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dateTimer.cancel();
    _burnInTimer?.cancel();
    _burnInMoveTimer?.cancel();
    _burnInInvertTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      if (_isAdminMode) setState(() => _isAdminMode = false);
    }
  }

  // ── 저장/로드 ──
  Future<void> _loadData() async {
    final d = await AppStorage.loadAll();
    setState(() {
      examName          = d['examName'] as String;
      _examNameFontSize = d['examNameFontSize'] as double;
      _examType         = (d['examType'] as String) == 'national' ? ExamType.national : ExamType.regular;
      _examYear         = d['examYear'] as int;
      _examMonth        = d['examMonth'] as int;
      _examSemester     = d['examSemester'] as int;
      _examRound        = d['examRound'] as int;
      _examCustomName   = d['examCustomName'] as String;
      _tableType        = (d['tableType'] as String) == 'mock' ? TableType.mock : TableType.regular;
      regularPeriods    = d['regularPeriods'] as List<RegularPeriod>;
      mockPeriods       = d['mockPeriods']    as List<MockPeriod>;
      noticeSections    = d['noticeSections'] as List<Map<String,dynamic>>;
      examTitle         = d['examTitle'] as String;
      _isDateAutomatic  = d['isDateAutomatic'] as bool;
      _manualDateText   = d['manualDateText'] as String;
      _noticeFontSize      = d['noticeFontSize'] as double;
      _tableCellFontSize   = d['tableCellFontSize'] as double;
      _tableHeaderFontSize = d['tableHeaderFontSize'] as double;
      _clockNumberSize  = d['clockNumberSize'] as double;
      _rColW1 = d['rColW1'] as double; _rColW2 = d['rColW2'] as double;
      _rColW3 = d['rColW3'] as double; _rColW4 = d['rColW4'] as double;
      _mColW1 = d['mColW1'] as double; _mColW2 = d['mColW2'] as double;
      _mColW3 = d['mColW3'] as double; _mColW4 = d['mColW4'] as double;
      _mColW5 = d['mColW5'] as double;
      _noticeRowHeight  = d['noticeRowHeight'] as double;
      _tableRowHeight   = d['tableRowHeight'] as double;
      _dateFontSize     = d['dateFontSize'] as double;
      _clockType        = d['clockType'] as String;
      _burnInIntervalMinutes = d['burnInInterval'] as int;
      _isLoading = false;
    });
  }

  Future<void> _saveData() async {
    await AppStorage.saveAll({
      'examName': examName, 'examNameFontSize': _examNameFontSize,
      'examType': _examType == ExamType.national ? 'national' : 'regular',
      'examYear': _examYear, 'examMonth': _examMonth,
      'examSemester': _examSemester, 'examRound': _examRound,
      'examCustomName': _examCustomName,
      'tableType': _tableType == TableType.mock ? 'mock' : 'regular',
      'regularPeriods': regularPeriods, 'mockPeriods': mockPeriods,
      'noticeSections': noticeSections, 'examTitle': examTitle,
      'isDateAutomatic': _isDateAutomatic, 'manualDateText': _manualDateText,
      'noticeFontSize': _noticeFontSize, 'tableCellFontSize': _tableCellFontSize,
      'tableHeaderFontSize': _tableHeaderFontSize, 'clockNumberSize': _clockNumberSize,
      'rColW1': _rColW1, 'rColW2': _rColW2, 'rColW3': _rColW3, 'rColW4': _rColW4,
      'mColW1': _mColW1, 'mColW2': _mColW2, 'mColW3': _mColW3, 'mColW4': _mColW4, 'mColW5': _mColW5,
      'noticeRowHeight': _noticeRowHeight, 'tableRowHeight': _tableRowHeight,
      'dateFontSize': _dateFontSize, 'clockType': _clockType,
      'burnInInterval': _burnInIntervalMinutes,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 8), Text('저장되었습니다.'),
        ]),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
    }
  }

  // ── 다이얼로그 헬퍼 ──
  Future<String?> _showEditDialog(BuildContext ctx, String current, {String title = '내용 수정'}) {
    if (!_isAdminMode) return Future.value(null);
    final c = TextEditingController(text: current);
    return showDialog<String>(
      context: ctx,
      builder: (cx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: c, autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 18), maxLines: null,
          decoration: const InputDecoration(
            labelText: '내용 입력', labelStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.lightBlueAccent)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(cx, c.text),
              child: const Text('확인', style: TextStyle(color: Colors.lightBlueAccent))),
          TextButton(onPressed: () => Navigator.pop(cx),
              child: const Text('취소', style: TextStyle(color: Colors.grey))),
        ],
      ),
    );
  }

  // ── 관리자 비밀번호 다이얼로그 ──
  Future<void> _showAdminDialog() async {
    if (_isAdminMode) {
      await showDialog(
        context: context, barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.lock_open, color: Colors.greenAccent), SizedBox(width: 8),
            Text('관리자 모드 해제', style: TextStyle(color: Colors.white)),
          ]),
          content: const Text('편집 모드를 종료하고 터치 잠금을 활성화합니다.', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () { setState(() => _isAdminMode = false); Navigator.pop(ctx); },
                child: const Text('잠금 활성화', style: TextStyle(color: Colors.redAccent))),
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: const Text('계속 편집', style: TextStyle(color: Colors.grey))),
          ],
        ),
      );
      return;
    }
    final pwCtrl = TextEditingController();
    String err = '';
    await showDialog(
      context: context, barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.admin_panel_settings, color: Colors.lightBlueAccent), SizedBox(width: 8),
          Text('관리자 인증', style: TextStyle(color: Colors.white)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('편집 모드를 활성화하려면\n관리자 비밀번호를 입력하세요.',
              style: TextStyle(color: Colors.white70, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          TextField(
            controller: pwCtrl, autofocus: true,
            obscureText: true, keyboardType: TextInputType.number, maxLength: 4,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 28, letterSpacing: 12),
            decoration: InputDecoration(
              counterText: '',
              hintText: '● ● ● ●', hintStyle: const TextStyle(color: Colors.white24, fontSize: 20),
              enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: err.isEmpty ? Colors.white30 : Colors.redAccent),
                  borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: err.isEmpty ? Colors.lightBlueAccent : Colors.redAccent, width: 2),
                  borderRadius: BorderRadius.circular(12)),
              filled: true, fillColor: Colors.white10,
            ),
            onSubmitted: (v) {
              if (v == AppDefaults.adminPassword) { setState(() => _isAdminMode = true); Navigator.pop(ctx); }
              else { ss(() => err = '비밀번호가 올바르지 않습니다.'); pwCtrl.clear(); }
            },
          ),
          if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 16), const SizedBox(width: 4),
              Text(err, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ])),
        ]),
        actions: [
          TextButton(onPressed: () {
            if (pwCtrl.text == AppDefaults.adminPassword) { setState(() => _isAdminMode = true); Navigator.pop(ctx); }
            else { ss(() => err = '비밀번호가 올바르지 않습니다.'); pwCtrl.clear(); }
          }, child: const Text('확인', style: TextStyle(color: Colors.lightBlueAccent))),
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('취소', style: TextStyle(color: Colors.grey))),
        ],
      )),
    );
  }

  // ── 고사명 드롭다운 다이얼로그 ──
  Future<void> _showExamNameDialog() async {
    if (!_isAdminMode) return;
    ExamType tmpType     = _examType;
    int      tmpYear     = _examYear;
    int      tmpMonth    = _examMonth;
    int      tmpSemester = _examSemester;
    int      tmpRound    = _examRound;
    final customCtrl = TextEditingController(text: _examCustomName);
    final currentYear = DateTime.now().year;
    final yearList = List.generate(5, (i) => currentYear - 1 + i);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) {
        String preview;
        if (tmpType == ExamType.regular) {
          preview = '$tmpYear학년도 ${tmpSemester == 1 ? '1학기' : '2학기'} $tmpRound차 정기고사';
        } else {
          final extra = customCtrl.text.isNotEmpty ? ' ${customCtrl.text}' : '';
          preview = '$tmpYear학년도 $tmpMonth월 전국연합 학력평가$extra';
        }
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.edit_note, color: Colors.lightBlueAccent), SizedBox(width: 8),
            Text('고사명 설정', style: TextStyle(color: Colors.white)),
          ]),
          content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dlgLabel('고사 유형'),
              _dropdownBox(child: DropdownButton<ExamType>(
                value: tmpType, isExpanded: true, dropdownColor: const Color(0xFF1A1A2E),
                underline: const SizedBox.shrink(), style: const TextStyle(color: Colors.white, fontSize: 16),
                items: const [
                  DropdownMenuItem(value: ExamType.regular,  child: Text('정기고사')),
                  DropdownMenuItem(value: ExamType.national, child: Text('전국연합 학력평가')),
                ],
                onChanged: (v) { if (v != null) ss(() => tmpType = v); },
              )),
              const SizedBox(height: 12),
              _dlgLabel('학년도'),
              _dropdownBox(child: DropdownButton<int>(
                value: tmpYear, isExpanded: true, dropdownColor: const Color(0xFF1A1A2E),
                underline: const SizedBox.shrink(), style: const TextStyle(color: Colors.white, fontSize: 16),
                items: yearList.map((y) => DropdownMenuItem(value: y, child: Text('$y학년도'))).toList(),
                onChanged: (v) { if (v != null) ss(() => tmpYear = v); },
              )),
              const SizedBox(height: 12),
              if (tmpType == ExamType.regular) ...[
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _dlgLabel('학기'),
                    _dropdownBox(child: DropdownButton<int>(
                      value: tmpSemester, isExpanded: true, dropdownColor: const Color(0xFF1A1A2E),
                      underline: const SizedBox.shrink(), style: const TextStyle(color: Colors.white, fontSize: 16),
                      items: const [DropdownMenuItem(value:1,child:Text('1학기')),DropdownMenuItem(value:2,child:Text('2학기'))],
                      onChanged: (v) { if (v != null) ss(() => tmpSemester = v); },
                    )),
                  ])),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _dlgLabel('차수'),
                    _dropdownBox(child: DropdownButton<int>(
                      value: tmpRound, isExpanded: true, dropdownColor: const Color(0xFF1A1A2E),
                      underline: const SizedBox.shrink(), style: const TextStyle(color: Colors.white, fontSize: 16),
                      items: const [DropdownMenuItem(value:1,child:Text('1차')),DropdownMenuItem(value:2,child:Text('2차')),DropdownMenuItem(value:3,child:Text('3차')),DropdownMenuItem(value:4,child:Text('4차'))],
                      onChanged: (v) { if (v != null) ss(() => tmpRound = v); },
                    )),
                  ])),
                ]),
              ],
              if (tmpType == ExamType.national) ...[
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _dlgLabel('시행 월'),
                    _dropdownBox(child: DropdownButton<int>(
                      value: tmpMonth, isExpanded: true, dropdownColor: const Color(0xFF1A1A2E),
                      underline: const SizedBox.shrink(), style: const TextStyle(color: Colors.white, fontSize: 16),
                      items: [3,4,5,6,7,9,10,11].map((m) => DropdownMenuItem(value:m, child:Text('$m월'))).toList(),
                      onChanged: (v) { if (v != null) ss(() => tmpMonth = v); },
                    )),
                  ])),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _dlgLabel('추가 문구 (선택)'),
                    TextField(
                      controller: customCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: '예: (고3)',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                        filled: true, fillColor: Colors.white10,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      onChanged: (v) => ss(() {}),
                    ),
                  ])),
                ]),
              ],
              const SizedBox(height: 16),
              Container(
                width: double.infinity, padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.lightBlueAccent.withValues(alpha: 0.4))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('미리보기', style: TextStyle(color: Colors.lightBlueAccent, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(preview, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                ]),
              ),
            ],
          ))),
          actions: [
            TextButton(onPressed: () {
              setState(() {
                final prevType = _examType;
                _examType = tmpType; _examYear = tmpYear; _examMonth = tmpMonth;
                _examSemester = tmpSemester; _examRound = tmpRound;
                _examCustomName = customCtrl.text;
                examName = _builtExamName;
                // ── 고사 유형 변경 시 시간표 자동 전환 ──
                if (prevType != _examType) {
                  if (_examType == ExamType.regular) {
                    _tableType = TableType.regular; // 정기고사 → 정기고사용 시간표
                  } else {
                    _tableType = TableType.mock;    // 전국연합 → 모의고사용 시간표
                  }
                }
              });
              Navigator.pop(ctx);
            }, child: const Text('적용', style: TextStyle(color: Colors.lightBlueAccent))),
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: const Text('취소', style: TextStyle(color: Colors.grey))),
          ],
        );
      }),
    );
  }

  Widget _dlgLabel(String t) => Padding(padding: const EdgeInsets.only(bottom: 4),
      child: Text(t, style: const TextStyle(color: Colors.white60, fontSize: 12)));

  Widget _dropdownBox({required Widget child}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white24)),
    child: child,
  );

  // ── 시험표 유형 선택 다이얼로그 ──
  Future<void> _showTableTypeDialog() async {
    if (!_isAdminMode) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.table_chart, color: Colors.lightBlueAccent), SizedBox(width: 8),
          Text('시험 시간표 유형 선택', style: TextStyle(color: Colors.white)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('시험 유형에 따라 표 형식이 달라집니다.', style: TextStyle(color: Colors.white60, fontSize: 13)),
          const SizedBox(height: 16),
          _typeOptionCard(
            icon: Icons.assignment, title: '정기고사용',
            desc: '교시 / 준비령 / 시간 / 과목 (4열)',
            selected: _tableType == TableType.regular,
            onTap: () { setState(() => _tableType = TableType.regular); Navigator.pop(ctx); },
          ),
          const SizedBox(height: 10),
          _typeOptionCard(
            icon: Icons.assessment, title: '모의고사용',
            desc: '교시 / 과목 / 준비령 / 본령 / 종료령 (5열)',
            selected: _tableType == TableType.mock,
            onTap: () { setState(() => _tableType = TableType.mock); Navigator.pop(ctx); },
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('닫기', style: TextStyle(color: Colors.grey))),
        ],
      ),
    );
  }

  Widget _typeOptionCard({required IconData icon, required String title, required String desc,
      required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? Colors.lightBlueAccent.withValues(alpha: 0.15) : Colors.white10,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? Colors.lightBlueAccent : Colors.white24, width: selected ? 2 : 1),
        ),
        child: Row(children: [
          Icon(icon, color: selected ? Colors.lightBlueAccent : Colors.white54, size: 28),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: selected ? Colors.lightBlueAccent : Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ])),
          if (selected) const Icon(Icons.check_circle, color: Colors.lightBlueAccent, size: 20),
        ]),
      ),
    );
  }

  // ── 유의사항 편집 ──
  Future<void> _editNoticeItem(int sIdx, int iIdx) async {
    if (!_isAdminMode) return;
    final r = await _showEditDialog(context, noticeSections[sIdx]['items'][iIdx]['text'] as String, title: '유의사항 수정');
    if (r != null) setState(() => noticeSections[sIdx]['items'][iIdx]['text'] = r);
  }

  Future<void> _editSectionTitle(int sIdx) async {
    if (!_isAdminMode) return;
    final r = await _showEditDialog(context, noticeSections[sIdx]['title'] as String, title: '섹션 제목 수정');
    if (r != null) setState(() => noticeSections[sIdx]['title'] = r);
  }

  void _cycleItemColor(int sIdx, int iIdx) {
    if (!_isAdminMode) return;
    const cols = ['white','red','cyan','yellow','green','orange'];
    final cur = noticeSections[sIdx]['items'][iIdx]['color'] as String;
    setState(() => noticeSections[sIdx]['items'][iIdx]['color'] = cols[(cols.indexOf(cur)+1)%cols.length]);
  }

  void _toggleItemBold(int sIdx, int iIdx) {
    if (!_isAdminMode) return;
    final cur = noticeSections[sIdx]['items'][iIdx]['bold'] as bool;
    setState(() => noticeSections[sIdx]['items'][iIdx]['bold'] = !cur);
  }

  Future<void> _editExamDate() async {
    if (!_isAdminMode) return;
    await showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('날짜 설정', style: TextStyle(color: Colors.white)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Icon(_isDateAutomatic ? Icons.sync : Icons.edit,
                color: _isDateAutomatic ? Colors.greenAccent : Colors.orangeAccent, size: 18),
            const SizedBox(width: 8),
            Text(_isDateAutomatic ? '현재: 실시간 자동 날짜' : '현재: 수동 입력 날짜',
                style: TextStyle(color: _isDateAutomatic ? Colors.greenAccent : Colors.orangeAccent, fontSize: 13)),
          ]),
        ),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade800, padding: const EdgeInsets.symmetric(vertical: 12)),
          icon: const Icon(Icons.sync, color: Colors.white),
          label: const Text('실시간 자동 날짜 사용', style: TextStyle(color: Colors.white)),
          onPressed: () { setState(() { _isDateAutomatic = true; _manualDateText = ''; }); Navigator.pop(ctx); },
        )),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey.shade700, padding: const EdgeInsets.symmetric(vertical: 12)),
          icon: const Icon(Icons.edit, color: Colors.white),
          label: const Text('직접 입력하기', style: TextStyle(color: Colors.white)),
          onPressed: () async {
            Navigator.pop(ctx);
            final r = await _showEditDialog(context, examDateText, title: '날짜 직접 입력 (예: 9월 26일 (목))');
            if (r != null && r.isNotEmpty) setState(() { _isDateAutomatic = false; _manualDateText = r; });
          },
        )),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('닫기', style: TextStyle(color: Colors.grey)))],
    ));
  }

  // ── 정기고사 셀 편집 ──
  Future<void> _editRegularCell(int idx, String field) async {
    if (!_isAdminMode) return;
    final p = regularPeriods[idx];
    final cur   = field == 'period' ? p.period : field == 'ready' ? p.ready : field == 'time' ? p.time : p.subject;
    final title = field == 'period' ? '교시 수정' : field == 'ready' ? '준비령 수정 (예: 08:50)' : field == 'time' ? '시간 수정 (예: 09:00 ~ 09:50)' : '과목 수정';
    final r = await _showEditDialog(context, cur, title: title);
    if (r != null) {
      setState(() {
        if (field == 'period') {
          regularPeriods[idx].period = r;
        } else if (field == 'ready') {
          regularPeriods[idx].ready = r;
        } else if (field == 'time') {
          regularPeriods[idx].time = r;
        } else {
          regularPeriods[idx].subject = r;
        }
      });
    }
  }

  // ── 모의고사 셀 편집 ──
  Future<void> _editMockCell(int idx, String field) async {
    if (!_isAdminMode) return;
    final p = mockPeriods[idx];
    final cur   = field == 'period' ? p.period : field == 'subject' ? p.subject : field == 'ready' ? p.ready : field == 'start' ? p.start : p.end;
    final title = field == 'period' ? '교시 수정' : field == 'subject' ? '과목 수정' : field == 'ready' ? '준비령 수정 (예: 08:35)' : field == 'start' ? '본령 수정 (예: 08:40)' : '종료령 수정 (예: 10:00)';
    final r = await _showEditDialog(context, cur, title: title);
    if (r != null) {
      setState(() {
        if (field == 'period') {
          mockPeriods[idx].period = r;
        } else if (field == 'subject') {
          mockPeriods[idx].subject = r;
        } else if (field == 'ready') {
          mockPeriods[idx].ready = r;
        } else if (field == 'start') {
          mockPeriods[idx].start = r;
        } else {
          mockPeriods[idx].end = r;
        }
      });
    }
  }

  void _addRegularRow()  { if (!_isAdminMode) return; setState(() => regularPeriods.add(RegularPeriod(period: '${regularPeriods.length+1}교시', ready: '00:00', time: '00:00 ~ 00:00', subject: '과목'))); }
  void _removeRegularRow() { if (!_isAdminMode || regularPeriods.length <= 1) return; setState(() => regularPeriods.removeLast()); }
  void _addMockRow()    { if (!_isAdminMode) return; setState(() => mockPeriods.add(MockPeriod(period: '', subject: '과목', ready: '', start: '00:00', end: '00:00'))); }
  void _removeMockRow() { if (!_isAdminMode || mockPeriods.length <= 1) return; setState(() => mockPeriods.removeLast()); }
  void _addNoticeItem(int sIdx)    { if (!_isAdminMode) return; setState(() => (noticeSections[sIdx]['items'] as List).add({'text': '새 항목 (탭하여 수정)', 'color': 'white', 'bold': false})); }
  void _removeNoticeItem(int sIdx) { if (!_isAdminMode) return; final items = noticeSections[sIdx]['items'] as List; if (items.length > 1) setState(() => items.removeLast()); }
  void _addNoticeSection()    { if (!_isAdminMode) return; setState(() => noticeSections.add({'title': '새 섹션', 'items': [{'text': '새 항목 (탭하여 수정)', 'color': 'white', 'bold': false}]})); }
  void _removeNoticeSection() { if (!_isAdminMode || noticeSections.length <= 1) return; setState(() => noticeSections.removeLast()); }

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
  // BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: Colors.black,
        body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircularProgressIndicator(color: Colors.white54), SizedBox(height: 16),
          Text('불러오는 중...', style: TextStyle(color: Colors.white54)),
        ])));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (_isAdminMode) {
          await showDialog(context: context, builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('앱 종료', style: TextStyle(color: Colors.white)),
            content: const Text('앱을 종료하시겠습니까?', style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(onPressed: () { Navigator.pop(ctx); SystemNavigator.pop(); },
                  child: const Text('종료', style: TextStyle(color: Colors.redAccent))),
              TextButton(onPressed: () => Navigator.pop(ctx),
                  child: const Text('취소', style: TextStyle(color: Colors.grey))),
            ],
          ));
        }
      },
      child: GestureDetector(
        onTapDown: (_) { if (!_burnInActive) _resetBurnInTimer(); },
        onPanDown: (_) { if (!_burnInActive) _resetBurnInTimer(); },
        behavior: HitTestBehavior.translucent,
        child: Stack(children: [
          Scaffold(
            backgroundColor: Colors.black,
            body: Column(children: [
              _buildExamNameBar(),
              _buildStatusBar(),
              Expanded(child: _examType == ExamType.national
                  ? _buildNationalLayout()   // 전국연합: 시계가 좌측 유의사항 위
                  : _buildRegularLayout()),  // 정기고사: 시계가 우측 시간표 상단
              if (_isAdminMode) _buildControlBar(),
              _buildBottomBar(),
            ]),
          ),
          // ── 번인 방지 오버레이 ──
          if (_burnInActive)
            GestureDetector(
              onTap: _deactivateBurnIn,
              child: Container(
                color: _burnInInverted ? Colors.white : Colors.black,
                child: Stack(children: [
                  Positioned(
                    left: MediaQuery.of(context).size.width * _burnInX,
                    top:  MediaQuery.of(context).size.height * _burnInY,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      _buildBurnInContent(),
                      const SizedBox(height: 6),
                      Text(examDateText, style: TextStyle(color: _burnInInverted ? Colors.black38 : Colors.white30, fontSize: 13)),
                      const SizedBox(height: 3),
                      Text(_burnInPhase == 2 ? '색상 반전 모드 (번인 방지)' : '화면을 터치하면 복귀합니다',
                          style: TextStyle(color: _burnInInverted ? Colors.black26 : Colors.white24, fontSize: 11)),
                    ]),
                  ),
                ]),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _buildBurnInContent() {
    if (_burnInPhase == 2) return DigitalClock(fontSize: 36, dimmed: false, inverted: true);
    return _clockType == 'analog'
        ? SizedBox(width: 160, height: 160, child: AnalogClock(clockNumberSize: 12))
        : DigitalClock(fontSize: 40, dimmed: true);
  }

  // ─────────────────────────────────────────────
  // 레이아웃: 정기고사용 (시계 우측 시간표 상단)
  // ─────────────────────────────────────────────
  Widget _buildRegularLayout() {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // 좌측: 유의사항 패널
      Expanded(flex: 5, child: _buildNoticePanel()),
      Container(width: 2, color: Colors.white24),
      // 우측: 시계(최상단) + 날짜 헤더 + 시간표
      Expanded(flex: 5, child: Column(children: [
        // 시계 영역 (날짜 헤더 위, 우측 최상단)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _buildClockTypeToggle(),
            const SizedBox(height: 4),
            SizedBox(
              height: 160,
              child: Center(child: _clockType == 'analog'
                  ? AnalogClock(clockNumberSize: _clockNumberSize)
                  : DigitalClock(fontSize: _clockNumberSize * 2.5)),
            ),
          ]),
        ),
        // 날짜 헤더 (시계 아래)
        _buildDateHeader(),
        // 시간표 (날짜 아래)
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: _buildExamTable()),
        const Spacer(),
        // made by 상윤T
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text('made by 상윤T',
            style: const TextStyle(color: Colors.white24, fontSize: 11, fontStyle: FontStyle.italic, letterSpacing: 1.0),
          ),
        ),
      ])),
    ]);
  }

  // ─────────────────────────────────────────────
  // 레이아웃: 전국연합용 (시계 우측 날짜 헤더 위 — 정기고사와 동일)
  // ─────────────────────────────────────────────
  Widget _buildNationalLayout() {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // 좌측: 유의사항 패널
      Expanded(flex: 5, child: _buildNoticePanel()),
      Container(width: 2, color: Colors.white24),
      // 우측: 시계(최상단) + 날짜 헤더 + 시간표 + made by 상윤T
      Expanded(flex: 5, child: Column(children: [
        // 시계 영역 (날짜 헤더 위, 우측 최상단)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _buildClockTypeToggle(),
            const SizedBox(height: 4),
            SizedBox(
              height: 160,
              child: Center(child: _clockType == 'analog'
                  ? AnalogClock(clockNumberSize: _clockNumberSize)
                  : DigitalClock(fontSize: _clockNumberSize * 2.5)),
            ),
          ]),
        ),
        // 날짜 헤더 (시계 아래)
        _buildDateHeader(),
        // 시간표 (날짜 아래)
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: _buildExamTable()),
        const Spacer(),
        // made by 상윤T
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text('made by 상윤T',
            style: const TextStyle(color: Colors.white24, fontSize: 11, fontStyle: FontStyle.italic, letterSpacing: 1.0),
          ),
        ),
      ])),
    ]);
  }

  // ── 시계 전환 버튼 ──
  Widget _buildClockTypeToggle() {
    return GestureDetector(
      onTap: _isAdminMode ? () => setState(() => _clockType = _clockType == 'analog' ? 'digital' : 'analog') : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: _isAdminMode ? Colors.blueGrey.shade800.withValues(alpha: 0.8) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: _isAdminMode ? Border.all(color: Colors.white24) : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(_clockType == 'analog' ? Icons.watch : Icons.access_time,
              color: _isAdminMode ? Colors.white70 : Colors.white24, size: 14),
          const SizedBox(width: 4),
          Text(_clockType == 'analog' ? '아날로그' : '디지털',
              style: TextStyle(color: _isAdminMode ? Colors.white70 : Colors.white24, fontSize: 11)),
          if (_isAdminMode) ...[const SizedBox(width: 4), const Icon(Icons.swap_horiz, color: Colors.lightBlueAccent, size: 14)],
        ]),
      ),
    );
  }

  // ── 고사명 바 ──
  Widget _buildExamNameBar() {
    return GestureDetector(
      onTap: _showExamNameDialog,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D1A),
          border: const Border(bottom: BorderSide(color: Colors.white24, width: 1)),
          boxShadow: _isAdminMode ? [BoxShadow(color: Colors.greenAccent.withValues(alpha: 0.15), blurRadius: 6)] : null,
        ),
        child: Stack(alignment: Alignment.center, children: [
          Text(examName.isEmpty ? '고사명을 입력하세요' : examName,
            style: TextStyle(color: examName.isEmpty ? Colors.white38 : Colors.white,
                fontSize: _examNameFontSize, fontWeight: FontWeight.bold, letterSpacing: 2.0),
            textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
          if (_isAdminMode) Positioned(right: 0, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.green.shade900, borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4))),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.arrow_drop_down, color: Colors.greenAccent, size: 16),
              Text('고사명 변경', style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
            ]),
          )),
        ]),
      ),
    );
  }

  // ── 관리자 상태 바 ──
  Widget _buildStatusBar() {
    if (!_isAdminMode) return const SizedBox.shrink();
    return Container(
      width: double.infinity, color: const Color(0xFF1A2A1A),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Row(children: [
        const Icon(Icons.edit, color: Colors.greenAccent, size: 14),
        const SizedBox(width: 6),
        const Text('관리자 편집 모드 활성화 중', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
        const Spacer(),
        _miniBtn(Icons.save, '저장', Colors.green.shade700, _saveData),
        const SizedBox(width: 8),
        _miniBtn(Icons.lock, '잠금', Colors.blueGrey.shade700, _showAdminDialog),
      ]),
    );
  }

  Widget _miniBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 14), const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ]),
    ));
  }

  // ── 유의사항 패널 ──
  Widget _buildNoticePanel() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white38, width: 1))),
          child: Text(_noticeTitle, style: TextStyle(
            color: Colors.white, fontSize: _noticeFontSize + 4, fontWeight: FontWeight.bold, letterSpacing: 1.5,
          ), textAlign: TextAlign.center),
        ),
        const SizedBox(height: 4),
        Expanded(child: SingleChildScrollView(child: Table(
          border: TableBorder.all(color: Colors.white54, width: 0.8),
          columnWidths: const {0: FixedColumnWidth(52), 1: FlexColumnWidth(1)},
          children: _buildNoticeRows(),
        ))),
      ]),
    );
  }

  List<TableRow> _buildNoticeRows() {
    final rows = <TableRow>[];
    for (int sIdx = 0; sIdx < noticeSections.length; sIdx++) {
      final section = noticeSections[sIdx];
      final items = section['items'] as List<dynamic>;
      for (int iIdx = 0; iIdx < items.length; iIdx++) {
        final item  = items[iIdx];
        final color = _parseColor(item['color'] as String);
        final bold  = item['bold'] as bool;
        rows.add(TableRow(children: [
          GestureDetector(onTap: () => _editSectionTitle(sIdx),
            child: Container(height: _noticeRowHeight, alignment: Alignment.center, color: const Color(0xFF0D0D0D),
              child: iIdx == 0 ? Text(section['title'] as String,
                style: TextStyle(color: Colors.white, fontSize: _noticeFontSize - 1, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center) : const SizedBox.shrink())),
          GestureDetector(
            onTap: () => _editNoticeItem(sIdx, iIdx),
            onLongPress: () => _cycleItemColor(sIdx, iIdx),
            onDoubleTap: () => _toggleItemBold(sIdx, iIdx),
            child: Container(
              height: _noticeRowHeight, alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Text(item['text'] as String,
                style: TextStyle(color: color, fontSize: _noticeFontSize,
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal),
                overflow: TextOverflow.ellipsis, maxLines: 2),
            )),
        ]));
      }
    }
    return rows;
  }

  // ── 날짜 헤더 ──
  Widget _buildDateHeader() {
    return GestureDetector(
      onTap: _editExamDate,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white38, width: 1))),
        child: Stack(alignment: Alignment.center, children: [
          Text('$examDateText  $examTitle',
            style: TextStyle(color: Colors.white, fontSize: _dateFontSize, fontWeight: FontWeight.bold, letterSpacing: 1.5),
            textAlign: TextAlign.center),
          Positioned(right: 0, child: Icon(_isDateAutomatic ? Icons.sync : Icons.edit,
              color: _isDateAutomatic ? Colors.greenAccent : Colors.orangeAccent, size: 16)),
        ]),
      ),
    );
  }

  // ── 시험 시간표 (유형 드롭다운 포함) ──
  Widget _buildExamTable() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // 유형 선택 헤더
      GestureDetector(
        onTap: _showTableTypeDialog,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
          decoration: BoxDecoration(
            color: _tableType == TableType.mock ? const Color(0xFF1A2A1A) : const Color(0xFF1A1A2E),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
            border: Border.all(color: Colors.white38, width: 1),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(_tableType == TableType.mock ? Icons.assessment : Icons.assignment,
                color: _tableType == TableType.mock ? Colors.greenAccent : Colors.lightBlueAccent, size: 16),
            const SizedBox(width: 6),
            Text(_tableType == TableType.mock ? '모의고사용 시간표' : '정기고사용 시간표',
              style: TextStyle(
                color: _tableType == TableType.mock ? Colors.greenAccent : Colors.lightBlueAccent,
                fontSize: 13, fontWeight: FontWeight.bold,
              )),
            if (_isAdminMode) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white12, borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.swap_horiz, color: Colors.white60, size: 12),
                  SizedBox(width: 2),
                  Text('유형 변경', style: TextStyle(color: Colors.white60, fontSize: 10)),
                ]),
              ),
            ],
          ]),
        ),
      ),
      // 표 본체
      _tableType == TableType.regular ? _buildRegularTable() : _buildMockTable(),
    ]);
  }

  // ── 정기고사 시간표: 교시 / 준비령 / 시간 / 과목 ──
  Widget _buildRegularTable() {
    return Table(
      border: TableBorder.all(color: Colors.white, width: 1.5),
      columnWidths: {
        0: FixedColumnWidth(_rColW1), 1: FixedColumnWidth(_rColW2),
        2: FixedColumnWidth(_rColW3), 3: FixedColumnWidth(_rColW4),
      },
      children: [
        TableRow(decoration: const BoxDecoration(color: Color(0xFF1A1A2E)), children: [
          _hdrCell('교  시'), _hdrCell('준비령'), _hdrCell('시  간'), _hdrCell('과  목'),
        ]),
        ...List.generate(regularPeriods.length, (i) {
          final p = regularPeriods[i];
          return TableRow(children: [
            _editCell(p.period,  () => _editRegularCell(i, 'period')),
            _editCell(p.ready,   () => _editRegularCell(i, 'ready')),
            _editCell(p.time,    () => _editRegularCell(i, 'time')),
            _editCell(p.subject, () => _editRegularCell(i, 'subject')),
          ]);
        }),
      ],
    );
  }

  // ── 모의고사 시간표: 교시 / 과목 / 준비령 / 본령 / 종료령 ──
  Widget _buildMockTable() {
    return Table(
      border: TableBorder.all(color: Colors.white, width: 1.5),
      columnWidths: {
        0: FixedColumnWidth(_mColW1), 1: FixedColumnWidth(_mColW2),
        2: FixedColumnWidth(_mColW3), 3: FixedColumnWidth(_mColW4),
        4: FixedColumnWidth(_mColW5),
      },
      children: [
        TableRow(decoration: const BoxDecoration(color: Color(0xFF1A2A1A)), children: [
          _hdrCell('교  시'), _hdrCell('과  목'), _hdrCell('준비령'), _hdrCell('본  령'), _hdrCell('종료령'),
        ]),
        ...List.generate(mockPeriods.length, (i) {
          final p = mockPeriods[i];
          // 교시 셀: 동일한 교시는 배경색으로 구분
          return TableRow(children: [
            _editCell(p.period,  () => _editMockCell(i, 'period')),
            _editCell(p.subject, () => _editMockCell(i, 'subject')),
            _editCell(p.ready,   () => _editMockCell(i, 'ready')),
            _editCell(p.start,   () => _editMockCell(i, 'start')),
            _editCell(p.end,     () => _editMockCell(i, 'end')),
          ]);
        }),
      ],
    );
  }

  Widget _hdrCell(String t) => Container(height: _tableRowHeight, alignment: Alignment.center,
    child: Text(t, style: TextStyle(color: Colors.white, fontSize: _tableHeaderFontSize, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center));

  Widget _editCell(String t, VoidCallback onTap) => GestureDetector(onTap: onTap,
    child: Container(height: _tableRowHeight, alignment: Alignment.center,
      child: Text(t, style: TextStyle(color: Colors.white, fontSize: _tableCellFontSize, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center)));

  // ── 조절 버튼 바 (관리자 모드) ──
  Widget _buildControlBar() {
    final isMock = _tableType == TableType.mock;
    return Container(
      color: const Color(0xFF111111),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _cg('고사명 글자', [
            _cb(Icons.text_increase, () => setState(() => _examNameFontSize += 1)),
            _cb(Icons.text_decrease, () => setState(() { if (_examNameFontSize > 12) _examNameFontSize -= 1; })),
          ]),
          _d(),
          _cg('유의사항 글자', [
            _cb(Icons.text_increase, () => setState(() => _noticeFontSize += 1)),
            _cb(Icons.text_decrease, () => setState(() { if (_noticeFontSize > 8) _noticeFontSize -= 1; })),
          ]),
          _d(),
          _cg('유의사항 행높이', [
            _cb(Icons.arrow_upward,   () => setState(() => _noticeRowHeight += 4)),
            _cb(Icons.arrow_downward, () => setState(() { if (_noticeRowHeight > 18) _noticeRowHeight -= 4; })),
          ]),
          _d(),
          _cg('시간표 글자', [
            _cb(Icons.text_increase, () => setState(() { _tableCellFontSize += 1; _tableHeaderFontSize += 1; })),
            _cb(Icons.text_decrease, () => setState(() { if (_tableCellFontSize > 8) { _tableCellFontSize -= 1; _tableHeaderFontSize -= 1; } })),
          ]),
          _d(),
          _cg('시간표 행높이', [
            _cb(Icons.arrow_upward,   () => setState(() => _tableRowHeight += 4)),
            _cb(Icons.arrow_downward, () => setState(() { if (_tableRowHeight > 24) _tableRowHeight -= 4; })),
          ]),
          _d(),
          // 열 너비 조절 (현재 유형에 따라)
          if (!isMock) ...[
            _cg('교시폭', [_cb(Icons.add, () => setState(()=>_rColW1+=8)), _cb(Icons.remove, () => setState((){if(_rColW1>30)_rColW1-=8;}))]), _d(),
            _cg('준비령폭', [_cb(Icons.add, () => setState(()=>_rColW2+=8)), _cb(Icons.remove, () => setState((){if(_rColW2>40)_rColW2-=8;}))]), _d(),
            _cg('시간폭', [_cb(Icons.add, () => setState(()=>_rColW3+=8)), _cb(Icons.remove, () => setState((){if(_rColW3>60)_rColW3-=8;}))]), _d(),
            _cg('과목폭', [_cb(Icons.add, () => setState(()=>_rColW4+=8)), _cb(Icons.remove, () => setState((){if(_rColW4>40)_rColW4-=8;}))]), _d(),
          ] else ...[
            _cg('교시폭', [_cb(Icons.add, () => setState(()=>_mColW1+=8)), _cb(Icons.remove, () => setState((){if(_mColW1>30)_mColW1-=8;}))]), _d(),
            _cg('과목폭', [_cb(Icons.add, () => setState(()=>_mColW2+=8)), _cb(Icons.remove, () => setState((){if(_mColW2>40)_mColW2-=8;}))]), _d(),
            _cg('준비령폭', [_cb(Icons.add, () => setState(()=>_mColW3+=8)), _cb(Icons.remove, () => setState((){if(_mColW3>35)_mColW3-=8;}))]), _d(),
            _cg('본령폭', [_cb(Icons.add, () => setState(()=>_mColW4+=8)), _cb(Icons.remove, () => setState((){if(_mColW4>35)_mColW4-=8;}))]), _d(),
            _cg('종료령폭', [_cb(Icons.add, () => setState(()=>_mColW5+=8)), _cb(Icons.remove, () => setState((){if(_mColW5>35)_mColW5-=8;}))]), _d(),
          ],
          _cg('날짜 글자', [
            _cb(Icons.text_increase, () => setState(() => _dateFontSize += 1)),
            _cb(Icons.text_decrease, () => setState(() { if (_dateFontSize > 12) _dateFontSize -= 1; })),
          ]),
          _d(),
          _cg('시계 숫자', [
            _cb(Icons.text_increase, () => setState(() => _clockNumberSize += 1)),
            _cb(Icons.text_decrease, () => setState(() { if (_clockNumberSize > 10) _clockNumberSize -= 1; })),
          ]),
          _d(),
          _cg('시계 유형', [
            GestureDetector(
              onTap: () => setState(() => _clockType = _clockType == 'analog' ? 'digital' : 'analog'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _clockType == 'analog' ? Colors.indigo.shade700 : Colors.teal.shade700,
                  borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white30),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_clockType == 'analog' ? Icons.watch : Icons.access_time, color: Colors.white, size: 13),
                  const SizedBox(width: 4),
                  Text(_clockType == 'analog' ? '아날로그' : '디지털', style: const TextStyle(color: Colors.white, fontSize: 11)),
                ]),
              ),
            ),
          ]),
          _d(),
          _cg('번인방지(분)', [
            _cb(Icons.add,    () => setState(() => _burnInIntervalMinutes = (_burnInIntervalMinutes + 5).clamp(5, 120))),
            _cb(Icons.remove, () => setState(() => _burnInIntervalMinutes = (_burnInIntervalMinutes - 5).clamp(5, 120))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text('$_burnInIntervalMinutes분', style: const TextStyle(color: Colors.white70, fontSize: 11))),
          ]),
          _d(),
          _cg('번인테스트', [
            GestureDetector(
              onTap: () { _burnInTimer?.cancel(); _activateBurnIn(); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.deepPurple.shade700, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white30)),
                child: const Text('테스트', style: TextStyle(color: Colors.white, fontSize: 11)),
              ),
            ),
          ]),
          _d(),
          _cg(!isMock ? '정기고사 행' : '모의고사 행', [
            _cb(Icons.add,    !isMock ? _addRegularRow : _addMockRow),
            _cb(Icons.remove, !isMock ? _removeRegularRow : _removeMockRow),
          ]),
          _d(),
          _cg('유의사항 섹션', [_cb(Icons.add, _addNoticeSection), _cb(Icons.remove, _removeNoticeSection)]),
          _d(),
          ...List.generate(noticeSections.length, (i) => Row(children: [
            _cg('${noticeSections[i]['title']} 항목', [_cb(Icons.add, () => _addNoticeItem(i)), _cb(Icons.remove, () => _removeNoticeItem(i))]),
            _d(),
          ])),
        ]),
      ),
    );
  }

  // ── 하단 바 ──
  Widget _buildBottomBar() {
    return Container(
      color: const Color(0xFF0A0A0A),
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        GestureDetector(
          onTap: _showAdminDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: _isAdminMode ? Colors.green.shade900 : const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _isAdminMode ? Colors.greenAccent : Colors.white24),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_isAdminMode ? Icons.lock_open : Icons.lock,
                  color: _isAdminMode ? Colors.greenAccent : Colors.white54, size: 16),
              const SizedBox(width: 6),
              Text(_isAdminMode ? '편집 모드 (탭하여 잠금)' : '잠금 상태 (탭하여 편집)',
                  style: TextStyle(color: _isAdminMode ? Colors.greenAccent : Colors.white54, fontSize: 13)),
            ]),
          ),
        ),
        if (_isAdminMode) ...[
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _saveData,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(color: Colors.green.shade800, borderRadius: BorderRadius.circular(20)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.save, color: Colors.white, size: 16), SizedBox(width: 6),
                Text('변경사항 저장', style: TextStyle(color: Colors.white, fontSize: 13)),
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _cg(String label, List<Widget> btns) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisSize: MainAxisSize.min, children: btns),
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
    ]),
  );

  Widget _cb(IconData icon, VoidCallback fn) => SizedBox(width: 32, height: 32,
    child: IconButton(padding: EdgeInsets.zero, iconSize: 18, icon: Icon(icon, color: Colors.white70), onPressed: fn));

  Widget _d() => Container(width: 1, height: 40, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 4));
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
      if (mounted) setState(() => _now = DateTime.now());
    });
  }
  @override
  void dispose() { _timer.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1.0,
    child: CustomPaint(painter: ClockPainter(clockNumberSize: widget.clockNumberSize, now: _now)),
  );
}

class ClockPainter extends CustomPainter {
  final double clockNumberSize;
  final DateTime now;
  ClockPainter({required this.clockNumberSize, required this.now});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2) * 0.92;

    canvas.drawCircle(center, radius, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 6.0);
    canvas.drawCircle(center, radius - 3, Paint()..color = const Color(0xFF0A0A0A));

    for (int i = 0; i < 60; i++) {
      final angle  = pi / 30 * i;
      final isHour = i % 5 == 0;
      final tickLen = isHour ? radius * 0.12 : radius * 0.05;
      canvas.drawLine(
        Offset(center.dx + (radius - tickLen) * cos(angle - pi/2), center.dy + (radius - tickLen) * sin(angle - pi/2)),
        Offset(center.dx + (radius - 3)       * cos(angle - pi/2), center.dy + (radius - 3)       * sin(angle - pi/2)),
        Paint()..color = isHour ? Colors.white : Colors.white54..strokeWidth = isHour ? 3.5 : 1.5,
      );
    }

    final tp = TextPainter(textAlign: TextAlign.center, textDirection: TextDirection.ltr);
    for (int i = 1; i <= 12; i++) {
      final angle = i * 30 * pi / 180;
      final x = center.dx + radius * 0.75 * cos(angle - pi/2);
      final y = center.dy + radius * 0.75 * sin(angle - pi/2);
      tp.text = TextSpan(text: '$i', style: TextStyle(color: Colors.white, fontSize: clockNumberSize, fontWeight: FontWeight.bold));
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width/2, y - tp.height/2));
    }

    void drawHand(double angle, double len, double width, Color color) {
      canvas.drawLine(
        Offset(center.dx - radius * 0.15 * cos(angle), center.dy - radius * 0.15 * sin(angle)),
        Offset(center.dx + radius * len   * cos(angle), center.dy + radius * len   * sin(angle)),
        Paint()..color = color..strokeWidth = width..strokeCap = StrokeCap.round,
      );
    }
    drawHand((now.hour % 12 + now.minute / 60 + now.second / 3600) * 30 * pi / 180 - pi/2, 0.50, 7.0, Colors.white);
    drawHand((now.minute + now.second / 60) * 6 * pi / 180 - pi/2, 0.72, 4.5, Colors.white);
    drawHand(now.second * 6 * pi / 180 - pi/2, 0.88, 2.0, Colors.red);
    canvas.drawCircle(center, 7, Paint()..color = Colors.white);
    canvas.drawCircle(center, 4, Paint()..color = Colors.red);
  }

  @override
  bool shouldRepaint(covariant ClockPainter old) => old.now != now || old.clockNumberSize != clockNumberSize;
}

// ─────────────────────────────────────────────
// 디지털 시계
// ─────────────────────────────────────────────
class DigitalClock extends StatefulWidget {
  final double fontSize;
  final bool dimmed;
  final bool inverted;
  const DigitalClock({super.key, required this.fontSize, this.dimmed = false, this.inverted = false});
  @override
  State<DigitalClock> createState() => _DigitalClockState();
}

class _DigitalClockState extends State<DigitalClock> {
  late Timer _timer;
  DateTime _now = DateTime.now();
  bool _colonVisible = true;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() { _now = DateTime.now(); _colonVisible = !_colonVisible; });
    });
  }
  @override
  void dispose() { _timer.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final h = _now.hour.toString().padLeft(2, '0');
    final m = _now.minute.toString().padLeft(2, '0');
    final s = _now.second.toString().padLeft(2, '0');
    final colon = _colonVisible ? ':' : ' ';
    Color baseColor, accentColor;
    if (widget.inverted)    { baseColor = Colors.black87; accentColor = Colors.red.shade800; }
    else if (widget.dimmed) { baseColor = Colors.white30; accentColor = Colors.redAccent.withValues(alpha: 0.5); }
    else                    { baseColor = Colors.white;   accentColor = Colors.redAccent; }

    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(h, style: TextStyle(color: baseColor, fontSize: widget.fontSize, fontWeight: FontWeight.w300, fontFamily: 'monospace', letterSpacing: 4)),
      Text(colon, style: TextStyle(color: accentColor, fontSize: widget.fontSize, fontWeight: FontWeight.w300)),
      Text(m, style: TextStyle(color: baseColor, fontSize: widget.fontSize, fontWeight: FontWeight.w300, fontFamily: 'monospace', letterSpacing: 4)),
      Text(colon, style: TextStyle(color: accentColor, fontSize: widget.fontSize, fontWeight: FontWeight.w300)),
      Text(s, style: TextStyle(color: baseColor, fontSize: widget.fontSize * 0.65, fontWeight: FontWeight.w300, fontFamily: 'monospace', letterSpacing: 2)),
    ]);
  }
}
