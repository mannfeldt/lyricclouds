import 'dart:async';
import 'dart:convert';
import './wordCloud.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'model/Artist.dart';
import 'model/Cloud.dart';
import 'constants.dart';

final BLOCKED_ARTISTS = [ARTISTS_NO_SONGS, ARTISTS_ONE_SONG, ARTISTS_TWO_SONGS]
    .expand((x) => x)
    .toList();

void main() {
  runApp(new MaterialApp(
    title: 'Lyric Clouds',
    home: new HomePage(),
  ));
}

class HomePage extends StatefulWidget {
  @override
  HomePageState createState() => new HomePageState();
}

class HomePageState extends State<HomePage> {
  List<Artist> selectableArtists;
  List<Artist> allArtists;
  List<Cloud> cachedClouds = [];
  bool activeSearch = false;

  Cloud getCachedCloud(artistId) {
    Cloud cachedCloud = cachedClouds.singleWhere((x) => x.artist.id == artistId,
        orElse: () => null);

    if (cachedCloud == null || cachedCloud.words == null) {
      return null;
    }
    return cachedCloud;
  }

  void saveToCache(Cloud cloud) {
    //en variant
    this.setState(() {
      Cloud cachedCloud = cachedClouds.singleWhere(
          (x) => x.artist.id == cloud.artist.id,
          orElse: () => null);
      if (cachedCloud != null) {
        cachedCloud.backgroundImage =
            cloud.backgroundImage ?? cachedCloud.backgroundImage;
        cachedCloud.words = cloud.words ?? cachedCloud.words;
      } else {
        cachedClouds.add(cloud);
        if (cachedClouds.length > MAX_CACHED_CLOUDS) {
          cachedClouds.removeAt(0);
        }
      }
    });
  }

  Future<String> getArtists() async {
    var response = await http
        .get(Uri.encodeFull("https://musicdemons.com/api/v1/artist"), headers: {
      "Accept": "application/json",
    });
    var data = json.decode(response.body);
    List<Artist> genArtists = List.generate(
      data.length,
      (i) => Artist(data[i]["id"].toString(), data[i]["name"]),
    ).where((x) => !BLOCKED_ARTISTS.contains(x.id)).toList();
    genArtists.sort((a, b) => a.name.compareTo(b.name));
    this.setState(() {
      allArtists = genArtists;
      selectableArtists = genArtists;
    });
    return "success";
  }

  @override
  void initState() {
    super.initState();
    this.getArtists();
  }

  void closeSearchField() {
    setState(() {
      selectableArtists = allArtists;
      activeSearch = false;
    });
  }

  void filterArtists(String searchString) {
    List<Artist> filteredArtists = allArtists
        .where((x) => x.name.toUpperCase().contains(searchString.toUpperCase()))
        .toList();

    setState(() {
      selectableArtists = filteredArtists;
    });
  }

  PreferredSizeWidget _homeAppBar() {
    if (activeSearch) {
      return new AppBar(
        leading: Icon(Icons.search),
        title: TextField(
          decoration: InputDecoration(
            hintText: "Search",
          ),
          onChanged: filterArtists,
        ),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.close),
            onPressed: closeSearchField,
          )
        ],
      );
    }
    return new AppBar(
      title: new Text("Artists"),
      actions: <Widget>[
        IconButton(
          icon: Icon(Icons.search),
          onPressed: () => setState(() => activeSearch = true),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (selectableArtists != null) {
      return new Scaffold(
        appBar: _homeAppBar(),
        body: new Container(
          decoration: new BoxDecoration(
            color: Colors.black.withOpacity(0.9),
          ),
          child: ListTileTheme(
            textColor: Colors.white,
            selectedColor: Colors.orange,
            child: new ListView.builder(
                itemCount:
                    selectableArtists == null ? 0 : selectableArtists.length,
                itemBuilder: (BuildContext context, int index) {
                  return ListTile(
                    title: Text(selectableArtists[index].name),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ArtistPage(
                              artist: selectableArtists[index],
                              saveToCache: saveToCache,
                              getCachedCloud: getCachedCloud),
                        ),
                      );
                    },
                  );
                }),
          ),
        ),
      );
    } else {
      return Scaffold(
          appBar: _homeAppBar(),
          body: new Container(
            decoration: new BoxDecoration(
              color: Colors.black.withOpacity(0.9),
            ),
            child: Center(child: new CircularProgressIndicator()),
          ));
    }
  }
}
