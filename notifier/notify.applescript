-- Shows the notifications the plugin queued as files (line 1: title, line 2: body), then quits.
on run
	set queueDir to (POSIX path of (path to home folder)) & "Library/Caches/claude-usage-swiftbar/notifications/"
	try
		set queued to paragraphs of (do shell script "ls " & quoted form of queueDir & " 2>/dev/null | grep '\\.txt$' | sort")
	on error
		return
	end try
	repeat with fileName in queued
		-- Claim the file first so parallel instances never show the same notification twice.
		set filePath to queueDir & fileName & ".shown"
		try
			do shell script "mv " & quoted form of (queueDir & fileName) & " " & quoted form of filePath
			set msg to paragraphs of (read (POSIX file filePath) as «class utf8»)
			display notification (item 2 of msg) with title (item 1 of msg) sound name "Glass"
			delay 1
			do shell script "rm -f " & quoted form of filePath
		end try
	end repeat
end run
