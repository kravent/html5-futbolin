'use strict';
var canvas=document.getElementById('canvas');
canvas.style.background='#000';
var ctx=canvas.getContext('2d');

//var mousex=0,mousey=0;
var lastKey=null;
var PRESSING=[];
var radio_player = 10, radio_pelota = 5;
var player = [];
var pelota = { x: 0, y: 0 };


window.requestAnimationFrame = requestAnimationFrame || mozRequestAnimationFrame || webkitmozRequestAnimationFrame;

var ws = new WebSocket('ws://localhost:8090/room?width='+canvas.width+'&height='+canvas.height);
ws.onmessage = function(msg){
	var data = JSON.parse(msg.data);
	player = data.player;
	pelota = data.pelota;
}
ws.onclose = function(data){console.log(data);}

ws.onopen = function() {console.log("Conexion establecida");
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


function paint_circle(pos, radio, color) {
	ctx.strokeStyle = color;
	ctx.beginPath();
	ctx.arc(pos.x,pos.y,radio,0,Math.PI*2,true);
	ctx.stroke();
}

function paint(){
    ctx.clearRect(0,0,canvas.width,canvas.height);
	for(var i in player)
		paint_circle(player[i], radio_player, '#0f0');
	paint_circle(pelota, radio_pelota, '#0f0');
	
	requestAnimationFrame(paint);
}
requestAnimationFrame(paint);
