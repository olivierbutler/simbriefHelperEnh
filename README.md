# simbriefHelperEnh
This Lua Script is an enhance version of the Simbrief Helper written by Alexander Garzon (https://forums.x-plane.org/index.php?/forums/topic/201318-simbrief-helper/) which upload Simbrief OFP to Zibo's B738 FMC

### what new ?
1. the simbrief flight plan files ( .fms and .xml) are also
    downloaded in the X-plane "Output/FMS plans" folder.

    i.e flight from LFPO to DAAG : files LFPODAAG01.fms and
    LFPODAAG01.xml are downloaded in the X-plane "Output/FMS plans"
    folder.

    On native XP B737 or Zibo B737, while programming the FMC , the
    CO-ROUTE item can be populated with LFPODAAG01 thanks only to
    Simbrief Helper Enh.

    On Zibo B737, on DES page / forecast : the uplink button can be used
    to get the wind datas (only if the OFP **layout is LIDO**)
    
2. On the script window some datas are added
    - Warning if the OFP is older than 2 hours
    - the FMS CO-ROUTE name ( needed to program the FMC)
    - the Alternate fuel quantity
    - the Reserve + Alternate fuel quantity
    
3. Simbrief Helper Enh displays updated METAR along your flight.
    - go to https://avwx.rest and register for free
    - set you own API token at the page https://account.avwx.rest/tokens
    - in the simbrief_helper.ini file located in the FlyWithLua scripts folder populated or add this line
avwxtoken=YOUR_AVWX_TOKEN
    - At any time METARs can be updated by clicking on the "Refresh Metar" button

4. Field of View angle keeper
    The Field of View angle (FoV) is a global setting of X-plane. This
    value may needed to be different for each aircraft.
    
    Simbrief Helper Enh stores your own setting for each plane and
    recall it automatically at each new flight.

This plugin pulls your OFP and flight plan from your Simbrief and put it inside your Simulator as a nice floating window (very useful for VR).
The idea is to get the most relevant data required for your flight plan to feed the FMC and prepare your aircraft (fuel and weighs)

You can do the same with Avitab and read the PDF? Yes ... but:

You need to download the PDF and save it in a specific folder each time. While this plugin pulls the full data with just one click inside without leaving the simulator.
The PDF is heavy and with tons of garbage and useless information.
Also, I have plans to integrate a "load me" button to automatically load your aircraft with fuel and payload based on your flight plan.
No everybody has Avitab, also Avitab does a lot more things! (which is nice) but because that consumes more resources (VR user’s needs resources as air to breath!)

### How it works?
Using Simbrief API, this script pulls your flight plan and save it as an XML file that then is been parsed. All you need to provide is your Simbrief username.
You can open it from the FlyWithLua macros menu. You can also assign a button or key to open it.
You need to enter your Simbrief username and then press the button "Fetch data"

#### Requirements
You need to have installed the latest version of FlyWithLua for Xp11 or Xp12 .

#### Installation
Just uncompress the content in your Resources/plugins/FlyWithLua folder.

#### Help?
https://forums.x-plane.org/index.php?/forums/topic/201318-simbrief-helper-enh/