import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter_scatter/flutter_scatter.dart';
import 'package:random_color/random_color.dart';
import 'model/Artist.dart';
import 'model/CloudWord.dart';
import 'model/Cloud.dart';
import 'constants.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:spotify/spotify_io.dart' as Spotify;

final List<ColorHue> WORD_COLORS = [
  ColorHue.red,
  ColorHue.blue,
  ColorHue.orange,
  ColorHue.purple,
  ColorHue.pink,
  ColorHue.yellow,
];

class ArtistPage extends StatefulWidget {
  final Artist artist;
  final Function getCachedCloud;
  final Function saveToCache;
  //constructor
  ArtistPage({this.artist, this.getCachedCloud, this.saveToCache}) : super();
  @override
  State<StatefulWidget> createState() {
    return ArtistPageState();
  }
}

class ArtistPageState extends State<ArtistPage> {
  List<CloudWord> cloudWords;
  String currentSong;
  String imageSrc;
  Future<String> getArtistImage() async {
    var artistName = widget.artist.name;
    var credentials = new Spotify.SpotifyApiCredentials(
        '8d249ca4324942cc97b566b33678e906', 'SPOTIFY_SECRET');
    var spotify = new Spotify.SpotifyApi(credentials);

    var search = await spotify.search
        .get(artistName, [Spotify.SearchType.artist])
        .first(1)
        .catchError((err) => print((err as Spotify.SpotifyException).message));
    var spotifyArtist;
    search.forEach((pages) {
      pages.items.forEach((item) {
        spotifyArtist = item;
      });
    });
    var _imageSrc = "";
    if (spotifyArtist != null && spotifyArtist.images.length > 0) {
      var images = spotifyArtist.images
          .where((x) => x.height > 580 && x.width > 580)
          .toList()
          .map((x) => x.url)
          .toList();
      if (images.length < 2) {
        _imageSrc = spotifyArtist.images[0].url;
      } else {
        final _random = new Random();
        var rand1 = _random.nextInt(images.length);
        _imageSrc = images[rand1];
      }
    }
    if (mounted) {
      this.setState(() {
        imageSrc = _imageSrc;
      });
    }

    Cloud cloud = Cloud(widget.artist, null, _imageSrc);
    widget.saveToCache(cloud);
    return _imageSrc;
  }

  Future<String> getCloudWords() async {
    final stopwatch = Stopwatch()..start();

    var artistId = widget.artist.id;

    var response = await http.get(
        Uri.encodeFull("https://musicdemons.com/api/v1/artist/$artistId/songs"),
        headers: {
          "Accept": "application/json",
        });
    var data = json.decode(response.body);
    Map<String, int> usedWords = new Map<String, int>();
    Map<String, int> filteredWords = new Map<String, int>();
    if (data.length > 0) {
      for (var i = 0, len = data.length; i < len; i++) {
        var songId = data[i]["id"];
        var songTitle = data[i]["title"];
        if (mounted) {
          this.setState(() {
            currentSong = songTitle;
          });
        }
        var lyricsResponse = await http.get(
            Uri.encodeFull(
                "https://musicdemons.com/api/v1/song/$songId/lyrics"),
            headers: {
              "Accept": "application/json",
            });
        var songLyrics = lyricsResponse.body;
        songLyrics = songLyrics.replaceAll(
            new RegExp('\r\n|\r|\n|,|\\.|\\"|\\!|\\(|\\)|\\;|\\:|\\?'), ' ');
        List lyrics = songLyrics.split(" ").where((x) => x.length > 0).toList();

        for (var i = 0, len = lyrics.length; i < len; i++) {
          var word = lyrics[i].toUpperCase();
          if (!BANNED_WORDS.contains(word)) {
            usedWords[word] = usedWords[word] != null ? usedWords[word] + 1 : 1;
          }
        }
        List<int> values = usedWords.values.toList();
        values.sort((a, b) => b.compareTo(a));
        int minValue =
            values.length < MAX_WORD_COUNT ? 2 : values[MAX_WORD_COUNT];
        filteredWords = new Map.fromIterable(
            usedWords.keys.where((k) => usedWords[k] >= minValue),
            key: (k) => k,
            value: (k) => usedWords[k]);
        List<CloudWord> genCloudWords = generateCloudWords(filteredWords);

        if (mounted) {
          this.setState(() {
            cloudWords = genCloudWords;
          });
        }
      }
    }
    if (mounted) {
      this.setState(() {
        currentSong = null;
      });
    }
    Cloud cloud = Cloud(widget.artist, filteredWords, null);
    widget.saveToCache(cloud);
    print('doSomething() executed in ${stopwatch.elapsed}');

    return "success";
  }

  List<CloudWord> generateCloudWords(Map<String, int> words) {
    RandomColor _randomColor = RandomColor();
    final _random = new Random();
    ColorHue colorHue = WORD_COLORS[_random.nextInt(WORD_COLORS.length)];

    List<CloudWord> genCloudWords = [];
    for (String word in words.keys) {
      int occurence = words[word];
      Color color = _randomColor.randomColor(colorHue: colorHue);
      var rotation = _random.nextInt(5) % 3 == 0 ? true : false;
      CloudWord cloudWord = CloudWord(word, color, occurence, rotation);
      genCloudWords.add(cloudWord);
      if (genCloudWords.length == MAX_WORD_COUNT) break;
    }
    genCloudWords[0].rotated = false;
    //vill jag ha stora orden i mitten så sortera på size
    return genCloudWords;
  }

  @override
  void initState() {
    super.initState();
    Cloud cachedCloud = widget.getCachedCloud(widget.artist.id);
    if (cachedCloud == null) {
      this.getArtistImage();
      this.getCloudWords();
    } else {
      if (mounted) {
        this.setState(() {
          imageSrc = cachedCloud.backgroundImage;
          List<CloudWord> _cloudWords = generateCloudWords(cachedCloud.words);
          cloudWords = _cloudWords;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (cloudWords != null && imageSrc != null) {
      return Scaffold(
          appBar: AppBar(
            title: Text(currentSong ?? widget.artist.name),
          ),
          body: new Container(
            decoration: new BoxDecoration(
                image: new DecorationImage(
                  image: NetworkImage(imageSrc),
                  colorFilter: new ColorFilter.mode(
                      Colors.black.withOpacity(0.7), BlendMode.darken),
                  fit: BoxFit.cover,
                ),
                color: Colors.black.withOpacity(0.9)),
            child: new WordCloud(cloudWords: cloudWords),
          ));
    } else if (imageSrc != null) {
      return Scaffold(
          appBar: AppBar(
            title: Text(widget.artist.name),
          ),
          body: new Container(
            decoration: new BoxDecoration(
              image: new DecorationImage(
                image: NetworkImage(imageSrc),
                colorFilter: new ColorFilter.mode(
                    Colors.black.withOpacity(0.7), BlendMode.darken),
                fit: BoxFit.cover,
              ),
              color: Colors.black.withOpacity(0.9),
            ),
            child: Center(child: new CircularProgressIndicator()),
          ));
    } else {
      return Scaffold(
          appBar: AppBar(
            title: Text(widget.artist.name),
          ),
          body: new Container(
            decoration: new BoxDecoration(
              color: Colors.black.withOpacity(0.9),
            ),
            child: Center(child: new CircularProgressIndicator()),
          ));
    }
  }
}

class WordCloud extends StatelessWidget {
  final List<CloudWord> cloudWords;
  WordCloud({this.cloudWords});

  @override
  Widget build(BuildContext context) {
    List<Widget> widgets = <Widget>[];

    if (cloudWords == null) {
      return new Container();
    }
    int maxSize =
        cloudWords.reduce((acc, cur) => cur.size > acc.size ? cur : acc).size;
    int extraSize = max(10, (maxSize / 10).round());
    for (var i = 0; i < cloudWords.length; i++) {
      widgets.add(ScatterItem(cloudWords[i], extraSize, i));
    }

    final screenSize = MediaQuery.of(context).size;
    final ratio = max(1, screenSize.width / screenSize.height).toDouble();

    return Center(
      child: FittedBox(
        child: Scatter(
          fillGaps: true,
          delegate: FermatSpiralScatterDelegate(ratio: ratio),
          children: widgets,
        ),
      ),
    );
  }
}

class ScatterItem extends StatelessWidget {
  ScatterItem(this.cloudWord, this.extraSize, this.index);
  final CloudWord cloudWord;
  final int index;
  final int extraSize;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = Theme.of(context).textTheme.body1.copyWith(
          fontSize: (cloudWord.size * 2 + extraSize).toDouble(),
          color: cloudWord.color,
        );
    return RotatedBox(
      quarterTurns: cloudWord.rotated ? 1 : 0,
      child: Text(
        cloudWord.text,
        style: style,
      ),
    );
  }
}
