'use strict';
var canvas=document.getElementById('canvas');
canvas.style.background='#000';
var ctx=canvas.getContext('2d');

//var mousex=0,mousey=0;
var lastKey=null;
//var PRESSING=[];
var player=new Circle(50,50,10);
var pelota=new Circle(100,100,5);

var ws = new WebSocket('ws://localhost:8080/room?width='+canvas.width+'&hight='+canvas.hight);
ws.onmessage = function(msg){
	var data = JSON.parse(msg.data);
	player.x = data.player.x;
	player.y = data.player.y;
	pelota.x = data.pelota.x;
	pelota.y = data.pelota.y;
}

/*function init(){
    //run();
}*/

/*function run(){
    setTimeout(run,50);
    //game();
    paint(ctx);
}*/

function game(){
    //player.x=mousex;
    //player.y=mousey;
    
	/*if(PRESSING[38]) //UP
		player.y-=2;
	if(PRESSING[39]) //RIGHT
		player.x+=2;
	if(PRESSING[40]) //DOWN
		player.y+=2;
	if(PRESSING[37]) //LEFT
		player.x-=2;
    
    if(player.x<0)
        player.x=0;
    if(player.x>canvas.width)
        player.x=canvas.width;
    if(player.y<0)
        player.y=0;
    if(player.y>canvas.height)
        player.y=canvas.height;
    
    if(pelota.distance(player)<0){
        var angle=player.getAngle(pelota);
        pelota.move(angle,3);
    }*/
}

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
    
    //ctx.fillStyle='#fff';
    //ctx.fillText('Distance: '+player.distance(pelota).toFixed(1),10,10);
    //ctx.fillText('Angle: '+(player.getAngle(pelota)*(180/Math.PI)).toFixed(1),10,20);
	
	requestAnimationFrame(paint);
}
requestAnimationFrame(paint);

/*document.addEventListener('mousemove',function(evt){
    mousex=evt.pageX-canvas.offsetLeft;
    mousey=evt.pageY-canvas.offsetTop;
},false);*/

document.addEventListener('keydown',function(evt){
	//lastKey=evt.keyCode;
	//PRESSING[evt.keyCode]=true;
	lastKey=evt.keyCode;
	ws.send(lastKey+' 1');
},false);

document.addEventListener('keyup',function(evt){
	//PRESSING[evt.keyCode]=false;
	ws.send(evt.keyCode+' 0');
},false);

function Circle(x,y,radius){
    this.x=(x==null)?0:x;
    this.y=(y==null)?0:y;
    this.radius=(radius==null)?0:radius;
    
    /*this.distance=function(circle){
        if(circle!=null){
            var dx=this.x-circle.x;
            var dy=this.y-circle.y;
            return (Math.sqrt(dx*dx+dy*dy)-(this.radius+circle.radius));
        }
    }
    
    this.getAngle=function(circle){
        if(circle!=null)
            return (Math.atan2(this.y-circle.y,this.x-circle.x));
    }
    
    this.move=function(angle,speed){
        if(speed!=null){
            this.x-=Math.cos(angle)*speed;
            this.y-=Math.sin(angle)*speed;
        }
    }*/
}
