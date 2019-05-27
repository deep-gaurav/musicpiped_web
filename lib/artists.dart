import 'dart:async';

import 'package:flutter_web/material.dart';
import 'dart:indexed_db';
import 'dart:html';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'artistPlaylist.dart';
import 'trending.dart';
import 'main.dart';

class Artists extends StatelessWidget {
  void Function(List<Map>) play;
  void Function(Map) playnext;

  Artists(this.play, this.playnext);

  @override
  Widget build(BuildContext context) {
    var futuredb = window.indexedDB.open("musicDB");

    return FutureBuilder<Database>(
      future: futuredb,
      builder: (context, ass) {
        if (ass.connectionState == ConnectionState.done) {
          var db = ass.data;
          var ob = db
              .transaction("tracks", "readonly")
              .objectStore("tracks")
              .openCursor(autoAdvance: true);
          var lc = Completer<List<Map>>();
          var l = lc.future;
          var list = List<Map>();
          ob.listen((data) {
            list.add(data.value);
          }, onDone: () {
            lc.complete(list);
          });
          return FutureBuilder<List<Map>>(
            future: l,
            builder: (ctx, ass) {
              if (ass.connectionState == ConnectionState.done) {
                var list = ass.data;
                var newl = Set<String>();
                String separator = ";;;";
                for (var c in list) {
                  print(c["author"]);
                  newl.add(c["author"] +
                      separator +
                      TrackTile.urlfromImage(c["authorThumbnails"], 176,
                          param: "width") +
                      separator +
                      c['authorId']);
                }
                return SingleChildScrollView(
                  child: Wrap(
                    children: (newl.map((data) {
                      return Padding(
                        padding: EdgeInsets.all(8),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => (ArtistPlaylist(
                                          play,
                                          playnext,
                                          data.split(separator)[0],
                                          usePlaylist: true,
                                          playlistdetail: {
                                            'id': data.split(separator)[2]
                                          },
                                        ))));
                          },
                          child: Container(
                            height: 176,
                            width: 176,
                            decoration: BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                      color: Colors.black,
                                      blurRadius: 2,
                                      offset: Offset(2, 2))
                                ],
                                shape: BoxShape.circle,
                                image: DecorationImage(
                                    image: NetworkImage(
                                      data.split(separator)[1],
                                    ),
                                    fit: BoxFit.cover)),
                          ),
                        ),
                      );
                    }))
                        .toList(),
                  ),
                );
              } else {
                return Center(
                  child: CircularProgressIndicator(),
                );
              }
            },
          );
        } else {
          return Center(
            child: CircularProgressIndicator(),
          );
        }
      },
    );
  }
}
