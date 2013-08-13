#!/usr/bin/env ruby
require 'em-websocket'
require 'json'

PORT = 8090
REFRESH_TIME = 0.05
ACELERACION = 0.7
ACELERACION2 = 0.3
DECELERACION_PELOTA = 0.05
MAX_VEL = 5
WIDTH,HEIGHT = 800,400

RADIO_PLAYER = 10
RADIO_PELOTA = 5

def distancia pos1, pos2
	Math.sqrt((pos1[:x]-pos2[:x])**2 + (pos1[:y]-pos2[:y])**2)
end

def unitario_direccion pos1, pos2, dist = nil
	dist = distancia pos1, pos2 if dist.nil?
	{ x: (pos2[:x]-pos1[:x])/dist, y: (pos2[:y]-pos1[:y])/dist }
end

$pos = { player: [], pelota: { x: 60.0, y: 60.0 } }
$vel = { player: [], pelota: { x: 0.0, y: 0.0 } }
$apretada = []
$njugadores = 0
$clients = Hash.new # clients[connection] = pos

def send_all data
	$clients.each_key { |ws| ws.send data }
end

def get_jugador i
	yield $pos[:player][i], $vel[:player][i], $apretada[i]
end

def for_jugadores
	$njugadores.times do |i|
		yield $pos[:player][i], $vel[:player][i], $apretada[i]
	end
end

def get_pelota
	yield $pos[:pelota], $vel[:pelota]
end

def for_jugadores_pelota
	$njugadores.times do |i|
		yield $pos[:player][i], $vel[:player][i]
	end
	yield $pos[:pelota], $vel[:pelota]
end

def actualizar_aceleraciones
	for_jugadores do |_, ivel, iapr|
		for eje,t1,t2 in [[:x,'l','r'],[:y,'u','d']]
			if iapr[t1] and not iapr[t2]	# izquierda o arriba
				if ivel[eje] < -MAX_VEL/2	# aceleración en movimiento
					ivel[eje] -= ACELERACION2 #if ivel[eje]
					ivel[eje] = -MAX_VEL if ivel[eje] < -MAX_VEL
				elsif ivel[eje] >= -MAX_VEL/2 and ivel[eje] <= 0	# aceleración inicial
					ivel[eje] -= ACELERACION #if ivel[eje]
				elsif ivel[eje] > 0	# desacelerar (se quiere ir al sentido contrario)
					ivel[eje] -= ACELERACION*2
				end
			elsif not iapr[t1] and iapr[t2]		# derecha o abajo
				if ivel[eje] > MAX_VEL/2	# aceleración en movimiento
					ivel[eje] += ACELERACION2 #if ivel[eje]
					ivel[eje] = MAX_VEL if ivel[eje] > MAX_VEL
				elsif ivel[eje] <= MAX_VEL/2 and ivel[eje] >= 0	# aceleración inicial
					ivel[eje] += ACELERACION
				elsif ivel[eje] < 0	# desacelerar (se quiere ir al sentido contrario)
					ivel[eje] += ACELERACION*2
				end
			elsif ivel[eje] > 0		# no se va a ninguna dirección y se desacelera despacio
				ivel[eje] -= ACELERACION2
				ivel[eje] = 0 if ivel[eje] < 0
			elsif ivel[eje] < 0
				ivel[eje] += ACELERACION2
				ivel[eje] = 0 if ivel[eje] > 0
			end
		end
	end
	
	get_pelota do |_, ivel|
		ivel[:x] = ivel[:x].abs < DECELERACION_PELOTA ? 0 : ( ivel[:x] < 0 ? ivel[:x] + DECELERACION_PELOTA : ivel[:x] - DECELERACION_PELOTA )
		ivel[:y] = ivel[:y].abs < DECELERACION_PELOTA ? 0 : ( ivel[:y] < 0 ? ivel[:y] + DECELERACION_PELOTA : ivel[:y] - DECELERACION_PELOTA )
	end
end

def colisionar_objetos o1pos, o1vel, o1radio, o2pos, o2vel, o2radio, isball=false
	dist = distancia(o1pos, o2pos)
	if dist <= o1radio + o2radio
		u1 = unitario_direccion o2pos, o1pos, dist
		u2 = unitario_direccion o1pos, o2pos, dist
		modulo1 = Math.sqrt(o1vel[:x]**2+o1vel[:y]**2)
		modulo2 = Math.sqrt(o2vel[:x]**2+o2vel[:y]**2) if !isball
		for eje in [:x, :y]
			if isball
				o2vel[eje] = u2[eje] * modulo1
			else
				o1vel[eje] += u1[eje] * modulo2
				o2vel[eje] += u2[eje] * modulo1
			end
		end
	end
end

def colisionar_pared ipos, ivel, radio, isball = false
	for eje,maxeje in [[:x,WIDTH],[:y,HEIGHT]]
		ipos[eje],ivel[eje] = radio,(isball ? -ivel[eje] : 0) if ipos[eje] <= radio and ivel[eje] < 0
		ivel[eje],ivel[eje] = maxeje-radio,(isball ? -ivel[eje] : 0) if ipos[eje] >= maxeje-radio and ivel[eje] > 0
	end
end

def actualizar_colisiones
	$njugadores.times do |i1|
		get_jugador i1 do |j1pos, j1vel|
			
			# Colisión con otro jugador
			(i1+1...$njugadores).each do |i2|
				get_jugador i2 do |j2pos, j2vel|
					colisionar_objetos j1pos, j1vel, RADIO_PLAYER, j2pos, j2vel, RADIO_PLAYER
				end
			end
			
			#Colisión con la pelota
			get_pelota do |ppos, pvel|
				colisionar_objetos j1pos, j1vel, RADIO_PLAYER, ppos, pvel, RADIO_PELOTA, true
			end
			
			#Colisión con la pared
			colisionar_pared j1pos, j1vel, RADIO_PLAYER
		end
	end
	
	get_pelota {|ipos, ivel| colisionar_pared ipos, ivel, RADIO_PELOTA, true }
end

def actualizar_posiciones
	for_jugadores_pelota do |ipos, ivel|
		modulo = Math.sqrt(ivel[:x]**2+ivel[:y]**2)
		for eje,maxeje in [[:x,WIDTH],[:y,HEIGHT]]
			ipos[eje] += (ivel[:x] == 0 || ivel[:y] == 0) ? ivel[eje] : ivel[eje]*(ivel[eje]/modulo).abs
		end
	end
end

EventMachine::run do
	timer = nil
	
	EventMachine::WebSocket.run(:host => "0.0.0.0", :port => PORT) do |connection|
		cpos = { x: 20, y: 20 }
		cvel = { x: 0, y: 0 }
		capr = {}
		
		connection.onopen do |handshake|
			connection.send JSON.generate({
				serverdata: {
					map_width: WIDTH,
					map_height: HEIGHT
				}
			})
			
			if $njugadores == 0
				timer = EventMachine::PeriodicTimer.new(REFRESH_TIME) do
					actualizar_aceleraciones
					actualizar_colisiones
					actualizar_posiciones
					send_all JSON.generate($pos)
				end
			end
			
			$clients[connection] = $njugadores
			$njugadores += 1
			# TODO  no superponer a otro jugador del campo la posición inicial
			$pos[:player] << cpos
			$vel[:player] << cvel
			$apretada << capr
		end
		
		connection.onmessage do |data|
			tecla,pressed = data.split
			capr[tecla] = (pressed == '1')
		end
		
		connection.onclose do
			i = $clients[connection]
			$clients.delete connection
			for cl,icl in $clients
				$clients[cl] = icl-1 if icl > i
			end
			$pos[:player].delete_at i
			$vel[:player].delete_at i
			$apretada.delete_at i
			$njugadores -= 1
			
			timer.cancel if $njugadores == 0
		end
	end
	
	
	
	
	puts "Iniciado servidor en el puerto #{PORT}"
end
