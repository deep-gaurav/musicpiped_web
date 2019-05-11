import 'dart:async';
import 'dart:math' as prefix0;

import 'package:flutter_web/cupertino.dart';
import 'package:flutter_web/material.dart';
import 'dart:js' as js;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:indexed_db';
import 'dart:html';

import 'searchScreen.dart';
import 'trending.dart';
import 'home.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    js.context.callMethod("removeLoader");
    return MaterialApp(
      title: 'MusicPiped Web',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
      ),
      home: MyHomePage(title: 'MusicPiped Web'),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  MyHomePageState createState() => MyHomePageState();
}

enum PlayerState { Loading, Playing, Paused, Stopped }

class MyHomePageState extends State<MyHomePage> {
  TextEditingController textEditingController = TextEditingController();

  js.JsObject howler = null;
  dynamic howlerId = 0;

  static String InvidiosAPI = "https://invidio.us/api/v1/";

  List queue;

  var playerState = ValueNotifier(PlayerState.Stopped);

  int currentIndex = 0;

  double totalLength = 0;

  String state;

  Timer syncTimer;

  Database db;

  var playing = ValueNotifier(false);
  var repeat = ValueNotifier(0);
  var shuffle = ValueNotifier(false);

  var positionNotifier = ValueNotifier(0.0);

  GlobalKey<ScaffoldState> scaffoldKey = GlobalKey();

  static const int ToMobileWidth = 600;

  SearchDelegate _searchDelegate = YoutubeSuggestion();

  Widget emptyWidget = Container(
    width: 0,
    height: 0,
  );

  @override
  void initState() {
    super.initState();

    syncTimer = Timer.periodic(Duration(milliseconds: 500), (t) {
      if (howler != null && howler.callMethod("state") == "loaded") {
        totalLength = howler.callMethod("duration");
        positionNotifier.value = howler.callMethod("seek");
        playing.value = howler.callMethod("playing");
        if (playing.value) {
          playerState.value = PlayerState.Playing;
        } else if (playerState.value == PlayerState.Playing) {
          playerState.value = PlayerState.Stopped;
        }
      }
    });
    playerState.addListener(() {
      if (playerState.value == PlayerState.Stopped) {
        onEnd();
      }
    });
    window.indexedDB.open("musicDB", version: 3, onUpgradeNeeded: (e) {
      print("upgrade DB");
      if (e.oldVersion < 1) {
        Database db = e.target.result;

        var ob = db.createObjectStore("tracks", keyPath: "videoId");
      } else if (e.oldVersion < 3) {
        Database db = e.target.result;
        var ob = db.transaction("tracks", "readwrite").objectStore("tracks");

        ob.createIndex("videoId", "videoId", unique: true);
        ob.createIndex("timesPlayed", "timesPlayed");
        ob.createIndex("lastPlayed", "lastPlayed");
      }
    }).then((db) {
      this.db = db;
      setState(() {
        
      });
    });
  }

  Future<Map> refreshLink(String vidId) async {
    String url = InvidiosAPI + "videos/" + vidId;
    var response = await http.get(url);
    return json.decode(utf8.decode(response.bodyBytes));
  }

  void playCurrent() async {
    Map s = this.queue[currentIndex];
    s = await refreshLink(s["videoId"]);
    try {
      Map ob = await db
          .transaction("tracks", "readwrite")
          .objectStore("tracks")
          .getObject(s["videoId"]);
      if (ob.containsKey("timesPlayed")) {
        s["timesPlayed"] = ob["timesPlayed"] + 1;
      } else {
        s["timesPlayed"] = 0;
      }
    } catch (e) {
      print(e);
    }
    s["lastPlayed"] = DateTime.now().microsecondsSinceEpoch;
    if (!s.containsKey("timesPlayed")) {
      s["timesPlayed"] = 0;
    }

    List formats = s["adaptiveFormats"];
    for (Map f in formats) {
      String type = f["type"];
      if (type.contains("audio")) {
        String url = f["url"];

        var param = js.JsObject.jsify({
          "src": [url],
          "html5": true,
        });
        if (howler != null) {
          howler.callMethod("stop");
          howler.callMethod("unload");
        }
        howler = js.JsObject(js.context['Howl'], [param]);

        howlerId = howler.callMethod("play");
        String id = await db
            .transaction("tracks", "readwrite")
            .objectStore("tracks")
            .put(s);
        print("added to db $id");
        setState(() {});
        break;
      }
    }
  }

  void onEnd() {
    if (repeat.value == 2) {
      howler.callMethod("play");
    }
  }

  @override
  Widget build(BuildContext context) {
    var titleBar = Expanded(
      child: Column(
        children: <Widget>[
          Container(
            height: Theme.of(context).textTheme.title.fontSize + 10,
            child: Text(
              queue == null ? "" : queue[currentIndex]["title"],
              style: Theme.of(context).textTheme.title,
              maxLines: 1,
            ),
          ),
          Text(
            queue == null ? "" : queue[currentIndex]["author"],
            style: Theme.of(context).textTheme.subtitle,
            maxLines: 1,
          )
        ],
      ),
    );

    return DefaultTabController(
      length: 3,
      initialIndex: 0,
      child: Scaffold(
        key: scaffoldKey,
        appBar: AppBar(
          title: Text(widget.title),
          actions: <Widget>[
            StatefulBuilder(builder: (ctx, setstate) {
              return IconButton(
                icon: Icon(Icons.search),
                onPressed: () async {
                  String searchQ = await showSearch<String>(
                      context: context, delegate: _searchDelegate);
                  if (searchQ.isNotEmpty) {
                    queue = (await Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) =>
                            (SearchScreen(searchQ)))))["queue"];
                    currentIndex = 0;
                    playerState.value = PlayerState.Loading;
                    playCurrent();
                  }
                },
              );
            })
          ],
          bottom: TabBar(
            tabs: <Widget>[
              Tab(
                icon: Icon(Icons.home),
                text: "Home",
              ),
              Tab(
                icon: Icon(Icons.trending_up),
                text: "Trending",
              ),
              Tab(
                icon: Icon(Icons.library_music),
                text: "Library",
              )
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            Home( (trackdata) {
              queue = [trackdata];
              currentIndex = 0;
              playerState.value = PlayerState.Loading;
              playCurrent();
            }),
            Trending((trackdata) {
              queue = [trackdata];
              currentIndex = 0;
              playerState.value = PlayerState.Loading;
              playCurrent();
            }),
            Container()
          ],
        ),
        bottomNavigationBar: Container(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ValueListenableBuilder(
                valueListenable: positionNotifier,
                builder: (context, double position, child) {
                  return Slider(
                    max: totalLength.toDouble(),
                    value: position.toDouble(),
                    onChanged: (newpos) {
                      positionNotifier.value = newpos;
                    },
                    onChangeEnd: (pos) {
                      howler.callMethod("seek", [pos]);
                    },
                  );
                },
              ),
              MediaQuery.of(context).size.width > ToMobileWidth
                  ? emptyWidget
                  : Row(
                      children: <Widget>[titleBar],
                    ),
              Row(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      IconButton(
                        icon: Icon(Icons.skip_previous),
                      ),
                      ValueListenableBuilder(
                        valueListenable: playerState,
                        builder: (context, state, child) {
                          if (state == PlayerState.Playing ||
                              state == PlayerState.Paused) {
                            return ValueListenableBuilder(
                              valueListenable: playing,
                              builder: (context, bool playing, child) {
                                return IconButton(
                                  icon: Icon(
                                      playing ? Icons.pause : Icons.play_arrow),
                                  iconSize: 36,
                                  onPressed: () {
                                    if (playing) {
                                      howler.callMethod("pause");
                                      playerState.value = PlayerState.Paused;
                                    } else {
                                      howler.callMethod("play");
                                    }
                                  },
                                );
                              },
                            );
                          } else if (state == PlayerState.Loading) {
                            return CircularProgressIndicator();
                          } else {
                            return Icon(
                              Icons.play_arrow,
                              size: 36,
                              color: Theme.of(context).disabledColor,
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.skip_next),
                      ),
                      ValueListenableBuilder(
                        valueListenable: positionNotifier,
                        builder: (context, double position, child) {
                          return Text(formatDuration(Duration(
                                  milliseconds: (positionNotifier.value * 1000)
                                      .toInt())) +
                              "/" +
                              formatDuration(Duration(
                                  milliseconds: (totalLength * 1000).toInt())));
                        },
                      ),
                    ],
                  ),
                  MediaQuery.of(context).size.width > ToMobileWidth
                      ? titleBar
                      : Expanded(child: emptyWidget),
                  Row(
                    children: <Widget>[
                      ValueListenableBuilder(
                        valueListenable: shuffle,
                        builder: (context, shuflecurrent, child) {
                          return IconButton(
                            icon: Icon(Icons.shuffle),
                            color: shuflecurrent
                                ? Theme.of(context).iconTheme.color
                                : Theme.of(context).disabledColor,
                            onPressed: () {
                              shuffle.value = !shuffle.value;
                            },
                          );
                        },
                      ),
                      ValueListenableBuilder(
                        valueListenable: repeat,
                        builder: (context, repeatcurrent, child) {
                          if (repeatcurrent == 0) {
                            return IconButton(
                              icon: Icon(Icons.repeat),
                              onPressed: () {
                                repeat.value = 1;
                              },
                              color: Theme.of(context).disabledColor,
                            );
                          } else if (repeatcurrent == 1) {
                            return IconButton(
                              icon: Icon(Icons.repeat),
                              onPressed: () {
                                repeat.value = 2;
                              },
                            );
                          } else {
                            return IconButton(
                              icon: Icon(Icons.repeat_one),
                              onPressed: () {
                                repeat.value = 0;
                              },
                            );
                          }
                        },
                      )
                    ],
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

class YoutubeSuggestion extends SearchDelegate<String> {
  static String corsanywhere = 'https://cors-anywhere.herokuapp.com/';
  String suggestionURL =
      'http://suggestqueries.google.com/complete/search?client=firefox&ds=yt&q=';

  @override
  List<Widget> buildActions(BuildContext context) {
    return <Widget>[
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = "";
          showSuggestions(context);
        },
      ),
      IconButton(
        icon: Icon(Icons.search),
        onPressed: () {
          close(context, query);
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () {
        close(context, "");
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return Container();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isNotEmpty) {
      String queryURL = corsanywhere + suggestionURL + query;
      Future results = http.get(queryURL);
      return FutureBuilder(
        future: results,
        builder: (context, ass) {
          if (ass.connectionState == ConnectionState.done) {
            http.Response response = ass.data;
            List l = json.decode(response.body);
            List<String> suggestions = List();
            for (var el in l[1]) {
              suggestions.add(el.toString());
            }
            return _SuggestionList(
              suggestions: suggestions,
              query: query,
              onSelected: (str) {
                query = str;
                close(context, str);
              },
              onAdd: (str) {
                query = str;
                showSuggestions(context);
              },
            );
          } else {
            return CircularProgressIndicator();
          }
        },
      );
    } else {
      return Container();
    }
  }
}

class _SuggestionList extends StatelessWidget {
  const _SuggestionList(
      {this.suggestions, this.query, this.onSelected, this.onAdd});

  final List<String> suggestions;
  final String query;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onAdd;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (BuildContext context, int i) {
        final String suggestion = suggestions[i];
        return ListTile(
          leading: query.isEmpty ? const Icon(Icons.history) : const Icon(null),
          title: RichText(
            text: TextSpan(
              text: suggestion.substring(0, query.length),
              style:
                  theme.textTheme.subhead.copyWith(fontWeight: FontWeight.bold),
              children: <TextSpan>[
                TextSpan(
                  text: suggestion.substring(query.length),
                  style: theme.textTheme.subhead,
                ),
              ],
            ),
          ),
          onTap: () {
            onSelected(suggestion);
          },
          trailing: Transform.rotate(
            angle: -prefix0.pi / 4,
            child: IconButton(
              icon: Icon(Icons.arrow_upward),
              onPressed: () {
                onAdd(suggestion);
              },
            ),
          ),
        );
      },
    );
  }
}
