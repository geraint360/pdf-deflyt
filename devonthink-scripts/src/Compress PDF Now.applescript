-- PDF Deflyt for DEVONthink 4
-- Purpose: Compress the currently selected PDFs in DEVONthink using pdf-deflyt
-- Put into ~/Library/Application Scripts/com.devon-technologies.think/Menu

use framework "Foundation"
use scripting additions

on appendLog(tag, msg)
	try
		set homePath to (current application's NSHomeDirectory() as text)
		set logDir to homePath & "/Library/Logs"
		set logFile to logDir & "/pdf-deflyt.log"
		set logLine to "[" & tag & "] " & (msg as text) & linefeed
		set fm to current application's NSFileManager's defaultManager()
		set createdDir to fm's createDirectoryAtPath:logDir withIntermediateDirectories:true attributes:(missing value) |error|:(missing value)
		set existingText to ""
		if (fm's fileExistsAtPath:logFile) as boolean then
			set existingText to (current application's NSString's stringWithContentsOfFile:logFile encoding:(current application's NSUTF8StringEncoding) |error|:(missing value)) as text
		end if
		set updatedText to existingText & logLine
		set updatedString to current application's NSString's stringWithString:updatedText
		updatedString's writeToFile:logFile atomically:true encoding:(current application's NSUTF8StringEncoding) |error|:(missing value)
	end try
end appendLog

on runTask(executablePath, arguments)
	set task to current application's NSTask's launchedTaskWithLaunchPath:executablePath arguments:arguments
	task's waitUntilExit()
	return task's terminationStatus() as integer
end runTask

on sizeOfFile(posixPath)
	set fm to current application's NSFileManager's defaultManager()
	set attrs to fm's attributesOfItemAtPath:posixPath |error|:(missing value)
	return ((attrs's objectForKey:"NSFileSize") as integer)
end sizeOfFile

on tempDir()
	set fm to current application's NSFileManager's defaultManager()
	set rootDir to current application's NSTemporaryDirectory() as text
	set workDir to rootDir & "pdf-deflyt.dt"
	set ok to fm's createDirectoryAtPath:workDir withIntermediateDirectories:true attributes:(missing value) |error|:(missing value)
	if ok is false then error "Failed to create temp directory: " & workDir
	return workDir
end tempDir

on pathWithoutExtension(posixPath)
	set nsPath to current application's NSString's stringWithString:posixPath
	return nsPath's stringByDeletingPathExtension() as text
end pathWithoutExtension

on replaceFile(stagePath, sourcePath)
	set status to my runTask("/bin/mv", {"-f", stagePath, sourcePath})
	if status is not 0 then error "Failed to replace source file (" & status & ")"
end replaceFile

on removePath(posixPath)
	my runTask("/bin/rm", {"-rf", posixPath})
end removePath

on refreshRecord(r)
	try
		tell application "DEVONthink"
			set selection of window 1 to {missing value}
			set selection of window 1 to {r}
		end tell
	on error errMsg number errNum
		my appendLog("Compress Now", "WARN: refresh failed on " & (name of r as text) & ": " & errMsg & " (" & errNum & ")")
	end try
end refreshRecord

on runCompression(sourcePath, recordName, tag)
	set workDir to my tempDir()
	set outputPath to workDir & "/output.pdf"
	set sourceDir to (current application's NSString's stringWithString:sourcePath)'s stringByDeletingLastPathComponent() as text
	set inputBytes to 0
	set outputBytes to 0
	try
		set pdfDeflytPath to (current application's NSHomeDirectory() as text) & "/bin/pdf-deflyt"
		set status to my runTask("/usr/bin/env", {"PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin", pdfDeflytPath, "-p", "standard", "-o", outputPath, sourcePath})
		if status is not 0 then error "pdf-deflyt exited with status " & status

		set inputBytes to my sizeOfFile(sourcePath)
		set outputBytes to my sizeOfFile(outputPath)
		if outputBytes is greater than or equal to inputBytes then
			my appendLog(tag, "FAIL on " & recordName & ": output not smaller (" & inputBytes & " -> " & outputBytes & "); keeping original")
			my removePath(workDir)
			return false
		end if

		set stagePath to sourceDir & "/.pdf-deflyt.stage.pdf"
		set status to my runTask("/bin/cp", {"-f", outputPath, stagePath})
		if status is not 0 then error "Failed to stage output (" & status & ")"
		my replaceFile(stagePath, sourcePath)
		my removePath(workDir)
		my appendLog(tag, "Done " & recordName & " (" & inputBytes & " -> " & outputBytes & " bytes)")
		my refreshRecord(r)
		return true
	on error errMsg number errNum
		try
			my removePath(workDir)
		end try
		my appendLog(tag, "FAIL on " & recordName & ": " & errMsg & " (" & errNum & "); keeping original")
		return false
	end try
end runCompression

on compressRecord(r)
	tell application "DEVONthink"
		set pth to (path of r)
		if pth is missing value then error "Record has no file path: " & (name of r as text)
		set recordName to (name of r as text)
	end tell
	set sourcePath to POSIX path of pth
	my appendLog("Compress Now", "Starting " & recordName & " -> " & sourcePath)
	my runCompression(sourcePath, recordName, "Compress Now")
end compressRecord

	try
		tell application "DEVONthink"
			if (count of windows) is 0 then error "No DEVONthink window is open."
			set theWindow to window 1
			set sel to selection of theWindow
			if sel is {} then error "Select one or more PDF records in DEVONthink."
			repeat with r in sel
				try
					my compressRecord(r)
				on error errMsg number errNum
					my appendLog("Compress Now", "ERROR on " & (name of r as text) & ": " & errMsg & " (" & errNum & ")")
				end try
			end repeat
		end tell
	on error errMsg number errNum
		my appendLog("Compress Now", "FATAL: " & errMsg & " (" & errNum & ")")
	end try
