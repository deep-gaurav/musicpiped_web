import 'dart:async';
import 'dart:html';
import 'dart:indexed_db';

import 'package:flutter_web/material.dart';

import 'trending.dart';

class Home extends StatefulWidget {
  void Function(Map) onpressed;

  Home(this.onpressed);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  Future<List<Map>> tracks;

  Database db;

  @override
  void initState() {
    super.initState();

    var c = Completer<List<Map>>();
    tracks = c.future;

    window.indexedDB.open("musicDB").then((newdb) {
      db = newdb;
      var obstore = db.transaction("tracks", "readonly").objectStore("tracks");
      var stream = obstore.openCursor(autoAdvance: true);
      print("readingDB");
      print(obstore.count().then((i) {
        print(i);
      }));
      List<Map> alltracks = List();
      stream.listen((cursor) {
        Map track = cursor.value;
        print(track);
        alltracks.add(track);
      }, onDone: () {
        c.complete(alltracks);
        print("Completed");
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: EdgeInsets.all(8),
          child: Text(
            "Top Tracks",
            style: Theme.of(context).textTheme.headline
              ..copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.start,
          ),
        ),
        FutureBuilder<List<Map>>(
          future: tracks,
          builder: (context, ass) {
            if (ass.connectionState == ConnectionState.done) {
              var alltracks = ass.data;
              return Container(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: alltracks.length,
                  itemBuilder: (context, i) {
                    return TrackTile(alltracks[i], widget.onpressed);
                  },
                ),
              );
            } else {
              return CircularProgressIndicator();
            }
          },
        )
      ],
    );
  }
}
