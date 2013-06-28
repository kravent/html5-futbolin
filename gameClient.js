'use strict';
var canvas=document.getElementById('canvas');
canvas.style.background='#000';
var ctx=canvas.getContext('2d');

var lastKey=null;
var pressing=[];
var radio_player = 10, radio_pelota = 5;
var player = [];
var pelota = { x: 0, y: 0 };

window.requestAnimationFrame = requestAnimationFrame || mozRequestAnimationFrame || webkitmozRequestAnimationFrame;

var ws = null;

// Conexiones con el servidor

function begin_websocket(server) {
	ws = new WebSocket('ws://'+server+'/room?width='+canvas.width+'&height='+canvas.height);
	ws.onmessage = function(msg){
		var data = JSON.parse(msg.data);
		player = data.player;
		pelota = data.pelota;
	}
	ws.onclose = function(data){
		console.log(data);
		ws = null;
	}

	ws.onopen = function() {console.log("Conexion establecida");
		document.addEventListener('keydown',function(evt){
			lastKey=evt.keyCode;
			if(!pressing[lastKey]){
				pressing[evt.keyCode]=true;
				ws.send(lastKey+' 1');
			}
		},false);

		document.addEventListener('keyup',function(evt){
			pressing[evt.keyCode]=false;
			ws.send(evt.keyCode+' 0');
		},false);
	};
}



// Funciones de dibujo

function paint_clear() {
	ctx.fillStyle = '#1A4300';
	ctx.fillRect(0,0,canvas.width,canvas.height);
}

function paint_player(pos) {
	ctx.strokeStyle = '#000';
	ctx.fillStyle = '#f00';
	ctx.beginPath();
	ctx.arc(pos.x,pos.y,radio_player,0,Math.PI*2,true);
	ctx.fill();
	ctx.stroke();
}

function paint_pelota(pos, radio, color) {
	ctx.strokeStyle = '#000';
	ctx.fillStyle = '#fff';
	ctx.beginPath();
	ctx.arc(pos.x,pos.y,radio_pelota,0,Math.PI*2,true);
	ctx.fill();
	ctx.stroke();
}

function paint(){
    paint_clear();
	for(var i in player)
		paint_player(player[i]);
	paint_pelota(pelota);
	
	requestAnimationFrame(paint);
}

function begin_paint() {
	requestAnimationFrame(paint);
}



// Inicializacion de componentes

begin_paint();
begin_websocket('localhost:8090');
