#!/usr/bin/env ruby
require 'em-websocket'
require 'json'

REFRESH_TIME = 0.1
ACELERACION = 2

RADIO_PLAYER = 10
RADIO_PELOTA = 5

def distancia obj1, obj2
	Math.sqrt((obj1[:x]-obj2[:x])**2 + (obj1[:y]-obj2[:y])**2)
end


EventMachine::run do
	EventMachine::WebSocket.run(:host => "0.0.0.0", :port => 8080) do |connection|
		width,height = 100,100
		pos = { player: { x: 20, y: 20 }, pelota: { x: 60, y: 60 } }
		vel = { player: { x: 0, y: 0 }, pelota: { x: 0, y: 0 } }
		apretada = {}
		timer = nil
		
		connection.onopen do |handshake| puts "Cliente conectado! :D"
			width,height = handshake.query.values_at('width', 'height').map{|e| e.to_i }
			# TODO  pos inicial
			timer = EventMachine::PeriodicTimer.new(REFRESH_TIME) do
				pos[:player][:x] -= ACELERACION if apretada[37] and pos[:player][:x] > ACELERACION # izquierda
				pos[:player][:y] -= ACELERACION if apretada[38] and pos[:player][:y] > ACELERACION # arriba
				pos[:player][:x] += ACELERACION if apretada[39] and pos[:player][:x] < width - ACELERACION # derecha
				pos[:player][:y] += ACELERACION if apretada[40] and pos[:player][:y] > height - ACELERACION # abajo
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
	
	puts "Iniciado servidor en el puerto 8080"
end
