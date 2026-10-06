/*
 _      _         _            _      _
| |__  | |__     | |__   _ __ (_)  __| |  __ _   ___
| '_ \ | '_ \    | '_ \ | '__|| | / _` | / _` | / _ \
| | | || |_) | _ | |_) || |   | || (_| || (_| ||  __/
|_| |_||_.__/ (_)|_.__/ |_|   |_| \__,_| \__, | \___|
                                         |___/
Released to Public Domain.
--------------------------------------------------------------------------------------
*/
#include "hbhrb.ch"
#include "fileio.ch"

FUNCTION ExecuteAddonHRB( cAddonName, oParams, cAddonRoot )
    LOCAL hHrb, cResult := "", cExt, cFile

    hb_default( @cAddonRoot, "./addons" )
    cFile := hb_DirSepAdd( cAddonRoot ) + cAddonName

    hb_FNameSplit( cAddonName, NIL, NIL, @cExt )

    IF File( cFile )
        BEGIN SEQUENCE
            cExt := Lower( cExt )
            SWITCH cExt
            CASE ".prg"
            CASE ".hb"
            CASE ".hrb"
                EXIT
            OTHERWISE
                cExt := FileSig( cFile )
            ENDSWITCH
            SWITCH cExt
            CASE ".prg"
            CASE ".hb"
                cFile := hb_compileBuf( hb_argv( 0 ), "-n2", "-w", "-es2", "-q0", ;
                    "-D" + "__HBSCRIPT__HBNETIOSRV", cFile )
                IF cFile != NIL
                    hHrb := hb_hrbLoad( HB_HRB_BIND_FORCELOCAL, cFile )
                ENDIF
                IF ! Empty( hHrb )
                    cResult := hb_hrbDo( hHrb, hb_jsonEncode( oParams ) )
                ENDIF
                EXIT
            OTHERWISE
                // FORCELOCAL isolates symbols of simultaneously loaded HRBs.
                // Harbour may reuse an unloaded module's initialized STATIC frame
                // on a later load; scope isolation does not reset static values.
                // Addons must initialize per-call state from explicit parameters.
                hHrb := hb_hrbLoad( HB_HRB_BIND_FORCELOCAL, cFile )
                IF ! Empty( hHrb )
                    cResult := hb_hrbDo( hHrb, hb_jsonEncode( oParams ) )
                ENDIF
                EXIT
            ENDSWITCH
        ALWAYS
            IF ! Empty( hHrb )
                hb_hrbUnload( hHrb )
            ENDIF
        END SEQUENCE
    ENDIF
RETURN cResult

STATIC FUNCTION FileSig( cFile )

    LOCAL hFile
    LOCAL cBuff, cSig, cExt

    cExt := ".prg"
    hFile := FOpen( cFile, FO_READ )
    IF hFile != F_ERROR
        cSig := hb_hrbSignature()
        cBuff := Space( hb_BLen( cSig ) )
        FRead( hFile, @cBuff, hb_BLen( cBuff ) )
        FClose( hFile )
        IF cBuff == cSig
            cExt := ".hrb"
        ENDIF
    ENDIF

    RETURN cExt
