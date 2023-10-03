# End of this project
This project has been migrated to YANSH https://github.com/olivierbutler/YANSH

=================================================================================


# simbriefHelperEnh
This Lua Script upload Simbrief OFP to Zibo's B738 FMC

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

5. Program the FMC automatically (Zibo B737 only)
Once the OFP is retrieved, Simbrief Helper Enh will program the FMC automatically

This plugin pulls your OFP and flight plan from your Simbrief and put it inside your Simulator as a nice floating window (very useful for VR).
The idea is to get the most relevant data required for your flight plan to feed the FMC and prepare your aircraft (fuel and weighs)

### How it works?
Using Simbrief API, this script pulls your flight plan and save it as an XML file that then is been parsed. All you need to provide is your Simbrief username.
You can open it from the FlyWithLua macros menu. You can also assign a button or key to open it.
You need to enter your Simbrief username and then press the button "Fetch data"

#### Requirements
You need to have installed the latest version of FlyWithLua for Xp11 or Xp12 .

#### Installation (First installation only)
Just uncompress the content of the SimbriefHelperEnh_Full_Install_2.x.zip file in your Resources/plugins/FlyWithLua folder.

#### Update (if already installed, use only this method)
Just uncompress the content of the SimbriefHelperEnh_Update_only_2.x.zip file in your Resources/plugins/FlyWithLua/Scripts folder.

#### Help?
https://forums.x-plane.org/index.php?/forums/topic/201318-simbrief-helper-enh/

#### Modules
Simbrief Helper Enh is provided with the following mandatory modules :
1. LIP.lua https://github.com/Dynodzzo/Lua_INI_Parser
2. xml2lua https://github.com/manoelcampos/xml2lua/releases

#### Credits
1. Original script by Alexander Garzon (https://forums.x-plane.org/index.php?/forums/topic/201318-simbrief-helper/)
2. xml2lua module by Manoel Campos (https://github.com/manoelcampos/xml2lua)
3. LIP module by Nicolas Carreras (https://github.com/Dynodzzo/Lua_INI_Parser)

#### History
- 3.2 This project has been migrated to YANSH https://github.com/olivierbutler/YANSH
- 2.2 Update modules to latest version of xml2Lua and improve logging
- 2.1 Add automatic FMC programing