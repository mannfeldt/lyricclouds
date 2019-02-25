import 'dart:async';
import 'dart:convert';
import './wordCloud.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'model/Artist.dart';

const List<String> BLOCKED_ARTISTS = ["10.000 Maniacs"];

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
  bool activeSearch = false;

  Future<String> getArtists() async {
    var response = await http.get(
      Uri.encodeFull("https://musicdemons.com/api/v1/artist"),
      headers: {
        "Accept": "application/json",
      }
    );
    var data = json.decode(response.body);
    var genArtists = List.generate(
        data.length,
        (i) => Artist(
              data[i]["id"].toString(),
              data[i]["name"],
              null
            ),
      ).where((x)=> !BLOCKED_ARTISTS.contains(x.name)).toList();
    this.setState((){
      allArtists = genArtists;
      selectableArtists =genArtists;
    });
    return "success";
  }

  @override
  void initState(){
    super.initState();
    this.getArtists();
  }

  void closeSearchField(){
    setState(() {
      selectableArtists = allArtists;
      activeSearch = false;
    });
  }

  void filterArtists(String searchString) {
    List<Artist> filteredArtists = allArtists.where((x)=> x.name.toUpperCase().contains(searchString.toUpperCase())).toList();

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
    return new Scaffold(
      appBar: _homeAppBar(),
      body: new ListView.builder(
        itemCount: selectableArtists == null ? 0 : selectableArtists.length,
        itemBuilder: (BuildContext context, int index){
          return ListTile(
            title:Text(selectableArtists[index].name),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ArtistPage(artist: selectableArtists[index]),
                ),
              );
            },
            );
        },
      ),
    );
  }
}

