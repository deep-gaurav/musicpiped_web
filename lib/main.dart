import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_web/services.dart';
import 'package:pedantic/pedantic.dart';

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
import 'trackDetail.dart';
import 'artists.dart';
import 'library.dart';

import 'package:flutter_web/foundation.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  void initSettings() {
    window.localStorage.putIfAbsent('brightness', () => ("dark"));
    window.localStorage
        .putIfAbsent('invidiousApi', () => ("https://invidio.us/"));
    window.localStorage.putIfAbsent('quality', () => ('best'));
  }

  @override
  Widget build(BuildContext context) {
    initSettings();

    js.context.callMethod("removeLoader");
    return MaterialApp(
      title: 'MusicPiped Web',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: window.localStorage["brightness"] == "dark"
            ? Brightness.dark
            : Brightness.light,
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

enum PlayerState { Loading, Playing, Paused, Stopped, Error }

class MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  TextEditingController textEditingController = TextEditingController();

  AudioElement player;
  dynamic howlerId = 0;

  static String InvidiosAPI = window.localStorage["invidiousApi"] + "api/v1/";

  List queue;

  var playerState = ValueNotifier(PlayerState.Stopped);

  int currentIndex = 0;

  double totalLength = 0;

  String state;

  Timer syncTimer;

  Database db;

  String debugString;

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

  TabController _tabController;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 3, vsync: this);

    _tabController.addListener(() {
      setState(() {});
    });

    player = querySelector('#mainPlayer') as AudioElement;
    player.addEventListener('loadedmetadata', (e) {
      totalLength = player.duration;
    });
    player.addEventListener('durationchange', (e) {
      totalLength = player.duration;
    });
    player.addEventListener('timeupdate', (e) {
      positionNotifier.value = player.currentTime;
    });
    player.addEventListener('ended', (e) {
      playerState.value = PlayerState.Stopped;
    });
    player.addEventListener('playing', (e) {
      playerState.value = PlayerState.Playing;
    });
    player.addEventListener('play', (e) {
      playerState.value = PlayerState.Playing;
    });
    player.addEventListener('pause', (e) {
      playerState.value = PlayerState.Paused;
    });
    player.addEventListener('loadstart', (e) {
      playerState.value = PlayerState.Loading;
    });
    player.addEventListener('error', (e) {
      playerState.value = PlayerState.Error;
    });
    syncTimer = Timer.periodic(Duration(milliseconds: 500), (t) {
      setMediaSession();
      playing.value = player.currentTime > 0 &&
          !player.paused &&
          !player.ended &&
          player.readyState > 2;
    });
    playerState.addListener(() {
      if (playerState.value == PlayerState.Stopped) {
        onEnd();
      } else if (playerState.value == PlayerState.Error) {
        scaffoldKey.currentState.showSnackBar(SnackBar(
          content: Text("This track can't be played"),
        ));
        onEnd();
      }
    });
    window.indexedDB.open("musicDB", version: 6, onUpgradeNeeded: (e) {
      print("upgrade DB");

      Database db = e.target.result;
      if (e.oldVersion < 1) {
        var ob = db.createObjectStore("tracks", keyPath: "videoId");
        ob.createIndex("videoId", "videoId", unique: true);
        ob.createIndex("timesPlayed", "timesPlayed");
        ob.createIndex("lastPlayed", "lastPlayed");
        var ob2 = db.createObjectStore(
          'playlists',
          keyPath: 'title',
        );
        ob2.add({'title': 'Favorites'});
      }
    }).then((db) {
      this.db = db;
      setState(() {});
    });
  }

  Future<Map> refreshLink(String vidId) async {
    String url = InvidiosAPI + "videos/" + vidId;
    var response = await http.get(url);
    return json.decode(utf8.decode(response.bodyBytes));
  }

  Future<Map> fetchVid(Map s) async {
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
    return s;
  }

  void next() {
    onEnd();
  }

  void previous() {
    if (currentIndex > 0) {
      currentIndex -= 1;
      playCurrent();
    } else {
      playCurrent();
    }
  }

  void playCurrent() async {
    Map s = this.queue[currentIndex];
    s = await fetchVid(s);
    queue[currentIndex] = s;
    List formats = s["adaptiveFormats"];
    formats.sort((t1, t2) {
      return int.parse(t1["bitrate"]).compareTo(int.parse(t2["bitrate"]));
    });

    for (Map f in window.localStorage["quality"].compareTo('best') == 0
        ? formats.reversed
        : formats) {
      String type = f["type"];
      if (type.contains("audio")) {
        String url = f["url"];

        player.pause();
        player.currentTime = 0;

        //howlerId = howler.callMethod("play");
        player.src = url;

        unawaited(player.play().catchError(() {
          playerState.value = PlayerState.Error;
        }));

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

  void setMediaSession() {
    Map s = queue[currentIndex];
    try {
      var metadata = MediaMetadata({
        "title": s["title"],
        "artist": s["author"],
      });
      try {
        metadata.artwork = [
          {"src": TrackTile.urlfromImage(s["videoThumbnails"], "medium")}
        ];
      } catch (e) {
        print(e);
      }
      print(window.navigator);
      print(window.navigator.mediaSession);
      try {
        if (window.navigator.mediaSession.metadata.title
                .compareTo(s["title"]) ==
            0) {
          return;
        }
      } catch (e) {
        print(e);
      }

      window.navigator.mediaSession.metadata = metadata;

      window.navigator.mediaSession.setActionHandler("play", () {
        player.play();
      });
      window.navigator.mediaSession.setActionHandler("pause", () {
        player.pause();
        playerState.value = PlayerState.Paused;
      });
      window.navigator.mediaSession.setActionHandler("nexttrack", () {
        next();
      });
      window.navigator.mediaSession.setActionHandler("previoustrack", () {
        previous();
      });
    } catch (e) {
      debugString = e.toString();
    }
  }

  void onEnd() {
    if (repeat.value == 2) {
      //IF repeatSingle
      player.play();
    } else {
      if (currentIndex == queue.length - 1) {
        if (repeat.value == 3) {
          queue.insert(currentIndex + 1,
              (queue[currentIndex]["recommendedVideos"] as List).first);
          currentIndex += 1;
          playCurrent();
        } else if (repeat.value == 1) {
          currentIndex = 0;
          playCurrent();
        }
      } else {
        if (shuffle.value) {
          currentIndex = math.Random().nextInt(queue.length);
        } else {
          currentIndex += 1;
        }
        playCurrent();
      }
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

    return Scaffold(
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
                      builder: (context) => (SearchScreen(searchQ)))))["queue"];
                  currentIndex = 0;
                  playerState.value = PlayerState.Loading;
                  playCurrent();
                }
              },
            );
          }),
          IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: () {
              showModalBottomSheet(
                  context: context,
                  builder: (context) => Container(
                      color: Theme.of(context).backgroundColor,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Padding(
                            padding: EdgeInsets.all(8),
                            child: Text(
                              "Settings",
                              style: Theme.of(context).textTheme.title,
                            ),
                          ),
                          SwitchListTile.adaptive(
                            value: window.localStorage["brightness"] == "dark",
                            title: Text("Dark Mode"),
                            onChanged: (val) {
                              if (val) {
                                window.localStorage['brightness'] = "dark";
                              } else {
                                window.localStorage["brightness"] = "light";
                              }
                              scaffoldKey.currentState.showSnackBar(SnackBar(
                                content: Text("Reload to take effect"),
                              ));
                              Navigator.pop(context);
                            },
                          ),
                          ListTile(
                            title: Text("Quality"),
                            trailing: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DropdownButton(
                                value: window.localStorage['quality'],
                                items: [
                                  DropdownMenuItem(
                                    value: 'best',
                                    child: Text("Best Quality"),
                                  ),
                                  DropdownMenuItem(
                                    value: 'worst',
                                    child: Text("Minimize Data"),
                                  )
                                ],
                                onChanged: (quality) {
                                  window.localStorage["quality"] = quality;
                                  Navigator.pop(context);
                                },
                              ),
                            ),
                          ),
                          ListTile(
                            title: Text("Invidious API"),
                            onTap: () async {
                              var controller = TextEditingController.fromValue(
                                  TextEditingValue(
                                      text:
                                          window.localStorage["invidiousApi"]));
                              await showDialog(
                                  context: context,
                                  builder: (context) => SimpleDialog(
                                        title: Text("Invidious API"),
                                        children: <Widget>[
                                          TextField(
                                            controller: controller,
                                          ),
                                          ButtonBar(
                                            children: <Widget>[
                                              FlatButton(
                                                child: Text("Cancel"),
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                },
                                              ),
                                              RaisedButton(
                                                child: Text("Apply"),
                                                onPressed: () {
                                                  window.localStorage[
                                                          "invidiousApi"] =
                                                      controller.text;
                                                  Navigator.pop(context);
                                                },
                                              )
                                            ],
                                          )
                                        ],
                                      ));
                              scaffoldKey.currentState.showSnackBar(SnackBar(
                                content: Text("Reload to take effect"),
                              ));
                            },
                          )
                        ],
                      )));
            },
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: <Widget>[
            Tab(
              icon: Icon(Icons.home),
              text: "Home",
            ),
            Tab(
              icon: Icon(Icons.person),
              text: "Artists",
            ),
            Tab(
              icon: Icon(Icons.library_music),
              text: "Library",
            )
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          Home((trackdata) {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => (TrackDetail(trackdata, (q) {
                      queue = q;
                      currentIndex = 0;
                      playerState.value = PlayerState.Loading;
                      playCurrent();
                    }))));
          }),
          Artists((q) {
            queue = q;
            currentIndex = 0;
            playCurrent();
          }, (track) {
            if (queue != null && queue.isNotEmpty) {
              queue.insert(currentIndex + 1, track);
            } else {
              queue = [track];
              currentIndex = 0;
              playCurrent();
            }
          }),
          Library((q) {
            queue = q;
            currentIndex = 0;
            playCurrent();
          }, (track) {
            if (queue != null && queue.isNotEmpty) {
              queue.insert(currentIndex + 1, track);
            } else {
              queue = [track];
              currentIndex = 0;
              playCurrent();
            }
          }, db),
        ],
      ),
      floatingActionButton: _tabController.index == 2
          ? FloatingActionButton(
              child: Icon(Icons.add),
              onPressed: () async {
                int create = await showDialog(
                    context: context,
                    builder: (context) {
                      return SimpleDialog(
                        title: Text("New Playlist"),
                        children: <Widget>[
                          FlatButton(
                            child: Text("Local Playlist"),
                            onPressed: () {
                              Navigator.pop(context, 1);
                            },
                          ),
                          FlatButton(
                            child: Text("Import from YouTube"),
                            onPressed: () {
                              Navigator.pop(context, 2);
                            },
                          )
                        ],
                      );
                    });
                if (create == 1) {
                  bool reload = await showDialog(
                      context: context,
                      builder: (context) {
                        var _controller = TextEditingController();
                        return SimpleDialog(
                          title: Text("Local Playlist"),
                          children: <Widget>[
                            TextField(
                              controller: _controller,
                              decoration:
                                  InputDecoration(labelText: "Playlist Name"),
                            ),
                            ButtonBar(
                              children: <Widget>[
                                FlatButton(
                                  child: Text("Cancel"),
                                  onPressed: () {
                                    Navigator.pop(context, false);
                                  },
                                ),
                                RaisedButton(
                                  child: Text("Create"),
                                  onPressed: () {
                                    if (!db.objectStoreNames
                                        .contains('playlists')) {
                                      var ob = db.createObjectStore(
                                        'playlists',
                                        keyPath: 'title',
                                      );
                                    }
                                    var ob = db
                                        .transaction('playlists', 'readwrite')
                                        .objectStore('playlists');
                                    ob.add({'title': _controller.text});
                                    Navigator.pop(context, true);
                                  },
                                )
                              ],
                            )
                          ],
                        );
                      });
                  setState(() {});
                } else if (create == 2) {
                  bool reload = await showDialog(
                      context: context,
                      builder: (context) {
                        var _controller = TextEditingController();
                        return SimpleDialog(
                          title: Text("Import Playlist"),
                          children: <Widget>[
                            TextField(
                              controller: _controller,
                              decoration: InputDecoration(
                                  labelText: "Youtube Playlist URL"),
                            ),
                            ButtonBar(
                              children: <Widget>[
                                FlatButton(
                                  child: Text("Cancel"),
                                  onPressed: () {
                                    Navigator.pop(context, false);
                                  },
                                ),
                                RaisedButton(
                                  child: Text("Import"),
                                  onPressed: () async {
                                    var url = InvidiosAPI +
                                        "playlists/" +
                                        _controller.text.split('list=').last;
                                    var response = await http.get(url);
                                    Map jsresponse = await json.decode(
                                        utf8.decode(response.bodyBytes));
                                    if (jsresponse.containsKey('title')) {
                                      var ob = db
                                          .transaction('playlists', 'readwrite')
                                          .objectStore('playlists');
                                      await ob.add(jsresponse);
                                      Navigator.pop(context, true);
                                    }
                                  },
                                )
                              ],
                            )
                          ],
                        );
                      });
                  setState(() {});
                }
              },
            )
          : null,
      bottomNavigationBar: Container(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            /*
              if (debugString != null && debugString.isNotEmpty && kDebugMode)
                Text(debugString),
              */
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
                    player.currentTime = pos;
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
                      onPressed: previous,
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
                                    player.pause();
                                    playerState.value = PlayerState.Paused;
                                  } else {
                                    player.play();
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
                      onPressed: next,
                    ),
                    ValueListenableBuilder(
                      valueListenable: positionNotifier,
                      builder: (context, double position, child) {
                        return Text(formatDuration(Duration(
                                milliseconds:
                                    (positionNotifier.value * 1000).toInt())) +
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
                              scaffoldKey.currentState.showSnackBar(SnackBar(
                                content: Text("Repeat All"),
                              ));
                            },
                            color: Theme.of(context).disabledColor,
                          );
                        } else if (repeatcurrent == 1) {
                          return IconButton(
                            icon: Icon(Icons.repeat),
                            onPressed: () {
                              repeat.value = 2;
                              scaffoldKey.currentState.showSnackBar(SnackBar(
                                content: Text("Repeat One"),
                              ));
                            },
                          );
                        } else if (repeatcurrent == 2) {
                          return IconButton(
                            icon: Icon(Icons.repeat_one),
                            onPressed: () {
                              repeat.value = 3;

                              scaffoldKey.currentState.showSnackBar(SnackBar(
                                content: Text("Autoplay Recommended"),
                              ));
                            },
                          );
                        } else {
                          return IconButton(
                            icon: Icon(Icons.sync),
                            onPressed: () {
                              repeat.value = 0;
                              scaffoldKey.currentState.showSnackBar(SnackBar(
                                content: Text("Repeat None"),
                              ));
                            },
                          );
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.arrow_upward),
                      onPressed: queue != null && queue.isNotEmpty
                          ? () {
                              showModalBottomSheet(
                                  context: context,
                                  builder: (context) {
                                    return Column(children: <Widget>[
                                      Text(
                                        "Queue",
                                        style:
                                            Theme.of(context).textTheme.title,
                                      ),
                                      Expanded(
                                        child: ListView.builder(
                                          itemCount: queue.length,
                                          shrinkWrap: true,
                                          itemBuilder: (ctx, i) {
                                            return Card(
                                              child: ListTile(
                                                leading: i == currentIndex
                                                    ? Icon(Icons.play_arrow)
                                                    : Text((i - currentIndex)
                                                        .toString()),
                                                title: Text(queue[i]["title"]),
                                              ),
                                            );
                                          },
                                        ),
                                      )
                                    ]);
                                  });
                            }
                          : null,
                    )
                  ],
                )
              ],
            )
          ],
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
            angle: -math.pi / 4,
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
