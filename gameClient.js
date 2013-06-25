'use strict';
var canvas=document.getElementById('canvas');
canvas.style.background='#000';
var ctx=canvas.getContext('2d');

//var mousex=0,mousey=0;
var lastKey=null;
var PRESSING=[];
var player=new Circle(50,50,10);
var pelota=new Circle(100,100,5);


requestAnimationFrame = requestAnimationFrame || mozRequestAnimationFrame || webkitmozRequestAnimationFrame;

var ws = new WebSocket('ws://agaman.me:8090/room?width='+canvas.width+'&hight='+canvas.hight);
ws.onmessage = function(msg){
	var data = JSON.parse(msg.data);
	player.x = data.player.x;
	player.y = data.player.y;
	pelota.x = data.pelota.x;
	pelota.y = data.pelota.y;
}
ws.onclose = function(data){console.log(data);}

ws.onconnect = function() {console.log("Conexion establecida");
	document.addEventListener('keydown',function(evt){
		lastKey=evt.keyCode;
		if(!PRESSING[lastKey]){
			PRESSING[evt.keyCode]=true;
			ws.send(lastKey+' 1');
		}
	},false);

	document.addEventListener('keyup',function(evt){
		PRESSING[evt.keyCode]=false;
		ws.send(evt.keyCode+' 0');
	},false);
};


function paint(){
    ctx.clearRect(0,0,canvas.width,canvas.height);
    ctx.strokeStyle='#0f0';
    ctx.beginPath();
    ctx.arc(player.x,player.y,player.radius,0,Math.PI*2,true);
    ctx.stroke();
    ctx.strokeStyle='#f00';
    ctx.beginPath();
    ctx.arc(pelota.x,pelota.y,pelota.radius,0,Math.PI*2,true);
    ctx.stroke();
	
	requestAnimationFrame(paint);
}
requestAnimationFrame(paint);

function Circle(x,y,radius){
    this.x=(x==null)?0:x;
    this.y=(y==null)?0:y;
    this.radius=(radius==null)?0:radius;
}
