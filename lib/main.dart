import 'package:flutter_web/material.dart';
import 'dart:js' as js;

import 'searchScreen.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    js.context.callMethod("removeLoader");
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatelessWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;
  TextEditingController textEditingController=TextEditingController();

  List queue;

  GlobalKey<ScaffoldState> scaffoldKey= GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextField(
              controller: textEditingController,
              decoration: InputDecoration(
                labelText: "Search"
              ),
            ),
            RaisedButton(
              child: Text(
                "Open Search"
              ),
              onPressed: (){
                
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context)=>(SearchScreen(textEditingController.text))
                  )
                ).then((queue){
                  this.queue=queue["queue"];
                  Map s = this.queue.first;
                  List formats =s["adaptiveFormats"];
                  for(Map f in formats){
                    String type = f["type"];
                    if(type.contains("audio")){
                      String url = f["url"];
                      js.context.callMethod("play",
                        [url]
                      );
                      scaffoldKey.currentState.showSnackBar(
                        SnackBar(
                          content: Text(
                            "Playing "+f["title"]
                          ),
                        )
                      );
                      break;
                    }
                  }
                });
              },
            ),
          ],
        ),
      ), 
    );
  }
}
