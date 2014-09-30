long rampe_millis = 0;
int valeur = 0;

void action() { 
/*********** Put what you want the code to do with the values (dmxvalue) here *************/
  
  int vitesse = min(max(VITESSE_SERVO, 1), 15);
  int valeur2 = map(dmxvalue[0],0, 255, VALEUR_MIN_COURSE, VALEUR_MAX_COURSE);
  
  
  if (vitesse == 15) {
    
    valeur = valeur2;
    rampe_millis = 0;
    
  } else {
    if (valeur == valeur2) {
      // nothing !
    } else if (valeur > valeur2) {
      valeur = max(valeur - vitesse, valeur2);
    } else {
      valeur = min(valeur + vitesse, valeur2);
    }
     rampe_millis = millis();
  }
  
  
  // écriture de l'angle du servo
  if (inversion) {
    myservo.write(map(valeur, 0, 255, 180, 0));
  } else {
    myservo.write(map(valeur, 0, 255, 0, 180));
  }
  
  return;  //go back to loop()
} //end action() loop
