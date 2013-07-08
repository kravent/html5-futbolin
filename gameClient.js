var canvas=document.getElementById('canvas');
var ctx=canvas.getContext('2d');

var paneles = {
	connect: document.getElementById('div_connect'),
	connecting: document.getElementById('div_connecting'),
	game: document.getElementById('div_game')
};

var lastKey=null;
var pressing=[];
var radio_player = 10, radio_pelota = 5;
var player = [];
var pelota = { x: 0, y: 0 };

window.requestAnimationFrame = requestAnimationFrame || mozRequestAnimationFrame || webkitmozRequestAnimationFrame;
var ws = null;


// Manejo de paneles

function show_panel(name) {
	for(var i in paneles) {
		if(i == name) paneles[i].style.display = "";
		else paneles[i].style.display = "none";
	}
}


// Conexiones con el servidor

function on_keydown(evt){
	lastKey=evt.keyCode;
	if(!pressing[lastKey]){
		pressing[evt.keyCode]=true;
		ws.send(lastKey+' 1');
	}
}

function on_keyup(evt){
			pressing[evt.keyCode]=false;
			ws.send(evt.keyCode+' 0');
		}

function begin_websocket(server) {
	show_panel('connecting');
	ws = new WebSocket('ws://'+server+'/room?width='+canvas.width+'&height='+canvas.height);

	ws.onopen = function() {
		show_panel('game');
		document.addEventListener('keydown', on_keydown);
		document.addEventListener('keyup', on_keyup);
		begin_paint();
	};
	
	ws.onmessage = function(msg){
		var data = JSON.parse(msg.data);
		player = data.player;
		pelota = data.pelota;
	}
	
	ws.onclose = function(data){
		show_panel('connect');
		console.log(data);
		ws = null;
		document.removeEventListener('keydown', on_keydown);
		document.removeEventListener('keyup', on_keyup);
		stop_paint();
	};
}



// Funciones de dibujo

canvas.style.background='#1A4300';

function paint_clear() {
	ctx.clearRect(0, 0, canvas.width, canvas.height);
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

var stop_paint = false;

function paint(){
    paint_clear();
	for(var i in player)
		paint_player(player[i]);
	paint_pelota(pelota);
	
	if(!stop_paint) requestAnimationFrame(paint);
}

function begin_paint() {
	stop_paint = false;
	requestAnimationFrame(paint);
}

function stop_paint() {
	stop_paint = true;
}


// Manejador de formularios

function on_submit_connect() {
	var form = document.forms['connect'];
	var server = form['server'].value + ':' + form['port'].value;
	begin_websocket(server);
	return false;
}


// Inicializacion de componentes

show_panel('connect');
document.forms['connect'].onsubmit = on_submit_connect;

