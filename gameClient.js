var canvas=document.getElementById('canvas');
var ctx=canvas.getContext('2d');

var paneles = {
	connect: document.getElementById('div_connect'),
	connecting: document.getElementById('div_connecting'),
	game: document.getElementById('div_game')
};

var keydown_map = {
	//32: 's 1', //espacio, chutar
	37: 'l 1',
	38: 'u 1',
	39: 'r 1',
	40: 'd 1'
}
var keyup_map = {
	37: 'l 0',
	38: 'u 0',
	39: 'r 0',
	40: 'd 0'
}

var pressing=[];
var radio_player = 10, radio_pelota = 5;
var player = [];
var pelota = { x: 0, y: 0 };
var playerinfo = [];

window.requestAnimationFrame = window.requestAnimationFrame || 
                               window.mozRequestAnimationFrame || 
                               window.webkitmozRequestAnimationFrame || 
                               function( callback ){ window.setTimeout(callback, 1000 / 60); };
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
	if(keydown_map[evt.keyCode] && !pressing[evt.keyCode]){
		pressing[evt.keyCode]=true;
		ws.send(keydown_map[evt.keyCode]);
	}
}

function on_keyup(evt){
	if(keyup_map[evt.keyCode] && pressing[evt.keyCode]){
		pressing[evt.keyCode]=false;
		ws.send(keyup_map[evt.keyCode]);
	}
}

function begin_websocket(server) {
	show_panel('connecting');
	ws = new WebSocket('ws://'+server+'/room');

	ws.onopen = function() {
		show_panel('game');
		document.addEventListener('keydown', on_keydown);
		document.addEventListener('keyup', on_keyup);
		begin_paint();
	};
	
	ws.onmessage = function(msg){
		var data = JSON.parse(msg.data);
		if(data.serverdata) parse_server_data(data.serverdata)
		if(data.playerinfo) playerinfo = data.playerinfo;
		if(data.player) player = data.player;
		if(data.pelota) pelota = data.pelota;
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


// Datos sobre el juego establecidos por el servidor

function parse_server_data(serverdata) {
	if(serverdata.map_width) canvas.width = serverdata.map_width;
	if(serverdata.map_height) canvas.height = serverdata.map_height;
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

var stop_paint_flag = false;

function paint(){
    paint_clear();
	for(var i in player)
		paint_player(player[i]);
	paint_pelota(pelota);
	
	if(!stop_paint_flag) requestAnimationFrame(paint);
}

function begin_paint() {
	stop_paint_flag = false;
	requestAnimationFrame(paint);
}

function stop_paint() {
	stop_paint_flag = true;
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

