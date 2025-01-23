MODULE_NAME='mSharpPN-R703'     (
                                    dev vdvObject,
                                    dev dvPort
                                )

(***********************************************************)
#include 'NAVFoundation.ModuleBase.axi'
#include 'NAVFoundation.Math.axi'
#include 'NAVFoundation.SocketUtils.axi'

/*
 _   _                       _          ___     __
| \ | | ___  _ __ __ _  __ _| |_ ___   / \ \   / /
|  \| |/ _ \| '__/ _` |/ _` | __/ _ \ / _ \ \ / /
| |\  | (_) | | | (_| | (_| | ||  __// ___ \ V /
|_| \_|\___/|_|  \__, |\__,_|\__\___/_/   \_\_/
                 |___/

MIT License

Copyright (c) 2023 Norgate AV Services Limited

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

(***********************************************************)
(*          DEVICE NUMBER DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_DEVICE

(***********************************************************)
(*               CONSTANT DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_CONSTANT

constant long TL_DRIVE    = 1
constant long TL_IP_CHECK = 2

constant integer REQUIRED_POWER_ON    = 1
constant integer REQUIRED_POWER_OFF    = 2

constant integer ACTUAL_POWER_ON    = 1
constant integer ACTUAL_POWER_OFF    = 2

constant integer REQUIRED_INPUT_DVI_1    = 1
constant integer REQUIRED_INPUT_VGA_1    = 2
constant integer REQUIRED_INPUT_COMPONENT_1    = 3
constant integer REQUIRED_INPUT_VIDEO_1    = 4
constant integer REQUIRED_INPUT_RGB_1    = 5
constant integer REQUIRED_INPUT_DVI_2    = 6
constant integer REQUIRED_INPUT_SVIDEO_1    = 7
constant integer REQUIRED_INPUT_HDMI_1_AV    = 8
constant integer REQUIRED_INPUT_HDMI_1_PC    = 9
constant integer REQUIRED_INPUT_HDMI_2_AV    = 10
constant integer REQUIRED_INPUT_HDMI_2_PC    = 11
constant integer REQUIRED_INPUT_DISPLAYPORT    = 12

constant integer ACTUAL_INPUT_DVI_1    = 1
constant integer ACTUAL_INPUT_VGA_1    = 2
constant integer ACTUAL_INPUT_COMPONENT_1    = 3
constant integer ACTUAL_INPUT_VIDEO_1    = 4
constant integer ACTUAL_INPUT_RGB_1    = 5
constant integer ACTUAL_INPUT_DVI_2    = 6
constant integer ACTUAL_INPUT_SVIDEO_1    = 7
constant integer ACTUAL_INPUT_HDMI_1_AV    = 8
constant integer ACTUAL_INPUT_HDMI_1_PC    = 9
constant integer ACTUAL_INPUT_HDMI_2_AV    = 10
constant integer ACTUAL_INPUT_HDMI_2_PC    = 11
constant integer ACTUAL_INPUT_DISPLAYPORT    = 12

constant char INPUT_COMMANDS[][NAV_MAX_CHARS]    = { '1',
                            '2',
                            '3',
                            '4',
                            '6',
                            '7',
                            '8',
                            '9',
                            '10',
                            '12',
                            '13',
                            '14' }

constant integer GET_POWER    = 1
constant integer GET_INPUT    = 2
constant integer GET_MUTE    = 3
constant integer GET_VOLUME    = 4

constant integer REQUIRED_MUTE_ON    = 1
constant integer REQUIRED_MUTE_OFF    = 2

constant integer ACTUAL_MUTE_ON    = 1
constant integer ACTUAL_MUTE_OFF    = 2

constant integer MAX_VOLUME = 31
constant integer MIN_VOLUME = 0

(***********************************************************)
(*              DATA TYPE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_TYPE

(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE

volatile long ltIPCheck[] = { 3000 }    //3 seconds
volatile _NAVDisplay uDisplay

volatile integer iLoop
volatile integer iPollSequence = GET_POWER

volatile integer iRequiredPower
volatile integer iRequiredInput
volatile integer iRequiredMute
volatile sinteger iRequiredVolume = 1

volatile long ltDrive[] = { 200 }

volatile integer iSemaphore
volatile char cRxBuffer[NAV_MAX_BUFFER]

volatile integer iModuleEnabled

volatile integer iPowerBusy

volatile char cIPAddress[15]
volatile integer iTCPPort
volatile integer iIPConnected = false

volatile integer iCommandBusy
volatile integer iCommandLockOut

volatile integer iCommunicating

volatile integer iWaitBusy

volatile integer iID = 1

(***********************************************************)
(*               LATCHING DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_LATCHING

(***********************************************************)
(*       MUTUALLY EXCLUSIVE DEFINITIONS GO BELOW           *)
(***********************************************************)
DEFINE_MUTUALLY_EXCLUSIVE

(***********************************************************)
(*        SUBROUTINE/FUNCTION DEFINITIONS GO BELOW         *)
(***********************************************************)
(* EXAMPLE: DEFINE_FUNCTION <RETURN_TYPE> <NAME> (<PARAMETERS>) *)
(* EXAMPLE: DEFINE_CALL '<NAME>' (<PARAMETERS>) *)
define_function SendStringRaw(char cParam[]) {
     NAVErrorLog(NAV_LOG_LEVEL_DEBUG, NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_STRING_TO, dvPort, cParam))
    send_string dvPort,"cParam"
}

define_function SendString(char cParam[]) {
    SendStringRaw("cParam,NAV_CR")
}

define_function SendQuery(integer iParam) {
    switch (iParam) {
    case GET_POWER: SendString("'POWR????'")
    case GET_INPUT: SendString("'INPS????'")
    case GET_MUTE: SendString("'MUTE????'")
    case GET_VOLUME: SendString("'VOLM????'")
    }
}

define_function TimeOut() {
    cancel_wait 'CommsTimeOut'
    wait 300 'CommsTimeOut' { iCommunicating = false }
}

define_function SetPower(integer iParam) {
    switch (iParam) {
    case REQUIRED_POWER_ON: { SendString("'POWR0001'") }
    case REQUIRED_POWER_OFF: { SendString("'POWR0000'") }
    }
}

define_function SetInput(integer iParam) { SendString("'INPS00',format('%02d',atoi(INPUT_COMMANDS[iParam]))") }

define_function SetVolume(sinteger siParam) { SendString("'VOLM00',format('%02d',siParam)") }

define_function SetMute(integer iParam) {
    switch (iParam) {
    case REQUIRED_MUTE_ON: { SendString("'MUTE0001'") }
    case REQUIRED_MUTE_OFF: { SendString("'MUTE0000'") }
    }
}

define_function Process() {
    stack_var char cTemp[NAV_MAX_BUFFER]
    iSemaphore = true
    while (length_array(cRxBuffer) && NAVContains(cRxBuffer,"NAV_LF")) {
    cTemp = remove_string(cRxBuffer,"NAV_LF",1)
    if (length_array(cTemp)) {
         NAVErrorLog(NAV_LOG_LEVEL_DEBUG, NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_PARSING_STRING_FROM, dvPort, cTemp))
        cTemp = NAVStripCharsFromRight(cTemp, 2)    //Removes CRLF
        select {
        active (NAVContains(cTemp,'ERR') || NAVContains(cTemp,"$FF,$FF,$FF")): {

        }
        active (NAVContains(cTemp,'WAIT')): {
            iWaitBusy = true
            wait 100 'WaitBusy' iWaitBusy = false    //Force it off after 10 seconds just incase
        }
        active (NAVContains(cTemp,'OK')): {
            cancel_wait 'WaitBusy'
            iWaitBusy = false
        }
        active (NAVContains(cTemp,'LOCKED')): {

        }
        active (NAVContains(cTemp,'UNSELECTED')): {

        }
        active (1): {
            switch (iPollSequence) {
            case GET_POWER: {
                switch (cTemp) {
                case '0': { uDisplay.PowerState.Actual = ACTUAL_POWER_OFF; iPollSequence = GET_INPUT }
                case '1': { uDisplay.PowerState.Actual = ACTUAL_POWER_ON; iPollSequence = GET_INPUT }
                case '2': { uDisplay.PowerState.Actual = ACTUAL_POWER_ON; iPollSequence = GET_INPUT }
                }
            }
            case GET_INPUT: {
                switch (cTemp) {
                case '10': { uDisplay.Input.Actual = ACTUAL_INPUT_HDMI_1_PC; iPollSequence = GET_MUTE }
                case '12': { uDisplay.Input.Actual = ACTUAL_INPUT_HDMI_2_AV; iPollSequence = GET_MUTE }
                case '13': { uDisplay.Input.Actual = ACTUAL_INPUT_HDMI_2_PC; iPollSequence = GET_MUTE }
                case '14': { uDisplay.Input.Actual = ACTUAL_INPUT_DISPLAYPORT; iPollSequence = GET_MUTE }
                case '1': { uDisplay.Input.Actual = ACTUAL_INPUT_DVI_1; iPollSequence = GET_MUTE }
                case '2': { uDisplay.Input.Actual = ACTUAL_INPUT_VGA_1; iPollSequence = GET_MUTE }
                case '3': { uDisplay.Input.Actual = ACTUAL_INPUT_COMPONENT_1; iPollSequence = GET_MUTE }
                case '4': { uDisplay.Input.Actual = ACTUAL_INPUT_VIDEO_1; iPollSequence = GET_MUTE }
                case '6': { uDisplay.Input.Actual = ACTUAL_INPUT_RGB_1; iPollSequence = GET_MUTE }
                case '7': { uDisplay.Input.Actual = ACTUAL_INPUT_DVI_2; iPollSequence = GET_MUTE }
                case '8': { uDisplay.Input.Actual = ACTUAL_INPUT_SVIDEO_1; iPollSequence = GET_MUTE }
                case '9': { uDisplay.Input.Actual = ACTUAL_INPUT_HDMI_1_AV; iPollSequence = GET_MUTE }
                }
            }
            case GET_MUTE: {
                switch (cTemp) {
                case '0': { uDisplay.Volume.Mute.Actual = ACTUAL_MUTE_OFF; iPollSequence = GET_VOLUME }
                case '1': { uDisplay.Volume.Mute.Actual = ACTUAL_MUTE_ON; iPollSequence = GET_VOLUME }
                }
            }
            case GET_VOLUME: {
                if (atoi(cTemp) != uDisplay.Volume.Level.Actual) {
                uDisplay.Volume.Level.Actual = atoi(cTemp)
                send_level vdvObject, VOL_LVL, NAVScaleValue(uDisplay.Volume.Level.Actual, 255, (MAX_VOLUME - MIN_VOLUME), 0)
                }
                iPollSequence = GET_POWER
            }
            }
        }
        }
    }
    }

    iSemaphore = false
}

define_function Drive() {
    iLoop++
    switch (iLoop) {
    case 1:
    case 6:
    case 11:
    case 16: { SendQuery(iPollSequence); return }
    case 21: { iLoop = 1; return }
    default: {
        if (iCommandLockOut || iWaitBusy) { return }
        if (iRequiredPower && (iRequiredPower == uDisplay.PowerState.Actual)) { iRequiredPower = 0; return }
        if (iRequiredInput && (iRequiredInput == uDisplay.Input.Actual)) { iRequiredInput = 0; return }
        if (iRequiredMute && (iRequiredMute == uDisplay.Volume.Mute.Actual)) { iRequiredMute = 0; return }
        if (iRequiredVolume && (iRequiredVolume == (uDisplay.Volume.Level.Actual + 1))) { iRequiredVolume = 0; return }

        if (iRequiredPower && (iRequiredPower != uDisplay.PowerState.Actual) && [vdvObject,DEVICE_COMMUNICATING]) {
        iCommandBusy = true
        SetPower(iRequiredPower)
        iCommandLockOut = true
        wait 80 iCommandLockOut = false
        iPollSequence = GET_POWER
        return
        }

        if (iRequiredInput && (uDisplay.PowerState.Actual == ACTUAL_POWER_ON) && (iRequiredInput != uDisplay.Input.Actual) && [vdvObject,DEVICE_COMMUNICATING]) {
        iCommandBusy = true
        SetInput(iRequiredInput)
        iCommandLockOut = true
        wait 10 iCommandLockOut = false
        iPollSequence = GET_INPUT
        return
        }

        if (iRequiredMute && (uDisplay.PowerState.Actual == ACTUAL_POWER_ON) && (iRequiredMute != uDisplay.Volume.Mute.Actual) && [vdvObject,DEVICE_COMMUNICATING]) {
        iCommandBusy = true
        SetMute(iRequiredMute);
        iCommandLockOut = true
        wait 10 iCommandLockOut = false
        iPollSequence = GET_MUTE;
        return
        }

        if ([vdvObject,VOL_UP]) {
        if (uDisplay.PowerState.Actual == ACTUAL_POWER_ON) {
            if (uDisplay.Volume.Level.Actual < MAX_VOLUME) {
            iRequiredVolume = (uDisplay.Volume.Level.Actual + 1) + 1
            }
        }
        }

        if ([vdvObject,VOL_DN]) {
        if (uDisplay.PowerState.Actual == ACTUAL_POWER_ON) {
            if (uDisplay.Volume.Level.Actual > MIN_VOLUME) {
            iRequiredVolume = (uDisplay.Volume.Level.Actual - 1) + 1
            }
        }
        }

        if (iRequiredVolume && (uDisplay.PowerState.Actual == ACTUAL_POWER_ON) && [vdvObject,DEVICE_COMMUNICATING]) {
        iCommandBusy = true
        SetVolume(iRequiredVolume - 1);
        iPollSequence = GET_VOLUME;
        return
        }
    }
    }
}

define_function MaintainIPConnection() {
    if (!iIPConnected) {
    NAVClientSocketOpen(dvPort.port,cIPAddress,iTCPPort,IP_TCP)
    }
}

(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)
DEFINE_START
create_buffer dvPort,cRxBuffer

iModuleEnabled = true

// Update event tables
rebuild_event()
(***********************************************************)
(*                THE EVENTS GO BELOW                      *)
(***********************************************************)
DEFINE_EVENT
data_event[dvPort] {
    online: {
    if (iModuleEnabled && data.device.number != 0) {
        send_command data.device,"'SET BAUD 38400,N,8,1 485 DISABLE'"
        send_command data.device,"'B9MOFF'"
        send_command data.device,"'CHARD-0'"
        send_command data.device,"'CHARDM-0'"
        send_command data.device,"'HSOFF'"
        NAVTimelineStart(TL_DRIVE,ltDrive,timeline_absolute,timeline_repeat)
    }

    if (iModuleEnabled && data.device.number == 0) {
        iIPConnected = true
        NAVTimelineStart(TL_DRIVE,ltDrive,timeline_absolute,timeline_repeat)
    }
    }
    string: {
    if (iModuleEnabled) {
        iCommunicating = true
        [vdvObject,DATA_INITIALIZED] = true
        TimeOut()
         NAVErrorLog(NAV_LOG_LEVEL_DEBUG, NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_STRING_FROM, dvPort, data.text))
        if (!iSemaphore) { Process() }
    }
    }
    offline: {
    if (data.device.number == 0) {
        NAVClientSocketClose(dvPort.port)
        iIPConnected = false
        //iCommunicating = false
    }
    }
    onerror: {
    if (data.device.number == 0) {
        //iIPConnected = false
        //iCommunicating = false
    }
    }
}

data_event[vdvObject] {
    command: {
    stack_var char cCmdHeader[NAV_MAX_CHARS]
    stack_var char cCmdParam[3][NAV_MAX_CHARS]
    if (iModuleEnabled) {
        NAVErrorLog(NAV_LOG_LEVEL_DEBUG, NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_COMMAND_FROM, data.device, data.text))
        cCmdHeader = DuetParseCmdHeader(data.text)
        cCmdParam[1] = DuetParseCmdParam(data.text)
        cCmdParam[2] = DuetParseCmdParam(data.text)
        cCmdParam[3] = DuetParseCmdParam(data.text)
        switch (cCmdHeader) {
        case 'PROPERTY': {
            switch (cCmdParam[1]) {
            case 'IP_ADDRESS': {
                cIPAddress = cCmdParam[2]
                //NAVTimelineStart(TL_IP_CHECK,ltIPCheck,timeline_absolute,timeline_repeat)
            }
            case 'TCP_PORT': {
                iTCPPort = atoi(cCmdParam[2])
                NAVTimelineStart(TL_IP_CHECK,ltIPCheck,timeline_absolute,timeline_repeat)
            }
            }
        }
        case 'PASSTHRU': { SendString(cCmdParam[1]) }

        case 'POWER': {
            switch (cCmdParam[1]) {
            case 'ON': { iRequiredPower = REQUIRED_POWER_ON; Drive() }
            case 'OFF': { iRequiredPower = REQUIRED_POWER_OFF; iRequiredInput = 0; Drive() }
            }
        }
        case 'VOLUME': {
            switch (cCmdParam[1]) {
            case 'ABS': {
                SetVolume(atoi(cCmdParam[1]))
            }
            default: {
                SetVolume(NAVScaleValue(atoi(cCmdParam[1]), (MAX_VOLUME - MIN_VOLUME), 255, 0))
            }
            }
        }
        case 'INPUT': {
            switch (cCmdParam[1]) {
            case 'VGA': {
                switch (cCmdParam[2]) {
                case '1': { iRequiredPower = REQUIRED_POWER_ON; iRequiredInput = REQUIRED_INPUT_VGA_1; Drive() }
                }
            }
            case 'RGB': {
                switch (cCmdParam[2]) {
                case '1': { iRequiredPower = REQUIRED_POWER_ON; iRequiredInput = REQUIRED_INPUT_RGB_1; Drive() }
                }
            }
            case 'DISPLAYPORT': {
                switch (cCmdParam[2]) {
                case '1': { iRequiredPower = REQUIRED_POWER_ON; iRequiredInput = REQUIRED_INPUT_DISPLAYPORT; Drive() }
                }
            }
            case 'HDMI': {
                switch (cCmdParam[2]) {
                case '1': {
                    switch (cCmdParam[3]) {
                    case 'AV': { iRequiredPower = REQUIRED_POWER_ON; iRequiredInput = REQUIRED_INPUT_HDMI_1_AV; Drive() }
                    case 'PC': { iRequiredPower = REQUIRED_POWER_ON; iRequiredInput = REQUIRED_INPUT_HDMI_1_PC; Drive() }
                    }
                }
                case '2': {
                    switch (cCmdParam[3]) {
                    case 'AV': { iRequiredPower = REQUIRED_POWER_ON; iRequiredInput = REQUIRED_INPUT_HDMI_2_AV; Drive() }
                    case 'PC': { iRequiredPower = REQUIRED_POWER_ON; iRequiredInput = REQUIRED_INPUT_HDMI_2_PC; Drive() }
                    }
                }
                }
            }
            case 'DVI': {
                switch (cCmdParam[2]) {
                case '1': { iRequiredPower = REQUIRED_POWER_ON; iRequiredInput = REQUIRED_INPUT_DVI_1; Drive() }
                case '2': { iRequiredPower = REQUIRED_POWER_ON; iRequiredInput = REQUIRED_INPUT_DVI_2; Drive() }
                }
            }
            case 'COMPONENT': {
                switch (cCmdParam[2]) {
                case '1': { iRequiredPower = REQUIRED_POWER_ON; iRequiredInput = REQUIRED_INPUT_COMPONENT_1; Drive() }
                }
            }
            case 'S-VIDEO': {
                switch (cCmdParam[2]) {
                case '1': { iRequiredPower = REQUIRED_POWER_ON; iRequiredInput = REQUIRED_INPUT_SVIDEO_1; Drive() }
                }
            }
            case 'COMPOSITE': {
                switch (cCmdParam[2]) {
                case '1': { iRequiredPower = REQUIRED_POWER_ON; iRequiredInput = REQUIRED_INPUT_VIDEO_1; Drive() }
                }
            }
            }
        }
        }
    }
    }
}

channel_event[vdvObject,0] {
    on: {
    if (iModuleEnabled) {
        switch (channel.channel) {
        case POWER: {
            if (iRequiredPower) {
            switch (iRequiredPower) {
                case REQUIRED_POWER_ON: { iRequiredPower = REQUIRED_POWER_OFF; iRequiredInput = 0; Drive() }
                case REQUIRED_POWER_OFF: { iRequiredPower = REQUIRED_POWER_ON; Drive() }
            }
            }else {
            switch (uDisplay.PowerState.Actual) {
                case ACTUAL_POWER_ON: { iRequiredPower = REQUIRED_POWER_OFF; iRequiredInput = 0; Drive() }
                case ACTUAL_POWER_OFF: { iRequiredPower = REQUIRED_POWER_ON; Drive() }
            }
            }
        }
        case PWR_ON: { iRequiredPower = REQUIRED_POWER_ON; Drive() }
        case PWR_OFF: { iRequiredPower = REQUIRED_POWER_OFF; iRequiredInput = 0; Drive() }
        //case PIC_MUTE: { SetShutter(![vdvObject,PIC_MUTE_FB]) }
        case VOL_MUTE: {
            if (uDisplay.PowerState.Actual == ACTUAL_POWER_ON) {
            if (iRequiredMute) {
                switch (iRequiredMute) {
                case REQUIRED_MUTE_ON: { iRequiredMute = REQUIRED_MUTE_OFF; Drive() }
                case REQUIRED_MUTE_OFF: { iRequiredMute = REQUIRED_MUTE_ON; Drive() }
                }
            }else {
                switch (uDisplay.Volume.Mute.Actual) {
                case ACTUAL_MUTE_ON: { iRequiredMute = REQUIRED_MUTE_OFF; Drive() }
                case ACTUAL_MUTE_OFF: { iRequiredMute = REQUIRED_MUTE_ON; Drive() }
                }
            }
            }
        }
        }
    }
    }
}

timeline_event[TL_DRIVE] { Drive() }

timeline_event[TL_IP_CHECK] { MaintainIPConnection() }

timeline_event[TL_NAV_FEEDBACK] {
    if (iModuleEnabled) {
    [vdvObject,DEVICE_COMMUNICATING]    = (iCommunicating)
    [vdvObject,VOL_MUTE_FB] = (uDisplay.Volume.Mute.Actual == ACTUAL_MUTE_ON)
    [vdvObject,POWER_FB] = (uDisplay.PowerState.Actual == ACTUAL_POWER_ON)
    //if (iIPConnected) {
        //NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'Sharp LCD IP Connected'")
    //}
    }
}

(***********************************************************)
(*                     END OF PROGRAM                      *)
(*        DO NOT PUT ANY CODE BELOW THIS COMMENT           *)
(***********************************************************)

