import 'dart:async';
import 'dart:convert';
import "dart:math";
import 'package:flutter_scatter/flutter_scatter.dart';
import 'package:random_color/random_color.dart';
import 'model/Artist.dart';
import 'model/CloudWord.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:spotify/spotify_io.dart' as Spotify;

const int MAX_WORD_COUNT = 100;

class ArtistPage extends StatefulWidget {
  final Artist artist;
  //constructor
  ArtistPage({this.artist}):super();
  @override
  State<StatefulWidget> createState() {
    return ArtistPageState();
  }
}

class ArtistPageState extends State<ArtistPage> {
  List<CloudWord> cloudWords;
  String imageSrc;
  Future<String> getArtistImage() async {
    var artistName = widget.artist.name;
    var credentials = new Spotify.SpotifyApiCredentials('8d249ca4324942cc97b566b33678e906', '9da18f2f03144e8eb2840356089e7251');
    var spotify = new Spotify.SpotifyApi(credentials);

    var search = await spotify.search
      .get(artistName, [Spotify.SearchType.artist])
      .first(1)
      .catchError((err) => print((err as Spotify.SpotifyException).message));
      var spotifyArtist;
      search.forEach((pages) {
      pages.items.forEach((item) {
        spotifyArtist=item;
      });
    });
    var _imageSrc = "";
    if(spotifyArtist.images.length> 0){
      var images = spotifyArtist.images.where((x)=> x.height >580 && x.width > 580).toList().map((x)=> x.url).toList();
      if(images.length<2){
        _imageSrc = spotifyArtist.images[0].url;
      }else{
        final _random = new Random();
        var rand1 = _random.nextInt(images.length);
         _imageSrc = images[rand1];
      }
    }
    if(mounted){
      this.setState((){
        imageSrc = _imageSrc;
      });
    }
    return _imageSrc;
  }

  Future<String> getCloudWords() async {

    var artistId = widget.artist.id;

    var response = await http.get(
      Uri.encodeFull("https://musicdemons.com/api/v1/artist/$artistId/songs"),
      headers: {
        "Accept": "application/json",
      }
    );
    var data = json.decode(response.body);
    List words = [];
    if(data.length>0){
      for(var i = 0, len = data.length; i<len; i++){
        var songId = data[i]["id"];
        var lyricsResponse = await http.get(
          Uri.encodeFull("https://musicdemons.com/api/v1/song/$songId/lyrics"),
          headers: {
            "Accept": "application/json",
          }
        );
        var songLyrics = lyricsResponse.body;
        songLyrics =songLyrics.replaceAll(new RegExp('\r\n|\r|\n|,|\\.|\\"|\\!'), ' ');
        List lyrics = songLyrics.split(" ").where((x) => x.length>0).toList();
        words = new List.from(words)..addAll(lyrics);
      }
    }
    words.addAll(["No","No","No","Lyrics","Lyrics","Found"]);
    
    RandomColor _randomColor = RandomColor();
    List<ColorHue> colorHues = [ColorHue.red, ColorHue.blue, ColorHue.orange, ColorHue.purple, ColorHue.pink];
    final _random = new Random();
    ColorHue colorHue = colorHues[_random.nextInt(colorHues.length)];

    List usedWords = [];
    List<CloudWord> genCloudWords = [];
    for(var i = 0, len = words.length; i<len; i++){
      var word = words[i].toUpperCase();
      if(!usedWords.contains(word)){
        var occurances = words.where((x)=>x.toUpperCase() == word).toList().length;
        Color color = _randomColor.randomColor(colorHue: colorHue);
        var rotation = i%3==0 ? true : false;
        CloudWord cloudWord = CloudWord(word, color, occurances, rotation);
        genCloudWords.add(cloudWord);
        usedWords.add(word);
      }
    }
    genCloudWords.sort((a, b) => b.size.compareTo(a.size));
    if(genCloudWords.length > MAX_WORD_COUNT){
      genCloudWords.length = MAX_WORD_COUNT;
    }
    genCloudWords[0].rotated=false;

  if(mounted){
    this.setState((){
      cloudWords = genCloudWords;
    });
  }
    return "success";
  }

    @override
  void initState(){
    super.initState();
    this.getArtistImage();
    this.getCloudWords();
  }

  @override
  Widget build(BuildContext context) {

    if(cloudWords!=null && imageSrc!=null){
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.artist.name),
        ),
        body: new Container(
          decoration: new BoxDecoration(
            image: new DecorationImage(
              image: NetworkImage(imageSrc),
              colorFilter: new ColorFilter.mode(Colors.black.withOpacity(0.7), BlendMode.darken),
              fit: BoxFit.cover,
            ),
          ),
          child: new WordCloud(cloudWords: cloudWords),
        )
      );        
    }else if(imageSrc != null){
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.artist.name),
        ),
        body: new Container(
          decoration: new BoxDecoration(
            image: new DecorationImage(
              image: NetworkImage(imageSrc),
              colorFilter: new ColorFilter.mode(Colors.black.withOpacity(0.7), BlendMode.darken),
              fit: BoxFit.cover,
            ),
          ),
          child: Center(
            child: new CircularProgressIndicator()
          ),
        )
      );  
    }else{
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.artist.name),
        ),
        body: Center(
          child: new CircularProgressIndicator()     
        ),
      );  
    }
  }
}

class WordCloud extends StatelessWidget {

  final List<CloudWord> cloudWords;
  WordCloud({this.cloudWords});

  @override
  Widget build(BuildContext context) {
    List<Widget> widgets = <Widget>[];

    if(cloudWords == null){
      return new Container();
    }

    for (var i = 0; i < cloudWords.length; i++) {
      widgets.add(ScatterItem(cloudWords[i], i));
    }

    final screenSize = MediaQuery.of(context).size;
    final ratio = max(1,screenSize.width / screenSize.height).toDouble();
  
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
  ScatterItem(this.cloudWord, this.index);
  final CloudWord cloudWord;
  final int index;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = Theme.of(context).textTheme.body1.copyWith(
          fontSize: cloudWord.size.toDouble()+15,
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