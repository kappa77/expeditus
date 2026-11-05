import 'package:flutter_test/flutter_test.dart';
import 'package:expeditus/src/util/chapter_parser.dart';

void main() {
  test('parses mm:ss and hh:mm:ss chapter lines', () {
    final chapters = ChapterParser.parse('''
Intro to the video
00:00 Benvenuto
00:10 Prima parte
01:02:03 Ultima parte
''');
    expect(chapters, hasLength(3));
    expect(chapters[0].startSeconds, 0);
    expect(chapters[0].title, 'Benvenuto');
    expect(chapters[1].startSeconds, 10);
    expect(chapters[2].startSeconds, 3723);
  });

  test('ignores a single timestamp and duplicate starts', () {
    expect(ChapterParser.parse('00:00 Solo intro'), isEmpty);
    final chapters = ChapterParser.parse('00:00 Intro\n00:00 Duplicato\n00:10 Topic');
    expect(chapters, hasLength(2));
    expect(chapters[1].startSeconds, 10);
  });

  test('rejects invalid minute or second values', () {
    expect(ChapterParser.parse('00:99 Non valido\n00:10 Valido'), isEmpty);
  });
}
