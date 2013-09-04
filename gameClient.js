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
	40: ['kd', 'd1'],
	65: ['kd', 'l1'],
	87: ['kd', 'u1'],
	68: ['kd', 'r1'],
	83: ['kd', 'd1']
}
var keyup_map = {
	37: ['kd', 'l0'],
	38: ['kd', 'u0'],
	39: ['kd', 'r0'],
	40: ['kd', 'd0'],
	65: ['kd', 'l0'],
	87: ['kd', 'u0'],
	68: ['kd', 'r0'],
	83: ['kd', 'd0']
}

var pressing=[];
var radio_player = 10, radio_pelota = 5, radio_player_alcance = 15;
var player = [];
var pelota = { x: 0, y: 0 };
var playerinfo = [];
var playerpos = -1;
var marcador = { red: 0, blue: 0 }, gol = undefined, golanimation = 0;

var duracion_animacion_chute = 10; //frames
var animacion_chute = -1;
var porteria_size_x = 20, porteria_size_y = 20, campo_x = 300, campo_y = 600;
var banda_size_x = 5, banda_size_y = 40;
var color_red = 'red', color_blue = 'blue';

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
		evt.preventDefault();
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
		evt.preventDefault();
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
	if(serverdata.map_width) campo_x = serverdata.map_width;
	if(serverdata.map_height) campo_y = serverdata.map_height;
	if(serverdata.radio_player) radio_player = serverdata.radio_player;
	if(serverdata.radio_pelota) radio_pelota = serverdata.radio_pelota;
	if(serverdata.radio_player_alcance) radio_player_alcance = serverdata.radio_player_alcance;
	if(serverdata.porteria_size_x) porteria_size_x = serverdata.porteria_size_x;
	if(serverdata.porteria_size_y) porteria_size_y = serverdata.porteria_size_y;
	if(serverdata.marcador) marcador = serverdata.marcador;
	if(serverdata.gol) {
		gol = serverdata.gol;
		golanimation = 0;
	}
	if(serverdata.reset) {
		gol = undefined;
	}
	canvas.width = campo_x + porteria_size_x*2 + banda_size_x*2;
	canvas.height = campo_y + banda_size_y*2;
}


// Funciones de dibujo

canvas.style.background='#569330';

function paint_clear() {
	ctx.clearRect(0, 0, canvas.width, canvas.height);
}

function paint_marcador() {
	ctx.font = 'bold '+(banda_size_y-10)+'px Arial';
	ctx.textAlign = 'right';
	ctx.textBaseline = 'middle';
	var x = canvas.width-20;
	var y = banda_size_y/2;
	ctx.strokeStyle = '#fff';
	ctx.lineWidth = 4;
	
	ctx.fillStyle = color_blue;
	ctx.strokeText(marcador.blue, x, y);
	ctx.fillText(marcador.blue, x, y);
	x -= ctx.measureText(marcador.blue).width;
	ctx.fillStyle = '#000';
	ctx.strokeText(' - ', x, y);
	ctx.fillText('- ', x, y);
	x -= ctx.measureText(' - ').width;
	ctx.fillStyle = color_red;
	ctx.strokeText(marcador.red, x, y);
	ctx.fillText(marcador.red, x, y);
}

function paint_gol_message() {
	if(gol) {
		ctx.save();
			ctx.translate(canvas.width/2, canvas.height/2)
			ctx.scale(golanimation, golanimation);
			golanimation += (1-golanimation)/10;
			var txt = 'GOOOOOL!', px = 100;
			ctx.font = 'bold '+px+'px Arial';
			ctx.textAlign = 'center';
			ctx.textBaseline = 'middle';
			if(gol == 'red') ctx.fillStyle = color_red;
			else ctx.fillStyle = color_blue;
			ctx.strokeStyle = '#fff';
			ctx.lineWidth = 8;
			ctx.strokeText(txt, 0, 0);
			ctx.fillText(txt, 0, 0);
		ctx.restore();
	}
}

var radio_red_porteria = 6;
function paint_porteria() {
	// Esquina superior derecha de la portería situada en el punto (0,0)
	ctx.beginPath();
	ctx.strokeStyle = '#fff';
	ctx.lineWidth = 2;
	ctx.fillStyle = '#477729';
	ctx.moveTo(0, 0);
	ctx.arcTo(-porteria_size_x, 0, -porteria_size_x, porteria_size_y, radio_red_porteria);
	ctx.arcTo(-porteria_size_x, porteria_size_y, 0, porteria_size_y, radio_red_porteria);
	ctx.lineTo(0, porteria_size_y);
	ctx.stroke();
	ctx.fill();
}

function paint_board() {
	// Dibujar lineas del campo
	ctx.strokeStyle = '#fff';
	ctx.lineWidth = 5;
	
	ctx.beginPath();
	ctx.rect(2, 0+2, campo_x-4, campo_y-4);
	ctx.stroke();
	
	ctx.beginPath();
	ctx.moveTo(campo_x/2, 0);
	ctx.lineTo(campo_x/2, campo_y);
	ctx.stroke();
	
	ctx.beginPath();
	ctx.arc(campo_x/2, campo_y/2, campo_y/4, 0, Math.PI*2);
	ctx.stroke();
	
	ctx.beginPath();
	ctx.arc(campo_x/2, campo_y/2, 4, 0, Math.PI*2);
	ctx.stroke();
	
	// Dibujar porterías
	ctx.save();
		ctx.translate(0, (campo_y-porteria_size_y)/2);
		paint_porteria();
		ctx.translate(campo_x, 0);
		ctx.scale(-1, 1);
		paint_porteria();
	ctx.restore();
}

function paint_player(pos, info) {
	ctx.strokeStyle = '#000';
	ctx.lineWidth = 2;
	if(info.color == 'red') {
		ctx.fillStyle = '#f00';
	} else {
		ctx.fillStyle = '#00f';
	}
	ctx.beginPath();
	ctx.arc(pos.x,pos.y,radio_player,0,Math.PI*2,true);
	ctx.fill();
	ctx.stroke();
}

function paint_pelota(pos) {
	ctx.strokeStyle = '#000';
	ctx.lineWidth = 2;
	ctx.fillStyle = '#E2E2E2';
	ctx.beginPath();
	ctx.arc(pos.x,pos.y,radio_pelota,0,Math.PI*2,true);
	ctx.fill();
	ctx.stroke();
}

function paint_self_player() {
	var selfplayer = player[playerpos];
	
	// Marcar zona de chute propia
	ctx.strokeStyle = '#454545';
	ctx.lineWidth = 1;
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
	paint_marcador();
	ctx.save();
		ctx.translate(banda_size_x+porteria_size_x, banda_size_y);
		paint_board();
		paint_self_player();
		for(var i in player)
			paint_player(player[i], playerinfo[i]);
		paint_pelota(pelota);
	ctx.restore();
	paint_gol_message();
	
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

