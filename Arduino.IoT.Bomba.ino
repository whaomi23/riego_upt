#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <WebServer.h>

// Configuración de redes
const char* ssid_primario = "Repeater_03AE";
const char* password_primario = "HackerRoot{MRX}@@";
IPAddress staticIP_primario(192, 168, 1, 132);
IPAddress gateway_primario(192, 168, 1, 1);
IPAddress subnet_primario(255, 255, 255, 0);
IPAddress dns_primario(8, 8, 8, 8);

const char* ssid_secundario = "WIFI_BOMBA_UPT";
const char* password_secundario = "RiegoUpt2025";
IPAddress staticIP_secundario(192, 168, 4, 4);
IPAddress gateway_secundario(192, 168, 4, 1);
IPAddress subnet_secundario(255, 255, 255, 0);
IPAddress dns_secundario(8, 8, 8, 8);

const char* serverIp = "0.0.0.0";
const int serverPort = 5000;
String serverUrl;
String esp32Ip;

// Estructura para gestión de bombas
struct BombaConfig {
    int pin;
    const char* nombre;
    unsigned long tiempoInicio;
    unsigned long tiempoRestante;
    bool pausada;
};

BombaConfig bombas[] = {
    {23, "bomba1", 0, 0, false},  // GPIO23 - Bomba 1
    {22, "bomba2", 0, 0, false},  // GPIO22 - Bomba 2
    {17, "bomba3", 0, 0, false},  // GPIO17 - Bomba 3
    {18, "bomba4", 0, 0, false},  // GPIO18 - Bomba 4
    {19, "bomba5", 0, 0, false},  // GPIO19 - Bomba 5
    {21, "bomba6", 0, 0, false}   // GPIO21 - Bomba 6
};
const int numBombas = sizeof(bombas) / sizeof(bombas[0]);

// Configuración de LEDs
const int ledRojo = 12;     // Error WiFi
const int ledAzul = 14;     // WiFi conectado
const int ledVerde = 27;    // Todas activas
const int ledAmarillo = 26; // Todas inactivas

// Control de conexión
unsigned long ultimaConexion = 0;
bool servidorConectado = false;
WebServer server(80);

// Control de secuencias
enum SecuenciaEstado { SEC_APAGADA, SEC_ACTIVANDO, SEC_APAGANDO };
SecuenciaEstado estadoSecuencia = SEC_APAGADA;
unsigned long tiempoSecuencia = 0;
const unsigned long intervaloEntreBombas = 1000; // 1 segundo entre operaciones
int bombaActualSecuencia = 0;

void setup() {
    Serial.begin(115200);
    while (!Serial);

    Serial.println("\n=== SISTEMA DE CONTROL DE BOMBAS ===");
    Serial.println("Comandos: 1-6 (bombas), a (todas), 0 (apagar), s (estado), w (WiFi)");

    // Inicializar relés y LEDs
    for (int i = 0; i < numBombas; i++) {
        pinMode(bombas[i].pin, OUTPUT);
        digitalWrite(bombas[i].pin, HIGH);
    }
    
    const int leds[] = {ledRojo, ledAzul, ledVerde, ledAmarillo};
    for (int i = 0; i < 4; i++) {
        pinMode(leds[i], OUTPUT);
        digitalWrite(leds[i], LOW);
    }

    conectarWiFi();
    configurarServidorWeb();
}

void conectarWiFi() {
    const struct {
        const char* ssid;
        const char* password;
        IPAddress ip;
        IPAddress gateway;
        IPAddress subnet;
    } redes[] = {
        {ssid_primario, password_primario, staticIP_primario, gateway_primario, subnet_primario},
        {ssid_secundario, password_secundario, staticIP_secundario, gateway_secundario, subnet_secundario}
    };

    for (int i = 0; i < 2; i++) {
        Serial.printf("\nConectando a %s...\n", redes[i].ssid);
        WiFi.disconnect(true);
        WiFi.config(redes[i].ip, redes[i].gateway, redes[i].subnet, dns_primario);
        WiFi.begin(redes[i].ssid, redes[i].password);

        for (int j = 0; j < 20 && WiFi.status() != WL_CONNECTED; j++) {
            delay(500);
            Serial.print(".");
        }

        if (WiFi.status() == WL_CONNECTED) {
            esp32Ip = WiFi.localIP().toString();
            serverUrl = "http://" + String(serverIp) + ":" + String(serverPort) + "/estado";
            Serial.printf("\nConectado! IP: %s\n", esp32Ip.c_str());
            actualizarLedsWiFi(true);
            return;
        }
    }
    
    Serial.println("\nError: No se pudo conectar");
    esp32Ip = "Sin conexión";
    actualizarLedsWiFi(false);
}

void configurarServidorWeb() {
    server.on("/control", HTTP_POST, []() {
        if (!server.hasArg("plain")) {
            server.send(400, "application/json", "{\"error\":\"Falta JSON\"}");
            return;
        }

        DynamicJsonDocument doc(1024);
        if (deserializeJson(doc, server.arg("plain"))) {
            server.send(400, "application/json", "{\"error\":\"JSON inválido\"}");
            return;
        }

        String bomba = doc["bomba"].as<String>();
        String accion = doc["accion"].as<String>();
        int tiempo = doc["tiempo"] | 0;

        if (bomba == "todas") {
            if (accion == "encender") {
                iniciarSecuenciaActivacion(tiempo);
            } else {
                iniciarSecuenciaApagado();
            }
            server.send(200, "application/json", "{\"status\":\"ok\"}");
            return;
        }

        for (int i = 0; i < numBombas; i++) {
            if (bomba == bombas[i].nombre) {
                controlarBombaIndividual(i, accion == "encender", tiempo);
                server.send(200, "application/json", "{\"status\":\"ok\"}");
                return;
            }
        }

        server.send(400, "application/json", "{\"error\":\"Bomba no válida\"}");
    });

    server.on("/estado", HTTP_GET, []() {
        DynamicJsonDocument doc(1024);
        for (int i = 0; i < numBombas; i++) {
            JsonObject obj = doc.createNestedObject(bombas[i].nombre);
            obj["encendida"] = digitalRead(bombas[i].pin) == LOW;
            obj["tiempo"] = bombas[i].tiempoRestante;
            obj["pausada"] = bombas[i].pausada;
        }
        String response;
        serializeJson(doc, response);
        server.send(200, "application/json", response);
    });

    server.on("/ping", HTTP_GET, []() {
        server.send(200, "application/json", "{\"status\":\"ok\"}");
    });

    server.begin();
    Serial.println("Servidor web iniciado");
}

void controlarBombaIndividual(int idx, bool encender, int tiempo) {
    digitalWrite(bombas[idx].pin, encender ? LOW : HIGH);
    
    if (encender && !bombas[idx].pausada) {
        bombas[idx].tiempoInicio = millis();
        bombas[idx].tiempoRestante = tiempo;
        Serial.printf("Bomba %d iniciada. Tiempo: %ds\n", idx + 1, tiempo);
    } else if (!encender) {
        bombas[idx].tiempoRestante = 0;
        Serial.printf("Bomba %d detenida\n", idx + 1);
    }
    
    bombas[idx].pausada = false;
    actualizarLedsRelays();
}

void iniciarSecuenciaActivacion(int tiempo) {
    estadoSecuencia = SEC_ACTIVANDO;
    bombaActualSecuencia = 0;
    tiempoSecuencia = millis();
    Serial.println("Iniciando secuencia de activación...");
}

void iniciarSecuenciaApagado() {
    estadoSecuencia = SEC_APAGANDO;
    bombaActualSecuencia = numBombas - 1;
    tiempoSecuencia = millis();
    Serial.println("Iniciando secuencia de apagado...");
}

void manejarSecuencia() {
    if (estadoSecuencia == SEC_APAGADA) return;
    
    if (millis() - tiempoSecuencia >= intervaloEntreBombas) {
        tiempoSecuencia = millis();
        
        if (estadoSecuencia == SEC_ACTIVANDO) {
            // Activar en orden ascendente (bomba 1 a 6)
            controlarBombaIndividual(bombaActualSecuencia, true, 0);
            bombaActualSecuencia++;
            
            if (bombaActualSecuencia >= numBombas) {
                estadoSecuencia = SEC_APAGADA;
                Serial.println("Secuencia de activación completada");
            }
        } 
        else if (estadoSecuencia == SEC_APAGANDO) {
            // Apagar en orden descendente (bomba 6 a 1)
            controlarBombaIndividual(bombaActualSecuencia, false, 0);
            bombaActualSecuencia--;
            
            if (bombaActualSecuencia < 0) {
                estadoSecuencia = SEC_APAGADA;
                Serial.println("Secuencia de apagado completada");
            }
        }
    }
}

void actualizarTiempo() {
    unsigned long ahora = millis();
    for (int i = 0; i < numBombas; i++) {
        if (bombas[i].tiempoRestante > 0 && !bombas[i].pausada) {
            unsigned long transcurrido = (ahora - bombas[i].tiempoInicio) / 1000;
            
            if (transcurrido >= bombas[i].tiempoRestante) {
                digitalWrite(bombas[i].pin, HIGH);
                bombas[i].tiempoRestante = 0;
                Serial.printf("Bomba %d: Tiempo completado\n", i + 1);
            } else {
                bombas[i].tiempoRestante -= transcurrido;
            }
            bombas[i].tiempoInicio = ahora;
        }
    }
    actualizarLedsRelays();
}

void manejarReconexion() {
    if (WiFi.status() != WL_CONNECTED && millis() - ultimaConexion > 5000) {
        Serial.println("Reconectando WiFi...");
        conectarWiFi();
        ultimaConexion = millis();
    }
}

void actualizarLedsWiFi(bool conectado) {
    digitalWrite(ledRojo, !conectado);
    digitalWrite(ledAzul, conectado);
}

void actualizarLedsRelays() {
    bool todosOn = true;
    bool todosOff = true;

    for (int i = 0; i < numBombas; i++) {
        if (digitalRead(bombas[i].pin) == HIGH) {
            todosOn = false;
        } else {
            todosOff = false;
        }
    }

    digitalWrite(ledVerde, todosOn);
    digitalWrite(ledAmarillo, todosOff);
}

void procesarComandoSerial() {
    if (!Serial.available()) return;
    
    char cmd = Serial.read();
    while (Serial.available()) Serial.read(); // Limpiar buffer

    if (cmd >= '1' && cmd <= '6') {
        int idx = cmd - '1';
        controlarBombaIndividual(idx, true, 0);
        Serial.printf("Bomba %d ACTIVADA\n", idx + 1);
    } else switch(cmd) {
        case 'a':
            iniciarSecuenciaActivacion(0);
            Serial.println("Iniciando secuencia de activación...");
            break;
        case '0':
            iniciarSecuenciaApagado();
            Serial.println("Iniciando secuencia de apagado...");
            break;
        case 's':
            Serial.println("\n=== ESTADO ===");
            for (int i = 0; i < numBombas; i++) {
                Serial.printf("Bomba %d (%s): %s\n", 
                    i + 1, 
                    bombas[i].nombre,
                    digitalRead(bombas[i].pin) == LOW ? "ACTIVA" : "INACTIVA");
            }
            Serial.println("==============");
            break;
        case 'w':
            Serial.println("\n=== WIFI ===");
            Serial.printf("Estado: %s\n", WiFi.status() == WL_CONNECTED ? "CONECTADO" : "DESCONECTADO");
            Serial.printf("IP ESP32: %s\n", esp32Ip.c_str());
            Serial.printf("Servidor: %s:%d\n", serverIp, serverPort);
            Serial.println("============");
            break;
        default:
            Serial.println("Comando inválido");
    }
}

void loop() {
    procesarComandoSerial();
    manejarReconexion();
    server.handleClient();
    if (WiFi.status() == WL_CONNECTED) actualizarTiempo();
    manejarSecuencia();
    delay(10);
}
