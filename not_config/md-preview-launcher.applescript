on run
	launchPreview("")
end run

on open markdownFiles
	set shellArguments to ""
	repeat with markdownFile in markdownFiles
		set shellArguments to shellArguments & " " & quoted form of POSIX path of markdownFile
	end repeat
	launchPreview(shellArguments)
end open

on launchPreview(shellArguments)
	set previewCommand to (system attribute "HOME") & "/.local/share/mise/shims/md-preview"
	try
		do shell script "test -x " & quoted form of previewCommand
	on error
		display dialog "md-previewが見つかりません。chezmoi applyまたはmise installを実行してください。" buttons {"OK"} default button "OK" with icon stop
		return
	end try

	do shell script "/usr/bin/nohup " & quoted form of previewCommand & shellArguments & " >/tmp/md-preview-launcher.log 2>&1 &"
end launchPreview
