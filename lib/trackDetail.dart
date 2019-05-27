import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:flutter_web/material.dart';
import 'package:musicpiped_web/searchScreen.dart';
import 'trending.dart';
import 'main.dart';

class TrackDetail extends StatelessWidget {
  final Map initialtrackInfo;

  Map trackInfo;
  void Function(List<Map>) onPressed;
  Future recommendedWids;

  TrackDetail(this.initialtrackInfo, this.onPressed);

  @override
  Widget build(BuildContext context) {
    trackInfo = initialtrackInfo;
    if (trackInfo.containsKey('recommendedVideos')) {
      recommendedWids = Future.value(trackInfo);
    }
    else{
      var c = Completer();
      recommendedWids = c.future;
      var url = MyHomePageState.InvidiosAPI+"videos/"+trackInfo["videoId"];
      http.get(url).then((response){
        var j = json.decode(utf8.decode(response.bodyBytes));
        trackInfo = j;
        c.complete(j);
      });
    }
    return Material(
      child: CustomScrollView(
        shrinkWrap: true,
        slivers: <Widget>[
          SliverAppBar(
            expandedHeight: 200,
            floating: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: Image.network(
                      TrackTile.urlfromImage(
                          trackInfo["videoThumbnails"], "high"),
                      fit: BoxFit.cover,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black])),
                  ),
                ],
              ),
              title: Text(trackInfo["title"]),
            ),
          ),
          SliverToBoxAdapter(
              child: Wrap(
            children: <Widget>[
              Chip(
                avatar: Icon(Icons.people),
                label: Text(trackInfo["author"]),
              ),
              Chip(
                avatar: Icon(Icons.timer),
                label: Text(formatDuration(
                    Duration(seconds: trackInfo["lengthSeconds"]))),
              ),
              Chip(
                avatar: Icon(Icons.trending_up),
                label: Text(trackInfo["viewCount"].toString()),
              ),
              if (trackInfo["timesPlayed"] != null)
                Chip(
                  avatar: Icon(Icons.favorite),
                  label: Text(
                      "TimesPlayed : " + (trackInfo["timesPlayed"]).toString()),
                )
            ],
          )),
          SliverToBoxAdapter(
            child: ButtonBar(
              children: <Widget>[
                RaisedButton.icon(
                  icon: Icon(Icons.play_arrow),
                  label: Text("Play"),
                  onPressed: () {
                    List<Map> q = new List();
                    q.add(trackInfo);
                    onPressed(q);
                    Navigator.of(context).pop(trackInfo);
                  },
                  color: Theme.of(context).primaryColor,
                ),
                RaisedButton.icon(
                  icon: Icon(Icons.playlist_play),
                  label: Text("Play with Queue"),
                  onPressed: () {
                    List<Map> q = new List();
                    q.add(trackInfo);
                    for (var x in trackInfo["recommendedVideos"]) {
                      q.add(x);
                    }
                    onPressed(q);
                    Navigator.of(context).pop(trackInfo);
                  },
                  color: Theme.of(context).primaryColor,
                )
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.all(8),
              child: Text(
                "Recommended Queue",
                style: Theme.of(context).textTheme.title
                  ..copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          FutureBuilder(
              future: recommendedWids,
              builder: (context, ass) {
                if (ass.connectionState == ConnectionState.done) {
                  var trackInfo = ass.data; 
                  return SliverList(
                    delegate: SliverChildBuilderDelegate((context, i) {
                      return Card(
                        elevation: 4,
                        child: ListTile(
                          leading: Text(i.toString()),
                          title:
                              Text(trackInfo["recommendedVideos"][i]["title"]),
                        ),
                      );
                    },
                        childCount:
                            (trackInfo["recommendedVideos"] as List).length),
                  );
                }
                else{
                  return SliverToBoxAdapter(child: Center(child: CircularProgressIndicator(),));
                }
              })
        ],
      ),
    );
  }
}
