#!/usr/bin/env hbmk2
/*
 * Commit preparer and source checker/fixer
 *
 * Copyright 2012-2017 Viktor Szakats
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 * (or visit their website at https://www.gnu.org/licenses/).
 *
 */

#define _CONFIGFIL_ ".hbcommit/config.ini"
#define _CONFIGENV_ "HBCOMMIT_USER"

#pragma -w3
#pragma -km+
#pragma -ko+

#include "directry.ch"
#include "hbgtinfo.ch"

PROCEDURE Main()

   LOCAL cVCS
   LOCAL cVCSDir
   LOCAL cLocalRoot
   LOCAL aFiles
   LOCAL aChanges
   LOCAL cLogName
   LOCAL aInput

   IF "-c" $ cli_Options()
      aInput := cli_Values()
      IF "--list" $ cli_Options()
         IF Len( aInput ) != 1 .OR. ! hb_vfExists( aInput[ 1 ] )
            OutStd( "Missing validation file list." + hb_eol() )
            ErrorLevel( 1 )
            RETURN
         ENDIF
         aInput := hb_ATokens( StrTran( hb_MemoRead( aInput[ 1 ] ), Chr( 13 ) ), Chr( 10 ) )
      ENDIF
      ErrorLevel( iif( CheckFileList( iif( Empty( aInput ),, aInput ) ), 0, 1 ) )
      RETURN
   ENDIF

   cVCS := VCSDetect( @cVCSDir, @cLocalRoot )

   IF cVCS == "git" .AND. "--install-hook" $ cli_Options()
      OutStd( "Use pwsh scripts/commit-check.ps1 -InstallHook to install all three checks." + hb_eol() )
      ErrorLevel( 1 )
      RETURN
   ENDIF

   aFiles := {}
   aChanges := DoctorChanges( cVCS, Changes( cVCS ), aFiles )

   IF Empty( aChanges )
      OutStd( hb_ProgName() + ": " + "no changes" + hb_eol() )
      ErrorLevel( 0 )
      RETURN
   ENDIF

   IF CheckFileList( aFiles, cLocalRoot, .F. )

      IF ! "--check-only" $ cli_Options() .AND. ;
         ! "--prepare-commit" $ cli_Options()

         hb_MemoWrit( cLogName := cLocalRoot + "_commit.txt", MakeEntry( aChanges ) )

         OutStd( hb_ProgName() + ": " + hb_StrFormat( "Edit %1$s and commit", cLogName ) + hb_eol() )
#if 0
         LaunchCommand( GitEditor(), cLogName )
#endif
      ENDIF

      ErrorLevel( 0 )
   ELSE
      OutStd( hb_ProgName() + ": " + "Please correct errors listed above and re-run" + hb_eol() )
      ErrorLevel( 1 )
   ENDIF

   RETURN

STATIC FUNCTION cli_Options()

   THREAD STATIC t_hOptions

   LOCAL tmp
   LOCAL nArg

   IF t_hOptions == NIL
      t_hOptions := { => }
      nArg := 1
      FOR tmp := 1 TO hb_argc()
         IF hb_LeftEq( hb_argv( tmp ), "-" )
            t_hOptions[ hb_argv( tmp ) ] := nArg
         ELSE
            ++nArg
         ENDIF
      NEXT
   ENDIF

   RETURN t_hOptions

STATIC FUNCTION cli_Values()

   THREAD STATIC t_aValues

   LOCAL tmp

   IF t_aValues == NIL
      t_aValues := {}
      FOR tmp := 1 TO hb_argc()
         IF ! hb_LeftEq( hb_argv( tmp ), "-" )
            AAdd( t_aValues, hb_argv( tmp ) )
         ENDIF
      NEXT
   ENDIF

   RETURN t_aValues

STATIC FUNCTION CommitScript()

   LOCAL cBaseName := hb_FNameName( hb_ProgName() ) + ".hb"
   LOCAL cName

   IF hb_vfExists( cName := hb_DirSepToOS( ".hbcommit/" ) + cBaseName )
      RETURN cName
   ENDIF

   RETURN cBaseName

STATIC FUNCTION InstallHook( cDir, cHookName, cCommand )

   LOCAL cName := hb_DirSepAdd( cDir ) + hb_DirSepToOS( "hooks/" ) + cHookName
   LOCAL cFile := hb_MemoRead( cName )

   cCommand := StrTran( cCommand, "\", "/" )

   IF cCommand $ cFile
      RETURN .T.
   ENDIF

   IF cFile == ""
      cFile += "#!/bin/sh" + Chr( 10 )
   ENDIF

   RETURN hb_MemoWrit( cName, cFile + Chr( 10 ) + cCommand + Chr( 10 ) )

STATIC FUNCTION GetLastEntry( cLog, /* @ */ nStart, /* @ */ nEnd )

   LOCAL cLogHeaderExp := "\n[1-2][0-9][0-9][0-9]-[0-1][0-9]-[0-3][0-9] [0-2][0-9]:[0-6][0-9] [\S ]*"

   LOCAL cOldCP := hb_cdpSelect( "cp437" )
   LOCAL cHit

   nEnd := 0

   IF Empty( cHit := hb_AtX( cLogHeaderExp, cLog ) )
      cHit := ""
   ENDIF

   IF ( nStart := At( AllTrim( cHit ), cLog ) ) > 0

      IF Empty( cHit := hb_AtX( cLogHeaderExp, cLog,, nStart + Len( cHit ) ) )
         cHit := ""
      ENDIF

      IF ( nEnd := At( AllTrim( cHit ), cLog ) ) == 0
         nEnd := Len( cLog )
      ENDIF

      cLog := RTrimEOL( SubStr( cLog, nStart, nEnd - nStart ) )
   ELSE
      cLog := ""
   ENDIF

   hb_cdpSelect( cOldCP )

   RETURN cLog

STATIC FUNCTION MakeEntry( aChanges )

   LOCAL cLog := "module: edit my changes" + hb_eol() + hb_eol()
   LOCAL cLine

   FOR EACH cLine IN aChanges
      cLog += cLine + hb_eol()
   NEXT

   RETURN cLog

STATIC FUNCTION VCSDetect( /* @ */ cVCSDir, /* @ */ cLocalRoot )

   DO CASE
   CASE hb_vfDirExists( ".svn" )
      cVCSDir := hb_DirSepToOS( "./.svn/" )
      cLocalRoot := hb_DirSepToOS( "./" )
      RETURN "svn"
   CASE hb_vfDirExists( ".git" )
      cVCSDir := hb_DirSepToOS( "./.git/" )
      cLocalRoot := hb_DirSepToOS( "./" )
      RETURN "git"
   CASE GitDetect( @cVCSDir )
      cVCSDir := cVCSDir
      cLocalRoot := GitLocalRoot()
      RETURN "git"
   ENDCASE

   cVCSDir := ""

   RETURN ""

STATIC FUNCTION GitDetect( /* @ */ cGitDir )

   LOCAL cStdOut, cStdErr
   LOCAL nResult := hb_processRun( "git rev-parse --is-inside-work-tree",, @cStdOut, @cStdErr )

   IF nResult == 0 .AND. hb_StrReplace( cStdOut, Chr( 13 ) + Chr( 10 ) ) == "true"
      hb_processRun( "git rev-parse --git-dir",, @cGitDir )
      cGitDir := hb_DirSepAdd( hb_DirSepToOS( hb_StrReplace( cGitDir, Chr( 13 ) + Chr( 10 ) ) ) )
      RETURN .T.
   ENDIF

   RETURN .F.

STATIC FUNCTION GitLocalRoot()

   LOCAL cStdOut, cStdErr
   LOCAL nResult := hb_processRun( "git rev-parse --show-toplevel",, @cStdOut, @cStdErr )

   RETURN iif( nResult == 0, hb_DirSepAdd( hb_DirSepToOS( hb_StrReplace( cStdOut, Chr( 13 ) + Chr( 10 ) ) ) ), "" )

STATIC FUNCTION GitFileList()

   LOCAL cStdOut
   LOCAL nResult := hb_processRun( "git ls-files",, @cStdOut )
   LOCAL aList := iif( nResult == 0, hb_ATokens( cStdOut, .T. ), {} )
   LOCAL cItem

   FOR EACH cItem IN aList DESCEND
      IF cItem == ""
         hb_ADel( aList, cItem:__enumIndex(), .T. )
      ELSE
         cItem := hb_DirSepToOS( cItem )
      ENDIF
   NEXT

   RETURN aList

STATIC FUNCTION GitEditor()

   LOCAL cValue

   hb_processRun( Shell() + " " + CmdEscape( "git config --global core.editor" ),, @cValue )

   cValue := hb_StrReplace( cValue, Chr( 10 ) + Chr( 13 ) )

   IF Left( cValue, 1 ) == "'" .AND. Right( cValue, 1 ) == "'"
      cValue := hb_StrShrink( SubStr( cValue, 2 ) )
   ENDIF

   IF Lower( cValue ) == "notepad.exe"  /* banned, use notepad2.exe or else */
      cValue := ""
   ENDIF

   RETURN cValue

STATIC FUNCTION DoctorChanges( cVCS, aChanges, aFiles )

   LOCAL cLine
   LOCAL cStart
   LOCAL aNew := {}

   LOCAL cFile
   LOCAL tmp

   ASort( aChanges )

   SWITCH cVCS
   CASE "svn"

      FOR EACH cLine IN aChanges
         IF ! Empty( cLine ) .AND. SubStr( cLine, 8, 1 ) == " "
            cStart := Left( cLine, 1 )
            SWITCH cStart
            CASE "M"
            CASE " "  ; cStart := "*" ; EXIT  /* modified props */
            CASE "A"  ; cStart := "+" ; EXIT
            CASE "D"  ; cStart := "-" ; EXIT
            CASE "X"  ; cStart := "" ; EXIT
            OTHERWISE ; cStart := "?"
            ENDSWITCH
            IF ! cStart == ""
               AAdd( aNew, "  " + cStart + " " + StrTran( SubStr( cLine, 8 + 1 ), "\", "/" ) )
               IF ! cStart == "-"
                  AAdd( aFiles, SubStr( cLine, 8 + 1 ) )
               ENDIF
            ENDIF
         ENDIF
      NEXT
      EXIT

   CASE "git"

      FOR EACH cLine IN aChanges
         IF ! Empty( cLine ) .AND. SubStr( cLine, 3, 1 ) == " "
            cStart := Left( cLine, 1 )
            IF Empty( Left( cLine, 1 ) )
               cStart := SubStr( cLine, 2, 1 )
            ENDIF
            SWITCH cStart
            CASE " "
            CASE "?"  ; cStart := "" ; EXIT
            CASE "M"
            CASE "R"
            CASE "T"
            CASE "U"  ; cStart := "*" ; EXIT
            CASE "A"
            CASE "C"  ; cStart := "+" ; EXIT
            CASE "D"  ; cStart := "-" ; EXIT
            OTHERWISE ; cStart := "?"
            ENDSWITCH
            IF ! cStart == ""
               AAdd( aNew, "  " + cStart + " " + StrTran( SubStr( cLine, 3 + 1 ), "\", "/" ) )
               IF ! cStart == "-"
                  cFile := SubStr( cLine, 3 + 1 )
                  IF ( tmp := At( " -> ", cFile ) ) > 0
                     cFile := SubStr( cFile, tmp + Len( " -> " ) )
                  ENDIF
                  AAdd( aFiles, cFile )
               ENDIF
            ENDIF
         ENDIF
      NEXT
      EXIT

   ENDSWITCH

   RETURN aNew

STATIC FUNCTION Shell()

   LOCAL cShell

#if defined( __PLATFORM__UNIX )
   cShell := GetEnv( "SHELL" )
#else
   cShell := GetEnv( "COMSPEC" )
#endif

   IF ! cShell == ""
#if defined( __PLATFORM__UNIX )
      cShell += " -c"
#else
      cShell += " /c"
#endif
   ENDIF

   RETURN cShell

STATIC FUNCTION CmdEscape( cCmd )

#if defined( __PLATFORM__UNIX )
   cCmd := '"' + cCmd + '"'
#endif

   RETURN cCmd

STATIC FUNCTION Changes( cVCS )

   LOCAL cStdOut

   SWITCH cVCS
   CASE "svn" ; hb_processRun( Shell() + " " + CmdEscape( "svn status -q" ),, @cStdOut ) ; EXIT
   /* FIXME: This will inconveniently (for us) return all files as changed, where
             automatic EOL conversion is going to be done by Git on commit. */
   CASE "git" ; hb_processRun( Shell() + " " + CmdEscape( "git status --porcelain" ),, @cStdOut ) ; EXIT
   OTHERWISE ; cStdOut := ""
   ENDSWITCH

   RETURN hb_ATokens( cStdOut, .T. )

#if 0
STATIC FUNCTION LaunchCommand( cCommand, cArg )

   IF cCommand == ""
      RETURN -1
   ENDIF

#if defined( __PLATFORM__WINDOWS )
   IF hb_osIsWinNT()
      cCommand := 'start "" "' + cCommand + '"'
   ELSE
      cCommand := "start " + cCommand
   ENDIF
#elif defined( __PLATFORM__OS2 )
   cCommand := 'start "" "' + cCommand + '"'
#endif

   RETURN hb_run( cCommand + " " + cArg )
#endif

/* Shared hbBridge file policies; retain the upstream tool's preparation flow. */
#define HBBRIDGE_CHECK_EMBEDDED
#include "check.hb"
