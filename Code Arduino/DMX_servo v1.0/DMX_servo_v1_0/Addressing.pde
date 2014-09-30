
unsigned int Addressing() {
  
  // Configuration des entrées du dipSwitch permettant d'entrer l'adresse DMX
  for (int i = 0; i < 9; i++) {
    pinMode(dipSwitch[i], INPUT);
    digitalWrite(dipSwitch[i], HIGH);
  }
  
  // init des variables
  int newdmxaddress = 0;
  
  // Adressage DMX
  for (int i = 0; i < 9; i++) {
    if (digitalRead(dipSwitch[i]) == LOW) {
      bitWrite(newdmxaddress, i, 1);
    } else {
      bitWrite(newdmxaddress, i, 0);
    }

  }
  
  // Clignotement permettant de signaler que l'adressage est fini.
  pinMode(13, OUTPUT);
  digitalWrite(13, LOW);
 if (newdmxaddress <= 511 && newdmxaddress >= 1) {
    for (int i = 0; i < 15; i++) {
     digitalWrite(13, HIGH);
     delay(30);
     digitalWrite(13, LOW);
     delay(30);
   }
 } else {
   newdmxaddress = 0;
 }
  
  // Configuration de l'inversion de la course du servo
  pinMode(INVERSION_PIN, INPUT);
  digitalWrite(INVERSION_PIN, HIGH);
  if (digitalRead(INVERSION_PIN) == LOW) {
    inversion = true;
  } else {
    inversion = false;
  }
  
  
  newdmxaddress = newdmxaddress + 3;
/*  this will allow the USART receive interrupt to fire an additional 3 times for every dmx frame.  
*   Here's why:
*   Once to account for the fact that DMX addresses run from 0-511, whereas channel numbers
*        start numbering at 1.
*   Once for the Mark After Break (MAB), which will be detected by the USART as a valid character 
*        (a zero, eight more zeros, followed by a one)
*   Once for the START code that precedes the 512 DMX values (used for RDM).  */

  return newdmxaddress;
} // fin de Addressing()

