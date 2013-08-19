#!/usr/bin/env ruby
require 'em-websocket'
require 'json'
require 'socket'

PORT = 8090
REFRESH_TIME = 0.05
ACELERACION_PLAYER = 1
DECELARACION_PLAYER = 0.3
DECELERACION_PELOTA = 0.05
MAX_VEL_PLAYER = 5
MAX_VEL_PELOTA = 20
BOARD_SIZE = { x: 800, y: 400 }
PORTERIA_SIZE = {x: 50, y: 100}
RADIO_PLAYER = 15
RADIO_PELOTA = 9
RADIO_PLAYER_ALCANCE = 25
VELOCIDAD_CHUTE = 10

def distancia(pos1, pos2)
	Math.sqrt((pos1[:x]-pos2[:x])**2 + (pos1[:y]-pos2[:y])**2)
end

def unitario_direccion(pos1, pos2, dist = nil)
	dist = distancia pos1, pos2 if dist.nil?
	[(pos2[:x]-pos1[:x])/dist, (pos2[:y]-pos1[:y])/dist]
end

def vector2unitario(vx, vy)
	return [0, 0, 0] if vx==0 and vy ==0
	mod = Math.sqrt(vx**2 + vy**2)
	[vx/mod, vy/mod, mod] # unitario_x, unitario_y, modulo
end

class Elemento
	attr_reader :tipo, :radio, :acel_mod, :decel_mod, :vel_max, :pos, :vel, :acel, :ws
	attr_accessor :chutar
	
	def initialize(tipo, radio, acel_mod, decel_mod, vel_max, pos, ws=nil)
		@tipo = tipo
		@radio = radio
		@acel_mod = acel_mod
		@decel_mod = decel_mod
		@vel_max = vel_max
		
		@pos = pos
		@vel = { x:0, y:0, mod: 0 }
		@acel = { x:0, y:0 }
		@chutar = false
		
		@ws = ws
	end
	
	def vel_xy
		[@vel[:x]*@vel[:mod], @vel[:y]*@vel[:mod]]
	end
	
	def acelerar()
		# Desaceleración debido al rozamiento
		@vel[:mod] -= @decel_mod
		@vel[:mod] = 0 if @vel[:mod] < 0
		
		if @acel[:x] != 0 or @acel[:y] != 0
			# Calcula la cantidad de aceleración en cada eje
			if @acel[:x] != 0 and @acel[:y] != 0
				am = 0.7071067811865475*@acel_mod
			else
				am = @acel_mod
			end
			
			# Calcula la nueva velocidad
			ax,ay = am*@acel[:x],am*@acel[:y]
			vx,vy = @vel[:x]*@vel[:mod]+ax,@vel[:y]*@vel[:mod]+ay
			@vel[:x],@vel[:y],@vel[:mod] = vector2unitario(vx,vy)
			
			# Reduce la velocidad si excede el máximo
			@vel[:mod] = @vel_max if @vel[:mod] > @vel_max
		end
	end
	
	def colisionar_con_objeto(obj)
		dist = distancia(@pos, obj.pos)
		colision = false
		if dist <= @radio + obj.radio
			colision = true
			unitx,unity = unitario_direccion obj.pos, @pos, dist
			mod,objmod = @vel[:mod],obj.vel[:mod]
			@vel.update({x: unitx, y: unity, mod: objmod})
			if @tipo != :pelota
				obj.vel.update({x: -unitx, y: -unity, mod: mod})
			end
		end
		if @tipo == :pelota and obj.chutar 
			obj.chutar = false
			if dist <= @radio + RADIO_PLAYER_ALCANCE
				if not colision
					unitx,unity = unitario_direccion obj.pos, @pos, dist
					@vel.update({x: unitx, y: unity, mod: VELOCIDAD_CHUTE})
				else
					@vel[:mod] = VELOCIDAD_CHUTE
				end
			end
		end
	end
	
	def colisionar_con_pared()
		for eje in [:x, :y]
			if @pos[eje] < radio
				# Colisión con la pared inferior en el eje
				@pos[eje] = @radio
				@vel[eje] = @tipo == :player ? 0 : -@vel[eje]
			elsif @pos[eje] > BOARD_SIZE[eje]-radio
				# Colisión con la pared inferior en el eje
				@pos[eje] = BOARD_SIZE[eje]-radio
				@vel[eje] = @tipo == :player ? 0 : -@vel[eje]
			end
		end
	end
	
	def mover()
		# Mueve la posición del objeto conforme a su velocidad
		for eje in [:x, :y]
			@pos[eje] += @vel[eje] * @vel[:mod]
		end
	end
end


class Tablero
	def initialize()
		pelota = Elemento.new(:pelota, RADIO_PELOTA, 0, DECELERACION_PELOTA, MAX_VEL_PELOTA, 
		                      { x: BOARD_SIZE[:x]/2, y: BOARD_SIZE[:y]/2 })
		@njugadores = 0
		@elementos = [pelota]
		@posiciones = {pelota: pelota.pos, player: []}
		@playerinfo =[]
		@timer = nil
		@send_info = false
	end
	
	def acelerar()
		for elemento in @elementos
			elemento.acelerar()
		end
	end
	
	def colisiones()
		for i in (0...@elementos.size-1)
			for j in (i+1...@elementos.size)
				# Como la pelota es el primer elemento sólo será cogida por el índice i
				@elementos[i].colisionar_con_objeto(@elementos[j])
			end
		end
		for elemento in @elementos
			elemento.colisionar_con_pared()
		end
	end
	
	def mover()
		for elemento in @elementos
			elemento.mover()
		end
	end
	
	def update_all()
		acelerar() # Cambia las velocidades según la aceleración
		colisiones() # Recalcula velocidades para rebotar en las colisiones
		mover() # Calcula las nuevas posiciones según las velocidades de los objetos
		
		# Envia las nuevas posiciones a los clientes
		if @send_info
			@msg = { pelota: @posiciones[:pelota], player: @posiciones[:player], playerinfo: @playerinfo, playerpos: 0 }
			for e in @elementos
				if e.ws
					e.ws.send(JSON.generate(@msg))
					@msg[:playerpos] += 1
				end
			end
			@send_info = false
		else
			msg = JSON.generate(@posiciones)
			for e in @elementos
				e.ws.send(msg) if e.ws
			end
		end
	end
	
	def add_client(cl)
		# Activa la actualización de movimientos si es el primer cliente
		@timer = EventMachine::PeriodicTimer.new(REFRESH_TIME){ update_all() } if @njugadores == 0
		
		# Añade el cliente en las estructuras
		@njugadores += 1
		@elementos << cl
		@posiciones[:player] << cl.pos
		
		# Marca para enviar a todos los datos del nuevo cliente
		@send_info = true
	end
	
	def delete_client(cl)
		# Borra el cliente de las estructuras
		i = @elementos.index{|e| e.object_id == cl.object_id }
		@elementos.delete_at(i)
		@posiciones[:player].delete_at(i-1)
		@njugadores -= 1
		
		if @njugadores == 0
			# Si es el último cliente desactiva las actualizaciones de movimientos
			@timer.cancel rescue nil
			
			# Marca para enviar a todos los datos sin este cliente
			@send_info = true
		end
	end
end





TABLERO = Tablero.new
KEYS_ACEL = {
	'u' => [:y, -1],
	'd' => [:y, 1],
	'l' => [:x, -1],
	'r' => [:x, 1]
}

EventMachine::run do
	EventMachine::WebSocket.run(:host => "0.0.0.0", :port => PORT) do |connection|
		cliente = nil
		keys = {}
		
		connection.onopen do |handshake|
			# Enviar al cliente datos para dibujar el campo
			connection.send JSON.generate({
				serverdata: {
					map_width: BOARD_SIZE[:x],
					map_height: BOARD_SIZE[:y],
					radio_player: RADIO_PLAYER,
					radio_pelota: RADIO_PELOTA,
					radio_player_alcance: RADIO_PLAYER_ALCANCE,
					porteria_size_x: PORTERIA_SIZE[:x],
					porteria_size_y: PORTERIA_SIZE[:y]
				}
			})
			
			# Crear el jugador y añadirlo al campo
			pos = {x: 100, y: 100}
			cliente = Elemento.new(:player, RADIO_PLAYER, ACELERACION_PLAYER, 
			                       DECELARACION_PLAYER, MAX_VEL_PLAYER, pos, connection)
			TABLERO.add_client(cliente)
			
		end
		
		connection.onmessage do |data|
			# Lee el dato recibido
			tipo,data = data.split
			if tipo == 'ks' # Tecla espaciadora
				cliente.chutar = true
			elsif tipo == 'kd' # Tecla de dirección
				tecla,pressed = data[0],(data[1] == '1')
				# Si cambia el estado de la tecla actualiza la aceleración del cliente
				if (!!keys[tecla]) != pressed
					keys[tecla] = pressed
					if pressed
						cliente.acel[KEYS_ACEL[tecla][0]] += KEYS_ACEL[tecla][1]
					else
						cliente.acel[KEYS_ACEL[tecla][0]] -= KEYS_ACEL[tecla][1]
					end
				end
			end
		end
		
		connection.onclose do
			# Borra el cliente del tablero
			TABLERO.delete_client(cliente)
		end
	end
	
	puts "Iniciado servidor en #{Socket.ip_address_list.detect{|intf| intf.ipv4_private?}.ip_address}:#{PORT}"
end
