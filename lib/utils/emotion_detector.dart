import '../widgets/robot_face.dart';

/// Danh sách thứ tự ưu tiên các cảm xúc khi nhiều nhóm cùng khớp:
/// angry > sad > surprised > laughing > loving > happy > confused > thinking > sleepy > winking > cool
const List<FaceEmotion> _emotionPriority = [
  FaceEmotion.angry,
  FaceEmotion.sad,
  FaceEmotion.surprised,
  FaceEmotion.laughing,
  FaceEmotion.loving,
  FaceEmotion.happy,
  FaceEmotion.confused,
  FaceEmotion.thinking,
  FaceEmotion.sleepy,
  FaceEmotion.winking,
  FaceEmotion.cool,
];

/// Bảng emoji tương ứng cho từng nhóm cảm xúc
const Map<FaceEmotion, List<String>> _emotionEmojis = {
  FaceEmotion.angry: ['😠', '😡', '💢', '🤬', '👿'],
  FaceEmotion.sad: ['😢', '😭', '😞', '☹', '🙁', '😿'],
  FaceEmotion.surprised: ['😮', '😲', '😱', '😯', '🤯'],
  FaceEmotion.laughing: ['😂', '🤣', '😆', '😹'],
  FaceEmotion.loving: ['❤', '❤️', '😍', '🥰', '😘', '💖', '💕', '💓', '💗'],
  FaceEmotion.happy: ['😊', '😄', '😁', '🙂', '☺', '😃', '😺'],
  FaceEmotion.confused: ['🤔', '😕', '🤨', '🧐'],
  FaceEmotion.thinking: [],
  FaceEmotion.sleepy: ['😴', '🥱', '💤'],
  FaceEmotion.winking: ['😉', '😜', '😝'],
  FaceEmotion.cool: ['😎'],
};

/// Bộ từ khóa phong phú cho từng nhóm cảm xúc (tiếng Việt có dấu)
const Map<FaceEmotion, List<String>> _emotionKeywords = {
  FaceEmotion.angry: [
    'không chấp nhận',
    'bực mình',
    'bực bội',
    'tức giận',
    'nổi giận',
    'khó chịu',
    'đừng có',
    'thôi đi',
    'điên tiết',
    'cáu gắt',
    'tức quá',
    'bực quá',
    'bực',
    'cáu',
    'ghét',
    'phiền',
    'hừ',
    'tức',
  ],
  FaceEmotion.sad: [
    'thật đáng tiếc',
    'không may',
    'mệt mỏi',
    'đau lòng',
    'thất vọng',
    'buồn bã',
    'buồn quá',
    'tiếc quá',
    'chán quá',
    'nản quá',
    'xin lỗi',
    'buồn',
    'tiếc',
    'khóc',
    'cô đơn',
  ],
  FaceEmotion.surprised: [
    'không thể tin',
    'trời đất ơi',
    'trời ơi',
    'thật sao',
    'thật à',
    'bất ngờ',
    'ngạc nhiên',
    'giật mình',
    'hú hồn',
    'kinh thật',
    'wow',
    'ôi',
    'ồ',
  ],
  FaceEmotion.laughing: [
    'buồn cười',
    'cười vỡ bụng',
    'cười bể bụng',
    'mắc cười',
    'hài hước',
    'haha',
    'hihi',
    'hehe',
    'hoho',
    'ha ha',
    'hi hi',
    'he he',
  ],
  FaceEmotion.loving: [
    'cảm ơn bạn nhiều',
    'cám ơn bạn nhiều',
    'cảm ơn nhiều',
    'cám ơn nhiều',
    'cảm ơn bạn',
    'cám ơn bạn',
    'yêu quý',
    'đáng yêu',
    'thương yêu',
    'quý mến',
    'yêu bạn',
    'thương bạn',
    'yêu',
    'thương',
    'quý',
    'ôm',
    'cảm ơn',
    'cám ơn',
  ],
  FaceEmotion.happy: [
    'tất nhiên rồi',
    'tuyệt cú mèo',
    'chúc mừng',
    'tuyệt vời',
    'phấn khởi',
    'hạnh phúc',
    'hào hứng',
    'tốt quá',
    'hay quá',
    'được chứ',
    'vui vẻ',
    'giỏi quá',
    'thích quá',
    'tốt lắm',
    'hay lắm',
    'vui',
    'tuyệt',
    'giỏi',
    'thích',
  ],
  FaceEmotion.confused: [
    'không hiểu',
    'khó hiểu',
    'sao vậy',
    'là sao',
    'lạ nhỉ',
    'sao cơ',
    'sao thế',
    'là thế nào',
    'hả',
    'ủa',
  ],
  FaceEmotion.thinking: [
    'để mình nghĩ',
    'để tôi nghĩ',
    'suy nghĩ',
    'có lẽ',
    'chắc là',
    'để xem nào',
    'xem nào',
    'hmm',
    'ừm',
  ],
  FaceEmotion.sleepy: [
    'buồn ngủ quá',
    'buồn ngủ',
    'ngủ ngon',
    'mệt quá',
    'khuya rồi',
    'đi ngủ',
    'ngủ thôi',
  ],
  FaceEmotion.winking: [
    'đùa thôi',
    'bí mật',
    'nháy mắt',
    'trêu thôi',
    'giỡn thôi',
  ],
  FaceEmotion.cool: [
    'chuyện nhỏ',
    'tự tin',
    'dễ ợt',
    'ngầu quá',
    'đỉnh quá',
    'chất quá',
    'siêu đỉnh',
    'ngầu',
  ],
};

/// Bảng ánh xạ ký tự tiếng Việt có dấu sang không dấu
const Map<String, String> _vietnameseCharMap = {
  'a': 'áàảãạăắằẳẵặâấầẩẫậ',
  'd': 'đ',
  'e': 'éèẻẽẹêếềểễệ',
  'i': 'íìỉĩị',
  'o': 'óòỏõọôốồổỗộơớờởỡợ',
  'u': 'úùủũụưứừửữự',
  'y': 'ýỳỷỹỵ',
};

/// Bảng các cụm từ trung tính/không mang cảm xúc cần loại trừ trước khi so khớp
const List<MapEntry<String, String>> _phraseReplacements = [
  MapEntry('tin tức', 'thongtin'),
  MapEntry('tin tuc', 'thongtin'),
  MapEntry('tức ngực', 'daunguc'),
  MapEntry('tuc nguc', 'daunguc'),
  MapEntry('quý khách', 'khachhang'),
  MapEntry('quy khach', 'khachhang'),
  MapEntry('quý vị', 'cacvi'),
  MapEntry('quy vi', 'cacvi'),
  MapEntry('thích ứng', 'thichnghi'),
  MapEntry('thich ung', 'thichnghi'),
  MapEntry('bình thường', 'binhthuong'),
  MapEntry('binh thuong', 'binhthuong'),
  MapEntry('câu chuyện', 'cauchuyen'),
  MapEntry('cau chuyen', 'cauchuyen'),
  MapEntry('cầu cứu', 'caucuu'),
  MapEntry('cau cuu', 'caucuu'),
];

/// Hàm bỏ dấu tiếng Việt, chuyển thành chuỗi chữ thường không dấu
String removeDiacritics(String text) {
  var result = text.toLowerCase();
  result = result.replaceAll(RegExp(r'[\u0300-\u036f]'), '');
  _vietnameseCharMap.forEach((nonDiacritic, diacritics) {
    for (int i = 0; i < diacritics.length; i++) {
      result = result.replaceAll(diacritics[i], nonDiacritic);
    }
  });
  return result;
}

/// Chuẩn hóa chuỗi văn bản: loại bỏ dấu câu, chuẩn hóa khoảng trắng
String _cleanDelimiters(String text) {
  final replaced = text.replaceAll(
    RegExp(r'''[\.,!\?:;\"\'\(\)\[\]\{\}<>\-/\*\+=_~@#\$%\^&\\|`\n\r\t]'''),
    ' ',
  );
  final normalizedSpaces = replaced.replaceAll(RegExp(r'\s+'), ' ').trim();
  return ' $normalizedSpaces ';
}

class _EmotionMatch {
  final int length;
  final int priorityIndex;
  final FaceEmotion emotion;

  const _EmotionMatch({
    required this.length,
    required this.priorityIndex,
    required this.emotion,
  });

  bool isBetterThan(_EmotionMatch other) {
    // 1. Ưu tiên từ khóa dài hơn
    if (length != other.length) {
      return length > other.length;
    }
    // 2. Cùng độ dài: thứ tự ưu tiên cảm xúc (chỉ số nhỏ hơn là ưu tiên cao hơn)
    return priorityIndex < other.priorityIndex;
  }
}

/// Phân tích một câu văn tiếng Việt (có dấu hoặc không dấu) + emoji,
/// trả về cảm xúc rõ nhất hoặc null nếu không rõ.
FaceEmotion? detectEmotionFromText(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;

  // 1. ƯU TIÊN EMOJI CAO NHẤT (theo đúng thứ tự ưu tiên các cảm xúc)
  for (final emotion in _emotionPriority) {
    final emojis = _emotionEmojis[emotion];
    if (emojis == null || emojis.isEmpty) continue;
    for (final em in emojis) {
      if (trimmed.contains(em)) {
        return emotion;
      }
    }
  }

  // Tiền xử lý: chuyển chữ thường và loại trừ các cụm từ trung gian
  String filtered = trimmed.toLowerCase();
  for (final entry in _phraseReplacements) {
    filtered = filtered.replaceAll(entry.key, entry.value);
  }

  final String paddedOrig = _cleanDelimiters(filtered);
  final String paddedNorm = _cleanDelimiters(removeDiacritics(filtered));

  _EmotionMatch? bestMatch;

  // 2. SO KHỚP TỪ KHÓA (ưu tiên từ khóa dài hơn > thứ tự cảm xúc)
  for (int i = 0; i < _emotionPriority.length; i++) {
    final emotion = _emotionPriority[i];
    final keywords = _emotionKeywords[emotion];
    if (keywords == null) continue;

    for (final kw in keywords) {
      final kwLower = kw.toLowerCase();
      final kwNorm = removeDiacritics(kwLower);

      final targetOrig = ' $kwLower ';
      final targetNorm = ' $kwNorm ';

      final bool matched =
          paddedOrig.contains(targetOrig) || paddedNorm.contains(targetNorm);

      if (matched) {
        final candidate = _EmotionMatch(
          length: kwLower.length,
          priorityIndex: i,
          emotion: emotion,
        );

        if (bestMatch == null || candidate.isBetterThan(bestMatch)) {
          bestMatch = candidate;
        }
      }
    }
  }

  if (bestMatch != null) {
    return bestMatch.emotion;
  }

  // 3. Quy tắc câu kết thúc bằng "!":
  // Câu kết thúc bằng "!" mà không khớp gì -> surprised chỉ khi có "ôi/ồ/wow", còn lại null.
  // Vì "ôi", "ồ", "wow" đã nằm trong bộ từ khóa surprised ở trên,
  // nếu không khớp gì thì câu có "!" vẫn trả về null (tránh đoán bừa biểu cảm ngạc nhiên).
  return null;
}
