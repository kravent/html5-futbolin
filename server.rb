#!/usr/bin/env ruby
require 'em-websocket'
require 'json'

PORT = 8090
REFRESH_TIME = 0.05
ACELERACION = 0.5
MAX_VEL = 6

RADIO_PLAYER = 10
RADIO_PELOTA = 5

def distancia obj1, obj2
	Math.sqrt((obj1[:x]-obj2[:x])**2 + (obj1[:y]-obj2[:y])**2)
end


EventMachine::run do
	EventMachine::WebSocket.run(:host => "0.0.0.0", :port => PORT) do |connection|
		width,height = 100,100
		pos = { player: { x: 20, y: 20 }, pelota: { x: 60, y: 60 } }
		vel = { player: { x: 0, y: 0 }, pelota: { x: 0, y: 0 } }
		apretada = {}
		timer = nil
		
		connection.onopen do |handshake| puts "Cliente conectado! :D"
			width,height = handshake.query.values_at('width', 'height').map{|e| e.to_i }
			# TODO  pos inicial
			timer = EventMachine::PeriodicTimer.new(REFRESH_TIME) do
				vel[:player][:x] += (apretada[37] ? -ACELERACION : 0) + (apretada[39] ? ACELERACION : 0)
				vel[:player][:y] += (apretada[38] ? -ACELERACION : 0) + (apretada[40] ? ACELERACION : 0)
				for eje,t1,t2 in [[:x,37,39],[:y,38,40]]
					if apretada[t1] and not apretada[t2]
						vel[:player][eje] -= ACELERACION if vel[:player][eje]
						vel[:player][eje] = -MAX_VEL if vel[:player][eje] < -MAX_VEL
					elsif not apretada[t1] and apretada[t2]
						vel[:player][eje] += ACELERACION if vel[:player][eje]
						vel[:player][eje] = MAX_VEL if vel[:player][eje] > MAX_VEL
					elsif vel[:player][eje] > 0
						vel[:player][eje] -= ACELERACION
						vel[:player][eje] = 0 if vel[:player][eje] < 0
					elsif vel[:player][eje] < 0
						vel[:player][eje] += ACELERACION
						vel[:player][eje] = 0 if vel[:player][eje] > 0
					end
				end
				
				for eje,maxeje in [[:x,width],[:y,height]]
					puts "eje y: #{pos[:player][:y]} #{vel[:player][:y]}    maxeje: #{maxeje}" if eje == :y
					pos[:player][eje] += vel[:player][eje]
					pos[:player][eje] = RADIO_PLAYER if pos[:player][eje] < RADIO_PLAYER
					pos[:player][eje] = maxeje-RADIO_PLAYER if pos[:player][eje] > maxeje-RADIO_PLAYER
				end
				
				connection.send JSON.generate(pos)
			end
		end
		
		connection.onmessage do |data| puts data
			tecla,pressed = data.split
			apretada[tecla.to_i] = (pressed == '1')
		end
		
		connection.onclose do puts "Se fue... T_T"
			timer.cancel rescue nil
		end
	end
	
	puts "Iniciado servidor en el puerto #{PORT}"
end
