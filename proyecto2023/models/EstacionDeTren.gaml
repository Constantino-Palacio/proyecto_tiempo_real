model estacion_berazategui

global {  
    file my_csv_file <- csv_file("../includes/fondo.csv",",");
    
    // base temporal para la simulacion (100 tick/min)
    int timebase <- 100#cycles;
    
    // tiempos del tren
    int frecuencia_tren <- 4000;					// cada cuanto pasa
    int tolerancia_anden <- 200;					// cuanto se queda en el anden (en ticks)
    int tiempo_anden_extra <- 10;					// tiempo (en ticks) que el tren esta parado y no deja que suba/baje nadie
    
    int trenes_pasados <- 0;
    
    bool detenido_derecho;
    bool detenido_izquierdo;
    point tren_derecho_detenido;
    point tren_izquierdo_detenido;
    point puente_izq;
	point puente_der;
	
	// contadores para ver cuantos pasajeros bajan
	int cant_bajan <- 38;
	int contador_derecho;
	int contador_izquierdo;
	
	// contadores para la grafica
	int nro_personas_izq <- 0;
	int nro_personas_der <- 0;
	int nro_personas_puente <- 0;
	
	// reloj
	int hora <- 5;
	int minuto <- 0;
	
	int hora_inicial <- 5;
	int hora_final <- 22;					// hora final para cambiarlo mas facilmente
	
	// estadisticas
	float prob_cruzar <- 1.0;				// porcentaje_bajan
	int total_pasajeros <- 212613;			// caso enero 2019
	string mes;
	
	// control de hora pico (si esta activado, se ignora el slider frecuencia_tren)
	bool ajuste <- false;	
	
	// creacion de pasajeros nuevos en los molinetes (en estados hacia_puente o esperando)
	bool ingresantes <- true;
	bool un_minuto_paso <- false;			// flag de "interrupcion" cada 1 minuto	
	
	// exportar resultados a archivo csv (para armar grafico mas rapidamente que el gama)
	bool salida_csv <- false;
	
	// selector de tasa de refresco de la grafica (chart) en ticks (aplica tambien a la salida a csv)
	int refresco_grafica <- 10;
	bool tiempo_refresco_paso <- false;		// flag de "interrupcion" cada refresco_grafica ticks
	
	/*
	 * La hora pico es hasta las 12hs y entre las 17 y 21hs
	 * En este horario, la frecuencia es de 12 minutos y viaja el doble de gente
	 */
	reflex ajuste_hora_pico when: (ajuste = true) {
		/*
		 * Si es hora pico, ajustar variables
		 */
		if (hora < 12 or (hora >= 17 and hora < 21)) {
			frecuencia_tren <- timebase * 12;									// cada 12 min
			// se supone que en horario pico viaja el doble de gente
			cant_bajan <- int ((total_pasajeros * 0.8) / (30 * 110 * 2));
		} else {
			frecuencia_tren <- timebase * 15;									// cada 15 min
			cant_bajan <- int ((total_pasajeros * 0.2) / (30 * 50 * 2));
		}
	}
	
	/*
	 * Exportar los valores del grafico a un csv cada cierto tiempo (el mismo que actualizo el grafico)
	 */
	reflex exportar_datos when: (salida_csv = true and tiempo_refresco_paso = true and hora <= hora_final) {
		/*save ("cycle: "+ cycle + "; nbPreys: " + nb_preys
	      + "; minEnergyPreys: " + (prey min_of each.energy)
	      + "; maxSizePreys: " + (prey max_of each.energy) 
	      + "; nbPredators: " + nb_predators           
	      + "; minEnergyPredators: " + (predator min_of each.energy)          
	      + "; maxSizePredators: " + (predator max_of each.energy)) 
	      to: "results.txt" rewrite: (cycle = 0) ? true : false;*/
	      
	      /*save (
	      	cycle + "," + nro_personas_izq + "," + nro_personas_der + "," + nro_personas_puente
	      ) to: "resultados.csv" rewrite: (cycle = 0) ? true : false;*/
	}
	
	/*
	 * La simulacion termina a la hora que indica la variable hora_final
	 */
	reflex stop_simulation when: (hora >= hora_final) {
		do pause;
	}
	
	/*
	 * Crear pasajeros que entran a la estacion por alguno de los molinetes
	 * Se crea un pasajero por minuto (100 ticks) hasta que sean las 21:00
	 */
	reflex crear_ingresante when: (ingresantes = true and un_minuto_paso = true and hora < 21) {
		un_minuto_paso <- false;		// desactivo flag de "interrupcion"
		
		// creo un pasajero en uno de los andenes con probabilidad 0.5
		if (rnd(0,1) < 0.5) {
			create persona number: 1 {
				// creo en lado derecho (fuera de camara)
				location <- my_gama_grid[22,30].location;		// celda W30 del excel
				//write "Creado agente" + self + " en posicion " + location;
				lado_derecho <- true;
				/*
				 * decido con probabilidad 0.5 si la persona cruza al otro anden o espera ahi
				 */
				if (rnd(0,1) < 0.5) {
					estado_inicial <- 1;		// cruza
				} else {
					estado_inicial <- 2;		// se queda
					target <- point([puente_der.x + rnd(-2,4), puente_der.y + rnd(20,50)]);
				}
			}
		} else {
			create persona number: 1 {
				// creo en lado izquierdo (fuera de camara)
				location <- my_gama_grid[8,30].location;		// celda H30 del excel
				//write "Creado agente" + self + " en posicion " + location;
				lado_derecho <- false;
				/*
				 * decido con probabilidad 0.5 si la persona cruza al otro anden o espera ahi
				 */
				if (rnd(0,1) < 0.5) {
					estado_inicial <- 1;		// cruza
				} else {
					estado_inicial <- 2;		// se queda
					target <- point([puente_izq.x + rnd(-4,2), puente_izq.y + rnd(20,50)]);
				}
			}
		}
	}
	
    init {    	
    	tren_derecho_detenido <- my_gama_grid[17,15].location;
    	tren_izquierdo_detenido <- my_gama_grid[13,15].location;
    	puente_izq <-  my_gama_grid[9,7].location;
		puente_der <-  my_gama_grid[22,7].location;
		
        matrix data <- matrix(my_csv_file);
        
        ask my_gama_grid {  
            grid_value <- float(data[grid_x,grid_y]);  
            do action_update_color;  
        }
        
        hora <- hora_inicial;
        
        /*
         * Configurar cantidad de pasajeros basado en el mes (datos 2019)
         */
        switch (mes) {
        	match "Enero" {total_pasajeros <- 212613;}
        	match "Febrero" {total_pasajeros <- 231473;}
        	match "Marzo" {total_pasajeros <- 263145;}
        	match "Abril" {total_pasajeros <- 275146;}
        	match "Mayo" {total_pasajeros <- 285549;}
        	match "Junio" {total_pasajeros <- 218172;}
        	match "Julio" {total_pasajeros <- 197322;}
        	match "Agosto" {total_pasajeros <- 288444;}
        	match "Septiembre" {total_pasajeros <- 308205;}
        	match "Octubre" {total_pasajeros <- 311335;}
        	match "Noviembre" {total_pasajeros <- 308932;}
        	match "Diciembre" {total_pasajeros <- 286682;}
        }
        
        create reloj number: 1;	// instanciar reloj     	
        
		// Tren izquierdo
        create tren number: 1 { // Crear tren a plaza
            img <- image("../includes/tren.png");
    		espera <- int (frecuencia_tren/2);
    		
    		location_inicial <- my_gama_grid[13,0].location;
    		location <- location_inicial;
			target1 <- tren_izquierdo_detenido;
			target2 <- my_gama_grid[13,30].location;
			lado_derecho <- false;
    	}
    	
    	// Tren derecho
    	 create tren number: 1 { // Crear tren a la plata
            img <- image("../includes/tren-arriba.png");
    		espera <- frecuencia_tren;
    		
    		location_inicial <- my_gama_grid[17,30].location;
    		location <- location_inicial;
			target1 <- tren_derecho_detenido;
			target2 <- my_gama_grid[17,0].location;
			lado_derecho <- true;
    	}
    }  
}  

grid my_gama_grid width: 31 height: 31 {  
	
    action action_update_color {  
		
        switch (grid_value) {
		    match 0.0 { 
		    	create piso number:1 { 
		    		location <- my_gama_grid[myself.grid_x,myself.grid_y].location;
		    		img <- image("../includes/piso.png");
		    		width <- 6.0; 
		    		height <- 5.37;
		    	}
		    }
		    match 1.0 {
		    	create puente number:1 {
		    		location <- my_gama_grid[myself.grid_x,myself.grid_y].location;
		    		img <- image("../includes/madera.png");
		    		width <- 5.5;
		    		height <- 5.5;
		    	}
		    }
		  	match 2.0 { color <- #yellow; }
		    match 3.0 { color <- #lightgrey; }
		    match 6.0 {
		    	create blanco number:1 {
		    		location <- my_gama_grid[myself.grid_x,myself.grid_y].location;
		    		img <- image("../includes/blanco.png");
		    		width <- 5.5;
		    		height <- 5.5;
		    	}
		    }
		    match 8.0 {
		    	create piso number:1 {
		    		location <- my_gama_grid[myself.grid_x,myself.grid_y].location;
		    		img <- image("../includes/vias.png");
		    		width <- 11.0;
		    		height <- 60.0;
		    	}
		    }
		    default { color <- #black; }
		}

    }  
}  

species piso{
	image img ;
	float width;
	float height;
	aspect base {
	    draw img at:location size: {width, height};
	}
}

species puente{
	image img ;
	float width;
	float height;
	aspect base {
	    draw img at:location size: {width, height};
	}
}

species blanco{
	image img ;
	float width;
	float height;
	aspect base {
	    draw img at:location size: {width, height};
	}
}

species tren control:fsm skills:[moving] {
	int espera;
	int tiempo_anden;
	
	image img;
	bool lado_derecho;
	
	point location_inicial;
	
	point target;
	point target1;
	point target2;
	
	bool visible;
	
	state en_marcha {	
		visible <- true;
		speed <- 0.8;
		do goto target: target;	
		
		/*
		 * Pasar al estado "lejano" cuando el tren se aleje lo suficiente
		 * de la estación. Para eso, asignar un tiempo de espera hasta el
		 * proximo tren y hacerlo invisible.
		 */
		transition to: lejano when: location = target2 {
			espera <- (frecuencia_tren + rnd(-1,3)*timebase);			// se puede atrasar hasta 3min o adelantar hasta 1min
			visible <- false;
		}
		
		/*
		 * Pasar al estado "detenido" cuando el tren llegue al punto
		 * de arribo. Para eso, asignar un tiempo de espera para que
		 * suban los pasajeros.
		 */
		transition to: detenido when: location = target1 {
			tiempo_anden <- tolerancia_anden;
			trenes_pasados <- trenes_pasados + 1;
			if(lado_derecho) {
				detenido_derecho <- true;
				contador_derecho <- cant_bajan;
			} else {
				detenido_izquierdo <- true;
				contador_izquierdo <- cant_bajan;
			}
		}
	}
	
	state detenido {
		/*
		 * Disminuir el tiempo de espera si nadie baja
		 */
		if ((lado_derecho and contador_derecho = 0) or 
			(!lado_derecho and contador_izquierdo = 0)) {
			tiempo_anden <- tiempo_anden - 1;
		}
		//tiempo_anden <- tiempo_anden - 1;
		
		/*
		 * Hacer que bajen pasajeros a velocidad reducida. Tener en cuenta que se verifica
		 * que el tiempo del anden sea mayor al tiempo adicional porque asi se da tiempo
		 * a que todos los que tenian que bajar bajen y los que tenian que subir suban. Ver que tambien se
		 * generan pasajeros nuevos cada 5 ticks (3 segundos)
		 */
		if (lado_derecho and contador_derecho > 0 and tiempo_anden > tiempo_anden_extra) {
			create persona number:1 {
	    		location <- point([puente_der.x + rnd(-2,4), puente_der.y + rnd(20,50)]);
				lado_derecho <- true;
				//speed <- 0.25;
				if (rnd(0,1) <= prob_cruzar) {estado_inicial <- 1;} else {estado_inicial <- 0;} 
	    	}
	    	contador_derecho <- contador_derecho - 1;
		}
		
		// solo hacen transbordo los del anden izquierdo, los que ya estan ahi se van sin mas
		
		if (!lado_derecho and contador_izquierdo > 0 and tiempo_anden > tiempo_anden_extra) {
			create persona number:1 {
	    		location <- point([puente_izq.x + rnd(-4,2), puente_izq.y + rnd(20,50)]);
				lado_derecho <- false;
				//speed <- 0.25;
				//if (rnd(0,1) <= prob_cruzar) {estado_inicial <- 1;} else {estado_inicial <- 0;} 
				estado_inicial <- 0;
	    	}
	    	contador_izquierdo <- contador_izquierdo - 1;
		}
		
		/*
		 * Los ultimos ticks en el anden NO son para que baje/suba nadie, son para dar
		 * tiempo a que se acomoden los agentes existentes (como la sirena en un tren real),
		 * por eso deshabilito los flags de detenido
		 */
		if (tiempo_anden = tiempo_anden_extra) {
			if(lado_derecho) {
				detenido_derecho <- false;
			} else {
				detenido_izquierdo <- false;
			}
		}
		 
		/*
		 * Pasar al estado "en marcha" cuando expire el tiempo de espera
		 * para los pasajeros
		 */
		 transition to: en_marcha when: tiempo_anden = 0 {
		 	target <- target2;
		 }
	}
	
	state lejano initial: true{
		espera <- espera - 1;
		
		/*
		 * Cuando se cumple el tiempo de espera, pasar al estado "en marcha"
		 * En tal caso, tengo que reposicionar el tren
		 */
		
		transition to: en_marcha when: espera <= 0 {
			location <-  location_inicial;
			target <- target1;
		}
	}

	aspect base {
	    if(visible) {
	    	draw img at: location size: {10, 25};
	    }
	}
}

species persona control:fsm skills:[moving] {
  float speed <- rnd(0.5,1.0); // Velocidad a la que la persona se mueve (simula edad)
  bool on_train <- false; // Si está en el tren o no
  image img <- image("../includes/persona.png");
  bool lado_derecho;
  int estado_inicial;
  int lado <- 1;
  point target;
  
  reflex {
  	lado <-lado_derecho ? -1 : 1; 
  }
  
  state inicio initial: true {
  	/*
  	 * Lo único que hace este estado es pasar acordemente a otro de los
  	 * estados iniciales disponibles según la FSM del informe.
  	 * 
  	 * Sumo uno a los contadores porque siempre se cuenta al iniciar
  	 */
  	 
  	transition to: saliendo when: estado_inicial = 0 {
  		if (lado_derecho) {
  	 		nro_personas_der <- nro_personas_der + 1;
  	 	} else {
  	 		nro_personas_izq <- nro_personas_izq + 1;
  	 	}
  	}
  	
  	transition to: hacia_puente when: estado_inicial = 1 {
  		if (lado_derecho) {
  			target <- puente_der;
  			nro_personas_der <- nro_personas_der + 1;
  		} else {
	  		target <- puente_izq;
	  		nro_personas_izq <- nro_personas_izq + 1;
	  	}
  	}
  	
  	transition to: esperando when: estado_inicial = 2 {
  		if (lado_derecho) {
  	 		nro_personas_der <- nro_personas_der + 1;
  	 	} else {
  	 		nro_personas_izq <- nro_personas_izq + 1;
  	 	}
  	}
  }
  
  state fin final: true {
  		do die;
  }
  
  state saliendo {
  	/*
  	 * En este estado el pasajero simplemente camina hacia el molinete,
  	 * es decir, el extremo inferior de la pantalla grafica.
  	 * 
  	 * Una vez fuera de la pantalla, deja de existir (pasa a estado FIN).
  	 */
  	 
 	do move speed: speed heading: 90.0;
 	
 	/*
 	 * Al salir, restar 1 del contador del anden
 	 */
	
	transition to: fin when: location.y >= my_gama_grid[0,30].location.y {
		if (lado_derecho) {
  	 		nro_personas_der <- nro_personas_der - 1;
  	 	} else {
  	 		nro_personas_izq <- nro_personas_izq - 1;
  	 	}
	}
  }
  
  state hacia_puente {
  	/*
  	 * El pasajero camina hasta alcanzar la coordenada Y del puente, luego
  	 * pasa al estado CRUZANDO. Se mueve hacia arriba, que es donde esta el
  	 * puente.
  	 */
  	 
  	 do goto target: target;
  	 
  	 transition to: cruzando when: location = target {
  	 	// actualizar contadores para grafica
  	 	nro_personas_puente <- nro_personas_puente + 1;		// sumar uno en el puente
  	 	
  	 	if(lado_derecho) {
  	 		target <- puente_izq;
  	 		nro_personas_der <- nro_personas_der - 1;		// restar uno en los andenes
	  	}
	    else {
	  		target <- puente_der;
	  		nro_personas_izq <- nro_personas_izq - 1;
	  	}
  	 }
  }
  
  state cruzando {
  	/*
  	 * El pasajero recorre el puente. Luego pasa al estado ESPERANDO
  	 * Se mueve horizontalmente segun el lado al que quiera cruzar
  	 * 
  	 * Para eso se usa el flag izq. Si es 0, va a derecha (0.0)
  	 */
  	
  	do goto target: target;
  	
  	transition to: esperando when: location = target {
  		// actualizar contadores grafica
  		nro_personas_puente <- nro_personas_puente - 1;		// resto uno en el puente
  		
  		lado_derecho <- !lado_derecho;
  		if(lado_derecho) {
  	 		target <- point([puente_der.x + rnd(-2,4), puente_der.y + rnd(20,50)]);
  	 		nro_personas_der <- nro_personas_der + 1;		// sumo uno en los andenes
	  	}
	    else {
	  		target <- point([puente_izq.x + rnd(-4,2), puente_izq.y + rnd(20,50)]);
	  		nro_personas_izq <- nro_personas_izq + 1;
	  	}
  		
  	}	
  }
  
  state esperando {
  	/*
  	 * En este estado los pasajeros se colocan en el anden y esperan a que
  	 * llegue el tren. Al ocurrir esto, se suben al tren a baja velocidad para
  	 * simular un "atasco" en la puerta del tren.
  	 */
  	do goto target:target;
  	if(location=target){
  		speed <- 0.0;
  	}
  	
  	transition to: subiendo when: (!lado_derecho) and detenido_izquierdo and (contador_izquierdo >= 0) {
  		speed <- 0.25;
  		target <- tren_izquierdo_detenido;
  	}
  	
  	transition to: subiendo when: lado_derecho and detenido_derecho and (contador_derecho >= 0) {
  		speed <- 0.25;
 		target <- tren_derecho_detenido;
  	}
  }
  
  state subiendo {
  	/*
  	 * En este estado el pasajero se sube al tren: camina en la direccion
  	 * de las vias y, al llegar al borde del anden (linea amarilla), deja
  	 * de existir (pasa a estado FIN).
  	 */
  	 if(lado_derecho and contador_derecho = 0){
 		speed <- 0.2 + rnd(0,0.8);
 		do goto target: target;
  	 }
  	 
  	  if(!lado_derecho and contador_izquierdo = 0){
 		speed <- 0.2 + rnd(0,0.8);
 		do goto target: target;
  	 }
  	 
  	 transition to: fin when: location = target {
  	 	if (lado_derecho) {
  	 		nro_personas_der <- nro_personas_der - 1;
  	 	} else {
  	 		nro_personas_izq <- nro_personas_izq - 1;
  	 	}
  	 }
  	 
  	 transition to: esperando when:
  	 	((lado_derecho and !detenido_derecho) or
  	 		(!lado_derecho and !detenido_izquierdo)) {
  	 			if(lado_derecho) {
		  	 		target <- point([puente_der.x + rnd(-2,4), puente_der.y + rnd(20,50)]);
			  	} else {
			  		target <- point([puente_izq.x + rnd(-4,2), puente_izq.y + rnd(20,50)]);
			  	}
  	 		}
  }
 
  aspect base {
  	draw img at: location size: {lado*4, 8};
  }
}

/*
 * Máquina de estados para control del reloj
 */
species reloj control: fsm {
	int ticks_por_minuto <- 0;
	state controlador initial: true {
		if (ticks_por_minuto < timebase) {
			ticks_por_minuto <- ticks_por_minuto + 1;
		} else {
			ticks_por_minuto <- 0;
			
			if (minuto < 59) {
				minuto <- minuto + 1;
				un_minuto_paso <- true;
			} else {
				minuto <- 0;
				
				if (hora < 23) {
					hora <- hora + 1;
				} else {
					hora <- 0;
				}
			}
		}
	}
}

experiment main type: gui {  
	parameter "hora_inicial" var: hora_inicial min: 5 max: 21;

	//parameter "Datos de Entrada" var: arch_datos extensions: ["csv"];

	parameter "mes" var: mes <- "Octubre" among: ["Enero", "Febrero","Marzo",
		"Abril","Mayo","Junio","Julio","Agosto","Septiembre","Octubre","Noviembre","Diciembre"];

	parameter "tolerancia_anden" var: tolerancia_anden min: 100 max: 500 step: 10;
	parameter "frecuencia_tren" var: frecuencia_tren min: 1000 max: 4000 step: 100;

	parameter "cant_bajan" var: cant_bajan min: 0 max: 50;
	parameter "prob_cruzar" var: prob_cruzar min: 0.0 max: 1.0 step: 0.01;

	parameter "ajuste" var: ajuste;
	parameter "ingresantes" var: ingresantes;
	
	//parameter "salida_csv" var: salida_csv;
	//parameter "refresco_grafica" var: refresco_grafica min: 1 max: 100 step: 10;
	
    output {  
        display display_grid {
        	//define a new overlay layer positioned at the coordinate 5,5, with a constant size of 180 pixels per 100 pixels.
            overlay position: {5, 5} size: {80#px, 20#px} background: #black transparency: 0.5 border: #black rounded: true {
                // dibujo el reloj -> HH:MM
                draw string(hora)+":"+string(minuto) at: {30#px, 15#px} color: #white;
            }
        	 
            grid my_gama_grid;  
            species piso aspect: base;
            species tren aspect: base;
            
            species puente aspect: base;
            species persona aspect: base;
            species blanco aspect: base;
            //species persona aspect: base;
        }
        
        // refrescar reloj cada 1 min de simulacion
        //monitor "Hora actual" value: [hora, minuto] refresh: every(1#cycles);
        monitor "Cantidad pasajeros" value: length(persona) refresh: every(refresco_grafica#cycles);
        monitor "Trenes pasados" value: trenes_pasados refresh: every(refresco_grafica#cycles);
        
        /*monitor "Andén izq." value: nro_personas_izq refresh: every(1#cycles);
		monitor "Andén der." value: nro_personas_der refresh: every(1#cycles);
		monitor "Cruzando" value: nro_personas_puente refresh: every(1#cycles);*/
        
        /*
         * Gráfico del flujo de pesajeros en la estación (se refresca cada 10 ciclos para que no sea tan pesado)
         */
        display flujo_pasajeros refresh: every(refresco_grafica#cycles) {
			chart "Pasajeros en la estación" type: series {
				data "Andén izq." value: nro_personas_izq color: #green marker: false style: line;			// respeto el color usado en netlogo
				data "Andén der." value: nro_personas_der color: #dodgerblue marker: false style: line;
				data "Cruzando" value: nro_personas_puente color: #red marker: false style: line;
			}
		}
    }  
}