#!/usr/bin/env ruby
require 'em-websocket'
require 'json'

PORT = 8090
REFRESH_TIME = 0.05
ACELERACION = 0.5
MAX_VEL = 6
WIDTH,HEIGHT = 600,300

RADIO_PLAYER = 10
RADIO_PELOTA = 5

def distancia obj1, obj2
	Math.sqrt((obj1[:x]-obj2[:x])**2 + (obj1[:y]-obj2[:y])**2)
end

$pos = { player: [], pelota: { x: 60, y: 60 } }
$vel = { player: [], pelota: { x: 0, y: 0 } }
$apretada = []
$njugadores = 0
$timer = nil
$clients = Hash.new # clients[connection] = pos

def send_all data
	$clients.each_key { |ws| ws.send data }
end

EventMachine::run do
	EventMachine::WebSocket.run(:host => "0.0.0.0", :port => PORT) do |connection|
		cpos = { x: 20, y: 20 }
		cvel = { x: 0, y: 0 }
		capr = {}
		
		connection.onopen do |handshake| puts "Cliente conectado! :D"
			$clients[connection] = $njugadores
			$njugadores += 1
			# TODO  no superponer a otro jugador del campo la posición inicial
			$pos[:player] << cpos
			$vel[:player] << cvel
			$apretada << capr
		end
		
		connection.onmessage do |data| puts data
			tecla,pressed = data.split
			capr[tecla.to_i] = (pressed == '1')
		end
		
		connection.onclose do puts "Se fue... T_T"
			i = $clients[connection]
			$clients.delete connection
			for cl,icl in $clients
				$clients[cl] = icl-1 if icl > i
			end
			$pos[:player].delete_at i
			$vel[:player].delete_at i
			$apretada.delete_at i
			$njugadores -= 1
		end
	end
	
	
	$timer = EventMachine::PeriodicTimer.new(REFRESH_TIME) do
		
		$njugadores.times do |i|
			ipos, ivel, iapr = $pos[:player][i], $vel[:player][i], $apretada[i]
			
			for eje,t1,t2 in [[:x,37,39],[:y,38,40]]
				if iapr[t1] and not iapr[t2]
					ivel[eje] -= ACELERACION if ivel[eje]
					ivel[eje] = -MAX_VEL if ivel[eje] < -MAX_VEL
				elsif not iapr[t1] and iapr[t2]
					ivel[eje] += ACELERACION if ivel[eje]
					ivel[eje] = MAX_VEL if ivel[eje] > MAX_VEL
				elsif ivel[eje] > 0
					ivel[eje] -= ACELERACION
					ivel[eje] = 0 if ivel[eje] < 0
				elsif ivel[eje] < 0
					ivel[eje] += ACELERACION
					ivel[eje] = 0 if ivel[eje] > 0
				end
			end
			
			for eje,maxeje in [[:x,WIDTH],[:y,HEIGHT]]
				ipos[eje] += ivel[eje]
				ipos[eje], ivel[eje] = RADIO_PLAYER, 0 if ipos[eje] < RADIO_PLAYER
				ipos[eje], ivel[eje] = maxeje-RADIO_PLAYER, 0 if ipos[eje] > maxeje-RADIO_PLAYER
			end
			
		end
		
		send_all JSON.generate($pos)
	end
	
	puts "Iniciado servidor en el puerto #{PORT}"
end
