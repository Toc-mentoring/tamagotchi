// API 응답을 Dart 객체로 바꾼다 (docs/api-spec.md 공통 객체)

int _int(dynamic v) => (v as num?)?.toInt() ?? 0;
int? _intOrNull(dynamic v) => (v as num?)?.toInt();

const stageLabels = {'EGG': '알', 'BABY': '아기', 'TEEN': '청소년', 'ADULT': '어른'};
const stageImages = {
  'EGG': 'assets/images/momo_egg.png',
  'BABY': 'assets/images/momo_baby.png',
  'TEEN': 'assets/images/momo_teen.png',
  'ADULT': 'assets/images/momo_adult.png',
};

class StageProgress {
  StageProgress.fromJson(Map<String, dynamic> j)
      : currentSteps = _int(j['currentSteps']),
        requiredSteps = _intOrNull(j['requiredSteps']),
        remainingSteps = _intOrNull(j['remainingSteps']),
        percent = _intOrNull(j['percent']),
        nextStage = j['nextStage'] as String?;
  final int currentSteps;
  final int? requiredSteps;
  final int? remainingSteps;
  final int? percent; // 어른이면 null
  final String? nextStage;
}

class PetStats {
  PetStats.fromJson(Map<String, dynamic> j)
      : satiety = _int(j['satiety']),
        happiness = _int(j['happiness']),
        cleanliness = _int(j['cleanliness']),
        health = _int(j['health']);
  final int satiety;
  final int happiness;
  final int cleanliness;
  final int health;
}

class Pet {
  Pet.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        name = j['name'] as String,
        stage = j['stage'] as String,
        growthSteps = _int(j['growthSteps']),
        progress = StageProgress.fromJson(j['stageProgress'] as Map<String, dynamic>),
        stats = j['stats'] == null ? null : PetStats.fromJson(j['stats'] as Map<String, dynamic>),
        createdAt = DateTime.parse(j['createdAt'] as String);
  final String id;
  final String name;
  final String stage; // EGG, BABY, TEEN, ADULT
  final int growthSteps;
  final StageProgress progress;
  final PetStats? stats; // 알이면 null
  final DateTime createdAt;

  String get stageLabel => stageLabels[stage] ?? stage;
  String get image => stageImages[stage] ?? stageImages['BABY']!;
  int get days => DateTime.now().difference(createdAt).inDays + 1;
}

class StepDay {
  StepDay.fromJson(Map<String, dynamic> j)
      : date = j['date'] as String,
        totalSteps = _intOrNull(j['totalSteps']),
        goalSteps = _int(j['goalSteps']),
        pointsEarned = _int(j['pointsEarned']),
        isSynced = j['isSynced'] as bool? ?? false;
  final String date;
  final int? totalSteps; // 동기화 전이면 null
  final int goalSteps;
  final int pointsEarned;
  final bool isSynced;
}

class Wallet {
  Wallet.fromJson(Map<String, dynamic> j)
      : balance = _int(j['balance']),
        todayEarned = _int(j['todayEarned']);
  final int balance;
  final int todayEarned;
}

class HomeData {
  HomeData.fromJson(Map<String, dynamic> j)
      : nickname = (j['user'] as Map<String, dynamic>)['nickname'] as String,
        pet = j['pet'] == null ? null : Pet.fromJson(j['pet'] as Map<String, dynamic>),
        today = StepDay.fromJson(j['today'] as Map<String, dynamic>),
        wallet = Wallet.fromJson(j['wallet'] as Map<String, dynamic>),
        unreadCount = _int(j['unreadCount']);
  final String nickname;
  final Pet? pet;
  final StepDay today;
  final Wallet wallet;
  final int unreadCount;
}
class StepSummary {
  StepSummary.fromJson(Map<String, dynamic> j)
      : startDate = j['startDate'] as String,
        endDate = j['endDate'] as String,
        days = (j['days'] as List).map((d) => StepDay.fromJson(d as Map<String, dynamic>)).toList(),
        totalSteps = _int(j['totalSteps']),
        averageSteps = _intOrNull(j['averageSteps']),
        goalAchievedDays = _int(j['goalAchievedDays']),
        changePercent = _intOrNull(j['previousPeriodChangePercent']);
  final String startDate;
  final String endDate;
  final List<StepDay> days; // 오래된 날 → 오늘
  final int totalSteps;
  final int? averageSteps; // 기록이 없으면 null
  final int goalAchievedDays;
  final int? changePercent; // 지난주와 비교할 수 없으면 null
}
class FriendPet {
  FriendPet.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String? ?? '',
        name = j['name'] as String,
        stage = j['stage'] as String;
  final String id;
  final String name;
  final String stage;

  String get stageLabel => stageLabels[stage] ?? stage;
  String get image => stageImages[stage] ?? stageImages['BABY']!;
}

class Friend {
  Friend.fromJson(Map<String, dynamic> j)
      : uid = j['uid'] as String,
        nickname = j['nickname'] as String,
        pet = j['pet'] == null ? null : FriendPet.fromJson(j['pet'] as Map<String, dynamic>),
        todaySteps = _intOrNull(j['todaySteps']),
        lastSeenAt = j['lastSeenAt'] == null ? null : DateTime.parse(j['lastSeenAt'] as String);
  final String uid;
  final String nickname;
  final FriendPet? pet;
  final int? todaySteps; // 오늘 기록이 없으면 null
  final DateTime? lastSeenAt;

  /// 방금 접속 / 15분 전 / 1시간 전 / 3일 전
  String get lastSeenLabel {
    if (lastSeenAt == null) return '';
    final diff = DateTime.now().difference(lastSeenAt!);
    if (diff.inMinutes < 5) return '방금 접속';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }
}

class FriendList {
  FriendList.fromJson(Map<String, dynamic> j)
      : items = (j['items'] as List).map((f) => Friend.fromJson(f as Map<String, dynamic>)).toList(),
        totalCount = _int(j['totalCount']);
  final List<Friend> items;
  final int totalCount;
}
/// 받침에 따라 조사 고르기: josa('모모', '이', '가') → '가', josa('복이', '을', '를') → '를'
String josa(String word, String withBatchim, String withoutBatchim) {
  if (word.isEmpty) return withoutBatchim;
  final code = word.runes.last;
  if (code < 0xAC00 || code > 0xD7A3) return withoutBatchim;
  return (code - 0xAC00) % 28 != 0 ? withBatchim : withoutBatchim;
}

class FriendVisit {
  FriendVisit.fromJson(Map<String, dynamic> j)
      : friend = Friend.fromJson(j['friend'] as Map<String, dynamic>),
        pet = j['pet'] == null ? null : FriendPet.fromJson(j['pet'] as Map<String, dynamic>),
        canPropose = j['canPropose'] as bool? ?? false;
  final Friend friend;
  final FriendPet? pet;
  final bool canPropose; // 둘 다 어른이면 true
}