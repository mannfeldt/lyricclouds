import 'Artist.dart';

class Cloud {
  Cloud(
    this.artist,
    this.words,
    this.backgroundImage,
  );
  Map<String,int> words;
  final Artist artist;
  String backgroundImage;
}
