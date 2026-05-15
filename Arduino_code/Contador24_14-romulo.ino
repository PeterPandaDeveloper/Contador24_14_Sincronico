/* ==========================================================================
   PROYECTO: CONTADOR MAESTRO ROMULO (1 BYTE ULTRARRÁPIDO)
   ========================================================================== */

#include <SoftwareSerial.h>
#include <SPI.h>
#include <DMD.h>
#include <TimerOne.h>

#define DISPLAYS_ACROSS 1
#define DISPLAYS_DOWN 2
DMD dmd(DISPLAYS_ACROSS, DISPLAYS_DOWN);

const int totalWidth = 32;
const int totalHeight = 32;
const int grosor = 4;

// --- CONFIGURACIÓN BLUETOOTH ---
// Conecta a Remo (Los pines que acabas de arreglar y dejar perfectos)
SoftwareSerial BTmaestro(2, 3);  

// Hack de pines de la App (Para no mover cables físicos)
SoftwareSerial BTapp(5, 4);      

// --- VARIABLES DE CONTROL ---
int valorInicialSec = 24;          
int valorRestanteSec = 24;         
bool countdownActivo = false;     
unsigned long lastTickMs = 0;     
const unsigned long TICK_SEC_MS = 1000UL;

void pix(int x, int y, int offset = 0) {
  int rx = x + offset; 
  int ry = y;          
  if (rx >= 0 && rx < totalWidth && ry >= 0 && ry < totalHeight) {
    int rotX = ry;
    int rotY = 31 - rx;
    dmd.writePixel(rotX, rotY, GRAPHICS_NORMAL, 1);
  }
}

void lineaH(int x, int y, int w) { for (int yy = 0; yy < grosor; yy++) { for (int xx = 0; xx < w; xx++) { pix(x + xx, y + yy); } } }
void lineaV(int x, int y, int h) { for (int yy = 0; yy < h; yy++) { for (int xx = 0; xx < grosor; xx++) { pix(x + xx, y + yy); } } }

void dibujar1(int offset=0) { int posX=3+offset, baseY=3, h=26; lineaV(posX+3, baseY, h); lineaH(posX, baseY+h-grosor, 10); lineaH(posX, baseY, 7); }
void dibujar2(int offset=0) { int posX=3+offset, baseY=3, w=10, h=26; lineaH(posX, baseY, w); lineaV(posX+w-grosor, baseY, h/2); lineaH(posX, (baseY+h/2)-2, w); lineaV(posX, baseY+h/2, h/2); lineaH(posX, baseY+h-grosor, w); }
void dibujar3(int offset=0) { int posX=3+offset, baseY=3, w=10, h=26; lineaH(posX, baseY, w); lineaH(posX, (baseY+h/2)-2, w); lineaH(posX, baseY+h-grosor, w); lineaV(posX+w-grosor, baseY, h); }
void dibujar4(int offset=0) { int posX=3+offset, baseY=3, w=10, h=26; lineaV(posX+w-grosor, baseY, h); lineaV(posX, baseY, h/2); lineaH(posX, (baseY+h/2)-2, w); }
void dibujar5(int offset=0) { int posX=3+offset, baseY=3, w=10, h=26; lineaH(posX, baseY, w); lineaV(posX, baseY, h/2); lineaH(posX, (baseY+h/2)-2, w); lineaV(posX+w-grosor, baseY+h/2, h/2); lineaH(posX, baseY+h-grosor, w); }
void dibujar6(int offset=0) { int posX=3+offset, baseY=3, w=10, h=26; lineaV(posX, baseY, h); lineaH(posX, (baseY+h/2)-2, w); lineaH(posX, baseY+h-grosor, w); lineaV(posX+w-grosor, baseY+h/2, h/2); lineaH(posX, baseY, w); }
void dibujar7(int offset=0) { int posX=3+offset, baseY=3, w=10, h=26; lineaH(posX, baseY, w); lineaV(posX+w-grosor, baseY, h); }
void dibujar8(int offset=0) { int posX=3+offset, baseY=3, w=10, h=26; lineaH(posX, baseY, w); lineaH(posX, (baseY+h/2)-2, w); lineaH(posX, baseY+h-grosor, w); lineaV(posX, baseY, h); lineaV(posX+w-grosor, baseY, h); }
void dibujar9(int offset=0) { int posX=3+offset, baseY=3, w=10, h=26; lineaH(posX, baseY, w); lineaH(posX, (baseY+h/2)-2, w); lineaV(posX+w-grosor, baseY, h); lineaV(posX, baseY, h/2); lineaH(posX, baseY+h-grosor, w); }
void dibujar0(int offset=0) { int posX=3+offset, baseY=3, w=10, h=26; lineaH(posX, baseY, w); lineaH(posX, baseY+h-grosor, w); lineaV(posX, baseY, h); lineaV(posX+w-grosor, baseY, h); }

void mostrarNumero(int n, int offset=0) {
  switch (n) {
    case 0: dibujar0(offset); break; case 1: dibujar1(offset); break;
    case 2: dibujar2(offset); break; case 3: dibujar3(offset); break;
    case 4: dibujar4(offset); break; case 5: dibujar5(offset); break;
    case 6: dibujar6(offset); break; case 7: dibujar7(offset); break;
    case 8: dibujar8(offset); break; case 9: dibujar9(offset); break;
  }
}

void scanDMD() { dmd.scanDisplayBySPI(); }

void renderValorActual(int valor) {
  if(valor < 0) valor = 0;
  if(valor > 99) valor = 99;
  dmd.clearScreen(true);
  
  if(valor == 0) {
    mostrarNumero(0, 16);  
    mostrarNumero(0, 0);   
  } else {
    mostrarNumero(valor / 10, 16); 
    mostrarNumero(valor % 10, 0);  
  }
}

// === CEREBRO DE PROCESAMIENTO ===
void procesarComando(byte cmd) {
  if (cmd == 250) { 
    if (!countdownActivo && valorRestanteSec > 0) { countdownActivo = true; lastTickMs = millis(); }
  } 
  else if (cmd == 251) { countdownActivo = false; } 
  else if (cmd == 252) { valorRestanteSec = 0; countdownActivo = false; renderValorActual(0); } 
  else if (cmd == 253) { valorRestanteSec = 14; valorInicialSec = 14; countdownActivo = false; renderValorActual(14); } 
  else if (cmd == 254) { valorRestanteSec = 24; valorInicialSec = 24; countdownActivo = false; renderValorActual(24); } 
  else if (cmd >= 0 && cmd <= 99) { valorRestanteSec = cmd; valorInicialSec = cmd; countdownActivo = false; renderValorActual(cmd); }
}

void setup() {
  Serial.begin(9600);
  
  // Velocidades calibradas
  BTmaestro.begin(115200);
  BTapp.begin(115200);

  BTapp.listen(); 

  // Punto dulce 4000
  Timer1.initialize(4000);
  Timer1.attachInterrupt(scanDMD);
  
  renderValorActual(valorRestanteSec);
  Serial.println("RÓMULO MAESTRO listo. ¡SISTEMA AL 100%!");
}

void loop() {
  // 1. LEER APP FLUTTER Y REENVIAR A REMO
  if (BTapp.available()) {
    byte cmd = BTapp.read(); 
    Serial.print("App envio el Byte: "); Serial.println(cmd);
    
    BTmaestro.write(cmd); // Disparo directo a Remo
    procesarComando(cmd); // Procesar en Rómulo
  }

  // 2. CONTEO LOCAL
  if (countdownActivo && valorRestanteSec >= 0) {
    unsigned long now = millis();
    if (now - lastTickMs >= TICK_SEC_MS) {
      lastTickMs = now;
      valorRestanteSec--;
      if (valorRestanteSec < 0) {
        valorRestanteSec = 0;
        countdownActivo = false;
      }
      renderValorActual(valorRestanteSec);
    }
  }
}