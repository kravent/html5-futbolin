#!/usr/bin/env ruby
require 'em-websocket'
require 'json'
require 'socket'

DEBUG = ARGV.include? 'debug'
PORT = 8090
REFRESH_TIME = 1/60.0 # 60fps
ACELERACION_PLAYER = 400
DECELARACION_PLAYER = 120
DECELERACION_PELOTA = 20
MAX_VEL_PLAYER = 100
MAX_VEL_PELOTA = 400
BOARD_SIZE = { x: 800, y: 400 }
PORTERIA_SIZE = {x: 50, y: 100}
RADIO_PLAYER = 15
RADIO_PELOTA = 9
RADIO_PLAYER_ALCANCE = 25
VELOCIDAD_CHUTE = 200
SIZE_LATERAL2PORTERIA = (BOARD_SIZE[:y]-PORTERIA_SIZE[:y])/2.0
RESET_TIME_TRAS_GOL = 2 # segundos

def distancia(pos1, pos2)
	Math.sqrt((pos1[:x]-pos2[:x])**2 + (pos1[:y]-pos2[:y])**2)
end

def unitario_direccion(pos1, pos2, dist = nil)
	dist = distancia pos1, pos2 if dist.nil?
	dist == 0 ? [1, 1] : [(pos2[:x]-pos1[:x])/dist, (pos2[:y]-pos1[:y])/dist]
end

def vector2unitario(vx, vy)
	return [0, 0, 0] if vx==0 and vy ==0
	mod = Math.sqrt(vx**2 + vy**2)
	[vx/mod, vy/mod, mod] # unitario_x, unitario_y, modulo
end




class Elemento
	attr_reader :tipo, :radio, :acel_mod, :decel_mod, :vel_max, :pos, :vel, :acel, :info, :ws
	attr_accessor :chutar
	
	def initialize(tipo, radio, acel_mod, decel_mod, vel_max, pos, color=nil, ws=nil)
		@tipo = tipo
		@radio = radio
		@acel_mod = acel_mod
		@decel_mod = decel_mod
		@vel_max = vel_max
		
		@pos = pos
		@vel = { x:0, y:0, mod: 0 }
		@acel = { x:0, y:0 }
		@info = { color: color, dorsal: '' }
		@chutar = false
		
		@ws = ws
	end
	
	def vel_xy
		[@vel[:x]*@vel[:mod], @vel[:y]*@vel[:mod]]
	end
	
	def acelerar(el)
		# Desaceleración debido al rozamiento
		@vel[:mod] -= @decel_mod * el
		@vel[:mod] = 0 if @vel[:mod] < 0
		
		if @acel[:x] != 0 or @acel[:y] != 0
			# Calcula la cantidad de aceleración en cada eje
			if @acel[:x] != 0 and @acel[:y] != 0
				am = 0.7071067811865475*@acel_mod
			else
				am = @acel_mod
			end
			
			# Calcula la nueva velocidad
			ax,ay = am * @acel[:x] * el, am * @acel[:y] * el
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
			if obj.tipo == :poste
				@vel[:mod] = mod # Si chocas contra un poste fijo rebotas con tu propia velocidad
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
		if @tipo == :pelota
			if @pos[:y] >= SIZE_LATERAL2PORTERIA and @pos[:y] <= SIZE_LATERAL2PORTERIA + PORTERIA_SIZE[:y]
				if @pos[:x] <= 0 or @pos[:x] >= BOARD_SIZE[:x] # Dentro de las porterías
					area_permitida = {
						min: { x: -PORTERIA_SIZE[:x]+@radio, y: SIZE_LATERAL2PORTERIA+@radio },
						max: { x: BOARD_SIZE[:x]+PORTERIA_SIZE[:x]-@radio, y: SIZE_LATERAL2PORTERIA+PORTERIA_SIZE[:y]-@radio }
					}
					for eje in [:x, :y] # El rebote en la malla de la portería es menor (vel/10)
						if @pos[eje] < area_permitida[:min][eje] # Colisión con la pared inferior en el eje
							@pos[eje],@vel[eje] = area_permitida[:min][eje],-@vel[eje]/10
						elsif @pos[eje] >  area_permitida[:max][eje] # Colisión con la pared inferior en el eje
							@pos[eje],@vel[eje] = area_permitida[:max][eje],-@vel[eje]/10
						end
					end
				else # O choca con los ejes de las porterías, o está en el centro del campo
					if @pos[:x] < @radio
						if @pos[:y] - SIZE_LATERAL2PORTERIA < @radio
							colisionar_con_objeto(BORDE_PORTERIA[:ul])
						elsif @pos[:y] - SIZE_LATERAL2PORTERIA > PORTERIA_SIZE[:y] - @radio
							colisionar_con_objeto(BORDE_PORTERIA[:dl])
						end
					elsif @pos[:x] > BOARD_SIZE[:x] - @radio
						if @pos[:y] - SIZE_LATERAL2PORTERIA < @radio
							colisionar_con_objeto(BORDE_PORTERIA[:ur])
						elsif @pos[:y] - SIZE_LATERAL2PORTERIA > PORTERIA_SIZE[:y] - @radio
							colisionar_con_objeto(BORDE_PORTERIA[:dr])
						end
					end
				end
			else
				for eje in [:x, :y]
					if @pos[eje] < @radio # Colisión con la pared inferior en el eje
						@pos[eje],@vel[eje] = @radio,-@vel[eje]
					elsif @pos[eje] > BOARD_SIZE[eje]-radio # Colisión con la pared inferior en el eje
						@pos[eje],@vel[eje] = BOARD_SIZE[eje]-radio,-@vel[eje]
					end
				end
			end
		else
			for eje in [:x, :y]
				if @pos[eje] < @radio # Colisión con la pared inferior en el eje
					@pos[eje],@vel[eje] = @radio,0
				elsif @pos[eje] > BOARD_SIZE[eje]-radio # Colisión con la pared inferior en el eje
					@pos[eje],@vel[eje] = BOARD_SIZE[eje]-radio,0
				end
			end
		end
	end
	
	def mover(el)
		# Mueve la posición del objeto conforme a su velocidad
		for eje in [:x, :y]
			@pos[eje] += @vel[eje] * @vel[:mod] * el
		end
	end
end



POSICIONES_INICIALES = [
	{ x: BOARD_SIZE[:x]*3/8-25 , y: BOARD_SIZE[:y]*3/6 },
	{ x: BOARD_SIZE[:x]*2/8 , y: BOARD_SIZE[:y]*1/6 },
	{ x: BOARD_SIZE[:x]*2/8 , y: BOARD_SIZE[:y]*5/6 },
	{ x: BOARD_SIZE[:x]*1/8 , y: BOARD_SIZE[:y]*2/6 },
	{ x: BOARD_SIZE[:x]*1/8 , y: BOARD_SIZE[:y]*4/6 },
	{ x: BOARD_SIZE[:x]*3/8+10 , y: BOARD_SIZE[:y]*1/6 },
	{ x: BOARD_SIZE[:x]*3/8+10 , y: BOARD_SIZE[:y]*5/6 }
]
def posicion_inicial(color, n)
	n %= POSICIONES_INICIALES.size
	if color == :red
		POSICIONES_INICIALES[n]
	else
		{ x: BOARD_SIZE[:x]-POSICIONES_INICIALES[n][:x], y: POSICIONES_INICIALES[n][:y] }
	end
end

class Tablero
	attr_reader :marcador, :contador_color_jugadores
	
	def initialize()
		@pelota = Elemento.new(:pelota, RADIO_PELOTA, 0, DECELERACION_PELOTA, MAX_VEL_PELOTA, 
		                      { x: BOARD_SIZE[:x]/2, y: BOARD_SIZE[:y]/2 })
		@njugadores = 0
		@elementos = [@pelota]
		@posiciones = {pelota: @pelota.pos, player: []}
		@playerinfo =[]
		@contador_color_jugadores = { red: 0, blue: 0 }
		@marcador = { red: 0, blue: 0 }
		@timer = nil
		@send_info = false
		@sendmarcador = false
		@time_to_reset = -1
	end
	
	def reset()
		@golmarcado = false
		@pelota.pos.update({ x: BOARD_SIZE[:x]/2, y: BOARD_SIZE[:y]/2 })
		@pelota.vel[:mod] = 0
		cuenta_colores = { red: 0, blue: 0 }
		for elemento in @elementos
			if elemento.tipo == :player
				color = elemento.info[:color]
				elemento.pos.update(posicion_inicial(color, cuenta_colores[color]))
				elemento.vel[:mod] = 0
				cuenta_colores[color] += 1
			end
		end
	end
	
	def acelerar(el)
		for elemento in @elementos
			elemento.acelerar(el)
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
	
	def mover(el)
		for elemento in @elementos
			elemento.mover(el)
		end
	end
	
	def animate(el) # el: Tiempo transcurrido desde el último frame
		t_begin = Time.now if DEBUG
		msg = {}
		
		if not @time_to_reset < 0
			@time_to_reset -= el
			if @time_to_reset < 0
				reset()
				msg[:serverdata] = { reset: true } # WARNING Podría ser sobreescrito por un serverdata posterior...
			end
		end
		
		t_colision = Time.now if DEBUG
		
		acelerar(el) # Cambia las velocidades según la aceleración
		colisiones() # Recalcula velocidades para rebotar en las colisiones
		mover(el) # Calcula las nuevas posiciones según las velocidades de los objetos
		
		
		msg[:pelota] = @posiciones[:pelota]
		msg[:player] = @posiciones[:player]
		
		if @time_to_reset < 0
			if @pelota.pos[:x] < 0
				@marcador[:blue] += 1
				msg[:serverdata] = { marcador: @marcador, gol: 'blue' }
				@time_to_reset = RESET_TIME_TRAS_GOL
			elsif @pelota.pos[:x] > BOARD_SIZE[:x]
				@marcador[:red] += 1
				msg[:serverdata] = { marcador: @marcador, gol: 'red' }
				@time_to_reset = RESET_TIME_TRAS_GOL
			end
		end
		
		t_send = Time.now if DEBUG
		
		# Envia las nuevas posiciones a los clientes
		if @send_info
			msg[:playerinfo] = @playerinfo
			msg[:playerpos] = 0
			for e in @elementos
				if e.ws
					e.ws.send(JSON.generate(msg))
					msg[:playerpos] += 1
				end
			end
			@send_info = false
		else
			msg = JSON.generate(msg)
			for e in @elementos
				e.ws.send(msg) if e.ws
			end
		end
		
		if DEBUG
			t_end = Time.now
			printf("Time frame: %.2fms (reset: %.2fms, colision: %.2fms, send: %.2fms)\n",
			       (t_end-t_begin)*1000,
			       (t_colision-t_begin)*1000,
			       (t_send-t_colision)*1000,
			       (t_end-t_send)*1000)
			       
		end
	end
	
	def update_all()
		animate(REFRESH_TIME)
	end
	
	def add_client(cl)
		# Activa la actualización de movimientos si es el primer cliente
		@timer = EventMachine::PeriodicTimer.new(REFRESH_TIME){ update_all() } if @njugadores == 0
		
		# Añade el cliente en las estructuras
		@njugadores += 1
		@elementos << cl
		@posiciones[:player] << cl.pos
		@playerinfo << cl.info
		@contador_color_jugadores[cl.info[:color]] += 1
		
		# Lo coloca en el campo
		cl.pos.update(posicion_inicial(cl.info[:color], @contador_color_jugadores[cl.info[:color]]-1))
		
		# Marca para enviar a todos los datos del nuevo cliente
		@send_info = true
	end
	
	def delete_client(cl)
		# Borra el cliente de las estructuras
		@contador_color_jugadores[cl.info[:color]] -= 1
		i = @elementos.index{|e| e.object_id == cl.object_id }
		@elementos.delete_at(i)
		@posiciones[:player].delete_at(i-1)
		@playerinfo.delete_at(i-1)
		@njugadores -= 1
		
		if @njugadores == 0
			# Si es el último cliente desactiva las actualizaciones de movimientos
			@timer.cancel rescue nil
		else
			# Marca para enviar a todos los datos sin este cliente
			@send_info = true
		end
	end
	
	def send_info_now()
		@send_info = true
	end
end






BORDE_PORTERIA = {
	ul: Elemento.new(:poste, 0, 0, 0, 0, { x: 0, y: SIZE_LATERAL2PORTERIA }),
	ur: Elemento.new(:poste, 0, 0, 0, 0, { x: BOARD_SIZE[:x], y: SIZE_LATERAL2PORTERIA }),
	dl: Elemento.new(:poste, 0, 0, 0, 0, { x: 0, y: SIZE_LATERAL2PORTERIA+PORTERIA_SIZE[:y] }),
	dr: Elemento.new(:poste, 0, 0, 0, 0, { x: BOARD_SIZE[:x], y: SIZE_LATERAL2PORTERIA+PORTERIA_SIZE[:y] })
}

TABLERO = Tablero.new
KEYS_ACEL = {
	'u' => [:y, -1],
	'd' => [:y, 1],
	'l' => [:x, -1],
	'r' => [:x, 1]
}



begin
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
						porteria_size_y: PORTERIA_SIZE[:y],
						marcador: TABLERO.marcador
					}
				})
				
				# Crear el jugador y añadirlo al campo
				color = (TABLERO.contador_color_jugadores[:red] <= TABLERO.contador_color_jugadores[:blue]) ? (:red) : (:blue)
				cliente = Elemento.new(:player, RADIO_PLAYER, ACELERACION_PLAYER, 
									DECELARACION_PLAYER, MAX_VEL_PLAYER, {x: 0, y: 0}, color, connection)
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
				elsif tipo == 'td' # Texto dorsal
					data = '' if data.nil?
					cliente.info[:dorsal] = data[0...2]
					TABLERO.send_info_now()
				end
			end
			
			connection.onclose do
				# Borra el cliente del tablero
				TABLERO.delete_client(cliente)
			end
		end
		
		puts "Iniciado servidor en #{Socket.ip_address_list.detect{|intf| intf.ipv4_private?}.ip_address rescue 'localhost'}:#{PORT}"
	end
rescue Interrupt
	puts
	puts "Servidor cerrado"
end
