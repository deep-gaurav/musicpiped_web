var sound=null;

function playNew(str){
  console.log(
    "playing"
  );
  console.log(
    str
  );
  console.log(
    Howl
  );
  if(sound!=null){
      sound.stop();
  }
  sound = new Howl({
    "src": [str],
    "html5": true
  });

  console.log(sound);
  sound.play();
}

function play(){
    if(sound!=null){
        sound.play();
    }
}
function pause(){
    if(sound!=null){
        sound.pause();
    }
}
function stop(){
    if(sound!=null){
        sound.stop();
    }
}
function seek(pos){
    if(pos===undefined){
        return sound.seek();
    }else{
        sound.seek(pos);
    }
}
function state(){
    return sound.state();
}
function duration(){
    return sound.duration();
}

function playing(){
    return sound.playing();
}

function removeLoader(){
  var elem = document.getElementById("loader");
  elem.parentNode.removeChild(elem);
}