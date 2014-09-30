/**********************************************************\
*                                                          *
* DMX-512 Reception et Servo                               *
* Créé par Jean-Nicolas VALDENAIRE                         *
* Version 0.1 - 12 octobre 2010                            *
* jn.valdenaire.free.fr                                    *
*                                                          *
* D'après le travail de Max Pierson :                      *
* http://blog.wingedvictorydesign.com/                     *
*                                                          *
\***********************************************************/





/**********************************************\
*                                              *
*            CONSTANTES A MODIFIER             *
*            v  v  v       v  v  v             *
\**********************************************/



// Configuration de la course du servo. Entre 0 et 255
#define VALEUR_MIN_COURSE 0
#define VALEUR_MAX_COURSE 255
// Par defaut la course est à 0 pour le minimum et à 255 pour le maximum : La plus grande course

// Configuration de la vitesse du servo. Entre 1 et 15
#define VITESSE_SERVO 15
//Par defaut la vitesse est à 20 : Le plus rapide


/**********************************************\
*            ^  ^  ^       ^  ^  ^             *
*            CONSTANTES A MODIFIER             *
*                                              *
\**********************************************/


/**************************************************************\
*                                                              *
*        Remplacer le fichier HardwareSerial.cpp               *
*                                                              *
\**************************************************************/




/******************************* Addressing variable declarations *****************************/

#include <Servo.h>
#include <EEPROM.h>
// Inclusion des librairies

#define NUMBER_OF_CHANNELS 1
// Nombre de canaux reçu


unsigned int dmxaddress = 1;
/* Adresse DMX qui sera récupéré.


/****************************** Configuration des connexions *******************************/

// Pin du dipswitch de sélection du canal (1, 2, 3, 4, 5, 6, 7, 8, 9)
int dipSwitch[9] = {2, 3, 4, 5, 6, 7, 8, 9, 11};
#define STATUT_LED_PIN 13    // Pin de la LED de statut
#define SERVO_PIN 10         // Pin de commande du servo
#define INVERSION_PIN 12     // Inversion de la course du servo

/******************************* Configuration MAX485 *************************************/

#define RX_PIN 0   // serial receive pin, which takes the incoming data from the MAX485.
#define TX_PIN 1   // serial transmission pin

/******************************* Variables DMX ********************************************/

volatile byte i = 0;              //dummy variable for dmxvalue[]
volatile byte dmxreceived = 0;    //dernière caleur dmx reçue
volatile unsigned int dmxcurrent = 0;     //counter variable that is incremented every time we receive a value.
volatile byte dmxvalue[NUMBER_OF_CHANNELS];     
/*  stores the DMX values we're interested in using-- 
 *  keep in mind that this is 0-indexed. */
volatile boolean dmxnewvalue = false; 
/*  set to 1 when updated dmx values are received 
 *  (even if they are the same values as the last time). */
volatile boolean inversion = false;  // inverse la course du servo

/******************************* Timer2 variable declarations *****************************/

volatile byte zerocounter = 0;          
/* a counter to hold the number of zeros received in sequence on the serial receive pin.  
*  When we've received a minimum of 11 zeros in a row, we must be in a break.  */

/******************************* Déclaration des variables du Servo ************************/

Servo myservo;


/*******************************************************************************************/
/******************************* Fonction setup() ******************************************/
/*******************************************************************************************/


void setup() {
  
  myservo.attach(SERVO_PIN);
  
  /******************************* Max485 configuration ***********************************/
  
  pinMode(RX_PIN, INPUT);  //sets serial pin to receive data
  
  pinMode(STATUT_LED_PIN, OUTPUT); //Statut Led Info

  /******************************* Addressing subroutine *********************************/

 /* pinMode(SWITCH_PIN_0, INPUT);           //sets pin for '0' switch to input
  digitalWrite(SWITCH_PIN_0, HIGH);       //turns on the internal pull-up resistor for '0' switch pin
  pinMode(SWITCH_PIN_1, INPUT);           //sets pin for '1' switch to input  
  digitalWrite(SWITCH_PIN_1, HIGH);       //turns on the internal pull-up resistor for '1' switch pin
  
  /* Call the addressing subroutine.  Three behaviors are possible:
  *  1. Neither switch is pressed, in which case the value previously stored in EEPROM
  *  is recalled,
  *  2. Both switches are pressed, in which case the address is reset to 1.
  *  3. Either switch is pressed (but not both), in which case the new address may 
  *  be entered by the user.
  */
  //set this equal to a constant value if you just want to hardcode the address.
  //AddressingLoop();
  dmxaddress = Addressing();
  
  /******************************* USART configuration ************************************/
  
  Serial.begin(250000);
  /* Each bit is 4uS long, hence 250Kbps baud rate */
  
  cli(); //disable interrupts while we're setting bits in registers
  
  bitClear(UCSR0B, RXCIE0);  //disable USART reception interrupt
  
  /******************************* Timer2 configuration ***********************************/
  
  //NOTE:  this will disable PWM on pins 3 and 11.
  bitClear(TCCR2A, COM2A1);
  bitClear(TCCR2A, COM2A0); //disable compare match output A mode
  bitClear(TCCR2A, COM2B1);
  bitClear(TCCR2A, COM2B0); //disable compare match output B mode
  bitSet(TCCR2A, WGM21);
  bitClear(TCCR2A, WGM20);  //set mode 2, CTC.  TOP will be set by OCRA.
  
  bitClear(TCCR2B, FOC2A);
  bitClear(TCCR2B, FOC2B);  //disable Force Output Compare A and B.
  bitClear(TCCR2B, WGM22);  //set mode 2, CTC.  TOP will be set by OCRA.
  bitClear(TCCR2B, CS22);
  bitClear(TCCR2B, CS21);
  bitSet(TCCR2B, CS20);   // no prescaler means the clock will increment every 62.5ns (assuming 16Mhz clock speed).
  
  OCR2A = 64;                
  /* Set output compare register to 64, so that the Output Compare Interrupt will fire
  *  every 4uS.  */
  
  bitClear(TIMSK2, OCIE2B);  //Disable Timer/Counter2 Output Compare Match B Interrupt
  bitSet(TIMSK2, OCIE2A);    //Enable Timer/Counter2 Output Compare Match A Interrupt
  bitClear(TIMSK2, TOIE2);   //Disable Timer/Counter2 Overflow Interrupt Enable          
  
  sei();                     //reenable interrupts now that timer2 has been configured. 
  
}  //end setup()


/*******************************************************************************************/
/******************************* Fonction loop() *******************************************/
/*******************************************************************************************/


void loop()  {
  // the processor gets parked here while the ISRs are doing their thing. 
  
  if (dmxnewvalue == 1) {
    digitalWrite(STATUT_LED_PIN, HIGH);
  } else {
    digitalWrite(STATUT_LED_PIN, LOW);
  }
  
  
  if (dmxnewvalue >= 1) {    //when a new set of values are received, jump to action loop...
    action();
    if (dmxnewvalue == 1) {  //when a new set of values are received form dmx and not from switch
      dmxnewvalue = 0;
    }
    dmxcurrent = 0;
    zerocounter = 0;      //and then when finished reset variables and enable timer2 interrupt
    i = 0;
    bitSet(TIMSK2, OCIE2A);    //Enable Timer/Counter2 Output Compare Match A Interrupt
  }
} //end loop()


/*******************************************************************************************/
/******************************* Fonction interuption **************************************/
/*******************************************************************************************/


//Timer2 compare match interrupt vector handler
ISR(TIMER2_COMPA_vect) {
  if (bitRead(PIND, PIND0)) {  // if a one is detected, we're not in a break, reset zerocounter.
    zerocounter = 0;
    }
  else {
    zerocounter++;             // increment zerocounter if a zero is received.
    if (zerocounter == 20)     // if 20 0's are received in a row (80uS break)
      {   
      bitClear(TIMSK2, OCIE2A);    //disable this interrupt and enable reception interrupt now that we're in a break.
      bitSet(UCSR0B, RXCIE0);
      }
  }
} //end Timer2 ISR



ISR(USART_RX_vect){
  dmxreceived = UDR0;
  /* The receive buffer (UDR0) must be read during the reception ISR, or the ISR will just 
  *  execute again immediately upon exiting. */
 
  dmxcurrent++;                        //increment address counter
 
  if(dmxcurrent > dmxaddress) {         //check if the current address is the one we want.
    dmxvalue[i] = dmxreceived;
    i++;
    if(i == NUMBER_OF_CHANNELS) {
      bitClear(UCSR0B, RXCIE0); 
      dmxnewvalue = 1;                        //set newvalue, so that the main code can be executed.
      digitalWrite(STATUT_LED_PIN, HIGH);
    } 
  }
} // end ISR
