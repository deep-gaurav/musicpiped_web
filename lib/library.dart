import 'dart:async';

import 'package:flutter_web/material.dart';
import 'package:flutter_web/material.dart' as prefix0;

import 'dart:html';
import 'dart:indexed_db';

import 'playlist.dart';
import 'ytplaylist.dart';

class Library extends StatelessWidget {
  void Function(List<Map>) play;
  void Function(Map) playnext;

  Database db;

  Future<List<Map>> playlistList;

  Library(this.play, this.playnext, this.db);

  @override
  Widget build(BuildContext context) {
    var c = Completer<List<Map>>();
    playlistList = c.future;

    window.indexedDB.open('musicDB').then((d) {
      db = d;
      print(db.objectStoreNames);
      var ob =
          db.transaction('playlists', 'readwrite').objectStore('playlists');
      var stream = ob.openCursor(autoAdvance: true);
      List<Map> l = List();
      stream.listen((data) {
        print(data.value);
        l.add(data.value);
      }).onDone(() {
        c.complete(l);
      });
    });

    return FutureBuilder<List<Map>>(
      future: playlistList,
      builder: (context, ass) {
        if (ass.connectionState == ConnectionState.done) {
          var playlists = ass.data;
          List<Widget> playlistwidgets = List();
          print(playlists.length);
          for (var p in playlists) {
            playlistwidgets.add(Card(
              child: ListTile(
                title: Text(p['title']),
                trailing: p.containsKey('playlistId') ? Icon(Icons.sync) : null,
                onTap: () {
                  if (p.containsKey('playlistId')) {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => (YTPlaylist(
                                  play,
                                  playnext,
                                  p['title'],
                                  usePlaylist: true,
                                  playlistdetail: p,
                                ))));
                  } else {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => (Playlist(
                                  play,
                                  playnext,
                                  p['title'],
                                  usePlaylist: true,
                                ))));
                  }
                },
              ),
            ));
          }
          return ListView(
            children: <Widget>[
              Card(
                child: ListTile(
                  title: Text("All Tracks"),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) =>
                            (Playlist(play, playnext, 'All Tracks'))));
                  },
                ),
              ),
              ...playlistwidgets
            ],
          );
        } else {
          return ListView(
            children: <Widget>[
              Card(
                child: ListTile(
                  title: Text("All Tracks"),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) =>
                            (Playlist(play, playnext, 'All Tracks'))));
                  },
                ),
              ),
              Center(
                child: CircularProgressIndicator(),
              )
            ],
          );
        }
      },
    );
  }
}
