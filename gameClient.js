var canvas=document.getElementById('canvas');
var ctx=canvas.getContext('2d');

var paneles = {
	connect: document.getElementById('div_connect'),
	connecting: document.getElementById('div_connecting'),
	game: document.getElementById('div_game')
};

var keydown_map = {
	32: ['ks', 's'],
	37: ['kd', 'l1'],
	38: ['kd', 'u1'],
	39: ['kd', 'r1'],
	40: ['kd', 'd1']
}
var keyup_map = {
	37: ['kd', 'l0'],
	38: ['kd', 'u0'],
	39: ['kd', 'r0'],
	40: ['kd', 'd0']
}

var pressing=[];
var radio_player = 10, radio_pelota = 5, radio_player_alcance = 15;
var player = [];
var pelota = { x: 0, y: 0 };
var playerinfo = [];
var playerpos = -1;

var duracion_animacion_chute = 10; //frames
var animacion_chute = -1;

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
	var k = keydown_map[evt.keyCode];
	if(k){
		if(k[0] == 'kd'){
			if(!!pressing[evt.keyCode]) return;
			pressing[evt.keyCode] = true;
		} else if(k[0] == 'ks') {
			animacion_chute = 0;
		}
		ws.send(k.join(' '));
	}
}

function on_keyup(evt){
	var k = keyup_map[evt.keyCode];
	if(k){
		if(k[0] == 'kd'){
			if(!pressing[evt.keyCode]) return;
			pressing[evt.keyCode] = false;
		}
		ws.send(k.join(' '));
	}
}

function begin_websocket(server) {
	show_panel('connecting');
	ws = new WebSocket('ws://'+server+'/room');
	var waiting_data = true; // Indica si sigue esperando para iniciar el juego
	
	ws.onopen = function() {
		
	};
	
	ws.onmessage = function(msg){
		var data = JSON.parse(msg.data);
		if(data.serverdata) parse_server_data(data.serverdata)
		if(data.playerinfo) playerinfo = data.playerinfo;
		if(data.playerpos != undefined) playerpos = data.playerpos;
		if(data.player) player = data.player;
		if(data.pelota) pelota = data.pelota;
		if(waiting_data && data.playerpos != undefined) {
			waiting_data = false;
			show_panel('game');
			document.addEventListener('keydown', on_keydown);
			document.addEventListener('keyup', on_keyup);
			begin_paint();
		}
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
	if(serverdata.radio_player) radio_player = serverdata.radio_player;
	if(serverdata.radio_pelota) radio_pelota = serverdata.radio_pelota;
	if(serverdata.radio_player_alcance) radio_player_alcance = serverdata.radio_player_alcance;
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

function paint_pelota(pos) {
	ctx.strokeStyle = '#000';
	ctx.fillStyle = '#fff';
	ctx.beginPath();
	ctx.arc(pos.x,pos.y,radio_pelota,0,Math.PI*2,true);
	ctx.fill();
	ctx.stroke();
}

function paint_self_player() {
	var selfplayer = player[playerpos];
	
	// Marcar zona de chute propia
	ctx.strokeStyle = '#848484';
	ctx.beginPath();
	ctx.arc(selfplayer.x,selfplayer.y,radio_player_alcance,0,Math.PI*2,true);
	ctx.stroke();
	
	// Animación de chute
	if(animacion_chute >= 0) {
		var rad = (animacion_chute * (radio_player_alcance-radio_player) / duracion_animacion_chute) + radio_player;
		ctx.strokeStyle = '#fff';
		ctx.beginPath();
		ctx.arc(selfplayer.x,selfplayer.y,rad,0,Math.PI*2,true);
		ctx.stroke();
		if(animacion_chute >= duracion_animacion_chute)
			animacion_chute = -2;
		animacion_chute += 1;
	}
}


// Control del redibujado

var stop_paint_flag = false;

function paint(){
	paint_clear();
	paint_self_player();
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

