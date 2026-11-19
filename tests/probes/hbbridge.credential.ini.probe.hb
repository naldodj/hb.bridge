/* Released to Public Domain. Standalone, synthetic INI planning probe. */

PROCEDURE HBBridgeCredentialINIProbe()
    LOCAL cBOM := Chr( 239 ) + Chr( 187 ) + Chr( 191 ), cCRLF := Chr( 13 ) + Chr( 10 )
    LOCAL cEnvelope := "enc:v1:" + hb_base64Encode( Replicate( "x", 41 ) )
    LOCAL cError, cInput, cExpected, cResult
    LOCAL hDefaults := {=>}
    LOCAL nFailures := 0

    cInput := cBOM + "# Test" + cCRLF + "[Credential/example]" + cCRLF + ;
        "User=fixture" + cCRLF + "KeyId=key" + cCRLF + "Password = enc:v1:previous" + cCRLF + ;
        "[Credential/example2]" + cCRLF + "User=other" + cCRLF + "KeyId=key" + cCRLF + ;
        "Password=enc:v1:previous" + cCRLF
    cExpected := StrTran( cInput, "Password = enc:v1:previous", "Password = " + cEnvelope )
    cResult := HBBridgeCredentialPlanINI( cInput, "example", cEnvelope, hDefaults, @cError )
    IF ! HB_ISSTRING( cResult ) .OR. cResult != cExpected .OR. cError != ""
        nFailures++
    ENDIF
    cResult := HBBridgeCredentialPlanINI( cInput, "example", "enc:v1:bad", hDefaults, @cError )
    IF cResult != NIL .OR. cError != "INVALID_CREDENTIAL_UPDATE"
        nFailures++
    ENDIF
    cResult := HBBridgeCredentialPlanINI( cInput + "[Credential/example]" + cCRLF, ;
        "example", cEnvelope, hDefaults, @cError )
    IF cResult != NIL .OR. cError != "INVALID_CREDENTIAL_UPDATE"
        nFailures++
    ENDIF
    ? "Credential INI planner synthetic checks: 3; failures:", nFailures
    ErrorLevel( iif( nFailures == 0, 0, 1 ) )
RETURN
